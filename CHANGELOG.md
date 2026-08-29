# Changelog

Notable changes per release. Dates are ISO. This project follows
[semantic versioning](https://semver.org): breaking changes to the config file,
the CLI surface, or the entry format bump the major.

## [Unreleased]

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

