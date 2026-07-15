use anyhow::Context;
use sqlx::types::Uuid;
use sqlx::PgPool;
use tokio::task::JoinSet;
use tracing::{error, info};

use crate::db;
use crate::wahlap::WahlapClient;

/// Step 3: When WeChat opens /tasks/{task_id}, request wahlap authorize URL,
/// extract state + r, store them in DB, and return the rewritten Location.
pub async fn prepare_authorize(db: &PgPool, task_id: Uuid) -> Result<String, anyhow::Error> {
    let _task = db::get_task(db, task_id).await?.context("task not found")?;

    let client = WahlapClient::new()?;
    let location = client.get_authorize_location().await?;

    // Parse the Location URL properly. The structure is:
    //   https://open.weixin.qq.com/connect/oauth2/authorize
    //     ?appid=...
    //     &redirect_uri=https%3A%2F%2Ftgk-wcaime.wahlap.com%2Fwc_auth%2Foauth%2Fcallback%2Fmaimai-dx%3Fr%3Duslf0Lbyrx6z%26t%3D...
    //     &state=CB936...#wechat_redirect
    //
    // `state` is a top-level query param (with a trailing #wechat_redirect fragment
    // that url::Url strips into the fragment). `r` lives *inside* the URL-encoded
    // redirect_uri, as a query param of the callback path.
    let parsed = url::Url::parse(&location).context("failed to parse authorize Location")?;

    let oauth_state = parsed
        .query_pairs()
        .find(|(k, _)| k == "state")
        .map(|(_, v)| v.to_string())
        .context("no state in authorize Location")?;

    // Decode redirect_uri and pull `r` out of its query string.
    let redirect_uri = parsed
        .query_pairs()
        .find(|(k, _)| k == "redirect_uri")
        .map(|(_, v)| v.to_string())
        .context("no redirect_uri in authorize Location")?;

    let callback = url::Url::parse(&redirect_uri).context("failed to parse redirect_uri")?;
    let oauth_r = callback
        .query_pairs()
        .find(|(k, _)| k == "r")
        .map(|(_, v)| v.to_string())
        .unwrap_or_default();

    info!(
        "[OAUTH] task={}, state={}, r={}",
        task_id, &oauth_state, &oauth_r
    );

    // Store state + r association in DB.
    db::set_oauth_state(db, task_id, &oauth_state, &oauth_r).await?;

    // Rewrite redirect_uri: https → http.
    let rewritten = WahlapClient::rewrite_redirect_uri(&location);
    info!(
        "[OAUTH] rewritten Location: {}...",
        &rewritten[..rewritten.len().min(200)]
    );

    Ok(rewritten)
}

/// Step 5: Proxy intercepted the OAuth callback.
/// Extract code, find task by state + r, and trigger fetch+upload.
pub async fn handle_callback(
    db: &PgPool,
    oauth_state: &str,
    oauth_r: &str,
    code: &str,
) -> Result<(), anyhow::Error> {
    info!(
        "[CALLBACK] state={}, r={}, code={}...",
        oauth_state,
        oauth_r,
        &code[..code.len().min(20)]
    );

    let task = db::find_task_by_oauth(db, oauth_state, oauth_r)
        .await?
        .context("no task found for oauth state+r")?;

    info!("[CALLBACK] matched task={}", task.id);

    // Store the code.
    db::set_oauth_code(db, task.id, code).await?;

    // Spawn background fetch to avoid blocking the proxy response.
    let db_clone = db.clone();
    let task_id = task.id;
    let code_owned = code.to_string();

    tokio::spawn(async move {
        if let Err(e) = fetch_and_upload(&db_clone, task_id, &code_owned).await {
            error!("[CALLBACK] fetch_and_upload failed: {:?}", e);
            let _ = db::set_task_results(&db_clone, task_id, &[], Some(&format!("{:?}", e))).await;
        }
    });

    Ok(())
}

/// Step 6: Login, fetch scores, upload to Diving-Fish.
async fn fetch_and_upload(db: &PgPool, task_id: Uuid, code: &str) -> Result<(), anyhow::Error> {
    let task = db::get_task(db, task_id)
        .await?
        .context("task disappeared")?;

    db::set_task_state(db, task_id, crate::models::TaskState::Fetching).await?;

    // Login to wahlap with the OAuth code.
    let client = WahlapClient::new()?;
    client.login_wechat(code).await?;

    // Fetch scores for each difficulty and upload to Diving-Fish in parallel.
    let diff_names = ["Basic", "Advanced", "Expert", "Master", "Re:Master"];
    let mut set = JoinSet::new();

    for &diff in &task.difficulties {
        let name = diff_names
            .get(diff as usize)
            .map(|s| s.to_string())
            .unwrap_or_else(|| format!("diff_{}", diff));

        let username = task.df_username.clone();
        let password = task.df_password.clone();
        let client = client.clone();

        set.spawn(async move {
            info!("[FETCH] Processing {} (diff={})", name, diff);

            match fetch_and_upload_one(&client, &username, &password, diff, &name).await {
                Ok(()) => crate::models::DifficultyResult {
                    difficulty: diff,
                    name,
                    status: "success".into(),
                    error: None,
                },
                Err(e) => {
                    error!("[FETCH] {} failed: {:?}", name, e);
                    crate::models::DifficultyResult {
                        difficulty: diff,
                        name,
                        status: "failed".into(),
                        error: Some(format!("{:?}", e)),
                    }
                }
            }
        });
    }

    let mut results = Vec::new();
    while let Some(res) = set.join_next().await {
        match res {
            Ok(result) => results.push(result),
            Err(e) => {
                error!("[FETCH] task join error: {:?}", e);
            }
        }
    }

    db::set_task_results(db, task_id, &results, None).await?;
    info!(
        "[FETCH] task={} complete, {} results",
        task_id,
        results.len()
    );

    Ok(())
}

async fn fetch_and_upload_one(
    client: &WahlapClient,
    df_username: &str,
    df_password: &str,
    diff: i32,
    name: &str,
) -> Result<(), anyhow::Error> {
    let html = client.fetch_scores(diff).await?;
    info!("[FETCH] {} HTML: {} bytes", name, html.len());

    // Upload to Diving-Fish pageparser.
    crate::fetcher::upload_to_divingfish(df_username, df_password, &html).await?;
    info!("[FETCH] {} uploaded successfully", name);

    Ok(())
}
