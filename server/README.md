# TransMeet Translation Backend

Node.js/Express server that provides AI translation services for the TransMeet Flutter app.

## Architecture

```
Flutter App
    ↓ HTTP
Node.js / Express (this server)
    ├── POST /api/translation/transcribe  →  OpenAI Whisper
    ├── POST /api/translation/translate   →  Google Cloud Translation
    └── POST /api/translation/synthesize  →  Google Cloud TTS
```

## Prerequisites

- Node.js >= 18.0.0
- npm

## Setup

### 1. Install dependencies

```bash
cd server
npm install
```

### 2. Configure environment variables

Copy the example file and fill in your API keys:

```bash
cp .env.example .env
```

Edit `.env`:

```
OPENAI_API_KEY=sk-your-openai-key
GOOGLE_TRANSLATE_API_KEY=your-google-translate-key
GOOGLE_TTS_API_KEY=your-google-tts-key
TRANSLATION_MOCK_MODE=false
PORT=3001
```

### 3. Obtaining API Keys

**OpenAI API Key (Whisper)**
1. Go to https://platform.openai.com/api-keys
2. Create a new API key
3. Set as `OPENAI_API_KEY`

**Google Cloud Translation API Key**
1. Go to https://console.cloud.google.com
2. Enable "Cloud Translation API"
3. Create an API key under Credentials
4. Set as `GOOGLE_TRANSLATE_API_KEY`

**Google Cloud TTS API Key**
1. Go to https://console.cloud.google.com
2. Enable "Cloud Text-to-Speech API"
3. Create an API key (or reuse the Translation key if scoped appropriately)
4. Set as `GOOGLE_TTS_API_KEY`

### 4. Start the server

```bash
npm start
```

Or for development with auto-reload:

```bash
npm run dev
```

## Mock Mode

Set `TRANSLATION_MOCK_MODE=true` in `.env` to use mock responses without real API keys.

When mock mode is enabled:
- **Transcribe** returns: `{ "text": "Hello, how are you?", "language": "en" }`
- **Translate** returns canned translations for common phrases, or `[Mock <lang>] <text>` for unknown text
- **Synthesize** returns a silent WAV audio file (base64-encoded)

This is useful for development and testing the end-to-end pipeline without API costs.

## API Reference

### Health Check

```
GET /api/translation/health
```

Response:
```json
{ "status": "ok", "mockMode": true }
```

### Transcribe (Speech-to-Text)

```
POST /api/translation/transcribe
Content-Type: multipart/form-data

Field: audio (file)
```

Response:
```json
{
  "text": "Where is the meeting?",
  "language": "en"
}
```

### Translate

```
POST /api/translation/translate
Content-Type: application/json

{
  "text": "Where is the meeting?",
  "sourceLanguage": "en",
  "targetLanguage": "ta"
}
```

Response:
```json
{
  "translatedText": "கூட்டம் எங்கே நடக்கிறது?",
  "sourceLanguage": "en",
  "targetLanguage": "ta"
}
```

### Synthesize (Text-to-Speech)

```
POST /api/translation/synthesize
Content-Type: application/json

{
  "text": "கூட்டம் எங்கே நடக்கிறது?",
  "languageCode": "ta"
}
```

Response:
```json
{
  "audioContent": "<base64-encoded-audio>"
}
```

## Connecting from Flutter

The Flutter app connects to this server via HTTP. During development on a physical Android device, use your machine's LAN IP:

```
http://192.168.x.x:3001
```

Update the `backendBaseUrl` constant in the Flutter app's `app_constants.dart`.

## Testing Two Users

1. Start this server on your development machine
2. Install the Flutter app on two Android devices
3. Both devices must be on the same network as the server
4. User A: Set preferred language to English
5. User B: Set preferred language to Tamil
6. Create a meeting on Device A, join from Device B
7. Enable translation (🌐 button)
8. User A speaks → User B sees Tamil translation
