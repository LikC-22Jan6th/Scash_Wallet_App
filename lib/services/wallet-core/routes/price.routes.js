import express from 'express';
import { getScashPriceUSD, getScashHistory } from '../services/price.service.js';

const router = express.Router();

router.get('/scash', async (req, res) => {
  try {
    const info = await getScashPriceUSD();

    const price =
      typeof info === 'number'
        ? info
        : (typeof info?.price === 'number' ? info.price : 0);

    res.set('Cache-Control', 'public, max-age=20');
    res.json({
      price,
      usd: price,
      source: typeof info === 'object' ? (info.source ?? 'coingecko') : 'coingecko',
      lastUpdate: typeof info === 'object' ? (info.lastUpdate ?? Date.now()) : Date.now(),
    });
  } catch (e) {
    console.error('price /scash error:', e?.message || e);
    res.status(500).json({ error: 'Failed to fetch price' });
  }
});

router.get('/history', async (req, res) => {
  try {
    const days = req.query.days ?? 1;
    const prices = await getScashHistory(days);
    res.set('Cache-Control', 'public, max-age=30');
    res.json({ prices });
  } catch (e) {
    console.error('price /history error:', e?.message || e);
    res.status(500).json({ error: 'Failed to fetch price history' });
  }
});

export default router;
