import axios from 'axios';
import http from 'http';
import https from 'https';

const COINGECKO_BASE = 'https://api.coingecko.com/api/v3';
const COINGECKO_ID = 'satoshi-cash-network';

const REQUEST_TIMEOUT_MS = 10_000;
const PRICE_CACHE_TTL_MS = 60_000;
const HISTORY_CACHE_TTL_MS = 5 * 60_000;
const MAX_HISTORY_KEYS = 32;

const USER_AGENT = 'scash-wallet/1.0';

const httpAgent = new http.Agent({ keepAlive: true, maxSockets: 50 });
const httpsAgent = new https.Agent({ keepAlive: true, maxSockets: 50 });

const client = axios.create({
  baseURL: COINGECKO_BASE,
  timeout: REQUEST_TIMEOUT_MS,
  httpAgent,
  httpsAgent,
  headers: { 'User-Agent': USER_AGENT, Accept: 'application/json' },
  validateStatus: () => true,
});

function clampDays(days) {
  const n = Number(days);
  if (!Number.isFinite(n) || n <= 0) return 1;
  return Math.min(Math.floor(n), 365);
}

// -------------------------
// 价格缓存
// -------------------------
let priceCache = { value: 0, ts: 0 };
let priceInflight = null;

async function fetchPriceUSD() {
  const resp = await client.get('/simple/price', {
    params: { ids: COINGECKO_ID, vs_currencies: 'usd' },
  });

  if (resp.status < 200 || resp.status >= 300) {
    throw new Error(`CoinGecko price HTTP ${resp.status}`);
  }

  const v = resp.data?.[COINGECKO_ID]?.usd;
  if (typeof v !== 'number' || !Number.isFinite(v) || v <= 0) {
    throw new Error('CoinGecko price invalid');
  }
  return v;
}

export async function getScashPriceUSD() {
  const now = Date.now();
  if (priceCache.value > 0 && now - priceCache.ts < PRICE_CACHE_TTL_MS) {
    return priceCache.value;
  }

  if (priceInflight) return priceInflight;

  priceInflight = (async () => {
    const v = await fetchPriceUSD();
    priceCache = { value: v, ts: Date.now() };
    return v;
  })();

  try {
    return await priceInflight;
  } catch (e) {
    console.error('[PRICE] CoinGecko failed:', e?.message || e);
    // 失败：尽量返回旧值（不抖动成 0）
    return priceCache.value || 0;
  } finally {
    priceInflight = null;
  }
}

// -------------------------
// 历史缓存
// -------------------------
const historyCache = new Map();    // key -> { data, ts }
const historyInflight = new Map(); // key -> Promise

async function fetchHistory(daysInt) {
  const resp = await client.get(`/coins/${COINGECKO_ID}/market_chart`, {
    params: { vs_currency: 'usd', days: daysInt },
  });

  if (resp.status < 200 || resp.status >= 300) {
    throw new Error(`CoinGecko history HTTP ${resp.status}`);
  }

  const prices = resp.data?.prices;
  if (!Array.isArray(prices)) throw new Error('CoinGecko history invalid: missing prices[]');

  return prices.map((it) => ({ time: it[0], price: it[1] }));
}

function evictHistoryIfNeeded() {
  if (historyCache.size <= MAX_HISTORY_KEYS) return;
  historyCache.clear();
}

export async function getScashHistory(days = 1) {
  const daysInt = clampDays(days);
  const key = String(daysInt);
  const now = Date.now();

  const cached = historyCache.get(key);
  if (cached && now - cached.ts < HISTORY_CACHE_TTL_MS) return cached.data;

  const inflight = historyInflight.get(key);
  if (inflight) return inflight;

  const p = (async () => {
    const data = await fetchHistory(daysInt);
    evictHistoryIfNeeded();
    historyCache.set(key, { data, ts: Date.now() });
    return data;
  })();

  historyInflight.set(key, p);

  try {
    return await p;
  } catch (e) {
    console.error('[PRICE] CoinGecko history failed:', e?.message || e);
    // 容错：有旧缓存就给旧缓存
    return historyCache.get(key)?.data || [];
  } finally {
    historyInflight.delete(key);
  }
}
