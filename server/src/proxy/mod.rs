mod socks5;
mod tls;

use std::net::SocketAddr;
use std::sync::Arc;

use tokio::net::TcpListener;
use tracing::{error, info};

use crate::config::{AppState, Config, ProxyMode};

pub async fn serve(addr: SocketAddr, config: Config, state: AppState) -> Result<(), anyhow::Error> {
    let state = Arc::new(state);
    let listener = TcpListener::bind(addr).await?;

    match &config.proxy_mode {
        ProxyMode::Plaintext => {
            info!("SOCKS5 proxy (plaintext) listening on {}", addr);
            serve_plaintext(listener, state).await
        }
        ProxyMode::Tls {
            cert_path,
            key_path,
        } => {
            let acceptor = tls::build_acceptor(cert_path, key_path)?;
            info!("SOCKS5 proxy (TLS) listening on {}", addr);
            serve_tls(listener, acceptor, state).await
        }
    }
}

async fn serve_plaintext(listener: TcpListener, state: Arc<AppState>) -> Result<(), anyhow::Error> {
    loop {
        let (stream, peer_addr) = match listener.accept().await {
            Ok(conn) => conn,
            Err(e) => {
                error!("accept error: {}", e);
                continue;
            }
        };

        let state = state.clone();

        tokio::spawn(async move {
            if let Err(e) = socks5::handle_plaintext(stream, peer_addr, &state).await {
                error!("SOCKS5 error from {}: {}", peer_addr, e);
            }
        });
    }
}

async fn serve_tls(
    listener: TcpListener,
    acceptor: tokio_rustls::TlsAcceptor,
    state: Arc<AppState>,
) -> Result<(), anyhow::Error> {
    loop {
        let (stream, peer_addr) = match listener.accept().await {
            Ok(conn) => conn,
            Err(e) => {
                error!("accept error: {}", e);
                continue;
            }
        };

        let acceptor = acceptor.clone();
        let state = state.clone();

        tokio::spawn(async move {
            match acceptor.accept(stream).await {
                Ok(tls_stream) => {
                    if let Err(e) = socks5::handle_tls(tls_stream, peer_addr, &state).await {
                        error!("SOCKS5 error from {}: {}", peer_addr, e);
                    }
                }
                Err(e) => {
                    error!("TLS handshake error from {}: {}", peer_addr, e);
                }
            }
        });
    }
}
