const axios = require('axios');

const isMockMode = () => process.env.TRANSLATION_MOCK_MODE === 'true';

// Mock translations for development/testing
const MOCK_TRANSLATIONS = {
  'en-ta': { 'Hello, how are you?': 'வணக்கம், எப்படி இருக்கிறீர்கள்?' },
  'ta-en': { 'வணக்கம், எப்படி இருக்கிறீர்கள்?': 'Hello, how are you?' },
};

/**
 * Translates text using Google Cloud Translation REST API v2.
 * Uses the API key directly via HTTP — no SDK, no ADC required.
 *
 * @param {string} text - Text to translate
 * @param {string} sourceLanguage - Source language code (e.g. "en", "ta")
 * @param {string} targetLanguage - Target language code (e.g. "ta", "en")
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

    // Build request params
    const params = {
      q: trimmedText,
      target: targetLanguage,
      key: apiKey,
      format: 'text',
    };

    // Only set source if it's not 'auto' — let Google auto-detect otherwise
    if (sourceLanguage && sourceLanguage !== 'auto') {
      params.source = sourceLanguage;
    }

    const response = await axios.get(
      'https://translation.googleapis.com/language/translate/v2',
      { params, timeout: 15000 }
    );

    const latency = Date.now() - t1;
    const translated = response.data?.data?.translations?.[0]?.translatedText;

    if (!translated) {
      throw new Error('Google Translate returned an empty response.');
    }

    console.log(
      `[Translation API] ${sourceLanguage}→${targetLanguage} latency=${latency}ms` +
      ` "${trimmedText.substring(0, 40)}" → "${translated.substring(0, 40)}"`
    );

    return {
      translatedText: translated,
      sourceLanguage,
      targetLanguage,
    };
  } catch (err) {
    // Unpack axios error for better logging
    if (err.response) {
      const status = err.response.status;
      const msg = err.response.data?.error?.message || err.message;
      console.error(`[Translation API Error] HTTP ${status}: ${msg}`);

      if (status === 400) throw new Error(`Unsupported language or bad request: ${msg}`);
      if (status === 403) throw new Error('API key is invalid or does not have access to Google Translate.');
      if (status === 429) throw new Error('Google Translate rate limit exceeded. Please wait a moment.');
      throw new Error(`Google Translate error (${status}): ${msg}`);
    }
    throw err;
  }
}

module.exports = { translate };
