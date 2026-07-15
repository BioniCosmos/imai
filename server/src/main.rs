mod api;
mod config;
mod db;
mod fetcher;
mod models;
mod oauth;
mod proxy;
mod wahlap;

use std::net::SocketAddr;

use tokio::net::TcpListener;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

use crate::config::{AppState, Config};

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| {
            "maimai-data-server=trace,maimai_data_server=trace,tower_http=trace,axum::rejection=trace".into()
        }))
        .with(tracing_subscriber::fmt::layer().pretty())
        .init();

    dotenvy::dotenv().ok();

    let config = Config::from_env()?;
    tracing::info!("connecting to database...");
    let state = AppState::new(&config.database_url).await?;
    tracing::info!("database connected, migrations applied");

    let api_addr: SocketAddr = config.api_listen_addr.parse()?;
    tracing::info!("API server listening on {}", api_addr);

    let proxy_addr: SocketAddr = config.proxy_listen_addr.parse()?;

    let (api_res, proxy_res) = tokio::join!(
        axum::serve(
            TcpListener::bind(api_addr).await?,
            api::router(state.clone()).into_make_service_with_connect_info::<SocketAddr>(),
        ),
        proxy::serve(proxy_addr, config.clone(), state),
    );

    api_res?;
    proxy_res?;

    Ok(())
}
