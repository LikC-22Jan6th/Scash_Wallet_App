import { scashRpc } from './scashRpc.js';
import { saveTransaction, getScanHeight, updateScanHeight } from './transactionService.js';

const prevTxCache = new Map();
const MAX_CACHE = 2000;

const SAT_UNIT = 100000000n;
const scanLocks = new Set();

function normalizeAddress(addr) {
  return String(addr ?? '').trim().toLowerCase();
}

const PLATFORM_FEE_ADDRESSES = [
  'scash1qcxe8x3gr4rex4dmq05ft0hpjvsrdtxj6fl4mhd',
].map(normalizeAddress);

const PLATFORM_FEE_ADDR_SET = new Set(PLATFORM_FEE_ADDRESSES);
const SPLIT_PLATFORM_FEE = true;

function coinToSatBI(v) {
  if (v == null) return 0n;

  let s;
  if (typeof v === 'number') s = v.toFixed(8);
  else s = String(v).trim();
  if (!s) return 0n;

  let sign = 1n;
  if (s.startsWith('-')) {
    sign = -1n;
    s = s.slice(1);
  } else if (s.startsWith('+')) {
    s = s.slice(1);
  }

  const [wholePart, fracPart = ''] = s.split('.');
  const whole = BigInt(wholePart ? wholePart : '0');
  const frac = (fracPart + '00000000').slice(0, 8);
  const fracInt = BigInt(frac ? frac : '0');

  return sign * (whole * SAT_UNIT + fracInt);
}

function getVoutAddress(vout) {
  return vout?.scriptPubKey?.address || vout?.scriptPubKey?.addresses?.[0] || '';
}

function cachePut(txid, tx) {
  prevTxCache.set(txid, tx);
  while (prevTxCache.size > MAX_CACHE) {
    const firstKey = prevTxCache.keys().next().value;
    prevTxCache.delete(firstKey);
  }
}

async function getPrevTx(txid) {
  if (!txid) return null;

  if (prevTxCache.has(txid)) {
    const v = prevTxCache.get(txid);
    prevTxCache.delete(txid);
    prevTxCache.set(txid, v);
    return v;
  }

  const tx = await scashRpc('getrawtransaction', [txid, true], {
    timeout: 120000,
    retries: 2,
  });
  cachePut(txid, tx);
  return tx;
}

async function fetchBlockWithTxObjects(blockHash) {
  try {
    const block = await scashRpc('getblock', [blockHash, 2], {
      timeout: 180000,
      retries: 2,
    });
    return block;
  } catch {
    const b1 = await scashRpc('getblock', [blockHash, 1], {
      timeout: 180000,
      retries: 2,
    });

    const txids = Array.isArray(b1?.tx) ? b1.tx : [];
    const txs = [];
    for (const txid of txids) {
      try {
        const tx = await scashRpc('getrawtransaction', [txid, true], {
          timeout: 120000,
          retries: 1,
        });
        if (tx) txs.push(tx);
      } catch {}
    }

    return { ...b1, tx: txs };
  }
}

export async function scanConfirmedTransactions(address) {
  const walletAddr = normalizeAddress(address);
  if (!walletAddr) return;

  if (scanLocks.has(walletAddr)) return;
  scanLocks.add(walletAddr);

  try {
    const currentHeightRaw = await scashRpc('getblockcount', [], { timeout: 15000, retries: 2 });
    const currentHeight = Number(currentHeightRaw);

    const lastHeight = await getScanHeight(walletAddr);

    let startHeight;
    if (lastHeight === null || lastHeight === undefined) {
      startHeight = Math.max(0, currentHeight - 1000);
    } else if (lastHeight >= currentHeight) {
      return;
    } else {
      startHeight = lastHeight + 1;
      const SAFE_LOOKBACK = 5000;
      if (currentHeight - startHeight > SAFE_LOOKBACK) {
        startHeight = currentHeight - SAFE_LOOKBACK;
      }
    }

    if (startHeight > currentHeight) return;

    const COMMIT_EVERY = 10;
    let lastOkHeight = startHeight - 1;

    for (let h = startHeight; h <= currentHeight; h++) {
      const ok = await processSingleBlock(h, walletAddr, currentHeight, { strictPrevTx: true });

      if (!ok) {
        if (lastOkHeight >= startHeight) {
          await updateScanHeight(walletAddr, lastOkHeight);
        }
        break;
      }

      lastOkHeight = h;

      if ((h - startHeight + 1) % COMMIT_EVERY === 0 || h === currentHeight) {
        await updateScanHeight(walletAddr, lastOkHeight);
      }
    }

    prevTxCache.clear();
  } catch (e) {
    console.error(`[Scan] ${walletAddr} failed:`, e?.message || e);
  } finally {
    scanLocks.delete(walletAddr);
  }
}

