# Developing omaipsum

Notes for working on omaipsum itself. If you only want to *use* it, everything
you need is in [README.md](README.md). [CHANGELOG.md](CHANGELOG.md) records what
changed when, and [AGENTS.md](AGENTS.md) has the conventions a change is
expected to follow.

## Layout

| Path | |
|------|--|
| `manifest.json` | the plugin manifest, and the only place the version lives |
| `BarWidget.qml` | the bar icon and everything in its pulldown |
| `Ipsum.js` | the generator: pure functions, no QML types, no I/O |
| `corpora/` | one JSON file per text variant; the widget reads the directory |
| `corpora/README.md` | the corpus schema, and where words may come from |
| `install.sh` | symlinks the checkout in and registers it through omarchy |
| `uninstall.sh` | unregisters, removes the link, `--purge` for state |
| `scripts/release.sh` | cuts a release, or refuses before writing anything |
| `tests/smoke.sh` | everything that is not the generator |
| `tests/generator.sh` | `Ipsum.js`, exercised under node |
| `.gitea/workflows/ci.yml` | the four CI jobs |
| `README.md` | for people using omaipsum rather than working on it |
| `AGENTS.md` | the conventions, the Omarchy API table, the Quickshell traps |
| `CLAUDE.md` | a pointer at `AGENTS.md`, and nothing else |
| `CHANGELOG.md` | what changed when |
| `LICENSE` | MIT |

## How it fits together

`Ipsum.js` is a `.pragma library`: no QML types, no state that outlives a call,
no I/O. Every function in it is a function of its arguments, so the same call
from the widget and from node produces the same string — which is the only
reason the generator can be tested at all without a shell, a bar or a display.
Presentation lives in the QML above it, and none of it belongs in that file.

The corpora are data rather than code, which is the same separation from the
other end. A variant is one JSON file in `corpora/`, and `BarWidget.qml`
discovers the directory with a `FolderListModel` and reads each file with a
`FileView` instead of importing a list — so a fourth variant is a fourth file
and no edit anywhere else. The files hold lowercase, unpunctuated words only:
the capitals, the commas and the paragraph breaks are all decided in
`Ipsum.js`, which is what keeps a corpus something a person can extend without
knowing how sentences get built.

There is no `bin/`. omapass has one because everything that touches a secret
has to happen in a single place, out of the long-lived shell process; omaipsum
handles nothing sensitive, so a backend would be a process boundary with
nothing to protect on either side of it. The widget shells out to exactly two
binaries — `wl-copy` for the clipboard and `omarchy-notification-send` for the
toast that follows — and both are a `Process` in `BarWidget.qml`. The text goes
to `wl-copy` down stdin rather than in argv, because a few thousand words is
past what `ARG_MAX` promises and because the blank lines between paragraphs do
not survive the trip through a command line intact.

## Working on it

`install.sh` symlinks your checkout into
`~/.config/omarchy/plugins/cschaba.omaipsum`, so an edit is live without
reinstalling — but you have to ask for the reload:

```bash
./install.sh                                  # once
omarchy restart shell                         # after every QML or JS edit
omarchy-shell cschaba.omaipsum.widget toggle  # open the pulldown
journalctl --user -f | grep omarchy-shell     # where QML errors land
```

The toggle target is the widget's own `ipcTarget` in `BarWidget.qml`, which
`Ui/Panel.qml` gives open, close and toggle; it is the same command `install.sh`
prints for the optional keybinding, and the same one `uninstall.sh` greps
`bindings.lua` for on the way out.

The restart is not optional, and `rescanPlugins` is not a substitute. That, the
0×0 bar slot a widget gets when it publishes no implicit size, and the Loader
error path that swallows its own message are the three ways a change looks
broken when it is not. They are written down in [AGENTS.md](AGENTS.md), under
*Before you believe a test*; read them before debugging something that renders
nothing.

## Testing

```bash
tests/smoke.sh       # 47 checks: the manifest, the schema, the QML, the scripts
tests/generator.sh   # 103 checks: counts, shape, determinism, the corpora
```

`smoke.sh` covers everything that is not the generator. It mirrors what
`PluginRegistry.validateManifest` enforces in the running shell, because a
manifest the shell rejects produces no error a user ever sees — the plugin
simply is not there. It also checks that the settings schema and the defaults
beside it agree and that the default variant names a corpus that exists, parses
every QML file with `qmlformat`, and confirms every shell script parses and is
executable.

`generator.sh` strips the `.pragma library` line off `Ipsum.js`, evaluates the
rest in node, and asks the three questions worth asking of a generator: that
the counts are exact, that sentence and paragraph lengths stay inside the
bounds the file declares, and that the same seed gives the same text — the
preview and the string that reaches the clipboard are two separate calls and
have to agree.

Both redirect `HOME` and the `XDG_*` variables into a throwaway directory and
clean up after themselves. Both *skip* rather than fail when `node` or
`qmlformat` is missing, which is right on a developer's machine and wrong on a
runner, so the CI job installs both and then asserts they are there before
running the suite.

Two findings from writing the suite are worth keeping.

**The dispatcher check earns its keep.** It walks every `case` branch in every
shell script and confirms the name the branch calls resolves to something: a
function defined in the same file, a shell builtin or keyword, or a known
external. bash only complains when a branch is actually taken, so a subcommand
dispatched to a function that has been deleted parses cleanly, passes `bash
-n`, passes every other check here, and dies the first time a user picks it.
omapass shipped exactly that twice.

**Resolving those names through `PATH` was itself a bug.** Looking externals up
with `command -v` makes the answer depend on the machine, in both directions: a
tool missing from CI fails a branch that is fine, and — the reason the
allowlist exists — this development box has a real `/usr/bin/usage`, which
quietly resolved a `release.sh` branch calling a `usage` function that had been
deleted. The check was hiding the precise failure it was written to catch.
Externals are an explicit set in `tests/smoke.sh` now, and a new one in a case
branch is a one-line addition to it.

