use axum::extract::{Path, State};
use axum::http::{header, StatusCode};
use axum::response::{IntoResponse, Response};
use sqlx::types::Uuid;

use crate::config::AppState;
use crate::oauth;

/// GET /tasks/{task_id}
///
/// This is the URL the user opens in WeChat.
/// The server requests wahlap's authorize endpoint, stores the state+r
/// association, rewrites redirect_uri (https→http), and returns a 302
/// redirect to WeChat's OAuth page.
pub async fn handler(State(state): State<AppState>, Path(task_id): Path<Uuid>) -> Response {
    tracing::info!("[WECHAT_ENTRY] task_id={}", task_id);

    match oauth::prepare_authorize(&state.db, task_id).await {
        Ok(location) => {
            tracing::info!(
                "[WECHAT_ENTRY] redirecting to {}...",
                &location[..location.len().min(150)]
            );
            (
                StatusCode::FOUND,
                [(header::LOCATION, location)],
                axum::body::Body::empty(),
            )
                .into_response()
        }
        Err(e) => {
            tracing::error!("[WECHAT_ENTRY] prepare_authorize error: {:#}", e);
            let body = format!(
                "<html><body><h1>Server Error</h1><pre>{:#}</pre></body></html>",
                e
            );
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                [(header::CONTENT_TYPE, "text/html; charset=utf-8")],
                body,
            )
                .into_response()
        }
    }
}
