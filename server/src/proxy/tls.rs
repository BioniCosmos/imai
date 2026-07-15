use std::fs::File;
use std::io::BufReader;
use std::sync::Arc;

use rustls::pki_types::{CertificateDer, PrivateKeyDer};
use rustls::ServerConfig;
use tokio_rustls::TlsAcceptor;

pub fn build_acceptor(cert_path: &str, key_path: &str) -> Result<TlsAcceptor, anyhow::Error> {
    let certs: Vec<CertificateDer<'static>> = {
        let mut reader = BufReader::new(File::open(cert_path)?);
        rustls_pemfile::certs(&mut reader).collect::<Result<Vec<_>, _>>()?
    };

    let key: PrivateKeyDer<'static> = {
        let mut reader = BufReader::new(File::open(key_path)?);
        rustls_pemfile::private_key(&mut reader)?
            .ok_or_else(|| anyhow::anyhow!("no private key found"))?
    };

    let config = ServerConfig::builder()
        .with_no_client_auth()
        .with_single_cert(certs, key)?;

    Ok(TlsAcceptor::from(Arc::new(config)))
}
