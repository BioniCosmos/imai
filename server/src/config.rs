use sqlx::postgres::PgPoolOptions;
use sqlx::PgPool;

fn env_or(key: &str, default: &str) -> String {
    std::env::var(key).unwrap_or_else(|_| default.into())
}

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
        match env_or("PROXY_MODE", "plaintext").as_str() {
            "tls" => Ok(Self::Tls {
                cert_path: env_or("PROXY_TLS_CERT", "cert.pem"),
                key_path: env_or("PROXY_TLS_KEY", "key.pem"),
            }),
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
            database_url: env_or("DATABASE_URL", "postgres://localhost:5432/maimai_data"),
            api_listen_addr: env_or("API_LISTEN_ADDR", "0.0.0.0:8080"),
            proxy_listen_addr: env_or("PROXY_LISTEN_ADDR", "0.0.0.0:1080"),
            proxy_mode: ProxyMode::from_env()?,
        })
    }
}
