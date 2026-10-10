const OpenAI = require('openai');
const fs = require('fs');
const path = require('path');
const os = require('os');

const isMockMode = () => process.env.TRANSLATION_MOCK_MODE === 'true';

/**
 * Transcribes audio using OpenAI Whisper API.
 *
 * @param {Buffer} audioBuffer - Raw audio data
 * @param {string} originalName - Original filename (used for extension detection)
 * @returns {Promise<{text: string, language: string}>}
 */
async function transcribe(audioBuffer, originalName = 'audio.wav', language = null) {
  if (isMockMode()) {
    console.log('[Whisper Mock] Returning mock transcription');
    return {
      text: 'Hello, how are you?',
      language: language || 'en',
    };
  }

  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    throw new Error('API key not configured: OPENAI_API_KEY');
  }

  // Whisper requires a file, so we write the buffer to a temp file.
  const ext = path.extname(originalName) || '.wav';
  const tempPath = path.join(os.tmpdir(), `transmeet_audio_${Date.now()}${ext}`);

  try {
    fs.writeFileSync(tempPath, audioBuffer);

    const t1 = Date.now();
    const openai = new OpenAI({
      apiKey,
      baseURL: 'https://api.groq.com/openai/v1'
    });
    const options = {
      file: fs.createReadStream(tempPath),
      model: 'whisper-large-v3-turbo',
      response_format: 'verbose_json',
      prompt: 'The speaker is speaking in either English or Tamil (தமிழ்). Do not transcribe in any other language.',
    };

    if (language && language !== 'auto') {
      options.language = language;
    }

    const response = await openai.audio.transcriptions.create(options);

    const latency = Date.now() - t1;
    console.log(
      `[Whisper API] latency=${latency}ms lang=${response.language || 'unknown'}` +
      ` text="${(response.text || '').substring(0, 80)}"`
    );

    return {
      text: response.text || '',
      language: response.language || 'en',
    };
  } finally {
    // Clean up temp file
    try {
      fs.unlinkSync(tempPath);
    } catch (_) {
      // Ignore cleanup errors
    }
  }
}

module.exports = { transcribe };
