# Changelog

Notable changes per release. Dates are ISO. This project follows
[semantic versioning](https://semver.org): breaking changes to the config file,
the CLI surface, or the entry format bump the major.

## [Unreleased]

- DEVOPS.md describes the marketplace submission form as it actually is.

## [0.1.7] — 2026-08-30

- The product name is written OmaIpsum in the docs, while ids, paths and
  artifacts stay lowercase.

## [0.1.6] — 2026-08-30

- The plugin shows itself as "OmaIpsum".

## [0.1.5] — 2026-08-30

- A third-party apt source being unavailable no longer fails CI.

## [0.1.4] — 2026-08-30

- A corpus file can no longer make the panel fetch anything: corpus text is
  rendered as plain text, and words that are not plain words are rejected.
- Corrected the claim that omaipsum writes nothing outside its own
  directories — installing it registers a bar widget in shell.json.

## [0.1.3] — 2026-08-30

- A narrated screencast in the README, behind a thumbnail.

- AGENTS.md warns that a closing keyword in commit prose closes the issue
  even when the sentence denies it.

## [0.1.2] — 2026-08-30

- The version at the foot of the panel is a link to the project homepage,
  with a tooltip showing where it goes.

## [0.1.1] — 2026-08-30

- Pushing a tag now publishes a GitHub Release with a tarball, its checksum
  and the changelog entry, instead of leaving a bare tag.

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

