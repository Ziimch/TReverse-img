# Lens Finder

Reverse image search app (Flutter, Android). Pick or shoot a photo, optionally
crop it, and get Similar / Exact / Product matches from Google Lens via SerpApi.

## Features
- Gallery + camera, crop-to-object (pure Dart), optional text refinement
- Similar / Exact / Products tabs, "best guess" card, locale-aware results
- Search history stored on-device (reopening costs no API credits)
- In-app browser, open in default browser, copy link
- Light / Dark / System theme, app icon, splash screen
- Versioned releases that install over previous ones (stable signing key)

## 1. API keys (free)
- **SerpApi**: https://serpapi.com/manage-api-key (~100 searches/month free)
- **ImgBB**: https://api.imgbb.com/ (SerpApi needs an image *URL*; uploads auto-delete after 10 min)
Enter both in the app: **Settings → API keys**.

## 2. Build with GitHub Actions
Push the repo contents, then either:
- `git tag v2.0.0 && git push origin v2.0.0`  (version name taken from the tag), or
- Actions tab → *Build & Release APK* → *Run workflow*.
The APK is attached to the repo's **Releases** page.
Repo → Settings → Actions → General → Workflow permissions: allow read/write.

## 3. Signing
`signing/debug.keystore` is a throwaway key bundled for personal sideloading so
updates install over older versions. For stricter control, add a repo secret
`DEBUG_KEYSTORE_BASE64` (base64 of your own keystore, alias `androiddebugkey`,
password `android`). For Play Store publishing use a proper upload key.

## Layout
```
lib/main.dart            bootstrap + bottom-nav shell
lib/models.dart          data + JSON
lib/services.dart        ImgBB / SerpApi / history storage
lib/state.dart           controllers + AppScope
lib/widgets.dart         shared widgets
lib/screens/             search, history, settings, web
assets/                  icon, adaptive icon foreground, splash
signing/debug.keystore   stable signing key
```
