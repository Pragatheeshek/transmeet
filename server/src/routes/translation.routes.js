const express = require('express');
const multer = require('multer');
const controller = require('../controllers/translation.controller');

const router = express.Router();

// Multer stores uploaded audio in memory for forwarding to Whisper.
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 25 * 1024 * 1024 }, // 25 MB max (Whisper limit)
});

// Health check for the translation subsystem
router.get('/health', (_req, res) => {
  const mockMode = process.env.TRANSLATION_MOCK_MODE === 'true';

  // Check which API keys are configured (without exposing values)
  const config = {
    openaiKey: !!process.env.OPENAI_API_KEY,
    googleTranslateKey: !!process.env.GOOGLE_TRANSLATE_API_KEY,
    googleTtsKey: !!process.env.GOOGLE_TTS_API_KEY,
  };

  const allConfigured = mockMode || (config.googleTranslateKey && config.googleTtsKey);

  res.json({
    service: 'translation',
    status: allConfigured ? 'ready' : 'misconfigured',
    configured: allConfigured,
    mockMode,
    apis: {
      whisperSTT: config.openaiKey ? 'configured' : 'not configured',
      googleTranslate: config.googleTranslateKey ? 'configured' : (mockMode ? 'mock' : 'not configured'),
      googleTTS: config.googleTtsKey ? 'configured' : (mockMode ? 'mock' : 'not configured'),
    },
  });
});

// Speech-to-text via Whisper
router.post('/transcribe', upload.single('audio'), controller.transcribe);

// Text translation via Google Translate
router.post('/translate', controller.translate);

// Text-to-speech via Google Cloud TTS
router.post('/synthesize', controller.synthesize);

module.exports = router;
