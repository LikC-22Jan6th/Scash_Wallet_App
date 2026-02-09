/// Scash 网络参数
pub struct ScashNetwork {
    pub bech32_hrp: &'static str,  // Bech32 前缀
    pub bip32_pub: u32,            // xpub 前缀
    pub bip32_priv: u32,           // xprv 前缀
    pub pubkey_hash: u8,           // P2PKH 地址前缀
    pub script_hash: u8,           // P2SH 地址前缀
    pub wif: u8,                   // 私钥 WIF 前缀
}

pub const SCASH: ScashNetwork = ScashNetwork {
    bech32_hrp: "scash",
    bip32_pub: 0x0488b21e,
    bip32_priv: 0x0488ade4,
    pubkey_hash: 0x3c,
    script_hash: 0x7d,
    wif: 0x80,
};
