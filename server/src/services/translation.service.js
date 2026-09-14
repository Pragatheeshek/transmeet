const { Translate } = require('@google-cloud/translate').v2;

const isMockMode = () => process.env.TRANSLATION_MOCK_MODE === 'true';

// Mock translations for development/testing
const MOCK_TRANSLATIONS = {
  'en-ta': { 'Hello, how are you?': 'வணக்கம், எப்படி இருக்கிறீர்கள்?' },
  'en-hi': { 'Hello, how are you?': 'नमस्ते, आप कैसे हैं?' },
  'ta-en': { 'வணக்கம், எப்படி இருக்கிறீர்கள்?': 'Hello, how are you?' },
  'hi-en': { 'नमस्ते, आप कैसे हैं?': 'Hello, how are you?' },
};

/**
 * Translates text using Google Cloud Translation API.
 *
 * @param {string} text - Text to translate
 * @param {string} sourceLanguage - Source language code (e.g. "en")
 * @param {string} targetLanguage - Target language code (e.g. "ta")
 * @returns {Promise<{translatedText: string, sourceLanguage: string, targetLanguage: string}>}
 */
async function translate(text, sourceLanguage, targetLanguage) {
  const trimmedText = (text || '').trim();
  if (!trimmedText) {
    throw new Error('Text is empty after trimming.');
  }

  if (isMockMode()) {
    console.log(`[Translation Mock] ${sourceLanguage} → ${targetLanguage}: "${trimmedText}"`);
    const key = `${sourceLanguage}-${targetLanguage}`;
    const mockResult = MOCK_TRANSLATIONS[key]?.[trimmedText];
    return {
      translatedText: mockResult || `[Mock ${targetLanguage}] ${trimmedText}`,
      sourceLanguage,
      targetLanguage,
    };
  }

  const apiKey = process.env.GOOGLE_TRANSLATE_API_KEY;
  if (!apiKey) {
    throw new Error('API key not configured: GOOGLE_TRANSLATE_API_KEY');
  }

  try {
    const t1 = Date.now();
    const client = new Translate({ key: apiKey });

    const options = { to: targetLanguage };
    // Only set 'from' if it's not 'auto' — let Google auto-detect otherwise
    if (sourceLanguage && sourceLanguage !== 'auto') {
      options.from = sourceLanguage;
    }

    const [result] = await client.translate(trimmedText, options);

    const latency = Date.now() - t1;
    console.log(
      `[Translation API] ${sourceLanguage}→${targetLanguage} latency=${latency}ms` +
      ` "${trimmedText.substring(0, 40)}" → "${(result || '').substring(0, 40)}"`
    );

    return {
      translatedText: result,
      sourceLanguage,
      targetLanguage,
    };
  } catch (err) {
    if (err.message && err.message.includes('is not supported')) {
      throw new Error(`Unsupported language: ${sourceLanguage} → ${targetLanguage}`);
    }
    throw err;
  }
}

module.exports = { translate };
