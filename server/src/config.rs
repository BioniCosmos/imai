use sqlx::postgres::PgPoolOptions;
use sqlx::PgPool;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
}

impl AppState {
    pub async fn new(database_url: &str) -> Result<Self, anyhow::Error> {
        let pool = PgPoolOptions::new()
            .max_connections(10)
            .connect(database_url)
            .await?;

        sqlx::migrate!("./migrations").run(&pool).await?;

        Ok(Self { db: pool })
    }
}

#[derive(Debug, Clone)]
pub enum ProxyMode {
    Plaintext,
    Tls { cert_path: String, key_path: String },
}

impl ProxyMode {
    pub fn from_env() -> Result<Self, anyhow::Error> {
        let mode = std::env::var("PROXY_MODE").unwrap_or_else(|_| "plaintext".into());
        match mode.as_str() {
            "tls" => {
                let cert_path =
                    std::env::var("PROXY_TLS_CERT").unwrap_or_else(|_| "cert.pem".into());
                let key_path = std::env::var("PROXY_TLS_KEY").unwrap_or_else(|_| "key.pem".into());
                Ok(Self::Tls {
                    cert_path,
                    key_path,
                })
            }
            _ => Ok(Self::Plaintext),
        }
    }
}

#[derive(Debug, Clone)]
pub struct Config {
    pub database_url: String,
    pub api_listen_addr: String,
    pub proxy_listen_addr: String,
    pub proxy_mode: ProxyMode,
}

impl Config {
    pub fn from_env() -> Result<Self, anyhow::Error> {
        Ok(Self {
            database_url: std::env::var("DATABASE_URL")
                .unwrap_or_else(|_| "postgres://localhost:5432/maimai_data".into()),
            api_listen_addr: std::env::var("API_LISTEN_ADDR")
                .unwrap_or_else(|_| "0.0.0.0:8080".into()),
            proxy_listen_addr: std::env::var("PROXY_LISTEN_ADDR")
                .unwrap_or_else(|_| "0.0.0.0:1080".into()),
            proxy_mode: ProxyMode::from_env()?,
        })
    }
}