## Where the code lives

`origin` is `ssh://gitea@gitea.s10r.de:2811/carsten/omaipsum.git`, and that is
where work happens: branches are pushed there, issues are filed there, pull
requests are opened and merged there. Nothing is developed elsewhere and copied
over afterwards.

That Gitea instance is private, and a plugin nobody can clone is not a plugin
anyone can install. So there is a second remote, `github`, at
`git@github.com:cschaba/omaipsum.git`, and it is public. It is the address
`manifest.json` gives as its homepage and the one the README tells people to
clone, and it is what a marketplace listing would point at — the marketplace
lists **a repository, not a release**, so a reviewer, and then anyone running
`omarchy plugin add`, follows the listing straight to the repository.

The mirror is pushed to and never worked in. Issues and pull requests do not
move with it, and `scripts/release.sh` pushes there second and best-effort,
once the release already exists at `origin`.

## CI

`.gitea/workflows/ci.yml`, not `.github/workflows`: Gitea is home, and
omapass's workflow was the template for the *jobs* rather than for the
directory. Four of them run on every push to `main` and every pull request:

| Job | |
|-----|--|
| `shell` | `bash -n` and `shellcheck --severity=warning` over every script |
| `test suite` | every executable in `tests/`, with node and qmlformat first |
| `qml syntax` | a `qmlformat` parse of every QML file |
| `manifest` | what the shell's registry enforces, plus semver and the corpus |

The script and QML lists are globbed rather than written out, in the workflow
and in `scripts/release.sh` alike: a hardcoded list stops covering the
repository the day a file lands, while still reporting a pass.

The QML job parses rather than lints. `qs.Commons` and `qs.Ui` resolve only
inside the running Omarchy shell, and older `qmllint` treats an unresolved
import as an error, so it rejects every file here regardless of syntax.
`qmlformat` ignores imports and still refuses a real syntax error. Run
`qmllint -I /usr/share/omarchy/shell *.qml` locally for the type checking CI
cannot do.

It is **not confirmed that this Gitea instance has an Actions runner**, and the
failure mode is quiet: a job whose `runs-on` label no runner claims does not
fail, it queues, and the run sits pending forever. If runs appear but never
start, check the label before the steps. Nothing depends on the answer, which
is why there is no `scripts/check.sh`: `tests/smoke.sh` already parses every
script and every QML file and validates the manifest from any checkout, and
`scripts/release.sh` runs all of that plus the whole suite and refuses to write
if any of it fails. What CI adds over those two is shellcheck, and running the
tests on a machine that is not the one they were written on.

## Issues and pull requests from the terminal

The `tea` CLI drives Gitea without a browser — `tea issues`, `tea issue close`,
`tea pr create`.

On the development machine `tea` authenticates as `omarchy-ai`, which needs
write access to `carsten/omaipsum`. Without it every command answers `not
found`, which reads like a mistyped repository name and is not: it is Gitea
declining to admit the repository exists. Check the access before debugging the
command.

## Releasing

```bash
scripts/release.sh patch --dry-run   # the whole plan, in order, writing nothing
scripts/release.sh minor             # or major, or an explicit 0.4.0
```

The version lives in `manifest.json` and nowhere else — Omarchy requires it
there, so a second copy could only drift out of step — and the script rewrites
that one field with `sed` rather than re-serialising the JSON, so the change is
one line of diff instead of a reformatted manifest.

It refuses before it writes anything: a dirty tree, a branch that is not
`main`, a checkout behind the remote, a tag that already exists locally or on
the remote, a `manifest.json` that does not parse or whose entry points are
missing, an empty `[Unreleased]` section, a shell script or QML file that does
not parse, or a failing test. The ordering is the point — a tag you have to
delete and re-push is worse than a release that refuses to start, because the
tag is the thing everyone else has already reacted to.

Then it bumps the version, moves the `[Unreleased]` entries under a new dated
heading, commits, tags `vX.Y.Z`, and pushes the commit before the tag: a remote
holding a tag whose commit it has not got is broken in a way nobody can fix by
pulling. Last it pushes both to the `github` mirror, best-effort — the release
exists once the tag is at `origin`, so an unreachable mirror is a re-push
rather than a re-tag.

Write the changelog entry under `[Unreleased]` as part of the fix. The script
refusing on an empty section is a backstop, and by then it is much too late to
remember what the change was for.

## Prior art

Where the ideas came from, kept here because [README.md](README.md) is for
people using omaipsum. **None of these is where any bundled text came from.**
`corpora/README.md` is explicit that a word pool is written from scratch rather
than copied out of somebody's generator or off their curated list, and the
three shipped variants were.

- A generator in the same genre:
  <https://www.funnylorem.com/>
- A survey of the genre, and where the idea of shipping more than one variant
  came from:
  https://www.domestika.org/en/blog/6073-the-10-funniest-lorem-ipsum-generators
- A longer catalogue of the same, useful for seeing which ideas recur:
  <https://loremipsum.io/ultimate-list-of-lorem-ipsum-generators/>
- The design lineage of the pulldown:
  <https://macmenubar.com/tiny-ipsum/>

Tiny Ipsum is a macOS menu-bar app that generates placeholder text and copies
it, and omaipsum is a bar icon with a pulldown for the same reason: filler text
is wanted in the middle of doing something else, so the whole interaction has
to fit in one surface reached from the bar rather than a widget plus a
full-screen overlay. `BarWidget.qml` names it twice — "the Tiny Ipsum shape"
for that decision, and "the Tiny Ipsum behaviour" for closing the panel on
copy.
