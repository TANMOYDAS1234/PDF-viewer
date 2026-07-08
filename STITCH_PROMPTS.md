# Stitch AI Prompts — PDF Viewer Pro

Copy-paste these into [Stitch](https://stitch.withgoogle.com) (Mobile project).
Start with the **Master prompt**, generate the Home screen, then run each
**screen prompt** so the whole app shares one design language. Prompts for the
**logo** and **animated splash** are at the bottom (use an image/animation AI).

---

## 0) MASTER PROMPT (paste first)

```
Design a premium, modern Android app called "PDF Viewer Pro" — an advanced,
trustworthy PDF reader and toolkit. Target users: students, professionals, and
office workers who read, annotate, and manage PDFs on the go. The feeling should
be calm, focused, premium and effortless — like a high-end productivity app.

DESIGN SYSTEM (use consistently on every screen):
- Brand: indigo → violet gradient (#6366F1 → #8B5CF6). Primary #4F46E5,
  secondary violet #7C3AED. One warm premium accent, gold #F59E0B, used sparingly
  for "Pro"/premium moments only. PDF badge red #E11D48.
- Neutrals (light): background #F7F8FC, cards/surfaces #FFFFFF, text #1E1B2E,
  muted text #6B7280. (Dark): background #0E0E12, surfaces #17171F, text #E7E5F0,
  muted #9CA3AF. Design BOTH light and dark versions.
- Typography: headings in "Sora" (600/700), body/UI in "Inter" (400/500/600).
- Shape: rounded corners — cards 16px, bottom sheets 24px, buttons 14px, chips
  fully rounded. Soft, low, indigo-tinted shadows. Generous white space.
- Iconography: rounded, consistent line weight (Material Symbols Rounded).
- Motion feel: smooth, 200–300ms ease-out, subtle scale on tap.
Make it clean, uncluttered, highly legible, and accessible (AA contrast).
```

---

## 1) Home / Library screen

```
Home screen for PDF Viewer Pro. A top header with the indigo→violet gradient,
rounded bottom corners, containing: app name "PDF Viewer Pro" with a small
document logo, a theme toggle icon, and a "PDF Tools" icon. Below the header, a
prominent rounded search bar ("Search your PDFs"). Then a "Recent" section: a
vertical list of recent-file cards — each card has a red-accent PDF thumbnail/
icon, the file name (bold), and a muted subtitle "Page 12 · 2h ago", plus a small
overflow menu. Empty-state variant: a friendly illustration of an open folder,
text "No recent PDFs", and a primary button "Open PDF". A floating extended
button bottom-right: "Open PDF" with a file icon. Show both light and dark.
```

## 2) PDF Viewer screen

```
PDF reading screen for PDF Viewer Pro. Top app bar: back arrow, file name
(truncating), and action icons — search, thumbnails (grid), bookmarks/outline,
night-mode (moon), and an overflow menu. The main area shows a PDF page on a soft
neutral canvas with a subtle page shadow and a small floating page indicator
"3 / 24" that opens a go-to-page field. Bottom bar: zoom out / zoom in, a centered
"3 / 24" page pill, previous/next page. Everything minimal so the document is the
hero. Provide light and dark (dark = near-black canvas). Also show the overflow
menu open, listing: Annotate, Read aloud, Single page / Continuous, Horizontal
scroll, Save to device, Share, Print.
```

## 3) Viewer — Annotation mode

```
The PDF Viewer with the annotation toolbar active, docked above the bottom bar.
A rounded elevated bar with tool chips: Highlight, Underline, Strikethrough,
Squiggly, Sticky note; then Undo, Redo, and a "Done" check. Below the tools, a
row of 6 round colour swatches (yellow, green, blue, red, orange, purple) with the
selected one ringed. Show a page with a few example highlights in yellow. Premium,
tactile, clearly grouped. Light and dark.
```

## 4) Viewer — Read-aloud mini player

```
The PDF Viewer with a "Read aloud" mini-player bar docked at the bottom (violet
tonal container). It shows a voice icon, the label "Read aloud", a large
play/pause button, a next-page (skip) button, a speed control (0.5×/1×/1.5×/2×),
and a close button. Calm, media-player feel. Light and dark.
```

## 5) Thumbnails grid

```
A page-thumbnails screen for PDF Viewer Pro. App bar "Pages (24)". A 3-column grid
of page thumbnails, each a white page preview with a soft border and the page
number beneath. The current page is highlighted with a thick indigo border and
bold number. Smooth, gallery-like. Include a subtle loading shimmer on some tiles.
Light and dark.
```

## 6) PDF Tools — Merge

```
"PDF Tools" screen with two top tabs: "Merge" and "Split". Merge tab: a reorderable
list of chosen PDF cards, each showing an index badge (1,2,3), file name, and a
remove (x) button, with drag handles. Empty state: icon + "Add two or more PDFs to
combine them. Drag to reorder." Bottom: two buttons side by side — outlined "Add
PDFs" and filled "Merge". After merging, a success dialog with a green check,
"Saved to …", and "Open" / "Share" actions. Light and dark.
```

## 7) PDF Tools — Split / Extract

```
The "Split" tab of PDF Tools. A card showing the chosen PDF (icon, name,
"24 pages", Change button). Below, a "Page range" section with two rounded number
fields "From" and "To". A big filled button "Extract pages". Clean form layout,
premium spacing. Light and dark.
```

## 8) Settings (new, optional)

```
A Settings screen for PDF Viewer Pro. Grouped rounded list sections: Appearance
(Theme: System/Light/Dark segmented control), Reading (Default layout, Default
scroll direction, Keep screen on), Reading aloud (Voice, Speed), About (Version,
Rate app, Privacy policy). Clean Material-3 list style with rounded group cards and
leading icons. Light and dark.
```

---

## 9) App LOGO prompt (image AI — Midjourney / Ideogram / DALL·E)

```
A modern, premium mobile app icon for a PDF viewer called "PDF Viewer Pro".
Centerpiece: a clean white document sheet with a subtly folded top-right corner
(dog-ear) and a small bold red "PDF" badge near the bottom. The document sits on a
smooth diagonal indigo-to-violet gradient background (#6366F1 to #8B5CF6). Flat,
minimal, geometric, soft long shadow under the sheet, rounded-square icon safe
area, no text other than "PDF", crisp vector style, high contrast, app-store
quality. Variations: also produce a monochrome white version of just the document
mark for the splash screen.
```

## 10) Animated SPLASH prompt (Lottie / Rive, or lottiefiles AI)

```
A short (1.5s) premium app-launch animation for "PDF Viewer Pro" on an indigo→
violet gradient background (#6366F1→#8B5CF6). Sequence: a white document sheet
draws/fades in from center, its top-right corner folds down (dog-ear) with a soft
bounce, a small red "PDF" badge pops in with a subtle spring, then the app name
"PDF Viewer Pro" fades up beneath in white Sora font. Gentle, smooth ease-out,
elegant, no harsh motion. Export as a Lottie JSON with a transparent or gradient
background, looping disabled.
```

**Implementing the animated splash in Flutter:**
1. `flutter pub add lottie`
2. Put the exported `splash.json` in `assets/splash/` and register it in
   `pubspec.yaml` assets.
3. Show it as the first screen, then navigate to Home on completion:
   ```dart
   Lottie.asset('assets/splash/splash.json',
       onLoaded: (c) => Future.delayed(c.duration, _goHome), repeat: false);
   ```
4. Keep `flutter_native_splash` (static brand frame) so there's no white flash
   before the Lottie screen mounts.
```
