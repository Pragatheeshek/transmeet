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
async function transcribe(audioBuffer, originalName = 'audio.wav') {
  if (isMockMode()) {
    console.log('[Whisper Mock] Returning mock transcription');
    return {
      text: 'Hello, how are you?',
      language: 'en',
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

    const openai = new OpenAI({ apiKey });
    const response = await openai.audio.transcriptions.create({
      file: fs.createReadStream(tempPath),
      model: 'whisper-1',
      response_format: 'verbose_json',
    });

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
