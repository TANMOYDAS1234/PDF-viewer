# PDF Viewer Pro — Workflow & Design Guide

An advanced, premium Flutter PDF viewer for Android. This document is the single
source of truth for **how the app is built, how to run it, and how to design it**
(including ready-to-paste prompts for Stitch AI, logo, and splash animation).

---

## 1. What the app does

| Area | Features |
|------|----------|
| **Open** | Registers as a system PDF handler → appears in Android "Open with"; file picker; recent files with resume-to-page |
| **View** | Pinch/zoom, single-page & continuous layouts, vertical/horizontal scroll, night mode, page thumbnails grid |
| **Find** | Full-text search with match navigation; document outline / bookmarks |
| **Annotate** | Highlight, underline, strikethrough, squiggly, sticky notes; 6-colour palette; undo/redo |
| **Listen** | Text-to-speech "Read aloud" with play/pause, next page, speed control |
| **Tools** | Merge multiple PDFs; split / extract a page range |
| **Output** | Save a copy to device (system Save dialog), share, print |
| **UX** | Light / dark / system theme; premium indigo→violet identity; custom logo & splash |

Monetization (AdMob + "Remove Ads" purchase) is **built but disabled** for
personal use — see `monetization_disabled/README.md` to switch it on before
publishing.

---

## 2. Architecture

```
lib/
├─ main.dart                     App root, theme, cold/warm "Open with" routing
├─ services/
│  ├─ app_intent.dart            MethodChannel bridge to native intent handler
│  ├─ theme_controller.dart      Light/dark/system, persisted
│  ├─ recent_files.dart          Recent list + resume page (SharedPreferences)
│  └─ pdf_tools.dart             Merge / split via Syncfusion templates
├─ screens/
│  ├─ home_screen.dart           Library: recents, open, tools, theme
│  ├─ viewer_screen.dart         The full viewer (search/annotate/TTS/save/print)
│  ├─ thumbnail_grid.dart        Page thumbnails (printing.raster)
│  └─ tools_screen.dart          Merge / Split tabs
android/app/src/main/
├─ AndroidManifest.xml           PDF intent-filters (VIEW/SEND application/pdf)
└─ kotlin/.../MainActivity.kt    Reads the opened file/URI → hands path to Flutter
monetization_disabled/           Ads + IAP code, kept for re-enable
```

**Rendering engine:** Syncfusion (`syncfusion_flutter_pdfviewer` / `_pdf`), pinned
`>=30.1.38 <33.2.13` so it stays compatible with `printing`. Add a free
[Syncfusion Community licence](https://www.syncfusion.com/products/communitylicense)
key in `main.dart` to remove the trial banner.

---

## 3. Build & run

```bash
# Run on a connected device (debug)
flutter run

# Personal release APK — small (~9.6 MB), signed with your upload key
flutter build apk --release --target-platform android-arm64 --obfuscate --split-debug-info=build/symbols
# output: build/app/outputs/flutter-apk/app-release.apk

# Play Store bundle (all device types)
flutter build appbundle --release
# output: build/app/outputs/bundle/release/app-release.aab
```

Signing is configured in `android/key.properties` + `android/app/build.gradle.kts`.
**Keep `android/app/upload-keystore.jks` and `key.properties` private and backed
up** — losing them means you can't update the app after publishing.

Size levers already applied: R8 minify + resource shrink, code obfuscation,
compressed native libs (`useLegacyPackaging`), removed unused SDKs.

---

## 4. Design system (premium)

A calm, premium, "trust-worthy document tool" look: deep indigo brand, generous
white space, rounded 16–20 px cards, soft shadows, one warm accent for premium
moments.

### Colour palette

| Role | Light | Dark | Notes |
|------|-------|------|-------|
| **Brand gradient** | `#6366F1 → #8B5CF6` | same | Indigo → Violet, used in headers/splash |
| Primary | `#4F46E5` | `#8B8CF0` | Buttons, active states |
| Primary container | `#E0E7FF` | `#2A2A55` | Chips, tonal buttons |
| Secondary / Violet | `#7C3AED` | `#A78BFA` | Secondary accents |
| **Premium accent (gold)** | `#F59E0B` | `#FBBF24` | Crown / "Pro" / highlights only |
| Background | `#F7F8FC` | `#0E0E12` | App background |
| Surface / Card | `#FFFFFF` | `#17171F` | Cards, sheets |
| On-surface | `#1E1B2E` | `#E7E5F0` | Primary text |
| On-surface muted | `#6B7280` | `#9CA3AF` | Secondary text |
| PDF red (badge) | `#E11D48` | `#F43F5E` | The "PDF" mark |
| Success | `#22C55E` | `#4ADE80` | Save/merge done |
| Error | `#EF4444` | `#F87171` | Failures |

### Typography
- **Headings:** Sora or Space Grotesk (600/700) — modern, premium.
- **Body/UI:** Inter or Plus Jakarta Sans (400/500/600).
- Scale: Display 28–32, Title 20–22, Body 14–16, Caption 12–13.

### Shape, spacing, motion
- Corners: cards 16, sheets 24, buttons 14, chips full-round.
- Spacing base unit: 4 px (use 8/12/16/24/32).
- Elevation: soft, low (`0–8`), coloured shadows tinted with primary at 8–12% alpha.
- Motion: 200–300 ms ease-out; shared-axis transitions between screens; subtle
  scale/opacity on tap.

---

## 5. Using Stitch AI to design the screens

[Stitch](https://stitch.withgoogle.com) turns text prompts into mobile UI you can
refine and export to Figma / front-end code.

**Workflow:**
1. Open Stitch → **New project → Mobile**.
2. Paste the **master prompt** from `STITCH_PROMPTS.md` (sets app, palette, type,
   mood). Generate the Home screen first.
3. For each remaining screen, paste that screen's prompt (same file) so the style
   stays consistent. Use "Edit" to nudge spacing/colours.
4. Export → copy the design tokens/Figma; translate to Flutter:
   - Colours → a `ColorScheme.fromSeed` + overrides (see palette above).
   - Fonts → add `google_fonts` and set `textTheme`.
   - Reuse existing widgets; only restyle (don't rewrite logic).
5. Keep screen **behaviour** from this repo; take **visuals** from Stitch.

See `STITCH_PROMPTS.md` for the exact prompts (master + per-screen + logo + splash).

---

## 6. Logo & splash

- **Current logo:** folded document + red "PDF" badge on indigo→violet gradient
  (`assets/icon/`). Regenerate via `python make_assets.py` (see repo) then
  `dart run flutter_launcher_icons`.
- **Splash:** `flutter_native_splash` shows a static mark on the brand colour.
  For an **animated** splash, add a first-run Flutter screen using **Lottie**
  (`lottie` package) or **Rive** and route to Home when it finishes.
- Generation prompts (logo + animated splash concept) are in `STITCH_PROMPTS.md`.

---

## 7. Publish checklist (recap)

1. Re-enable monetization (optional) — `monetization_disabled/README.md`.
2. Add real Syncfusion licence key.
3. `flutter build appbundle --release`.
4. Play Console ($25 one-time) → create app → listing, content rating, data
   safety, privacy policy → upload `.aab` → testing track → production.
