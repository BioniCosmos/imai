use axum::extract::State;
use axum::http::StatusCode;
use axum::Json;

use crate::config::AppState;
use crate::db;
use crate::models::{CreateTaskRequest, CreateTaskResponse};

pub async fn handler(
    State(state): State<AppState>,
    Json(req): Json<CreateTaskRequest>,
) -> Result<(StatusCode, Json<CreateTaskResponse>), (StatusCode, String)> {
    if req.diving_fish_username.is_empty() || req.diving_fish_password.is_empty() {
        return Err((
            StatusCode::BAD_REQUEST,
            "diving_fish_username and diving_fish_password are required".into(),
        ));
    }

    let task_id = db::create_task(
        &state.db,
        &req.diving_fish_username,
        &req.diving_fish_password,
        &req.difficulties,
    )
    .await
    .map_err(|e| {
        tracing::error!("create_task error: {:?}", e);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "failed to create task".into(),
        )
    })?;

    Ok((StatusCode::CREATED, Json(CreateTaskResponse { task_id })))
}
