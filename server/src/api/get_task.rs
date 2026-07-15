use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::Json;
use sqlx::types::Uuid;

use crate::config::AppState;
use crate::db;
use crate::models::GetTaskResponse;

pub async fn handler(
    State(state): State<AppState>,
    Path(task_id): Path<Uuid>,
) -> Result<Json<GetTaskResponse>, (StatusCode, String)> {
    tracing::info!("[GET_TASK] id={}", task_id);
    let task = db::get_task(&state.db, task_id)
        .await
        .map_err(|e| {
            tracing::error!("get_task error: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "failed to get task".into(),
            )
        })?
        .ok_or_else(|| (StatusCode::NOT_FOUND, "task not found".into()))?;

    Ok(Json(GetTaskResponse::from(task)))
}
