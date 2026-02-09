import { pool } from './db.js';

function normalizeAddress(addr) {
  const s = String(addr ?? '').trim();
  return s ? s.toLowerCase() : '';
}

function normalizePeer(addr) {
  const s = String(addr ?? '').trim();
  if (!s) return '';
  if (s === 'Other' || s === 'Unknown') return s;
  return s.toLowerCase();
}

async function tryQuery(sql) {
  try {
    await pool.query(sql);
  } catch (e) {
    const msg = String(e?.message || '').toLowerCase();
    if (
      msg.includes('duplicate column') ||
      msg.includes('duplicate key name') ||
      msg.includes('already exists')
    ) return;
    throw e;
  }
}

export async function initTransactionTable() {
  await tryQuery(`
    CREATE TABLE IF NOT EXISTS transactions (
      txHash VARCHAR(64) PRIMARY KEY COMMENT '交易哈希',
      walletAddress VARCHAR(128) NOT NULL COMMENT '所属钱包地址',
      \`from\` VARCHAR(128) NOT NULL COMMENT '发送方地址',
      \`to\` VARCHAR(128) NOT NULL COMMENT '接收方地址',
      direction ENUM('sent','received') NOT NULL COMMENT '交易方向',
      amountSat BIGINT NOT NULL COMMENT '实际转账金额（不含平台费）',
      feeSat BIGINT NULL COMMENT '矿工费',
      platformFeeSat BIGINT NULL COMMENT '平台手续费',
      platformFeeAddress VARCHAR(128) NULL COMMENT '平台手续费接收地址',
      status VARCHAR(16) NOT NULL COMMENT '交易状态',
      confirmations INT NOT NULL COMMENT '确认数',
      blockHeight INT NOT NULL COMMENT '所在区块高度',
      timestamp BIGINT NOT NULL COMMENT '时间戳毫秒'
    ) COMMENT='交易记录表'
  `);

  await tryQuery(`ALTER TABLE transactions ADD COLUMN walletAddress VARCHAR(128) NOT NULL COMMENT '所属钱包地址' AFTER txHash`);
  await tryQuery(`ALTER TABLE transactions ADD COLUMN \`from\` VARCHAR(128) NOT NULL COMMENT '发送方地址' AFTER walletAddress`);
  await tryQuery(`ALTER TABLE transactions ADD COLUMN \`to\` VARCHAR(128) NOT NULL COMMENT '接收方地址' AFTER \`from\``);
  await tryQuery(`ALTER TABLE transactions ADD COLUMN direction ENUM('sent','received') NOT NULL COMMENT '交易方向' AFTER \`to\``);
  await tryQuery(`ALTER TABLE transactions ADD COLUMN amountSat BIGINT NOT NULL COMMENT '实际转账金额（不含平台费）' AFTER direction`);
  await tryQuery(`ALTER TABLE transactions ADD COLUMN feeSat BIGINT NULL COMMENT '矿工费' AFTER amountSat`);
  await tryQuery(`ALTER TABLE transactions ADD COLUMN platformFeeSat BIGINT NULL COMMENT '平台手续费' AFTER feeSat`);
  await tryQuery(`ALTER TABLE transactions ADD COLUMN platformFeeAddress VARCHAR(128) NULL COMMENT '平台手续费接收地址' AFTER platformFeeSat`);
  await tryQuery(`ALTER TABLE transactions ADD COLUMN status VARCHAR(16) NOT NULL COMMENT '交易状态' AFTER platformFeeAddress`);
  await tryQuery(`ALTER TABLE transactions ADD COLUMN confirmations INT NOT NULL COMMENT '确认数' AFTER status`);
  await tryQuery(`ALTER TABLE transactions ADD COLUMN blockHeight INT NOT NULL COMMENT '区块高度' AFTER confirmations`);
  await tryQuery(`ALTER TABLE transactions ADD COLUMN timestamp BIGINT NOT NULL COMMENT '时间戳毫秒' AFTER blockHeight`);

  await tryQuery(`CREATE INDEX idx_wallet_ts ON transactions (walletAddress, timestamp)`);
  await tryQuery(`CREATE INDEX idx_status ON transactions (status)`);

  await tryQuery(`
    CREATE TABLE IF NOT EXISTS scan_state (
      walletAddress VARCHAR(128) PRIMARY KEY COMMENT '钱包地址',
      lastHeight INT NOT NULL COMMENT '已扫描到的最高区块'
    ) COMMENT='扫描状态表'
  `);

  try {
    await pool.query(`UPDATE transactions SET walletAddress = LOWER(walletAddress) WHERE walletAddress <> LOWER(walletAddress)`);
    await pool.query(`UPDATE scan_state SET walletAddress = LOWER(walletAddress) WHERE walletAddress <> LOWER(walletAddress)`);
  } catch {}
}

export async function saveTransaction(tx) {
  const walletAddress = normalizeAddress(tx.walletAddress);
  if (!walletAddress) throw new Error('walletAddress is required');

  const from = normalizePeer(tx.from);
  const to = normalizePeer(tx.to);

  const amountSatStr = tx.amountSat != null ? String(tx.amountSat) : null;
  const feeSatStr = tx.feeSat != null ? String(tx.feeSat) : null;
  const platformFeeSatStr = tx.platformFeeSat != null ? String(tx.platformFeeSat) : null;
  const platformFeeAddress = tx.platformFeeAddress != null
    ? normalizeAddress(tx.platformFeeAddress)
    : null;

  await pool.query(
    `INSERT INTO transactions
     (txHash, walletAddress, \`from\`, \`to\`, direction, amountSat, feeSat, platformFeeSat, platformFeeAddress, status, confirmations, blockHeight, timestamp)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE
       walletAddress = VALUES(walletAddress),
       \`from\` = VALUES(\`from\`),
       \`to\` = VALUES(\`to\`),
       direction = VALUES(direction),
       amountSat = VALUES(amountSat),
       feeSat = VALUES(feeSat),
       platformFeeSat = VALUES(platformFeeSat),
       platformFeeAddress = VALUES(platformFeeAddress),
       status = VALUES(status),
       confirmations = VALUES(confirmations),
       blockHeight = VALUES(blockHeight),
       timestamp = VALUES(timestamp)`,
    [
      tx.txHash,
      walletAddress,
      from,
      to,
      tx.direction,
      amountSatStr,
      feeSatStr,
      platformFeeSatStr,
      platformFeeAddress,
      tx.status,
      tx.confirmations ?? 0,
      tx.blockHeight ?? 0,
      tx.timestamp ?? Date.now(),
    ]
  );
}

export async function getTransactions(walletAddress) {
  const addr = normalizeAddress(walletAddress);
  if (!addr) return [];

  const [rows] = await pool.query(
    `SELECT * FROM transactions WHERE walletAddress = ? ORDER BY timestamp DESC`,
    [addr]
  );
  return rows;
}

export async function getScanHeight(walletAddress) {
  const addr = normalizeAddress(walletAddress);
  if (!addr) return null;

  const [rows] = await pool.query(
    `SELECT lastHeight FROM scan_state WHERE walletAddress = ?`,
    [addr]
  );
  return rows.length ? rows[0].lastHeight : null;
}

export async function updateScanHeight(walletAddress, height) {
  const addr = normalizeAddress(walletAddress);
  if (!addr) return;

  await pool.query(
    `INSERT INTO scan_state (walletAddress, lastHeight)
     VALUES (?, ?)
     ON DUPLICATE KEY UPDATE lastHeight = VALUES(lastHeight)`,
    [addr, height]
  );
}
