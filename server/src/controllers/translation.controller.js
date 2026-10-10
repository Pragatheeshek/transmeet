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

    const language = req.body?.language;
    const result = await whisperService.transcribe(req.file.buffer, req.file.originalname, language);
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

/**
 * POST /api/translation/pipeline
 * Accepts: multipart/form-data with:
 *   audio           (file)   — audio bytes (m4a, wav, mp3…)
 *   targetLanguage  (text)   — e.g. "hi"
 *   sourceLanguage  (text)   — optional; omit or "auto" for auto-detect
 *
 * Runs the full pipeline server-side in sequence:
 *   Whisper STT → Google Translate → Google TTS
 *
 * Returns:
 *   { transcript, detectedLanguage, translatedText, audioContent, skippedTranslation }
 *
 * Benefits vs 3 separate calls:
 *   - 2 fewer HTTP round-trips from the mobile client (saves ~300–800ms on LAN)
 *   - Single error boundary for the whole pipeline
 *   - Atomic: if Whisper returns empty text the pipeline short-circuits cleanly
 */
async function pipeline(req, res) {
  const requestId = `pipe-${Date.now()}`;
  const t1 = Date.now();

  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No audio file provided.' });
    }

    const targetLanguage = req.body?.targetLanguage;
    if (!targetLanguage) {
      return res.status(400).json({ error: 'targetLanguage is required.' });
    }

    const sourceLanguage = req.body?.sourceLanguage || 'auto';

    // ── Step 1: Whisper STT ───────────────────────────────────────────────────
    console.log(`[Pipeline] ${requestId} step=STT bytes=${req.file.buffer.length}`);
    const sttResult = await whisperService.transcribe(req.file.buffer, req.file.originalname || 'audio.m4a');
    const transcript = (sttResult.text || '').trim();
    const detectedLanguage = sttResult.language || 'en';

    console.log(`[Pipeline] ${requestId} step=STT done lang=${detectedLanguage} text="${transcript.substring(0, 60)}"`);

    if (!transcript) {
      const latency = Date.now() - t1;
      console.log(`[Pipeline] ${requestId} empty transcript — skipping. latency=${latency}ms`);
      return res.json({
        transcript: '',
        detectedLanguage,
        translatedText: '',
        audioContent: '',
        skippedTranslation: true,
      });
    }

    // ── Step 2: Google Translate ──────────────────────────────────────────────
    let translatedText = transcript;
    let skippedTranslation = false;

    const effectiveSource = (sourceLanguage === 'auto' || !sourceLanguage) ? detectedLanguage : sourceLanguage;

    if (effectiveSource !== targetLanguage) {
      console.log(`[Pipeline] ${requestId} step=TRANSLATE ${effectiveSource}→${targetLanguage}`);
      const translateResult = await translationService.translate(transcript, effectiveSource, targetLanguage);
      translatedText = translateResult.translatedText || transcript;
      console.log(`[Pipeline] ${requestId} step=TRANSLATE done text="${translatedText.substring(0, 60)}"`);
    } else {
      skippedTranslation = true;
      console.log(`[Pipeline] ${requestId} step=TRANSLATE skipped (source==target)`);
    }

    // ── Step 3: Google TTS ────────────────────────────────────────────────────
    console.log(`[Pipeline] ${requestId} step=TTS lang=${targetLanguage}`);
    let audioContent = '';
    try {
      const ttsResult = await ttsService.synthesize(translatedText, targetLanguage);
      audioContent = ttsResult.audioContent || '';
      console.log(`[Pipeline] ${requestId} step=TTS done audioLen=${audioContent.length}`);
    } catch (ttsErr) {
      // TTS failure is non-fatal — return text results with no audio.
      console.error(`[Pipeline] ${requestId} TTS error (non-fatal): ${ttsErr.message}`);
    }

    const latency = Date.now() - t1;
    console.log(`[Pipeline] ${requestId} COMPLETE latency=${latency}ms`);

    return res.json({
      transcript,
      detectedLanguage,
      translatedText,
      audioContent,
      skippedTranslation,
    });
  } catch (err) {
    const latency = Date.now() - t1;
    console.error(`[Pipeline Error] ${requestId} latency=${latency}ms error=${err.message}`);

    if (err.message.includes('Invalid audio')) {
      return res.status(400).json({ error: 'Invalid audio format.' });
    }
    if (err.message.includes('API key')) {
      return res.status(503).json({ error: 'A required service is unavailable.' });
    }
    return res.status(500).json({ error: 'Translation pipeline failed. Please try again.' });
  }
}

module.exports = { transcribe, translate, synthesize, pipeline };

