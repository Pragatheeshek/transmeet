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
  res.json({
    status: 'ok',
    mockMode: process.env.TRANSLATION_MOCK_MODE === 'true',
  });
});

// Speech-to-text via Whisper
router.post('/transcribe', upload.single('audio'), controller.transcribe);

// Text translation via Google Translate
router.post('/translate', controller.translate);

// Text-to-speech via Google Cloud TTS
router.post('/synthesize', controller.synthesize);

module.exports = router;
