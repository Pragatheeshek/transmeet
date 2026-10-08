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
// Start (Local testing)
// ---------------------------------------------------------------------------
if (require.main === module) {
  app.listen(PORT, '0.0.0.0', () => {
    const mockMode = process.env.TRANSLATION_MOCK_MODE === 'true';
    const hasOpenAI = !!process.env.OPENAI_API_KEY;
    const hasGoogleTranslate = !!process.env.GOOGLE_TRANSLATE_API_KEY;
    const hasGoogleTTS = !!process.env.GOOGLE_TTS_API_KEY;

    console.log('');
    console.log('╔══════════════════════════════════════════════════╗');
    console.log(`║  TransMeet Translation Server — port ${PORT}       ║`);
    console.log('╚══════════════════════════════════════════════════╝');
    console.log(`  Mock mode      : ${mockMode ? 'ENABLED (no real APIs used)' : 'DISABLED (real APIs)'}`);
    console.log(`  Whisper / Groq : ${hasOpenAI ? '✓ configured' : '✗ missing OPENAI_API_KEY'}`);
    console.log(`  Google Translate: ${hasGoogleTranslate ? '✓ configured' : '✗ missing GOOGLE_TRANSLATE_API_KEY'}`);
    console.log(`  Google TTS      : ${hasGoogleTTS ? '✓ configured' : '✗ missing GOOGLE_TTS_API_KEY'}`);
    console.log('');
    console.log('  Endpoints:');
    console.log(`    GET  /health`);
    console.log(`    GET  /api/translation/health`);
    console.log(`    POST /api/translation/transcribe`);
    console.log(`    POST /api/translation/translate`);
    console.log(`    POST /api/translation/synthesize`);
    console.log(`    POST /api/translation/pipeline  (combined STT+Translate+TTS)`);
    console.log('');
    console.log('  Server ready. Listening on 0.0.0.0:' + PORT);
    console.log('');
  });
}

// Export the Express app so Firebase Cloud Functions can wrap it
module.exports = app;

