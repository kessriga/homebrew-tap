# Personal Homebrew tap

## Ghostty fork

`ghostty-fork` builds [kessriga/ghostty](https://github.com/kessriga/ghostty) from the immutable commit declared in
`Formula/ghostty-fork.rb`. It preserves colored-cell transparency on macOS. This is a local source build, not an
upstream release or a notarized binary distribution.

```sh
brew tap kessriga/tap
brew install --build-from-source kessriga/tap/ghostty-fork
brew test kessriga/tap/ghostty-fork
```

Building requires full Xcode 26 or later, its Metal toolchain, and the declared Homebrew build dependencies. The formula
preserves Ghostty's normal bundle identifier, stamps the source revision, and disables automatic update checks in the
bundle. The effective Ghostty config must also set `auto-update = off` to override saved preferences.

The formula is keg-only: building does not replace or relink the running app. From
[kessriga/dotfiles](https://github.com/kessriga/dotfiles), deploy the Ghostty config, quit Ghostty, then run:

```sh
mise run activate-ghostty --replace-existing
```

Activation backs up the existing app, unregisters only the official Ghostty cask without deleting configuration, links
the fork's CLI, manuals, and completions, and points `/Applications/Ghostty.app` at the stable Homebrew `opt` path.
`mise run rollback-ghostty` restores the previous app. The CLI wrapper always runs `/Applications/Ghostty.app`,
including a restored backup. Rollback does not re-register the official cask; return to official Homebrew ownership
separately if desired.

## Updates and verification

The formula is the source of truth for the fork commit and version. Change both only after reviewing the fork and
running its renderer tests, Metal regression harness, and a real-window transparency check. The fork's
[`docs/fork-maintenance.md`](https://github.com/kessriga/ghostty/blob/fix/colored-cell-opacity/docs/fork-maintenance.md)
describes the test coverage and graphics limitations.

Before merging a formula change, stage its branch in the registered tap and run
`brew style --formula kessriga/tap/ghostty-fork`, build it from source, run `brew test kessriga/tap/ghostty-fork`, and
verify the packaged app's signature. Homebrew rejects formula paths outside registered taps; CI copies the checked-out
formula into a temporary tap before checking style. Source builds and real-window checks are local gates because they
require the macOS developer toolchain and graphical session.
