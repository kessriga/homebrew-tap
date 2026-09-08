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

Homebrew's build sandbox remains enabled. A build-local Xcode wrapper disables only Swift Package Manager's nested
manifest sandbox, which macOS cannot start inside another sandbox. It does not change saved Xcode settings. See the
[Homebrew discussion](https://github.com/orgs/Homebrew/discussions/59) for this restriction.

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

Activation pins the formula so ordinary `brew upgrade` or `brew bundle` cannot move the active app to another keg. After
reviewing a new formula version, quit Ghostty and run `mise run update-ghostty` from another terminal. This command
backs up the current app before unpinning and upgrading, validates the new app, and restores the pin. Failed updates
attempt to restore the signed backup and pin, and report any incomplete recovery. Do not unpin the package manually;
Dotfiles verification and bootstrap reject that state.

The formula links manuals and completions without moving resources out of the app. It signs the bundle in
`post_install_steps`, after Homebrew's binary fixups, and verifies that final signature. Run `brew update` before
building if Homebrew does not recognize this API.

The formula is the source of truth for the fork commit and version. Change both only after reviewing the fork and
running its renderer tests, Metal regression harness, and a real-window transparency check. The fork's
[`docs/fork-maintenance.md`](https://github.com/kessriga/ghostty/blob/fix/colored-cell-opacity/docs/fork-maintenance.md)
describes the test coverage and graphics limitations.

Before merging a formula change, stage its branch in the registered tap and run
`brew style --formula kessriga/tap/ghostty-fork`, build it from source, run `brew test kessriga/tap/ghostty-fork`, and
verify the packaged app's signature. Homebrew rejects formula paths outside registered taps; CI copies the checked-out
formula into a temporary tap before checking style. Source builds and real-window checks are local gates because they
require the macOS developer toolchain and graphical session.
