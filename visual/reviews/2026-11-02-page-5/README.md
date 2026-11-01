# Figure 11 baseline review — 2026-11-02

The old snapshot was stale relative to the drawing and document changes
preserved in `8c11407`. The reviewed current page is accepted as the new
baseline. No drawing parameters or seeds were changed for this update.

## Evidence

- **Environment control:** rendering `d19720d:main.typ` with its matching
  library under the current Typst 0.15.1 reproduces the old reference with
  zero decoded-pixel error. This rules out an environment change as the
  explanation for this failure.
- **Page layout:** the revised Figure 2 code listing and preceding prose
  change pagination. The “Next” heading and both bullets now start page 5;
  previously only the final bullet was on that page. Figure 11 and its
  caption move down about 58 px at 130 ppi. Rendering the old `main.typ`
  against the current library restores the old layout; its only remaining
  differences are coastlines and eyelashes (see `layout-isolation-diff.png`).
- **Fonts:** rendering the current page with system fonts disabled and only
  the flake's DejaVu fonts plus Typst's embedded fonts gives zero pixel
  difference against the current default-environment render.
- **Component isolation:** `components.typ` places each primitive at the
  same origin, so changes in document flow cannot contaminate the comparison.

| Component | Historical vs. current pixels | Cause / review |
| --- | --- | --- |
| Globe | Different only along the supplied coast | `_globe-densify` now interpolates longitude/latitude before projection. This implements the documented 5° subdivision. Graticule and silhouette are unchanged. |
| Eye | Different only at lashes | The keyed `_rng` mixer changed after the original snapshot. Fixed seed 17 gives different lash lengths; eye outline, iris, pupil and highlight are unchanged. |
| Strand knot | Identical | No observed regression for this specimen. |
| Refraction | Identical | No observed regression for this specimen. |

`page-comparison.png` shows old / current / red differences from left to
right. The globe and eye comparison images use the same order. The old page
is retained as `reference-before.png`; the accepted page is the regression
fixture at `../../figure-11-page-5.png`.

## Reproduction

Run from the repository root inside the Nix devshell. These commands write
only to ignored `build/` and do not update a baseline:

```sh
mkdir -p build/page5-review/historical
git archive d19720d | tar -x -C build/page5-review/historical
export TYPST_FONT_PATHS="$FIZIKO_TEST_FONT_PATH"
export TYPST_IGNORE_SYSTEM_FONTS=true
unset TYPST_IGNORE_EMBEDDED_FONTS
typst compile build/page5-review/historical/main.typ build/page5-review/old.png --pages 5 --ppi 130
typst compile main.typ build/page5-review/current.png --pages 5 --ppi 130
python3 visual/compare.py build/page5-review/old.png build/page5-review/current.png build/page5-review/page
```

The last command deliberately exits 1 because the old and current pages
differ. To isolate a component, copy `components.typ` into the historical
tree, then render it with `--root build/page5-review/historical` and
`--input case=globe` (or `eye`, `knot`, `optics`). Render the checked-in copy
with `--root .` using the same input. Compare the two PNGs with
`visual/compare.py`. Use 130 ppi for these comparisons.
