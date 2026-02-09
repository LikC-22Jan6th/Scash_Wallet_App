use crate::network::SCASH;
use bitcoin::bip32::{DerivationPath, Xpriv};
use bitcoin::Network;
use bitcoin::secp256k1::Secp256k1;
use bip39::Mnemonic;
use std::str::FromStr;
use anyhow::{Result, Context};
use flutter_rust_bridge::frb;

/// 映射 SCash 配置到 bitcoin 库的 Network 枚举
pub fn get_network() -> Network {
    if SCASH.bech32_hrp == "scash" {
        Network::Bitcoin
    } else {
        Network::Testnet
    }
}

/// 核心函数：派生扩展私钥 (Xpriv)
#[frb(sync)]
pub fn derive_xprv(phrase: String, path: String) -> Result<String> {
    let secp = Secp256k1::new();

    // 解析助记词 (增加错误上下文)
    let mnemonic = Mnemonic::from_str(&phrase)
        .map_err(|_| anyhow::anyhow!("助记词格式无效"))?;

    // 生成种子（空密码作为默认，后续可扩展）
    let seed = mnemonic.to_seed("");

    // 创建主密钥
    let network = get_network();
    let master_xprv = Xpriv::new_master(network, &seed)
        .context("无法根据种子创建主私钥")?;

    // 解析并执行路径派生
    let derivation_path = DerivationPath::from_str(&path)
        .map_err(|_| anyhow::anyhow!("派生路径格式错误: {}", path))?;

    let derived_xprv = master_xprv.derive_priv(&secp, &derivation_path)
        .context("路径派生失败")?;

    // 返回 Base58 编码的字符串，方便 Dart 存储或进一步处理
    Ok(derived_xprv.to_string())
}