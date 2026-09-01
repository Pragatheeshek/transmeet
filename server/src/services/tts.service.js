const axios = require('axios');

const isMockMode = () => process.env.TRANSLATION_MOCK_MODE === 'true';

// Language code to Google TTS voice mapping
const VOICE_MAP = {
  'en': { languageCode: 'en-US', name: 'en-US-Standard-C' },
  'ta': { languageCode: 'ta-IN', name: 'ta-IN-Standard-A' },
  'hi': { languageCode: 'hi-IN', name: 'hi-IN-Standard-A' },
  'te': { languageCode: 'te-IN', name: 'te-IN-Standard-A' },
  'ml': { languageCode: 'ml-IN', name: 'ml-IN-Standard-A' },
  'kn': { languageCode: 'kn-IN', name: 'kn-IN-Standard-A' },
  'es': { languageCode: 'es-ES', name: 'es-ES-Standard-A' },
  'fr': { languageCode: 'fr-FR', name: 'fr-FR-Standard-A' },
  'de': { languageCode: 'de-DE', name: 'de-DE-Standard-A' },
  'ja': { languageCode: 'ja-JP', name: 'ja-JP-Standard-A' },
};

// A minimal valid WAV file (44 bytes header + ~100ms silence at 16kHz mono)
function generateSilentWav() {
  const sampleRate = 16000;
  const numSamples = 1600; // 100ms
  const bytesPerSample = 2;
  const dataSize = numSamples * bytesPerSample;
  const headerSize = 44;
  const buffer = Buffer.alloc(headerSize + dataSize);

  // RIFF header
  buffer.write('RIFF', 0);
  buffer.writeUInt32LE(headerSize + dataSize - 8, 4);
  buffer.write('WAVE', 8);

  // fmt sub-chunk
  buffer.write('fmt ', 12);
  buffer.writeUInt32LE(16, 16);         // Sub-chunk size
  buffer.writeUInt16LE(1, 20);          // PCM format
  buffer.writeUInt16LE(1, 22);          // Mono
  buffer.writeUInt32LE(sampleRate, 24); // Sample rate
  buffer.writeUInt32LE(sampleRate * bytesPerSample, 28); // Byte rate
  buffer.writeUInt16LE(bytesPerSample, 32); // Block align
  buffer.writeUInt16LE(16, 34);         // Bits per sample

  // data sub-chunk
  buffer.write('data', 36);
  buffer.writeUInt32LE(dataSize, 40);
  // Samples are already 0 (silence)

  return buffer;
}

/**
 * Synthesizes speech from text using Google Cloud TTS REST API.
 *
 * @param {string} text - Text to synthesize
 * @param {string} languageCode - Language code (e.g. "ta")
 * @returns {Promise<{audioContent: string}>} Base64-encoded audio
 */
async function synthesize(text, languageCode) {
  if (isMockMode()) {
    console.log(`[TTS Mock] Generating mock audio for "${text}" (${languageCode})`);
    const silentAudio = generateSilentWav();
    return {
      audioContent: silentAudio.toString('base64'),
    };
  }

  const apiKey = process.env.GOOGLE_TTS_API_KEY;
  if (!apiKey) {
    throw new Error('API key not configured: GOOGLE_TTS_API_KEY');
  }

  const voice = VOICE_MAP[languageCode];
  if (!voice) {
    throw new Error(`Unsupported language for TTS: ${languageCode}`);
  }

  try {
    const response = await axios.post(
      `https://texttospeech.googleapis.com/v1/text:synthesize?key=${apiKey}`,
      {
        input: { text },
        voice: {
          languageCode: voice.languageCode,
          name: voice.name,
        },
        audioConfig: {
          audioEncoding: 'MP3',
        },
      },
      {
        timeout: 30000,
      }
    );

    return {
      audioContent: response.data.audioContent,
    };
  } catch (err) {
    if (err.response && err.response.status === 400) {
      throw new Error(`Unsupported language for TTS: ${languageCode}`);
    }
    throw err;
  }
}

module.exports = { synthesize };