async function processSingleBlock(height, walletAddr, currentHeight, { strictPrevTx = false } = {}) {
  try {
    const blockHash = await scashRpc('getblockhash', [height], { timeout: 15000, retries: 2 });
    const block = await fetchBlockWithTxObjects(blockHash);

    const txs = Array.isArray(block?.tx) ? block.tx : [];
    const tsMs = Number(block?.time || 0) * 1000;
    const confirmations = Math.max(0, Number(currentHeight) - Number(height) + 1);

    for (const tx of txs) {
      if (tx?.vin?.some(v => v.coinbase)) continue;

      let isSent = false;
      let allInputsResolved = true;
      let inputTotalSat = 0n;

      for (const vin of tx.vin || []) {
        if (!vin?.txid) continue;

        let prevTx;
        try {
          prevTx = await getPrevTx(vin.txid);
        } catch {
          allInputsResolved = false;
          if (strictPrevTx) break;
          continue;
        }

        const prevVout = prevTx?.vout?.[vin.vout];
        if (!prevVout) {
          allInputsResolved = false;
          if (strictPrevTx) break;
          continue;
        }

        inputTotalSat += coinToSatBI(prevVout.value);

        const inAddr = normalizeAddress(getVoutAddress(prevVout));
        if (inAddr === walletAddr) isSent = true;
      }

      if (strictPrevTx && !allInputsResolved) {
        continue;
      }

      let myOutputSat = 0n;
      let outputTotalSat = 0n;

      let platformCandidateSat = 0n;
      let firstPlatformFeeAddress = null;

      let recipientOutputSat = 0n;
      let firstRecipientAddress = 'Unknown';

      for (const vout of tx.vout || []) {
        const outAddrRaw = getVoutAddress(vout);
        const outAddr = normalizeAddress(outAddrRaw);
        const outSat = coinToSatBI(vout.value);

        outputTotalSat += outSat;

        if (outAddr === walletAddr) {
          myOutputSat += outSat;
          continue;
        }

        if (PLATFORM_FEE_ADDR_SET.has(outAddr)) {
          platformCandidateSat += outSat;
          if (!firstPlatformFeeAddress && outAddrRaw) firstPlatformFeeAddress = outAddrRaw;
          continue;
        }

        recipientOutputSat += outSat;
        if (firstRecipientAddress === 'Unknown' && outAddrRaw) {
          firstRecipientAddress = outAddrRaw;
        }
      }

      if (!isSent) {
        if (myOutputSat <= 0n) continue;
        if (strictPrevTx && !allInputsResolved) continue;

        await saveTransaction({
          txHash: tx.txid,
          walletAddress: walletAddr,
          from: 'Other',
          to: walletAddr,
          direction: 'received',
          amountSat: myOutputSat.toString(),
          feeSat: null,
          platformFeeSat: null,
          platformFeeAddress: null,
          status: 'confirmed',
          blockHeight: height,
          confirmations,
          timestamp: tsMs,
        });

        continue;
      }

      const feeBI = inputTotalSat - outputTotalSat;
      const feeSatBI = feeBI > 0n ? feeBI : 0n;

      let platformFeeSat = 0n;
      let platformFeeAddress = null;
      let amountSat = 0n;
      let toAddress = 'Unknown';

      if (SPLIT_PLATFORM_FEE) {
        if (recipientOutputSat > 0n && platformCandidateSat > 0n) {
          platformFeeSat = platformCandidateSat;
          platformFeeAddress = firstPlatformFeeAddress || null;
          amountSat = recipientOutputSat;
          toAddress = firstRecipientAddress !== 'Unknown' ? firstRecipientAddress : 'Unknown';
        } else {
          amountSat = recipientOutputSat + platformCandidateSat;
          toAddress =
            firstRecipientAddress !== 'Unknown'
              ? firstRecipientAddress
              : (firstPlatformFeeAddress || 'Unknown');
        }
      } else {
        amountSat = recipientOutputSat + platformCandidateSat;
        toAddress =
          firstRecipientAddress !== 'Unknown'
            ? firstRecipientAddress
            : (firstPlatformFeeAddress || 'Unknown');
      }

      await saveTransaction({
        txHash: tx.txid,
        walletAddress: walletAddr,
        from: walletAddr,
        to: toAddress,
        direction: 'sent',
        amountSat: amountSat.toString(),
        feeSat: feeSatBI.toString(),
        platformFeeSat: (SPLIT_PLATFORM_FEE && platformFeeSat > 0n) ? platformFeeSat.toString() : null,
        platformFeeAddress: (SPLIT_PLATFORM_FEE && platformFeeSat > 0n) ? platformFeeAddress : null,
        status: 'confirmed',
        blockHeight: height,
        confirmations,
        timestamp: tsMs,
      });
    }

    return true;
  } catch (err) {
    console.error(`区块 ${height} 处理失败:`, err?.message || err);
    return false;
  }
}
