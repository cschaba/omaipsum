# Shipping OmaIpsum

For someone releasing it, running CI on it, or working out what installing it
does to a machine.

[DEVELOPER.md](DEVELOPER.md) covers changing the code and running the tests.
[ARCHITECTURE.md](ARCHITECTURE.md) holds the reasoning behind the decisions
below — why GitHub rather than Gitea, why the version lives in one file.
[../AGENTS.md](../AGENTS.md) has the process rules, including the marketplace
promises this project would be making if it were listed.

## Remotes

- **`origin`** is `git@github.com:cschaba/omaipsum.git`, public, and holds the
  code, the issues, the releases and CI.
- **`gitea`** is `ssh://gitea@gitea.s10r.de:2811/carsten/omaipsum.git`,
  private, and is a backup of the code.

Everything happens at `origin`. Gitea is pushed to and never worked in; if it
vanished tomorrow the only thing lost would be a spare copy. It also holds a
frozen copy of issues 1 to 19 as they stood when the tracker moved — nothing
mirrors issues, so file nothing there.

The project started the other way round, and
[ARCHITECTURE.md](ARCHITECTURE.md) records why it swapped and why moving the
issues was safe. The short version: the Gitea instance has no Actions runner,
and CI that cannot run is not CI.

## CI

`.github/workflows/ci.yml`. Four jobs, on every push to `main`, every pull
request, and on `workflow_dispatch`:

| Job | |
|-----|--|
| `shell` | `bash -n` and `shellcheck --severity=warning` over every script |
| `test suite` | every executable in `tests/`, with node and qmlformat first |
| `qml syntax` | a `qmlformat` parse of every QML file |
| `manifest` | what the shell's registry enforces, plus semver and the corpus |

The script and QML lists are globbed rather than written out, in the workflow
and in `scripts/release.sh` alike: a hardcoded list stops covering the
repository the day a file lands, while still reporting a pass.

The test job installs node and `qmlformat` and then asserts they are there.
Both test scripts skip rather than fail when a tool is missing, which is right
on a laptop and wrong on a runner — a slim image would otherwise produce a
green job that checked almost nothing.

The QML job parses rather than lints. `qs.Commons` and `qs.Ui` resolve only
inside the running Omarchy shell, and older `qmllint` treats an unresolved
import as an error, so it rejects every file here regardless of syntax.
`qmlformat` ignores imports and still refuses a real syntax error. Run
`qmllint -I /usr/share/omarchy/shell *.qml` locally for the type checking CI
cannot do.

If a run ever appears but never starts, check the `runs-on` label before the
steps: a job no runner claims does not fail, it queues, and sits pending
forever. That quiet failure is what the Gitea instance would have given us —
it has no runner at all, which is why the code moved.

**There is no `scripts/check.sh`**, and the reason survives the move.
`tests/smoke.sh` already parses every script and every QML file and validates
the manifest from any checkout, and `scripts/release.sh` runs all of that plus
the whole suite and refuses to write if any of it fails. What CI adds over
those two is narrow and worth being honest about: shellcheck, and running the
tests on a machine that is not the one they were written on.

## Releasing

```bash
scripts/release.sh patch --dry-run   # the whole plan, in order, writing nothing
scripts/release.sh minor             # or major, or an explicit 0.4.0
```

One release per fixed issue, cut by hand from a local checkout after the
merge. It is a maintainer tool: no user ever runs it and nothing in the plugin
calls it.

It refuses before it writes anything — a dirty tree, a branch that is not
`main`, a checkout behind the remote, a tag that already exists locally or on
the remote, a `manifest.json` that does not parse or whose entry points are
missing, an empty `[Unreleased]` section, a shell script or QML file that does
not parse, or a failing test. The ordering is the point: a tag you have to
delete and re-push is worse than a release that refuses to start, because the
tag is the thing everyone else has already reacted to.

Then it bumps the version in `manifest.json` — the only place it lives — moves
the `[Unreleased]` entries under a new dated heading, commits, tags `vX.Y.Z`,
and pushes the commit before the tag: a remote holding a tag whose commit it
has not got is broken in a way nobody can fix by pulling. Last it pushes both
to `gitea`, best-effort, printing the re-push command if that fails. The
release exists once the tag is at `origin`, so an unreachable mirror is a
re-push rather than a re-tag.

