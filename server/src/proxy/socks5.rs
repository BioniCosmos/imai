use std::net::SocketAddr;
use std::sync::Arc;

use fast_socks5::server::{transfer, Socks5ServerProtocol};
use fast_socks5::{ReplyError, Socks5Command, SocksError};
use tokio::io::{AsyncBufReadExt, AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt};
use tracing::{debug, error, info};

use crate::config::AppState;
use crate::oauth;

/// Core SOCKS5 serve loop using fast-socks5. Generic over the stream type so
/// it works for both plaintext TcpStream and TLS-wrapped streams.
pub(super) async fn serve_socks5<S>(socket: S, state: &Arc<AppState>) -> Result<(), SocksError>
where
    S: AsyncRead + AsyncWrite + Unpin,
{
    // Accept no-auth, read the CONNECT command. We do NOT resolve DNS here
    // because we want to inspect the domain ourselves.
    let (proto, cmd, target_addr) = Socks5ServerProtocol::accept_no_auth(socket)
        .await?
        .read_command()
        .await?;

    if cmd != Socks5Command::TCPConnect {
        proto.reply_error(&ReplyError::CommandNotSupported).await?;
        return Err(ReplyError::CommandNotSupported.into());
    }

    debug!("SOCKS5 CONNECT request to {:?}", target_addr);

    // Send SOCKS5 success reply, getting back the inner stream to talk to
    // the client. From here the client will send its HTTP request.
    let inner = proto
        .reply_success(SocketAddr::new(
            std::net::IpAddr::V4(std::net::Ipv4Addr::new(127, 0, 0, 1)),
            0,
        ))
        .await?;

    // Read the HTTP request the client sends after the SOCKS5 reply.
    let (inner, http_data) = read_http_request(inner).await?;

    // Check if this is the wahlap OAuth callback.
    if is_oauth_callback(&http_data) {
        info!("SOCKS5: OAuth callback intercepted!");
        handle_callback_intercept(inner, &http_data, state).await?;
        return Ok(());
    }

    // Otherwise, forward to the real destination.
    let (host, port) = target_addr.into_string_and_port();
    let remote = match tokio::net::TcpStream::connect((host.as_str(), port)).await {
        Ok(conn) => conn,
        Err(e) => {
            error!("SOCKS5: failed to connect to {}:{}: {}", host, port, e);
            return Ok(());
        }
    };

    // Write the buffered HTTP request to the remote, then bidirectional copy.
    let mut remote = remote;
    remote.write_all(&http_data).await?;

    transfer(inner, remote).await;
    Ok(())
}

/// Read enough data to parse the HTTP request line + headers (+ body).
async fn read_http_request<S>(stream: S) -> Result<(S, Vec<u8>), anyhow::Error>
where
    S: AsyncRead + AsyncWrite + Unpin,
{
    let mut reader = tokio::io::BufReader::new(stream);
    let mut buf = Vec::new();

    // Read until \r\n\r\n (end of HTTP headers).
    loop {
        let mut line = String::new();
        let n = reader.read_line(&mut line).await?;
        if n == 0 {
            break;
        }
        buf.extend_from_slice(line.as_bytes());
        if line == "\r\n" {
            break;
        }
        if buf.len() > 65536 {
            anyhow::bail!("HTTP headers too large");
        }
    }

    // Read Content-Length body if present.
    let headers_str = String::from_utf8_lossy(&buf);
    let content_length = headers_str
        .lines()
        .find(|l| l.to_lowercase().starts_with("content-length"))
        .and_then(|l| l.split(':').nth(1))
        .and_then(|v| v.trim().parse::<usize>().ok());

    if let Some(len) = content_length {
        let mut body = vec![0u8; len];
        reader.read_exact(&mut body).await?;
        buf.extend_from_slice(&body);
    }

    let stream = reader.into_inner();
    Ok((stream, buf))
}

/// Check if the HTTP request is the wahlap OAuth callback.
fn is_oauth_callback(data: &[u8]) -> bool {
    let s = String::from_utf8_lossy(data);
    s.contains("/wc_auth/oauth/callback/maimai-dx") && s.contains("code=")
}

/// Intercept the OAuth callback: extract code/state/r, associate with task,
/// return a success page to the client (WeChat).
async fn handle_callback_intercept<S>(
    mut stream: S,
    data: &[u8],
    state: &AppState,
) -> Result<(), SocksError>
where
    S: AsyncRead + AsyncWrite + Unpin,
{
    let http_str = String::from_utf8_lossy(data);

    let first_line = http_str.lines().next().unwrap_or("");
    let path = first_line.split_whitespace().nth(1).unwrap_or("");

    let code = extract_param(path, "code").unwrap_or_default();
    let oauth_state = extract_param(path, "state").unwrap_or_default();
    let oauth_r = extract_param(path, "r").unwrap_or_default();

    info!(
        "SOCKS5 CALLBACK: code={}..., state={}, r={}",
        &code[..code.len().min(20)],
        oauth_state,
        oauth_r
    );

    if code.is_empty() || oauth_state.is_empty() {
        let body = "<html><body><h1>Error: missing code or state</h1></body></html>";
        let resp = format!(
            "HTTP/1.1 400 Bad Request\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
            body.len(), body
        );
        stream.write_all(resp.as_bytes()).await?;
        return Ok(());
    }

    // Use the original request path as the callback URL (just switch scheme to
    // https, exactly like Android does).
    let callback_url = format!("https://tgk-wcaime.wahlap.com{}", path);

    if let Err(e) = oauth::handle_callback(&state.db, &oauth_state, &oauth_r, &callback_url).await {
        error!("handle_callback error: {:?}", e);
    }

    let body = "<html><body><h1>登录信息已获取，可关闭该窗口并请切回到更新器等待分数上传!</h1></body></html>";
    let resp = format!(
        "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
        body.len(), body
    );
    stream.write_all(resp.as_bytes()).await?;

    Ok(())
}

/// Extract a query parameter value from a URL path.
fn extract_param(path: &str, name: &str) -> Option<String> {
    let prefix = format!("{}=", name);
    let qs = path.split('?').nth(1)?;
    for part in qs.split('&') {
        if let Some(v) = part.strip_prefix(&prefix) {
            return Some(v.to_string());
        }
    }
    None
}
