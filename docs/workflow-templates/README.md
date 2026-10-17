# GitHub Actions templates

These are the complete CI, macOS packaging, and release-note synchronization workflows inherited from the project and adjusted for this custom edition.

They are stored here because the current publishing OAuth authorization has `repo` access but not `workflow` scope. GitHub rejected the initial push while these YAML files were under `.github/workflows/`. No workflow content was discarded.

To enable them later, authorize workflow updates, provide a runner with macOS 27 and Xcode 27 / Swift 6.4, and move the three YAML files into `.github/workflows/`. Signing and notarization still require your own secrets configured through GitHub Actions Secrets. Never commit credential values.

Until then, run `swift test`, `bash scripts/check_style.sh`, `bash scripts/check_no_signing_material.sh`, and `python3 scripts/check_public_files.py` locally. Tag creation alone does not build or publish a binary in this repository.