The remote names are `OMAIPSUM_RELEASE_REMOTE` (default `origin`) and
`OMAIPSUM_MIRROR_REMOTE` (default `gitea`) if you ever need to point it
somewhere else.

Write the changelog entry under `[Unreleased]` as part of the fix. The script
refusing on an empty section is a backstop, and by then it is much too late to
remember what the change was for.

### What the tag sets off

Pushing the tag is where the maintainer's part ends and
`.github/workflows/release.yml` begins. It runs on any pushed `v*` tag, and on
`workflow_dispatch` with a tag typed in, which is how a tag pushed before the
workflow existed gets a Release without being deleted and re-pushed.

Until #28 there was no second half: the tag landed, the tags page showed it,
and the releases page said "There aren't any releases here", because a tag is
not a Release.

In order, and refusing at the first thing that does not hold:

| Step | |
|---|--|
| tag vs manifest | the tag is `vX.Y.Z` and `manifest.json` says the same `X.Y.Z` |
| tests | every executable in `tests/`, globbed, on a clean checkout of the tagged commit |
| package | `omaipsum-X.Y.Z.tar.gz` and its `.sha256` |
| drift | every `*.qml`, `*.js` and `corpora/*` in the repository is in the tarball, and nothing from `.git`, `tests/`, `docs/`, `.github/` or `scripts/` is |
| extract | unpack it and ask what the shell asks at load |
| notes | the `## [X.Y.Z]` section of `CHANGELOG.md`, up to the next `## ` |
| publish | `gh release create`, titled `omaipsum X.Y.Z` |

`scripts/release.sh` already refuses to tag a tree whose tests fail, so the
suite runs twice on purpose. The local run is against one laptop's working
tree; this one is against the commit everyone else will get, and it is the last
place that can still say no — a release that cannot pass its own tests must not
be published.

The tarball unpacks to a directory called `cschaba.omaipsum`, not
`omaipsum-X.Y.Z`, because that is the name Omarchy wants:
`tar -xzf omaipsum-X.Y.Z.tar.gz -C ~/.config/omarchy/plugins` is then the whole
install. It carries the manifest, the QML, `Ipsum.js`, `corpora/`, the licence,
the README, the changelog and the two install scripts — and not `tests/`,
`docs/`, `scripts/`, `.github/`, `AGENTS.md` or `DEVELOPMENT.md`, none of which
a user needs and all of which would be shipped under a version number nobody
can correct afterwards.

**There is no `PKGBUILD`**, which is where this differs from omapass. omapass
keeps `packaging/PKGBUILD` in its repository and has a `bin/omapass` that
belongs in `/usr/bin`. An Omarchy plugin is a per-user directory under
`~/.config/omarchy/plugins` with nothing for pacman to place, this repository
has no PKGBUILD to template, and one invented in the workflow would be a file
the project has never built or tested, published under its name. It would also
put a package manager into a plugin whose honest current position (AGENTS.md,
*Capabilities it will flag*) is that a scan reports neither `privilege` nor
`package-manager`.

The extract check is the part worth explaining, because omapass's equivalent
runs its CLI out of the unpacked tarball and OmaIpsum has no CLI to run. What
it does instead is ask the questions the shell asks at load, of the extract
rather than of the checkout: the manifest parses and its version is the one
being published; every `entryPoint` resolves to a file that is there; each
`import "X.js"` in that QML resolves inside the extract, which is what catches
a tarball built without `Ipsum.js`; the manifest's default variant has a
corpus; the QML parses under `qmlformat`. Then it eval's the shipped `Ipsum.js`
under node and generates against every shipped corpus, asking for counts it
has to hit exactly — the same trick `tests/generator.sh` uses. That last one is
the difference between a check and a ritual: it runs the shipped code over the
shipped data and compares the answer.

Publishing goes through `gh release create` rather than a third-party action.
`gh` is on every runner and needs only `GITHUB_TOKEN`; the action would buy
formatting and cost a supply-chain dependency on someone who can change what
runs in this repository. `ci.yml` holds the same line, and `permissions:
contents: write` is spelled out because creating a Release needs it and nothing
else here does.

`.github/` is excluded from the marketplace's static scan (AGENTS.md, *What the
static scan reads*), so this file is not read there — the same reason `ci.yml`'s
`sudo apt-get` does not count against the project. Worth remembering if a
workflow ever moves out of `.github/`.

