use anyhow::Context;
use reqwest::header::{HeaderMap, HeaderValue};
use reqwest::Client;
use tracing::{debug, info};

const WECHAT_AUTHORIZE_URL: &str =
    "https://tgk-wcaime.wahlap.com/wc_auth/oauth/authorize/maimai-dx";
const MAIMAI_SCORES_URL: &str = "https://maimai.wahlap.com/maimai-mobile/record/musicGenre/search/";

const ANDROID_WX_UA: &str = "Mozilla/5.0 (Linux; Android 12; IN2010 Build/RKQ1.211119.001; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/86.0.4240.99 XWEB/4317 MMWEBSDK/20220903 Mobile Safari/537.36 MMWEBID/363 MicroMessenger/8.0.28.2240(0x28001C57) WeChat/arm64 Weixin NetType/WIFI Language/zh_CN ABI/arm64";
const WINDOWS_WX_UA: &str = "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/81.0.4044.138 Safari/537.36 NetType/WIFI MicroMessenger/7.0.20.1781(0x6700143B) WindowsWechat(0x6307001e)";

#[derive(Clone)]
pub struct WahlapClient {
    client: Client,
}

impl WahlapClient {
    pub fn new() -> Result<Self, anyhow::Error> {
        let client = Client::builder()
            .cookie_store(true)
            .redirect(reqwest::redirect::Policy::none())
            .build()?;
        Ok(Self { client })
    }

    /// Build headers matching Android WeChat UA (for authorize step).
    fn android_headers() -> HeaderMap {
        let mut headers = HeaderMap::new();
        headers.insert("Host", HeaderValue::from_static("tgk-wcaime.wahlap.com"));
        headers.insert("Upgrade-Insecure-Requests", HeaderValue::from_static("1"));
        headers.insert("User-Agent", HeaderValue::from_static(ANDROID_WX_UA));
        headers.insert(
            "Accept",
            HeaderValue::from_static(
                "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/wxpic,\
                 image/tpg,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9",
            ),
        );
        headers.insert(
            "X-Requested-With",
            HeaderValue::from_static("com.tencent.mm"),
        );
        headers.insert("Sec-Fetch-Site", HeaderValue::from_static("none"));
        headers.insert("Sec-Fetch-Mode", HeaderValue::from_static("navigate"));
        headers.insert("Sec-Fetch-User", HeaderValue::from_static("?1"));
        headers.insert("Sec-Fetch-Dest", HeaderValue::from_static("document"));
        headers.insert(
            "Accept-Language",
            HeaderValue::from_static("zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7"),
        );
        headers
    }

    /// Build headers matching Windows WeChat UA (for login + score fetching).
    fn windows_headers() -> HeaderMap {
        let mut headers = HeaderMap::new();
        headers.insert("Connection", HeaderValue::from_static("keep-alive"));
        headers.insert("Upgrade-Insecure-Requests", HeaderValue::from_static("1"));
        headers.insert("User-Agent", HeaderValue::from_static(WINDOWS_WX_UA));
        headers.insert(
            "Accept",
            HeaderValue::from_static(
                "text/html,application/xhtml+xml,application/xml;q=0.9,\
                 image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9",
            ),
        );
        headers.insert("Sec-Fetch-Site", HeaderValue::from_static("none"));
        headers.insert("Sec-Fetch-Mode", HeaderValue::from_static("navigate"));
        headers.insert("Sec-Fetch-User", HeaderValue::from_static("?1"));
        headers.insert("Sec-Fetch-Dest", HeaderValue::from_static("document"));
        headers.insert(
            "Accept-Language",
            HeaderValue::from_static("zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7"),
        );
        headers
    }

    /// Step 3: GET wahlap authorize endpoint, return the 302 Location header.
    /// The Location points to open.weixin.qq.com with redirect_uri and state.
    pub async fn get_authorize_location(&self) -> Result<String, anyhow::Error> {
        info!("[WAHLAP] Requesting authorize URL...");
        let resp = self
            .client
            .get(WECHAT_AUTHORIZE_URL)
            .headers(Self::android_headers())
            .send()
            .await
            .context("failed to request authorize URL")?;

        let status = resp.status();
        info!("[WAHLAP] authorize status: {}", status);

        if !status.is_redirection() {
            let body = resp.text().await.unwrap_or_default();
            let preview: String = body.chars().take(500).collect();
            anyhow::bail!(
                "authorize endpoint did not redirect: status={}, body=\n{}",
                status,
                preview
            );
        }

        let location = resp
            .headers()
            .get("Location")
            .context("no Location header in authorize response")?
            .to_str()
            .context("invalid Location header")?
            .to_string();

        info!(
            "[WAHLAP] Got Location: {}...",
            &location[..location.len().min(200)]
        );
        Ok(location)
    }

    /// Rewrite redirect_uri from https to http so the callback goes through
    /// the proxy (plain HTTP, not HTTPS CONNECT tunnel).
    pub fn rewrite_redirect_uri(location: &str) -> String {
        location.replace("redirect_uri=https", "redirect_uri=http")
    }

    /// Step 6: Login to wahlap using the OAuth code.
    /// Follows the redirect chain with Windows WeChat UA, collecting cookies.
    pub async fn login_wechat(&self, callback_url: &str) -> Result<(), anyhow::Error> {
        info!("[WAHLAP] Login: following redirect chain...");
        let mut current_url = callback_url.to_string();

        for i in 0..10 {
            debug!(
                "[WAHLAP] Login request {}: {}",
                i + 1,
                &current_url[..current_url.len().min(120)]
            );

            let resp = self
                .client
                .get(&current_url)
                .headers(Self::windows_headers())
                .send()
                .await?;

            let status = resp.status();
            debug!("[WAHLAP] Login status: {}", status);

            if let Some(location) = resp.headers().get("Location") {
                let loc = location.to_str()?.to_string();
                // Resolve relative redirects against the current URL.
                current_url = match url::Url::parse(&loc) {
                    Ok(abs) => abs.to_string(),
                    Err(url::ParseError::RelativeUrlWithoutBase) => {
                        let base = url::Url::parse(&current_url)?;
                        base.join(&loc)?.to_string()
                    }
                    Err(e) => return Err(e.into()),
                };
            } else {
                debug!("[WAHLAP] No more redirects, login complete");
                break;
            }

            if !status.is_redirection() {
                break;
            }
        }

        info!("[WAHLAP] Login complete");
        Ok(())
    }

    /// Step 6: Fetch maimai score HTML for a given difficulty.
    pub async fn fetch_scores(&self, diff: i32) -> Result<String, anyhow::Error> {
        let url = format!("{}?genre=99&diff={}", MAIMAI_SCORES_URL, diff);
        info!("[WAHLAP] Fetching scores: diff={}", diff);

        let resp = self
            .client
            .get(&url)
            .header("Host", "maimai.wahlap.com")
            .header("User-Agent", WINDOWS_WX_UA)
            .send()
            .await
            .context("failed to fetch scores")?;

        let status = resp.status();
        let body = resp.text().await?;

        if !status.is_success() {
            anyhow::bail!(
                "scores fetch failed: status={}, body_len={}",
                status,
                body.len()
            );
        }

        if body.contains("错误") || body.contains("error") {
            anyhow::bail!("error page detected in scores response");
        }

        info!("[WAHLAP] Scores fetched: diff={}, len={}", diff, body.len());
        Ok(body)
    }
}
