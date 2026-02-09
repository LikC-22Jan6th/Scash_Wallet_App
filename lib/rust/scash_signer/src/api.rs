use anyhow::{anyhow, Context, Result};
use bitcoin::bip32::Xpriv;
use flutter_rust_bridge::frb;
use std::str::FromStr;

use crate::{address, hd, mnemonic, sign, tx_builder, utxo::Utxo};

#[frb(sync)]
pub fn generate_mnemonic() -> Result<String> {
    mnemonic::generate_mnemonic()
}

#[frb]
pub fn derive_address(mnemonic: String, path: String) -> Result<String> {
    address::derive_scash_address(mnemonic, path)
}

#[frb]
pub fn build_and_sign_transaction(
    mnemonic: String,
    path: String,
    utxos: Vec<Utxo>,
    to_address: String,
    amount: u64,
    fee: u64,
    platform_fee_sat: Option<u64>,
    platform_fee_address: Option<String>,
) -> Result<String> {
    let xprv_str = hd::derive_xprv(mnemonic, path).context("Failed to derive xprv")?;
    let xprv = Xpriv::from_str(&xprv_str).context("Invalid Xpriv")?;

    let to_script = address::address_to_script(&to_address).context("Invalid destination address")?;
    let change_script = address::derive_change_script(&xprv_str).context("Failed to derive change script")?;

    let input_amounts: Vec<u64> = utxos.iter().map(|u| u.value).collect();

    let pf_sat = platform_fee_sat.unwrap_or(0);

    let pf_script = if pf_sat > 0 {
        let addr = platform_fee_address
            .as_ref()
            .ok_or_else(|| anyhow!("platform_fee_address is required when platform_fee_sat > 0"))?;
        Some(address::address_to_script(addr).context("Invalid platform fee address")?)
    } else {
        None
    };

    let tx = tx_builder::build_p2wpkh_tx(
        utxos,
        to_script,
        change_script,
        amount,
        fee,
        pf_sat,
        pf_script,
    )
    .context("Failed to build transaction")?;

    let priv_hex = hex::encode(xprv.private_key.secret_bytes());
    let tx_hex = sign::sign_tx_p2wpkh(tx, input_amounts, priv_hex).context("Failed to sign tx")?;

    Ok(tx_hex)
}
