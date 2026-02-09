import express from 'express';
import cors from 'cors';

import priceRoutes from './routes/price.routes.js';
import { scashRpc } from './scashRpc.js';
import {
  initTransactionTable,
  saveTransaction,
  getTransactions,
} from './transactionService.js';
import { scanConfirmedTransactions } from './scanConfirmedTransactions.js';

const PORT = 3000;

function normalizeAddress(addr) {
  return String(addr ?? '').trim().toLowerCase();
}

function parseSat(v, fieldName) {
  const s = String(v ?? '').trim();
  if (!s) throw new Error(`${fieldName} is required`);
  if (!/^[0-9]+$/.test(s)) throw new Error(`${fieldName} must be integer sat`);
  const bi = BigInt(s);
  if (bi < 0n) throw new Error(`${fieldName} must be >= 0`);
  return bi;
}

const SAT_UNIT = 100000000n;

function coinToSatBI(v) {
  if (v == null) return 0n;
  if (typeof v === 'number') {
    const s = v.toFixed(8);
    const [i, f = ''] = s.split('.');
    return BigInt(i || '0') * SAT_UNIT + BigInt((f + '00000000').slice(0, 8));
  }
  const s = String(v);
  const [i, f = ''] = s.split('.');
  return BigInt(i || '0') * SAT_UNIT + BigInt((f + '00000000').slice(0, 8));
}

function satToCoinString(sat) {
  const neg = sat < 0n;
  const x = neg ? -sat : sat;
  const i = x / SAT_UNIT;
  const f = (x % SAT_UNIT).toString().padStart(8, '0');
  const s = `${i}.${f}`.replace(/\.?0+$/, '');
  return neg ? `-${s}` : s;
}

function scantxDesc(address) {
  return `addr(${address})`;
}

/* =========================
 * TTL缓存
 * ========================= */

class TTLCache {
  constructor({ ttlMs = 5000, max = 1000 } = {}) {
    this.ttlMs = ttlMs;
    this.max = max;
    this.map = new Map();
  }
  get(k) {
    const v = this.map.get(k);
    if (!v) return null;
    if (Date.now() > v.exp) {
      this.map.delete(k);
      return null;
    }
    return v.value;
  }
  set(k, value) {
    this.map.set(k, { value, exp: Date.now() + this.ttlMs });
    while (this.map.size > this.max) {
      this.map.delete(this.map.keys().next().value);
    }
  }
  delete(k) {
    this.map.delete(k);
  }
}

const app = express();
app.use(cors());
app.use(express.json({ limit: '2mb' }));

app.get('/health', (_, res) => res.json({ ok: true }));
app.use('/price', priceRoutes);

/* =========================
 * 缓存
 * ========================= */

const balanceCache = new TTLCache({ ttlMs: 5000, max: 5000 });
const utxoCache = new TTLCache({ ttlMs: 5000, max: 2000 });
const txCache = new TTLCache({ ttlMs: 5000, max: 2000 });

/* =========================
 * 块高度缓存
 * ========================= */

let heightCache = { ts: 0, h: 0 };
async function getBestHeight() {
  const now = Date.now();
  if (heightCache.h && now - heightCache.ts < 2000) return heightCache.h;
  const h = Number(await scashRpc('getblockcount'));
  heightCache = { ts: now, h };
  return h;
}

/* =========================
 * scantxoutset（全局互联）
 * ========================= */

let scanLock = Promise.resolve();
function withScanLock(fn) {
  const p = scanLock.then(fn, fn);
  scanLock = p.catch(() => {});
  return p;
}

async function scanUtxos(address) {
  const desc = scantxDesc(address);
  return withScanLock(async () => {
    const r = await scashRpc('scantxoutset', ['start', [desc]]);
    return Array.isArray(r?.unspents) ? r.unspents : [];
  });
}

/* =========================
 * 端点
 * ========================= */

app.get('/balance', async (req, res) => {
  try {
    const address = normalizeAddress(req.query.address);
    if (!address) return res.status(400).json({ error: 'address required' });

    const cached = balanceCache.get(address);
    if (cached) return res.json(cached);

    const utxos = await scanUtxos(address);
    const sum = utxos.reduce((a, u) => a + coinToSatBI(u.amount), 0n);

    const payload = {
      address,
      balanceSat: sum.toString(),
      balance_sat: sum.toString(),
      balanceStr: satToCoinString(sum),
      balance: Number(satToCoinString(sum)),
    };

    balanceCache.set(address, payload);
    res.json(payload);
  } catch (e) {
    console.error('GET /balance error:', e);
    res.status(500).json({ error: 'balance failed' });
  }
});

app.get('/utxos', async (req, res) => {
  try {
    const address = normalizeAddress(req.query.address);
    if (!address) return res.status(400).json({ error: 'address required' });

    const cached = utxoCache.get(address);
    if (cached) return res.json(cached);

    const utxos = await scanUtxos(address);
    const list = utxos.map(u => ({
      txid: u.txid,
      vout: u.vout,
      value: coinToSatBI(u.amount).toString(),
      scriptPubkey: u.scriptPubKey ?? '',
      address,
      height: u.height ?? null,
    }));

    const payload = { value: list, count: list.length };
    utxoCache.set(address, payload);
    res.json(payload);
  } catch (e) {
    console.error('GET /utxos error:', e);
    res.status(500).json({ error: 'utxos failed' });
  }
});

app.get('/transactions', async (req, res) => {
  try {
    const address = normalizeAddress(req.query.address);
    if (!address) return res.status(400).json({ error: 'address required' });

    const refresh = String(req.query.refresh) === 'true';
    const bestHeight = await getBestHeight();

    let rows = txCache.get(address);
    if (!rows || refresh) {
      await scanConfirmedTransactions(address);
      rows = await getTransactions(address);
      txCache.set(address, rows);
    }

    const txs = rows.map(r => ({
      ...r,
      confirmations:
        r.blockHeight > 0 ? bestHeight - r.blockHeight + 1 : 0,
    }));

    res.json({ transactions: txs });
  } catch (e) {
    console.error('GET /transactions error:', e);
    res.status(500).json({ error: 'transactions failed' });
  }
});

app.post('/send', async (req, res) => {
  try {
    const txHex = String(req.body.txHex || '').trim();
    if (!txHex) return res.status(400).json({ error: 'txHex required' });

    const walletAddress = normalizeAddress(req.body.walletAddress);
    if (!walletAddress) return res.status(400).json({ error: 'walletAddress required' });

    const txid = await scashRpc('sendrawtransaction', [txHex]);
    res.json({ txid });

    void saveTransaction({
      txHash: txid,
      walletAddress,
      from: walletAddress,
      to: normalizeAddress(req.body.to),
      direction: 'sent',
      amountSat: parseSat(req.body.amountSat, 'amountSat').toString(),
      feeSat: req.body.feeSat ?? null,
      platformFeeSat: null,
      platformFeeAddress: null,
      status: 'pending',
      confirmations: 0,
      blockHeight: 0,
      timestamp: Date.now(),
    });
  } catch (e) {
    console.error('POST /send error:', e);
    res.status(500).json({ error: 'send failed' });
  }
});

async function main() {
  await initTransactionTable();
  app.listen(PORT, () =>
    console.log(`Server running on http://localhost:${PORT}`)
  );
}

main().catch(e => {
  console.error('Fatal startup error:', e);
  process.exit(1);
});
