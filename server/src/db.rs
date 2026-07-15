use anyhow::Context;
use chrono::Utc;
use sqlx::types::Uuid;
use sqlx::PgPool;

use crate::models::{DifficultyResult, Task, TaskState};

pub async fn create_task(
    db: &PgPool,
    df_username: &str,
    df_password: &str,
    difficulties: &[i32],
) -> Result<Uuid, anyhow::Error> {
    let id = Uuid::now_v7();
    let now = Utc::now();

    sqlx::query(
        r#"
        INSERT INTO tasks (id, state, df_username, df_password, difficulties, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        "#,
    )
    .bind(id)
    .bind(TaskState::Created.as_str())
    .bind(df_username)
    .bind(df_password)
    .bind(difficulties)
    .bind(now)
    .bind(now)
    .execute(db)
    .await
    .context("failed to insert task")?;

    Ok(id)
}

pub async fn get_task(db: &PgPool, id: Uuid) -> Result<Option<Task>, anyhow::Error> {
    let row = sqlx::query_as::<_, TaskRow>(
        r#"
        SELECT id, state, df_username, df_password, difficulties,
               oauth_state, oauth_r, oauth_code, results, error_message,
               created_at, updated_at
        FROM tasks WHERE id = $1
        "#,
    )
    .bind(id)
    .fetch_optional(db)
    .await?;

    Ok(row.map(Task::from))
}

pub async fn set_oauth_state(
    db: &PgPool,
    id: Uuid,
    oauth_state: &str,
    oauth_r: &str,
) -> Result<(), anyhow::Error> {
    sqlx::query(
        r#"
        UPDATE tasks
        SET state = $2, oauth_state = $3, oauth_r = $4, updated_at = $5
        WHERE id = $1
        "#,
    )
    .bind(id)
    .bind(TaskState::WaitingCallback.as_str())
    .bind(oauth_state)
    .bind(oauth_r)
    .bind(Utc::now())
    .execute(db)
    .await?;

    Ok(())
}

pub async fn find_task_by_oauth(
    db: &PgPool,
    oauth_state: &str,
    oauth_r: &str,
) -> Result<Option<Task>, anyhow::Error> {
    let row = sqlx::query_as::<_, TaskRow>(
        r#"
        SELECT id, state, df_username, df_password, difficulties,
               oauth_state, oauth_r, oauth_code, results, error_message,
               created_at, updated_at
        FROM tasks
        WHERE oauth_state = $1 AND oauth_r = $2 AND state = $3
        ORDER BY created_at DESC
        LIMIT 1
        "#,
    )
    .bind(oauth_state)
    .bind(oauth_r)
    .bind(TaskState::WaitingCallback.as_str())
    .fetch_optional(db)
    .await?;

    Ok(row.map(Task::from))
}

pub async fn set_oauth_code(db: &PgPool, id: Uuid, code: &str) -> Result<(), anyhow::Error> {
    sqlx::query(
        r#"
        UPDATE tasks
        SET oauth_code = $2, updated_at = $3
        WHERE id = $1
        "#,
    )
    .bind(id)
    .bind(code)
    .bind(Utc::now())
    .execute(db)
    .await?;

    Ok(())
}

pub async fn set_task_state(db: &PgPool, id: Uuid, state: TaskState) -> Result<(), anyhow::Error> {
    sqlx::query("UPDATE tasks SET state = $2, updated_at = $3 WHERE id = $1")
        .bind(id)
        .bind(state.as_str())
        .bind(Utc::now())
        .execute(db)
        .await?;

    Ok(())
}

pub async fn set_task_results(
    db: &PgPool,
    id: Uuid,
    results: &[DifficultyResult],
    error: Option<&str>,
) -> Result<(), anyhow::Error> {
    let state = if error.is_some() {
        TaskState::Failed
    } else {
        TaskState::Completed
    };

    let results_json = serde_json::to_value(results)?;

    sqlx::query(
        r#"
        UPDATE tasks
        SET state = $2, results = $3, error_message = $4, updated_at = $5
        WHERE id = $1
        "#,
    )
    .bind(id)
    .bind(state.as_str())
    .bind(results_json)
    .bind(error)
    .bind(Utc::now())
    .execute(db)
    .await?;

    Ok(())
}

// Row type for sqlx query_as
#[derive(Debug, sqlx::FromRow)]
struct TaskRow {
    id: Uuid,
    state: String,
    df_username: String,
    df_password: String,
    difficulties: Vec<i32>,
    oauth_state: Option<String>,
    oauth_r: Option<String>,
    oauth_code: Option<String>,
    results: Option<serde_json::Value>,
    error_message: Option<String>,
    created_at: chrono::DateTime<Utc>,
    updated_at: chrono::DateTime<Utc>,
}

impl From<TaskRow> for Task {
    fn from(row: TaskRow) -> Self {
        Self {
            id: row.id,
            state: TaskState::from_str(&row.state).unwrap_or(TaskState::Failed),
            df_username: row.df_username,
            df_password: row.df_password,
            difficulties: row.difficulties,
            oauth_state: row.oauth_state,
            oauth_r: row.oauth_r,
            oauth_code: row.oauth_code,
            results: row.results,
            error_message: row.error_message,
            created_at: row.created_at,
            updated_at: row.updated_at,
        }
    }
}
