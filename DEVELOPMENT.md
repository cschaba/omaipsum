# Developing omaipsum

The entry point for working on omaipsum itself. This file used to hold
everything; it is now a pointer, because one document for four different
readers is a document nobody finishes.

| Read | If you are |
|---|---|
| [docs/DEVELOPER.md](docs/DEVELOPER.md) | changing the code |
| [docs/DEVOPS.md](docs/DEVOPS.md) | shipping it |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | asking why it is like this |
| [README.md](README.md) | using omaipsum rather than working on it |

[AGENTS.md](AGENTS.md) has the conventions a change is expected to follow, and
[CHANGELOG.md](CHANGELOG.md) records what changed when.

## What moved where

- **Layout, the local edit loop, the shell restart, the Quickshell traps,
  testing, and driving the trackers from the terminal** are in
  [docs/DEVELOPER.md](docs/DEVELOPER.md).
- **The remotes, CI, releasing, the marketplace, and what `install.sh` and
  `uninstall.sh` do to a machine** are in [docs/DEVOPS.md](docs/DEVOPS.md).
- **The reasoning** — why the generator is pure, why corpora are data, why
  there is no `bin/`, why the settings are shaped as they are, why a copy is
  reported when it is, and the prior art the product came from — is in
  [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

That last one is the point of the split. An issue is scaffolding and the code
is the building — the code shows every decision and never the options it beat
— so why a choice beat the obvious alternative moves out of the tracker and
into `docs/ARCHITECTURE.md`. [AGENTS.md](AGENTS.md) states the rule in full,
under *An issue is scaffolding, the code is the building*.
