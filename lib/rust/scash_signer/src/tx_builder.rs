use anyhow::{anyhow, Result};
use std::str::FromStr;

use bitcoin::absolute::LockTime;
use bitcoin::transaction::Version;
use bitcoin::{Amount, OutPoint, ScriptBuf, Sequence, Transaction, TxIn, TxOut, Txid, Witness};

use crate::utxo::Utxo;

pub fn build_p2wpkh_tx(
    utxos: Vec<Utxo>,
    to_script: ScriptBuf,
    change_script: ScriptBuf,
    amount_sat: u64,
    fee_sat: u64,
    platform_fee_sat: u64,
    platform_script: Option<ScriptBuf>,
) -> Result<Transaction> {
    // 计算总输入金额
    let total_in: u64 = utxos.iter().map(|u| u.value).sum();

    // 计算用户实际花费（转账 + 平台费），不包括矿工费
    let total_spent = amount_sat
        .checked_add(platform_fee_sat)
        .ok_or_else(|| anyhow!("amount overflow"))?;

    // 验证余额是否足以支付（花费 + 矿工费）
    if total_in < total_spent + fee_sat {
        return Err(anyhow!(
            "余额不足: 拥有 {}, 需要 {} (含手续费 {})",
            total_in,
            total_spent + fee_sat,
            fee_sat
        ));
    }

    // 构建输入 Inputs
    let inputs: Vec<TxIn> = utxos
        .iter()
        .map(|u| -> Result<TxIn> {
            let txid = Txid::from_str(&u.txid)
                .map_err(|e| anyhow!("Invalid txid {}: {}", u.txid, e))?;

            Ok(TxIn {
                previous_output: OutPoint::new(txid, u.vout),
                script_sig: ScriptBuf::new(),
                sequence: Sequence::ENABLE_RBF_NO_LOCKTIME,
                witness: Witness::default(),
            })
        })
        .collect::<Result<Vec<_>>>()?;

    // 构建输出 Outputs
    let mut outputs = vec![TxOut {
        value: Amount::from_sat(amount_sat),
        script_pubkey: to_script,
    }];

    // 如果有平台手续费，添加平台费输出
    if platform_fee_sat > 0 {
        let ps = platform_script
            .ok_or_else(|| anyhow!("platform_script is required when platform_fee_sat > 0"))?;
        outputs.push(TxOut {
            value: Amount::from_sat(platform_fee_sat),
            script_pubkey: ps,
        });
    }

    // 计算找零 (Change)
    // 核心公式：找零 = 总输入 - 实际花费 - 矿工费
    let change = total_in - total_spent - fee_sat;

    // 只有找零金额大于粉尘限制（546 sat）才创建找零输出
    // 否则这部分金额会直接作为矿工费给到节点
    if change > 546 {
        outputs.push(TxOut {
            value: Amount::from_sat(change),
            script_pubkey: change_script,
        });
    }

    Ok(Transaction {
        version: Version(2),
        lock_time: LockTime::ZERO,
        input: inputs,
        output: outputs,
    })
}