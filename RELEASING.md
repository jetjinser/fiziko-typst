# Release readiness

The automated release checks and local Typst package scaffold are ready. A
public release is not ready until the maintainer confirms the licensing and
authorship metadata below.

## Completed release preparation

- `nix/flake.lock` pins the compiler, drawing tools, print preflight tools,
  upstream Fiziko source, and fonts used by the checks.
- `.github/workflows/ci.yml` runs the full repository gate on pushes and pull
  requests with immutable, full-SHA GitHub Action references.
- `typst.toml` provides the compiler-required local package fields. The
  package smoke build checks the entrypoint and its relative imports from an
  isolated local package path.
- `./check.sh` runs numeric assertions, Python suites, shell/workflow lint,
  the package smoke build, the five-page specimen build, and structural PDF
  preflight.
- Generated PDFs, page previews, upstream comparison artifacts, and
  diagnostics remain under ignored `build/`; they are not package contents or
  source release files. `build/check/main.pdf` is the CI/review specimen only.

Run the same release gate locally:

```sh
nix develop path:./nix --command ./check.sh
```

## Maintainer decisions still required

### Project license and attribution

The pinned upstream source includes the text of GNU GPL version 3. This
repository ports that library, so the project license expression and required
upstream notices must be confirmed before adding a `LICENSE` file or publishing
the Typst package. The current manifest deliberately omits `license` and
`authors`; it supports local package testing but is incomplete for Typst
Universe submission. The package registry requires both fields and a valid
SPDX license expression ([manifest requirements](https://github.com/typst/packages/blob/main/docs/manifest.md)).

The maintainer should confirm:

- The project's SPDX license expression and whether all contributed code may
  be distributed under it.
- The author display names and any public contact/handles to publish.
- The upstream attribution text to preserve with that license.

The comparison workflow retains the exact upstream license text with each
run's provenance snapshot. It is not yet copied as this project's `LICENSE`
because that would imply an unconfirmed project licensing decision.

### PDF/X output

PDF/X is not part of the release output. A target print profile has not been
specified, and no PDF/X validator is configured. veraPDF validates PDF/A,
PDF/UA, and WTPDF profiles, not PDF/X ([veraPDF's supported validation
specifications](https://docs.verapdf.org/validation/)). The current preflight
only checks PDF structure, fonts, page geometry, transparency, color operators,
and that Ghostscript can render the file. It does not claim PDF/X conformance.

If print delivery later requires PDF/X, first obtain the printer's requested
PDF/X level and ICC output profile, then use a converter and validator that
support that exact profile. Do not label a generated file PDF/X from an
OutputIntent check alone.
