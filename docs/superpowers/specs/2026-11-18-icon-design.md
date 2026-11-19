# Deceiver icon — design

## Intent

Give Deceiver a recognisable icon for the READMEs (GitHub and pub.dev) and
for the `deceiver_flutter` debug panel. The icon tells the package's story:
the real response package gets swapped for a fake one.

## The icon (chosen: "N2 · Briefcase swap")

On a rounded square (`#0175C2`, corner radius 22% of the size):

- **Top-left:** a navy (`#0A1F3D`) briefcase, the real response.
- **Bottom-right:** an identical cyan (`#13B9FD`) briefcase, the fake one.
- **Top-right and bottom-left:** two white curved arrows circling between
  them, like the familiar "swap" icon.

Each briefcase is a rounded body with a handle on top, a faint white seam
across the middle and a small white clasp. Reference geometry (100×100
viewBox) is the `swapBriefcase` symbol in
`.superpowers/brainstorm/40779-1795012836/content/icon-normal-bags.html`.

## Approaches considered

How the panel draws the icon:

- **Painted in Dart with a `CustomPainter`** (chosen): sharp at any size,
  no extra dependency or asset; the shapes exist twice (SVG + Dart), which
  is fine for a shape this simple.
- PNG asset in the package: least code, but multiple resolutions, bigger
  package and fixed colours.
- SVG + `flutter_svg`: one source, but forces an extra dependency on every
  app that uses the panel just for a logo.

## Where it shows up

- **READMEs:** at the top of `README.md`, `deceiver/README.md` and
  `deceiver_flutter/README.md`, about 120 px wide.
- **Debug panel:** as the first item in `DeceiverPanel`'s `ListView`, above
  "Global Settings", so it scrolls away with the rest. The icon about 40 px
  with "Deceiver" next to it. Nothing else.

## Calls made by Claude (please check)

- The SVG lives at `assets/deceiver_icon.svg` in the repo root, shared by all
  three READMEs.
- The package READMEs reference it by absolute URL
  (`https://raw.githubusercontent.com/DutchCodingCompany/deceiver/main/assets/deceiver_icon.svg`),
  because pub.dev resolves relative paths against the repository root, not
  the package folder. The image only shows on pub.dev after it is merged to
  `main`.
- The header and its painter stay private to `deceiver_panel.dart`; there is
  no public `DeceiverIcon` widget for now.
- Colours are fixed to the three blues above and don't follow the app theme.
  The "Deceiver" text does use the theme's text style.
- A widget test checks that the header with "Deceiver" is the first item in
  the panel. No golden tests.
- `.superpowers/` is added to `.gitignore`.

## Non-goals

- No app/launcher icon or favicon.
- No public icon widget, theming or dark-mode variant.
- No version number in the header.
