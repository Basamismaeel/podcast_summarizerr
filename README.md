# Podcast Safety Net

Flutter app: podcast discovery, transcription, and AI summaries.

## Spotify share links (clipboard)

Pasting an `open.spotify.com/episode/...` link uses the **Spotify Web API** to read the real episode and show name, then matches that to Taddy’s catalog for the audio URL.

### Listeners (people who download your app)

They **do nothing**. You (the publisher) add Spotify credentials **once** when you build and ship the app. Those values are bundled in the binary (via `.env` in `pubspec.yaml` assets, or via CI secrets — see below). No Spotify Developer account is required for end users.

### You (the developer) — one-time setup

1. Create **one** app in the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).
2. Put **your** Client ID and Client Secret in `.env`:

```env
SPOTIFY_CLIENT_ID=your_client_id
SPOTIFY_CLIENT_SECRET=your_client_secret
```

3. Use **exact** key names. No spaces around `=` (avoid `KEY= value`). The app strips a UTF-8 BOM if your editor adds one.
4. **Release / TestFlight / App Store:** run a **clean release build** so `.env` is copied into the asset bundle. In CI (GitHub Actions, Codemagic, etc.), generate `.env` from **repository secrets** before `flutter build` — same idea, no per-user setup.

**Optional:** In-app **Settings → Spotify API (advanced)** is only for **you** while debugging (e.g. testing keys without rebuilding). You do **not** ask customers to use it.

**Security note:** A client secret inside a mobile app can be extracted by determined users. For a serious production product, prefer a tiny **backend** that holds the secret and returns short-lived tokens or episode metadata (your `API_BASE_URL` is a natural place to add that later).

Short links (`spotify.link`, `spoti.fi`) are expanded automatically before parsing.

## Gemini (summaries)

Summaries call **Google’s Generative Language API** at  
`https://generativelanguage.googleapis.com/{v1beta|v1}/models/{model}:generateContent`  
with header **`x-goog-api-key`**. Default API version is **`v1beta`**; set **`GEMINI_API_VERSION=v1`** in `.env` only if you intentionally need `v1`.

Models are tried in order (**`gemini-2.5-flash`** first, then lite, then 2.0 variants, then **`gemini-flash-latest`**). On **429 / quota**, the app tries the next model (Google often reports `limit: 0` on one model while another still has free tier). The request body uses `contents[].role` = `user`, `contents[].parts[].text`.

**429 “quota exceeded” / `RESOURCE_EXHAUSTED`:** Enable billing or wait for the reset Google mentions; see [rate limits](https://ai.google.dev/gemini-api/docs/rate-limits).

`GEMINI_API_KEY` must be a key from **[Google AI Studio](https://aistudio.google.com/apikey)**. Valid keys almost always start with **`AIza`** (not **`AAIza`** — a stray extra `A` is a common paste typo and will make Google return **API_KEY_INVALID**). If you paste a **Deepgram**, **OpenAI**, or other vendor’s key into `GEMINI_API_KEY`, Google will also reject it.

**There are no API keys hardcoded in Dart** — only `GEMINI_API_KEY` (and other secrets) in **`.env`**, which is **gitignored** (use **`.env.example`** as a template).

### Pushing to GitHub (no leaked secrets)

1. **Never commit `.env`.** If it was ever tracked, run `git rm --cached .env`, commit that change, and **rotate every API key** that was inside (GitHub history keeps old blobs).
2. Before push, run: **`./tool/verify_ready_for_github.sh`** — it errors if `.env` is tracked or if `AIzaSy…` appears in Dart/YAML/JSON.
3. Commit **`.env.example`** only (placeholders). In **GitHub Actions**, inject real values from **repository secrets** when building.

- Put the key in `.env`, then **stop the app and run `flutter run` again** (hot reload does not refresh bundled assets).
- **One-off debug:** pass the flag to **`flutter run`**, not by itself (zsh will error). Example:  
  `flutter run --dart-define=GEMINI_API_KEY=YOUR_AI_STUDIO_KEY`  
  Or: `GEMINI_API_KEY='your_key' ./tool/flutter_run_ios.sh`
- If `.env` on disk is correct but logs still show `startsAIza=false`, the **device build is stale**. Run **`flutter clean`**, delete the app from the phone, then **`flutter run`** again so the `.env` asset is re-bundled.

**400 “API key expired” / `API_KEY_INVALID`:** Google uses that message for **any** bad or blocked key (revoked, leaked, wrong product, restrictions), not only literal expiry. Create a **new** key in AI Studio, enable **Generative Language API** for the project if you use Cloud keys, and avoid restrictions that block `generativelanguage.googleapis.com`.

## Audible

**Audible is not supported for AI summaries.** Audiobooks and Audible exclusives use DRM; there is no legal public audio URL for services like Deepgram to download and transcribe. The app will detect an Audible link in the clipboard and explain this — use **Apple Podcasts** or **Spotify** if the same show exists there, or **Manual Entry**.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
