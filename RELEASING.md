# Release readiness

The automated release checks, local Typst package scaffold, and project
license are ready. A Typst Universe submission still needs maintainer author
metadata.

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

## Maintainer information still required

### Typst package authors

The package uses SPDX `GPL-3.0-or-later`, matching the upstream source header,
which permits GPL version 3 or any later version. The full license is in
`LICENSE`. The upstream attribution is Sergey Slyusarev, Copyright 2023; it is
also recorded in the README. The package registry requires an `authors` field
in addition to a valid SPDX license expression
([manifest requirements](https://github.com/typst/packages/blob/main/docs/manifest.md)).

Before submitting to Typst Universe, add the current package maintainer(s)' own
display names and any public contact/handles they want listed. The upstream
author is credited in the README as the original Fiziko author, not presented
as the author of this Typst port.

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
