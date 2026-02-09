use anyhow::{anyhow, Result};
use bitcoin::hashes::Hash;
use bitcoin::sighash::{EcdsaSighashType, SighashCache};
use bitcoin::secp256k1::{Message, Secp256k1, SecretKey};
use bitcoin::{Amount, PublicKey, ScriptBuf, Transaction, WPubkeyHash};
use flutter_rust_bridge::frb;
use std::str::FromStr;

#[frb(sync)]
pub fn sign_tx_p2wpkh(
    mut tx: Transaction,
    input_amounts: Vec<u64>,
    private_key_hex: String,
) -> Result<String> {
    let secp = Secp256k1::new();
    let sk = SecretKey::from_str(&private_key_hex)?;

    // bitcoin::PublicKey（包装了 secp256k1::PublicKey）
    let pubkey = PublicKey::new(sk.public_key(&secp));
    let pubkey_bytes = pubkey.inner.serialize(); // 33 bytes compressed

    // P2WPKH scriptPubKey
    let wpkh = WPubkeyHash::hash(&pubkey_bytes);
    let script_pubkey = ScriptBuf::new_p2wpkh(&wpkh);

    let mut cache = SighashCache::new(&mut tx);
    let n_inputs = cache.transaction().input.len();

    if input_amounts.len() != n_inputs {
        return Err(anyhow!(
            "input_amounts 数量({}) 与输入数量({})不匹配",
            input_amounts.len(),
            n_inputs
        ));
    }

    for i in 0..n_inputs {
        let amount = Amount::from_sat(input_amounts[i]);

        let sighash = cache.p2wpkh_signature_hash(
            i,
            &script_pubkey,
            amount,
            EcdsaSighashType::All,
        )?;

        let msg = Message::from_digest_slice(sighash.as_byte_array())?;
        let sig = secp.sign_ecdsa(&msg, &sk);

        let mut sig_ser = sig.serialize_der().to_vec();
        sig_ser.push(EcdsaSighashType::All as u8);

        // 关键：只通过 cache 写 witness，避免二次可变借用 tx.input
        let witness = cache
            .witness_mut(i)
            .ok_or_else(|| anyhow!("Invalid input index {}", i))?;
        witness.clear();
        witness.push(sig_ser);
        witness.push(pubkey_bytes.to_vec());
    }

    Ok(hex::encode(bitcoin::consensus::serialize(
        cache.transaction(),
    )))
}
