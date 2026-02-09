use anyhow::{anyhow, Context, Result};
use bech32::{segwit, Hrp};
use bitcoin::bip32::Xpriv;
use bitcoin::hashes::Hash;
use bitcoin::secp256k1::Secp256k1;
use bitcoin::{ScriptBuf, WPubkeyHash};
use std::str::FromStr;

use crate::network::SCASH;

/// 根据助记词和派生路径生成 SCash 地址（P2WPKH / segwit v0）
pub fn derive_scash_address(phrase: String, path: String) -> Result<String> {
    // 派生 Xpriv
    let xprv_str = crate::hd::derive_xprv(phrase, path)?;
    let xprv = Xpriv::from_str(&xprv_str).context("Invalid Xpriv")?;

    // 获取公钥（secp256k1::PublicKey）
    let secp = Secp256k1::new();
    let pubkey = xprv.private_key.public_key(&secp);

    // 计算 WPubkeyHash：HASH160(pubkey_compressed_33bytes)
    let wpkh = WPubkeyHash::hash(&pubkey.serialize());

    // segwit v0 地址编码：hrp + version0 + program(20 bytes)
    let hrp = Hrp::parse(SCASH.bech32_hrp).context("Invalid HRP")?;
    let address = segwit::encode(hrp, segwit::VERSION_0, wpkh.as_byte_array())
        .map_err(|e| anyhow!("Segwit encode failed: {}", e))?;

    Ok(address)
}

/// 将 bech32 segwit 地址解析为 ScriptPubKey（仅支持 v0 + 20 bytes => P2WPKH）
pub fn address_to_script(address: &str) -> Result<ScriptBuf> {
    let (_hrp, ver, program) = segwit::decode(address)
        .map_err(|e| anyhow!("Invalid segwit address: {}", e))?;

    if ver != segwit::VERSION_0 {
        return Err(anyhow!("Only segwit v0 is supported"));
    }
    if program.len() != 20 {
        return Err(anyhow!("Invalid witness program length: {}", program.len()));
    }

    Ok(ScriptBuf::new_p2wpkh(&WPubkeyHash::from_slice(&program)?))
}

/// 派生找零脚本（示例：直接用传入 xprv 的公钥生成 P2WPKH；也可自行改为派生子路径）
pub fn derive_change_script(xprv_str: &str) -> Result<ScriptBuf> {
    let xprv = Xpriv::from_str(xprv_str).context("Invalid Xpriv")?;
    let secp = Secp256k1::new();
    let pubkey = xprv.private_key.public_key(&secp);
    let wpkh = WPubkeyHash::hash(&pubkey.serialize());
    Ok(ScriptBuf::new_p2wpkh(&wpkh))
}
