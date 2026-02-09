// FRB 自动生成的代码模块
mod frb_generated; 

// 内部逻辑模块（保持私有，仅供内部调用）
mod mnemonic;
mod hd;
mod address;
mod sign;
mod tx_builder;
mod utxo;

// 外部可见模块
pub mod network; // 如果 Dart 端需要访问网络配置
pub mod api;     // 核心 API 入口，FRB 扫描的主要目标

pub use utxo::Utxo;