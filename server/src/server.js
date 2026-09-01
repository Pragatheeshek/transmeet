require('dotenv').config();

const express = require('express');
const cors = require('cors');
const translationRoutes = require('./routes/translation.routes');

const app = express();
const PORT = process.env.PORT || 3001;

// ---------------------------------------------------------------------------
// Middleware
// ---------------------------------------------------------------------------
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------
app.use('/api/translation', translationRoutes);

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ---------------------------------------------------------------------------
// Error handler
// ---------------------------------------------------------------------------
app.use((err, _req, res, _next) => {
  console.error('[Server Error]', err.message);
  res.status(500).json({ error: 'Internal server error' });
});

// ---------------------------------------------------------------------------
// Start
// ---------------------------------------------------------------------------
app.listen(PORT, '0.0.0.0', () => {
  const mockMode = process.env.TRANSLATION_MOCK_MODE === 'true';
  console.log(`TransMeet server running on port ${PORT}`);
  console.log(`Mock mode: ${mockMode ? 'ENABLED' : 'DISABLED'}`);
  if (mockMode) {
    console.log('  → Using mock responses (no API keys required)');
  }
});
