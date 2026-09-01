const whisperService = require('../services/whisper.service');
const translationService = require('../services/translation.service');
const ttsService = require('../services/tts.service');

/**
 * POST /api/translation/transcribe
 * Accepts an audio file (multipart/form-data field "audio").
 * Returns { text, language }.
 */
async function transcribe(req, res) {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No audio file provided.' });
    }

    const result = await whisperService.transcribe(req.file.buffer, req.file.originalname);
    return res.json(result);
  } catch (err) {
    console.error('[Transcribe Error]', err.message);
    if (err.message.includes('Invalid audio')) {
      return res.status(400).json({ error: 'Invalid audio format.' });
    }
    if (err.message.includes('API key')) {
      return res.status(503).json({ error: 'Speech recognition service unavailable.' });
    }
    return res.status(500).json({ error: 'Speech recognition failed. Please try again.' });
  }
}

/**
 * POST /api/translation/translate
 * Accepts { text, sourceLanguage, targetLanguage }.
 * Returns { translatedText, sourceLanguage, targetLanguage }.
 */
async function translate(req, res) {
  try {
    const { text, sourceLanguage, targetLanguage } = req.body;

    if (!text || typeof text !== 'string' || text.trim().length === 0) {
      return res.status(400).json({ error: 'Text is required.' });
    }
    if (!sourceLanguage || !targetLanguage) {
      return res.status(400).json({ error: 'Source and target languages are required.' });
    }
    if (sourceLanguage === targetLanguage) {
      return res.json({
        translatedText: text,
        sourceLanguage,
        targetLanguage,
      });
    }

    const result = await translationService.translate(text, sourceLanguage, targetLanguage);
    return res.json(result);
  } catch (err) {
    console.error('[Translate Error]', err.message);
    if (err.message.includes('Unsupported language')) {
      return res.status(400).json({ error: err.message });
    }
    if (err.message.includes('API key')) {
      return res.status(503).json({ error: 'Translation service unavailable.' });
    }
    return res.status(500).json({ error: 'Translation failed. Please try again.' });
  }
}

/**
 * POST /api/translation/synthesize
 * Accepts { text, languageCode }.
 * Returns { audioContent } (base64-encoded audio).
 */
async function synthesize(req, res) {
  try {
    const { text, languageCode } = req.body;

    if (!text || typeof text !== 'string' || text.trim().length === 0) {
      return res.status(400).json({ error: 'Text is required.' });
    }
    if (!languageCode) {
      return res.status(400).json({ error: 'Language code is required.' });
    }

    const result = await ttsService.synthesize(text, languageCode);
    return res.json(result);
  } catch (err) {
    console.error('[Synthesize Error]', err.message);
    if (err.message.includes('Unsupported language')) {
      return res.status(400).json({ error: err.message });
    }
    if (err.message.includes('API key')) {
      return res.status(503).json({ error: 'Text-to-speech service unavailable.' });
    }
    return res.status(500).json({ error: 'Text-to-speech failed. Please try again.' });
  }
}

module.exports = { transcribe, translate, synthesize };
