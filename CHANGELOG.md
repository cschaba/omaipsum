# Changelog

Notable changes per release. Dates are ISO. This project follows
[semantic versioning](https://semver.org): breaking changes to the config file,
the CLI surface, or the entry format bump the major.

## [Unreleased]

## [0.1.0] — 2026-08-30

- A screenshot in the README, the three new variants documented beside the
  others, and everything the marketplace asks for checked off.

- Three more variants: Space Opera, High Fantasy and Sitcom.

- The README says plainly that this project was built with AI, and what
  that does and does not mean for someone deciding to trust it.

- Backspace rubs out the last digit of a typed count instead of only Esc
  clearing the whole thing.

- Return copies again after picking a variant with the mouse.

- The docs are split by audience — user, developer, devops, architecture —
  and the reasoning behind each decision now lives in the repository rather
  than in closed issues.

- The issue tracker moved to GitHub too, keeping the original numbers, so
  every Fixes #N in the history resolves.

- The code lives on GitHub now, with CI that can actually run; Gitea is the
  mirror and keeps the issue tracker.

- The variant name on the trigger no longer keeps showing a variant the
  panel has stopped generating.

- Typed counts in the pulldown, vim style: 4w, 2s, 3p, and a bare unit key
  for the count already set.

- Left click on the bar icon copies straight to the clipboard; right click
  opens the pulldown, which now shows the version at the bottom.

- The bar icon is an L in a square frame, and the copy notification uses the
  same glyph.

- Copying twice in a row no longer claims the second copy failed when it
  succeeded.

- AGENTS.md and DEVELOPMENT.md describe omaipsum rather than the project
  they were copied from.

- CI on Gitea Actions: shellcheck, the test suite, a QML parse and a
  manifest check on every push and pull request.

- A README for people who want to use omaipsum rather than work on it.
- manifest.json's homepage points at the public GitHub mirror, not the
  private Gitea instance.

- A test suite: tests/generator.sh covers the counts, shapes and corpora,
  tests/smoke.sh the manifest, the settings schema and the scripts.

- scripts/release.sh cuts a release, and refuses to start unless the tree,
  the tag, the parsers, the changelog and the tests all agree.

- install.sh and uninstall.sh: symlink the checkout, register through
  omarchy's own commands, and print the optional keybinding rather than
  writing it.

- Default variant, unit and amount are configurable from the bar's own widget
  settings; the pulldown opens in them.

- Copying: the text goes to the clipboard through wl-copy, the pulldown
  closes, and a notification says what was copied.
- The panel says so when wl-clipboard is not installed, rather than failing
  at copy time.

- The bar pulldown: variant and unit pickers, a count, a live preview and
  Regenerate, all reachable from the keyboard.

- Ipsum.js generates exactly the asked-for number of words, sentences or
  paragraphs, reproducibly under a seeded RNG.

- Three text variants — Classic, Bacon and Corporate — as one JSON file each
  under corpora/, with the schema documented beside them.

- The plugin loads: manifest, MIT licence, and a bar widget that draws its
  icon and opens an empty panel.

- DEVELOPMENT.md records that Gitea is home and what the later GitHub
  mirror is for, so the decision does not get re-argued.

## [0.0.0] — 2026-08-29

- Initial setup

