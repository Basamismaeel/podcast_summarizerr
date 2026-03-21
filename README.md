# podcast_safety_net

A new Flutter project.

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