To publish a Release for a tag that already exists:

```bash
gh workflow run release.yml --repo cschaba/omaipsum -f tag=v0.1.0
```

## The marketplace

**OmaIpsum is not on the [Omarchy plugin marketplace][mp] yet.** Everything it
asks for is in place; the submission itself is still to do. Nothing in this
repository claims a listing, and nothing should until one is made.

[mp]: https://github.com/HANCORE-linux/omarchy-plugin-marketplace

### What it requires, and where each one is

Checked against [the publishing docs](https://omarchyplugins.com/publish.html):

| Requirement | Where |
|---|---|
| Public GitHub repository | `cschaba/omaipsum` |
| Valid `manifest.json` at the root, with all eight mandatory fields | `schemaVersion`, `id`, `name`, `version`, `author`, `description`, `kinds`, `entryPoints` |
| README and licence | [../README.md](../README.md), [../LICENSE](../LICENSE) — MIT |
| Safe install and removal | [../install.sh](../install.sh), [../uninstall.sh](../uninstall.sh) |
| Namespaced id | `cschaba.omaipsum` |
| Preview image (optional) | [pulldown.png](pulldown.png) |

`description` in the manifest is the marketplace summary, so it is the one
string that has to read well out of context. Keep it in step with the README's
opening paragraph: they are the same claim in two lengths, and a listing that
promises something the README does not is the kind of drift a reviewer notices.

The submission itself is a GitHub issue form wanting the repository link, a
category and tags — both are fixed dropdowns, not free text, which is worth
knowing before drafting anything. The categories are Appearance, Desktop,
Developer Tools, Hardware, Productivity, System, Widgets and Other; **Widgets**
is the honest one for a bar widget. The tags come from a fixed list too, and
**a submission with more than three is rejected** — of AI, Bar, Games,
Hyprland, Launcher, Media, Power management, Quickshell, Security, System and
Workspaces, the two that actually describe this are **Bar** and **Quickshell**.

The form also asks for maintainer notes and five required checkboxes: the repo
is public with install and removal instructions; the licence and external
dependencies are documented; the submitter owns the plugin and its preview
assets; the plugin does not overwrite user configuration without explicit
consent; and the submitter understands approval is a listing decision and not a
security review.

Validation runs automatically against the current commit before a maintainer
looks at it — which is the concrete reason `main` has to stay releasable rather
than merely eventually correct.

Worth being clear-eyed about what the marketplace does and does not do: it
validates the listing, not the plugin. Plugins run unsandboxed. Everything that
makes OmaIpsum safe to install is a property of this repository — it writes
nothing outside its own directories, runs no package manager, needs no
privileges — and not of anyone's review.

A listing points at **the repository, not a release**, so a reviewer sees
whatever is on `main` at the moment they look, and so does anyone who follows
it to `omarchy plugin add`. That is the sharper reason for the branch rule in
[../AGENTS.md](../AGENTS.md): `main` is the public face, not a workspace.

The submission form is a checklist, and every item on it is a claim about how
the plugin behaves made to people who cannot check it themselves. Those
claims, what a static scan of this repository reads, and which capabilities it
would report are in [../AGENTS.md](../AGENTS.md) under *Publishing* — they
live there because keeping them true is a constraint on every change, not a
step in a release. Check them against the code on the day rather than against
any list.

## The screencast, and its copy on GitHub's CDN

`docs/screencast.mp4` is in the repository and is the master. The README does
**not** embed it today: a thumbnail linking to the file looked like a player and
behaved like a download, which is a worse promise than making none, so the
README carries the still screenshot and lists the video among the docs.

An inline player is possible and is described below, because it needs a second
copy of the same file on GitHub's CDN — refreshed by a different route from the
one in git, which is the whole hazard and the reason for the check.

GitHub renders a player only for an uploaded attachment. Checked, rather than
assumed from the documentation, which does not mention READMEs at all:

- A `<video>` tag is **stripped** by GitHub's sanitiser. Both an attachment URL
  and a repo-relative path render as an empty paragraph.
- A plain markdown **link** to `https://github.com/user-attachments/assets/<uuid>`
  is rewritten into a `<video>` element pointing at a signed
  `private-user-images.githubusercontent.com/….mp4` URL. That is the player.

Video attachments are capped at 10 MB on a free plan and 100 MB on a paid one.

### Replacing the video

There is no API for markdown attachments, so the upload is a manual step:

1. Re-record, and replace `docs/screencast.mp4`.
2. Open any issue, pull request or discussion comment on GitHub — a draft is
   enough, it does not have to be posted — and drag the file in.
3. Copy the `https://github.com/user-attachments/assets/<uuid>` URL it inserts,
   and put it in `README.md` in place of the old one.
4. Update `docs/screencast.mp4.sha256`:
   `sha256sum docs/screencast.mp4 | awk '{print $1}' > docs/screencast.mp4.sha256`

Step 4 is not bookkeeping. `tests/smoke.sh` compares that hash against the
committed file and fails if they differ — but only once `README.md` actually
contains a `user-attachments` URL, so the check arrives with the thing it
protects rather than failing an honest re-record today. That is what stops step
2 being forgotten: the README would otherwise keep playing the old take indefinitely,
and nobody rereads their own README often enough to catch it. The suite also
fails if a `<video>` tag appears, because that renders as nothing at all.

The test cannot verify the CDN copy holds the same bytes — the URL is signed
and expires, so it is not fetchable from a test. It proves the repository copy
did not move without the upload, which is the failure that actually happens.

## What install.sh does to a machine

Both scripts are safe to re-run, and neither writes anything outside
OmaIpsum's own directories. Registration goes through Omarchy's own commands
because they own `~/.config/omarchy/shell.json`; the keybinding is printed
rather than written, because `~/.config/hypr/bindings.lua` belongs to the
user. A plugin that rewrites your compositor config is one you have to trust
twice.

`install.sh`, in order:

1. Symlinks the checkout to `~/.config/omarchy/plugins/cschaba.omaipsum` — a
   link, not a copy, so the checkout stays the only copy of the code and an
   edit is live after a shell restart. If that path is a real directory it
   stops rather than deleting somebody's files: that is an `omarchy plugin
   add` clone or an older copy-install, and removing it is not this script's
   call.
2. Stops if `omarchy` is not on `PATH`, because registering means writing
   `shell.json`, and that is omarchy's file rather than this script's.
3. Asks the running shell to rescan its plugins, quietly and best-effort —
   with no shell running there is nobody to tell, and that is not a failure.
4. **Waits for the plugin to appear in `omarchy plugin list`**, polling up to
   forty times at 50ms. `rescanPlugins` is fire-and-forget: the call returns
   when the shell accepts it, not when the scan has finished. Enabling on the
   next line asks about a plugin the shell has not read yet and is told it
   does not exist — which is exactly what a fresh install used to do, silently
   (#23). `omarchy-plugin-add` has the same problem and polls the same way.
   If the plugin never turns up, the script says the shell is not running and
   stops, which is the only case where that diagnosis is the true one.
5. Asks which bar section to use — `gum choose` over left / center / right,
   pre-selected to the manifest's `defaultSection`. A non-interactive run, or
   a machine without `gum`, takes that default without a word, because this
   script has to stay usable from automation.
6. Runs `omarchy plugin enable` with that section and then `omarchy bar put`.
   Reading the real CLI corrected three assumptions worth recording: `bar put`
   is idempotent and `plugin enable` places the widget as a side effect, so a
   second run produces one widget and not two; there is no `omarchy bar
   remove` at all; and `bar put` exits 0 even with no shell running, which is
   why `enable` goes first, so a failure is visible.
7. Checks for `wl-copy` and, if it is missing, suggests
   `omarchy pkg add wl-clipboard`. It installs nothing — no package manager
   runs from this repository.
8. Prints the optional keybinding line for you to paste, and says so if the
   chord already appears in `bindings.lua`.
9. Reminds you to `omarchy restart shell`, because the shell reads a plugin's
   QML once at startup.

`uninstall.sh` reverses it: `omarchy plugin disable`, which is the whole way
back out since there is no `bar remove`; then the symlink, which is removed
without touching what it points at, and left alone if it turns out to be a
real directory. `--purge` additionally removes `~/.config/omaipsum` and
`~/.local/state/omaipsum` — neither of which this version creates, so that a
version that starts writing there does not also have to remember to teach the
uninstaller. The keybinding is printed back with its line number for you to
delete: what the installer could not add, the uninstaller must not remove.
