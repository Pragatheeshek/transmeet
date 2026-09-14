const whisperService = require('../services/whisper.service');
const translationService = require('../services/translation.service');
const ttsService = require('../services/tts.service');

/**
 * POST /api/translation/transcribe
 * Accepts an audio file (multipart/form-data field "audio").
 * Returns { text, language }.
 */
async function transcribe(req, res) {
  const requestId = `stt-${Date.now()}`;
  const t1 = Date.now();

  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No audio file provided.' });
    }

    const result = await whisperService.transcribe(req.file.buffer, req.file.originalname);
    const latency = Date.now() - t1;
    console.log(`[Transcribe] requestId=${requestId} latency=${latency}ms text="${result.text?.substring(0, 80)}"`);
    return res.json(result);
  } catch (err) {
    const latency = Date.now() - t1;
    console.error(`[Transcribe Error] requestId=${requestId} latency=${latency}ms error=${err.message}`);

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
  const requestId = `tr-${Date.now()}`;
  const t1 = Date.now();

  try {
    const { text, sourceLanguage, targetLanguage } = req.body;

    if (!text || typeof text !== 'string' || text.trim().length === 0) {
      return res.status(400).json({ error: 'Text is required.' });
    }
    if (!sourceLanguage || !targetLanguage) {
      return res.status(400).json({ error: 'Source and target languages are required.' });
    }

    const trimmedText = text.trim();

    if (sourceLanguage === targetLanguage) {
      return res.json({
        translatedText: trimmedText,
        sourceLanguage,
        targetLanguage,
      });
    }

    const result = await translationService.translate(trimmedText, sourceLanguage, targetLanguage);
    const latency = Date.now() - t1;
    console.log(
      `[Translate] requestId=${requestId} latency=${latency}ms` +
      ` ${sourceLanguage}→${targetLanguage} "${trimmedText.substring(0, 60)}" → "${(result.translatedText || '').substring(0, 60)}"`
    );
    return res.json(result);
  } catch (err) {
    const latency = Date.now() - t1;
    console.error(
      `[Translate Error] requestId=${requestId} latency=${latency}ms` +
      ` source=${req.body?.sourceLanguage} target=${req.body?.targetLanguage}` +
      ` error=${err.message}`
    );

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
  const requestId = `tts-${Date.now()}`;
  const t1 = Date.now();

  try {
    const { text, languageCode } = req.body;

    if (!text || typeof text !== 'string' || text.trim().length === 0) {
      return res.status(400).json({ error: 'Text is required.' });
    }
    if (!languageCode) {
      return res.status(400).json({ error: 'Language code is required.' });
    }

    const result = await ttsService.synthesize(text.trim(), languageCode);
    const latency = Date.now() - t1;
    console.log(`[Synthesize] requestId=${requestId} latency=${latency}ms lang=${languageCode} textLen=${text.trim().length}`);
    return res.json(result);
  } catch (err) {
    const latency = Date.now() - t1;
    console.error(
      `[Synthesize Error] requestId=${requestId} latency=${latency}ms` +
      ` lang=${req.body?.languageCode} error=${err.message}`
    );

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
