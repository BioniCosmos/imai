pub mod create_task;
pub mod get_task;
pub mod wechat_entry;

use axum::routing::{get, post};
use axum::Router;
use tower_http::trace::TraceLayer;

use crate::config::AppState;

pub fn router(state: AppState) -> Router {
    Router::new()
        .route("/api/tasks", post(create_task::handler))
        .route("/api/tasks/{task_id}", get(get_task::handler))
        .route("/tasks/{task_id}", get(wechat_entry::handler))
        .with_state(state)
        .layer(TraceLayer::new_for_http())
}
