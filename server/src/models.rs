use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::types::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum TaskState {
    Created,
    WaitingCallback,
    Fetching,
    Completed,
    Failed,
}

impl TaskState {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Created => "created",
            Self::WaitingCallback => "waiting_callback",
            Self::Fetching => "fetching",
            Self::Completed => "completed",
            Self::Failed => "failed",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "created" => Some(Self::Created),
            "waiting_callback" => Some(Self::WaitingCallback),
            "fetching" => Some(Self::Fetching),
            "completed" => Some(Self::Completed),
            "failed" => Some(Self::Failed),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DifficultyResult {
    pub difficulty: i32,
    pub name: String,
    pub status: String, // "success" | "failed"
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Task {
    pub id: Uuid,
    pub state: TaskState,
    pub df_username: String,
    pub df_password: String,
    pub difficulties: Vec<i32>,
    pub oauth_state: Option<String>,
    pub oauth_r: Option<String>,
    pub oauth_code: Option<String>,
    pub results: Option<serde_json::Value>,
    pub error_message: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// API request/response types

#[derive(Debug, Deserialize)]
pub struct CreateTaskRequest {
    pub diving_fish_username: String,
    pub diving_fish_password: String,
    #[serde(default = "default_difficulties")]
    pub difficulties: Vec<i32>,
}

fn default_difficulties() -> Vec<i32> {
    vec![0, 1, 2, 3, 4]
}

#[derive(Debug, Serialize)]
pub struct CreateTaskResponse {
    pub task_id: Uuid,
}

#[derive(Debug, Serialize)]
pub struct GetTaskResponse {
    pub task_id: Uuid,
    pub state: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub results: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error_message: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl From<Task> for GetTaskResponse {
    fn from(t: Task) -> Self {
        Self {
            task_id: t.id,
            state: t.state.as_str().to_string(),
            results: t.results,
            error_message: t.error_message,
            created_at: t.created_at,
            updated_at: t.updated_at,
        }
    }
}
