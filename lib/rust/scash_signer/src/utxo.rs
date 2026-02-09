use flutter_rust_bridge::frb;
use serde::{Serialize, Deserialize};

#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Utxo {
    pub txid: String,
    pub vout: u32,
    pub value: u64,
    pub script_pubkey: String,
    pub address: String,
    #[serde(default)]
    pub height: Option<u32>,
}