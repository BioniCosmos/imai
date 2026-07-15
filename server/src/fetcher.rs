use anyhow::Context;
use reqwest::Client;
use tracing::info;

/// Upload maimai score HTML to Diving-Fish pageparser API.
/// Wraps the HTML with login credentials as the Android app does:
/// `<login><u>{username}</u><p>{password}</p></login>{html}`
pub async fn upload_to_divingfish(
    username: &str,
    password: &str,
    html: &str,
) -> Result<(), anyhow::Error> {
    let body = format!(
        "<login><u>{}</u><p>{}</p></login>{}",
        username, password, html
    );

    info!(
        "[DIVINGFISH] Uploading to pageparser ({} bytes)...",
        body.len()
    );

    let client = Client::builder().build()?;

    let resp = client
        .post("https://www.diving-fish.com/api/pageparser/page")
        .header("Content-Type", "text/plain")
        .body(body)
        .send()
        .await
        .context("failed to send pageparser request")?;

    let status = resp.status();
    let response_text = resp.text().await?;

    info!(
        "[DIVINGFISH] Response: status={}, body={}",
        status, response_text
    );

    if !status.is_success() {
        anyhow::bail!("pageparser returned {}: {}", status, response_text);
    }

    Ok(())
}
