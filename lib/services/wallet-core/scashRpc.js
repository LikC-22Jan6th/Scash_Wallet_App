import axios from 'axios';
import http from 'http';
import https from 'https';

export class RpcError extends Error {
  constructor(message, { code, data, status, method } = {}) {
    super(message);
    this.name = 'RpcError';
    this.code = code;
    this.data = data;
    this.status = status;
    this.method = method;
  }
}

const RPC_URL = 'https://explorer.scash.network/api/rpc';
const RPC_USER = 'scash';
const RPC_PASSWORD = 'scash';

const DEFAULT_TIMEOUT_MS = 30_000;

const httpAgent = new http.Agent({ keepAlive: true, maxSockets: 50 });
const httpsAgent = new https.Agent({ keepAlive: true, maxSockets: 50 });

const client = axios.create({
  timeout: DEFAULT_TIMEOUT_MS,
  httpAgent,
  httpsAgent,
  headers: {
    'Content-Type': 'application/json',
    Accept: 'application/json',
  },
  validateStatus: () => true,
  maxBodyLength: Infinity,
  maxContentLength: Infinity,
});

let requestId = 1;

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

export function isMethodNotAllowed(err) {
  const msg = String(err?.message || err || '').toLowerCase();
  // 兼容你日志里出现的提示
  if (msg.includes('method not allowed') || msg.includes('missing')) return true;
  // JSON-RPC 常见：-32601 method not found
  if (err?.code === -32601) return true;
  return false;
}

export async function scashRpc(method, params = [], opts = {}) {
  const timeout = Number(opts.timeout ?? DEFAULT_TIMEOUT_MS);
  const retries = Number(opts.retries ?? 0);
  const retryDelayMs = Number(opts.retryDelayMs ?? 500);

  const id = requestId++;
  const payload = { jsonrpc: '2.0', id, method, params };

  let lastErr;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const resp = await client.post(
        RPC_URL,
        payload,
        {
          timeout,
          auth: { username: RPC_USER, password: RPC_PASSWORD },
        }
      );

      if (resp.status < 200 || resp.status >= 300) {
        throw new RpcError(`HTTP ${resp.status} from RPC`, {
          status: resp.status,
          method,
          data: resp.data,
        });
      }

      const body = resp.data;
      if (!body) {
        throw new RpcError('Empty RPC response', { status: resp.status, method });
      }

      if (body.error) {
        throw new RpcError(body.error.message || 'RPC error', {
          code: body.error.code,
          data: body.error.data,
          status: resp.status,
          method,
        });
      }

      return body.result;
    } catch (e) {
      lastErr = e;
      if (attempt < retries) {
        await sleep(retryDelayMs * Math.pow(2, attempt));
        continue;
      }
      throw lastErr;
    }
  }

  throw lastErr;
}
