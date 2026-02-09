use bip39::{Mnemonic, Language};
use std::str::FromStr;
use anyhow::Result;

pub fn generate_mnemonic() -> Result<String> {
    // 使用 Mnemonic::generate_in
    let mnemonic = Mnemonic::generate_in(Language::English, 12)
        .map_err(|e| anyhow::anyhow!("Generate failed: {}", e))?;
    Ok(mnemonic.to_string())
}

pub fn parse_mnemonic_internal(phrase: &str) -> Result<Mnemonic> {
    Mnemonic::from_str(phrase).map_err(|e| anyhow::anyhow!("Invalid: {}", e))
}