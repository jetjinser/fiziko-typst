;; Guix development tools for fiziko-typst.
;; Enter with: guix shell -m manifest.scm
;;
;; Tinymist is omitted because it is not present in the Guix channel currently
;; configured on the development machine. The comparison runner also currently
;; requires Typst 0.15.1; the configured Guix channel provides 0.15.0, so that
;; version must be supplied separately before using comparisons/run.py.
;; Guix currently provides ImageMagick 6, whose CLI is `convert`; the comparison
;; runner expects the ImageMagick 7 `magick` command. Add a small `magick`
;; compatibility wrapper to PATH, or update the runner to support `convert`.
;; The comparison runner also needs FIZIKO_UPSTREAM_PATH and
;; FIZIKO_TEST_FONT_PATH at runtime; this package manifest cannot pin a source
;; checkout or configure those per-project paths.

(use-modules (guix profiles) (gnu packages))

(specifications->manifest
 '(
   ;; Typst sources and the Python comparison/diagnostic tools.
   "typst"
   "python"

   ;; MetaPost reference rendering and PDF rasterization.
   "texlive-metapost"
   "texlive-mptopdf"
   "texlive-pdftex"
   "ghostscript"

   ;; Comparison image generation and optional PDF inspection.
   "imagemagick"
   "qpdf"
   "poppler"

   ;; The flake's explicit test/font and maintenance tools.
   "font-liberation"
   "font-dejavu"
   "actionlint"
   "shellcheck"))
