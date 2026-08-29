# Developing omaipsum

Notes for working on omaipsum itself. If you only want to *use* it, everything
you need is in [README.md](README.md). [CHANGELOG.md](CHANGELOG.md) records what
changed when, and [AGENTS.md](AGENTS.md) has the conventions a change is
expected to follow.

There is no layout table yet. The repository is documentation only; no code has
landed.

## Where the code lives

`origin` is `ssh://gitea@gitea.s10r.de:2811/carsten/omaipsum.git`, and that is
the only place work happens: branches are pushed there, issues are filed there,
pull requests are opened and merged there. Nothing is developed elsewhere and
copied over afterwards.

A GitHub mirror follows later, once a first working version exists. It is worth
being precise about what it is for, because the answer is narrow. The Omarchy
plugin marketplace lists **a repository, not a release** — a reviewer, and then
anyone running `omarchy plugin add`, follows the listing straight to the
repository and clones it. That has to be a public repository, and this Gitea
instance is not one. So the mirror is the public face and Gitea is where the
work is; the mirror is pushed to, never worked in. Issues and pull requests do
not move with it.

Before there is a working version there is nothing worth listing, which is why
the mirror does not exist yet — it is sequencing, not an oversight.

## CI

Workflows belong in `.gitea/workflows`. omapass keeps its own under
`.github/workflows`, and those files are the template for the *jobs*, not for
the directory. The checks omaipsum wants are the same five:

| Job | |
|-----|--|
| `shellcheck --severity=warning` | every shell script |
| `bash -n` | every shell script parses |
| the test suite | `tests/` |
| `qmlformat` | a parse of every QML file |
| `manifest.json` | entry points exist, version is semver |

One caveat is worth writing down: it is **not confirmed that this Gitea instance
has Actions runners**. If it turns out it has none, the same five checks go into
a `scripts/check.sh` that runs locally and is called by the release script
before it writes anything. Running the checks matters; running them on a server
does not. Issue #10 tracks CI and is where that gets settled.

## Issues and pull requests from the terminal

The `tea` CLI drives Gitea without a browser — `tea issues`, `tea issue close`,
`tea pr create`.

On the development machine `tea` authenticates as `omarchy-ai`, which needs
write access to `carsten/omaipsum`. Without it every command answers `not
found`, which reads like a mistyped repository name and is not: it is Gitea
declining to admit the repository exists. Check the access before debugging the
command.
