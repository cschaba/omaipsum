#!/bin/bash

# Cut a release: check everything, bump the version, move the changelog entry,
# commit, tag, push.
#
# A maintainer tool, run by hand from a local checkout after a fix has been
# merged to main. It is not part of installing or running omaipsum — no user
# ever executes it, and nothing in the plugin calls it. One release per fixed
# issue, as AGENTS.md has it, which is also why the release bookkeeping is one
# of the two things that happen on main directly instead of on a branch.
#
# The version lives in exactly one place, manifest.json. Omarchy reads it from
# there, so a second copy anywhere else could only drift; this script therefore
# rewrites that one field and nothing else.
#
# Two ordering rules run through the whole thing:
#
#   Everything that can fail is checked before a tag exists. A tag you have to
#   delete and re-push is worse than a release that refuses to start, because
#   the tag is the thing other people (and later, CI) have already reacted to.
#   So the tests, the parsers and the remote are all consulted while the tree
#   is still untouched, and the script exits non-zero with one line saying why.
#
#   The commit is pushed before the tag. A remote that has a tag pointing at a
#   commit it does not have is broken in a way nobody can fix by pulling; a
#   remote that has the commit but not yet the tag is merely a release that has
#   not finished, and the next line of this script finishes it.
#
# The `git fetch` below only *counts* how far behind the remote this checkout
# is. Nothing fetched is ever checked out, merged or run — the fetch touches
# refs and the object store, never the working tree, and FETCH_HEAD is read
# only by `git rev-list --count`. Releasing from a checkout that is behind is
# how a fix gets tagged out of a tree that does not contain it.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

MANIFEST="$ROOT/manifest.json"
CHANGELOG="$ROOT/CHANGELOG.md"

# Gitea is home; GitHub is a mirror (DEVELOPMENT.md, "Where the code lives").
# The release is *made* at origin — that is where the branch, the issues and
# the pull requests are, and it is the remote this script insists on being in
# step with before it writes anything. The mirror is pushed to, never worked
# in, so it is pushed second and best-effort: once the tag is at home the
# release exists, and a mirror that is briefly behind is a re-push, not a
# broken release. The marketplace listing points at the mirror's repository
# rather than a release, so what the mirror owes the world is an up-to-date
# main; the tag goes along for completeness.
REMOTE="${OMAIPSUM_RELEASE_REMOTE:-origin}"
MIRROR="${OMAIPSUM_MIRROR_REMOTE:-github}"

DRY_RUN=0
MISSING_TESTS=0
TODAY="$(date +%F)"

die() { echo "release: $*" >&2; exit 1; }
say() { echo "  $*"; }
plan() { echo "  would $*"; }

# In a real run, do it. In a dry run, say it and move on — the point of
# --dry-run is to read the whole plan in order before agreeing to any of it.
run() {
  if (( DRY_RUN )); then
    local quoted=() a
    for a in "$@"; do
      if [[ $a == *[[:space:]]* ]]; then quoted+=("\"$a\""); else quoted+=("$a"); fi
    done
    plan "run: ${quoted[*]}"
  else
    "$@"
  fi
}

usage() {
  cat <<'USAGE'
scripts/release.sh <major|minor|patch|X.Y.Z> [--dry-run]

  Refuses unless the tree is clean, you are on main and in step with the
  remote, the tag is free, manifest.json is valid, CHANGELOG.md has a
  non-empty [Unreleased] section, every shell script and QML file parses,
  and the tests in tests/ pass.

  Then: bumps the version in manifest.json, moves the [Unreleased] entries
  under a new dated heading in CHANGELOG.md, commits, tags vX.Y.Z, pushes
  the commit and then the tag to the Gitea origin, and mirrors both to
  GitHub if that remote is configured.

  --dry-run prints every one of those steps, in order, and writes nothing.

  Environment: OMAIPSUM_RELEASE_REMOTE (default origin),
               OMAIPSUM_MIRROR_REMOTE (default github).
USAGE
}

manifest_version() {
  python3 - "$MANIFEST" <<'PY'
import json, sys
try:
    print(json.load(open(sys.argv[1])).get("version", ""))
except Exception:
    print("")
PY
}

# major/minor/patch, or an explicit X.Y.Z. Anything else is a typo, and a typo
# that reaches `git tag` is the expensive kind.
next_version() {
  local current="$1" bump="$2"
  local a b c
  IFS=. read -r a b c <<<"${current%%-*}"
  [[ $a =~ ^[0-9]+$ && $b =~ ^[0-9]+$ && $c =~ ^[0-9]+$ ]] \
    || die "manifest.json version '$current' is not major.minor.patch"
  case "$bump" in
  major) echo "$((a + 1)).0.0" ;;
  minor) echo "$a.$((b + 1)).0" ;;
  patch) echo "$a.$b.$((c + 1))" ;;
  *)
    [[ $bump =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] \
      || die "'$bump' is not a version or one of major/minor/patch"
    # An explicit version has to move forwards. Going backwards would tag an
    # older number onto newer code, and every consumer that compares versions
    # would then be wrong about which build it has.
    local x y z
    IFS=. read -r x y z <<<"${bump%%-*}"
    if ! (( x > a || (x == a && y > b) || (x == a && y == b && z > c) )); then
      die "$bump is not greater than the current version $current"
    fi
    echo "$bump"
    ;;
  esac
}

# The [Unreleased] section must exist and hold at least one entry. An empty one
# means the changelog entry was never written, and AGENTS.md is explicit that it
# is written as part of the fix, not afterwards — releasing over an empty
# section would silently ship a version nobody can read the history of.
unreleased_entries() {
  awk '
    /^## \[Unreleased\]/ { inside = 1; next }
    inside && /^## /     { exit }
    inside && NF         { found = 1 }
    END                  { exit found ? 0 : 1 }
  ' "$CHANGELOG"
}

main() {
  local bump="" arg
  for arg in "$@"; do
    case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h | --help) usage; exit 0 ;;
    -*) usage >&2; die "unknown option '$arg'" ;;
    *)
      [[ -z $bump ]] || { usage >&2; die "more than one version argument"; }
      bump="$arg"
      ;;
    esac
  done
  [[ -n $bump ]] || { usage >&2; exit 1; }

  if (( DRY_RUN )); then
    echo "release: dry run — nothing will be written"
    echo
  fi

  # --- refuse to release from a state you would regret ----------------------
  # Every check below happens while the tree is still exactly as it was found.
  # The first one that fails ends the script; nothing is half-applied.

  command -v python3 >/dev/null 2>&1 || die "python3 is required (manifest and changelog surgery)"
  command -v qmlformat >/dev/null 2>&1 \
    || die "qmlformat is required to parse the QML — install qt6-declarative-tools"

  git rev-parse --git-dir >/dev/null 2>&1 || die "not a git repository"
  [[ -z $(git status --porcelain) ]] || die "working tree is dirty — commit or stash first"

  local branch
  branch=$(git rev-parse --abbrev-ref HEAD)
  [[ $branch == "main" ]] || die "on '$branch' — releases are cut from main"

  git remote get-url "$REMOTE" >/dev/null 2>&1 || die "no remote named '$REMOTE'"
  # Counting only. FETCH_HEAD is read by rev-list and by nothing else, and no
  # ref of ours is moved: being behind is a reason to stop, not to merge.
  git fetch --quiet "$REMOTE" main 2>/dev/null || die "could not reach $REMOTE"
  local behind
  behind=$(git rev-list --count HEAD..FETCH_HEAD)
  (( behind == 0 )) || die "$behind commit(s) behind $REMOTE/main — pull first"

  # Validated before anything reads a version out of it, and python3's own
  # message is the whole reason, printed as one line — a traceback is not a
  # reason.
  local manifest_error
  if ! manifest_error=$(python3 - "$MANIFEST" 2>&1 <<'PY'
import json, os, re, sys
try:
    manifest = json.load(open(sys.argv[1]))
except Exception as exc:
    sys.exit(f"manifest.json does not parse: {exc}")
for key in ("schemaVersion", "id", "name", "version", "kinds", "entryPoints"):
    if key not in manifest:
        sys.exit(f"manifest.json is missing {key!r}")
if not re.fullmatch(r"\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?", str(manifest["version"])):
    sys.exit(f"manifest.json version {manifest['version']!r} is not semver")
for kind, path in manifest["entryPoints"].items():
    if not os.path.isfile(path):
        sys.exit(f"entryPoint {kind} -> {path} does not exist")
PY
  ); then
    die "${manifest_error##*$'\n'}"
  fi

  local current next tag
  current=$(manifest_version)
  [[ $current =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] \
    || die "manifest.json version '$current' is not semver"
  next=$(next_version "$current" "$bump")
  tag="v$next"

  # Locally *and* on the remote: a tag that exists in only one of the two is
  # exactly the mess this script is built to avoid, and it is cheap to ask.
  ! git rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1 \
    || die "tag $tag already exists locally"
  [[ -z $(git ls-remote --tags "$REMOTE" "refs/tags/$tag" 2>/dev/null) ]] \
    || die "tag $tag already exists on $REMOTE"

  say "repository  $ROOT"
  say "home        $REMOTE  ($(git remote get-url "$REMOTE"))"
  if git remote get-url "$MIRROR" >/dev/null 2>&1; then
    say "mirror      $MIRROR  ($(git remote get-url "$MIRROR"))"
  else
    say "mirror      $MIRROR  (not configured — nothing will be mirrored)"
  fi
  say "current     $current"
  say "next        $next  (tag $tag, dated $TODAY)"
  echo

  say "manifest.json is valid"

  grep -q '^## \[Unreleased\]' "$CHANGELOG" || die "CHANGELOG.md has no [Unreleased] section"
  unreleased_entries \
    || die "CHANGELOG.md [Unreleased] is empty — write the entry as part of the fix"
  say "CHANGELOG.md has [Unreleased] entries"

  # Globbed, never a hardcoded list: install.sh, uninstall.sh and tests/ arrive
  # with their own issues, and a list would silently stop covering the repo the
  # day one of them lands.
  local -a scripts=()
  local f
  while IFS= read -r -d '' f; do scripts+=("$f"); done \
    < <(find "$ROOT" -path "$ROOT/.git" -prune -o -type f -name '*.sh' -print0 | sort -z)
  (( ${#scripts[@]} )) || die "no shell scripts found — that cannot be right"
  for f in "${scripts[@]}"; do
    bash -n "$f" 2>/dev/null || die "${f#"$ROOT"/} has a shell syntax error"
  done
  say "${#scripts[@]} shell script(s) parse"

  # qmlformat rather than qmllint: qs.Commons and qs.Ui resolve only inside the
  # Omarchy shell, and qmllint calls an unresolved import an error, so it would
  # reject every file here regardless of syntax. qmlformat is a pure parser.
  local -a qml=()
  while IFS= read -r -d '' f; do qml+=("$f"); done \
    < <(find "$ROOT" -path "$ROOT/.git" -prune -o -type f -name '*.qml' -print0 | sort -z)
  (( ${#qml[@]} )) || die "no *.qml files found — this is a QML plugin"
  for f in "${qml[@]}"; do
    qmlformat "$f" >/dev/null 2>&1 || die "${f#"$ROOT"/} does not parse"
  done
  say "${#qml[@]} QML file(s) parse"

  # Every executable in tests/, globbed — issue #9's files may land under names
  # this script has never heard of, and a hardcoded list would run none of them
  # while still saying "tests pass".
  local -a suite=()
  if [[ -d $ROOT/tests ]]; then
    while IFS= read -r -d '' f; do suite+=("$f"); done \
      < <(find "$ROOT/tests" -maxdepth 1 -type f -perm -u+x -print0 | sort -z)
  fi

  if (( ${#suite[@]} == 0 )); then
    # A release with no tests run is not a release. But a *dry* run is the tool
    # you reach for precisely while the suite is still being written — refusing
    # outright would hide the rest of the plan at the one moment it is most
    # worth reading. So a dry run reports this and keeps going, and still exits
    # non-zero at the end so nobody mistakes it for a green light.
    if (( DRY_RUN )); then
      say "WOULD REFUSE: no executable tests in tests/ — a release with no tests run is not a release"
      say "              (continuing the dry run anyway, to show the rest of the plan)"
      MISSING_TESTS=1
    else
      die "no executable tests in tests/ — a release with no tests run is not a release"
    fi
  else
    for f in "${suite[@]}"; do
      "$f" >/dev/null 2>&1 || die "tests/${f##*/} failed — not releasing"
    done
    say "${#suite[@]} test script(s) pass"
  fi
  echo

  # --- write ----------------------------------------------------------------
  # Nothing above this line changed a byte. Everything below is ordered so the
  # tag is the last thing created locally and the second-to-last thing pushed.

  if (( DRY_RUN )); then
    plan "set manifest.json version: \"$current\" -> \"$next\"  (that field only)"
    plan "rewrite CHANGELOG.md — [Unreleased] entries move under [$next] — $TODAY:"
    echo
    python3 - "$CHANGELOG" "$next" "$TODAY" preview <<'PY' | sed 's/^/      | /'
import sys
path, version, today, mode = sys.argv[1:5]
text = open(path).read().replace(
    "## [Unreleased]\n",
    f"## [Unreleased]\n\n## [{version}] — {today}\n",
    1,
)
head = text.split("\n")
stop = 0
seen = 0
for i, line in enumerate(head):
    if line.startswith("## ["):
        seen += 1
        if seen == 3:
            stop = i
            break
else:
    stop = len(head)
print("\n".join(head[:stop]).rstrip())
print("...")
PY
    echo
  else
    # sed on the one line, not a JSON re-dump: re-serialising would reformat
    # the whole manifest and bury the version change in a diff nobody reads.
    local hits
    hits=$(grep -c '^[[:space:]]*"version"[[:space:]]*:' "$MANIFEST" || true)
    (( hits == 1 )) || die "expected exactly one \"version\" line in manifest.json, found $hits"
    sed -i "s/^\([[:space:]]*\"version\"[[:space:]]*:[[:space:]]*\)\"[^\"]*\"/\1\"$next\"/" "$MANIFEST"
    [[ $(manifest_version) == "$next" ]] || die "manifest.json version did not take"
    say "manifest.json -> $next"

    python3 - "$CHANGELOG" "$next" "$TODAY" write <<'PY'
import sys
path, version, today, mode = sys.argv[1:5]
text = open(path).read()
marker = "## [Unreleased]\n"
if marker not in text:
    sys.exit("CHANGELOG.md lost its [Unreleased] heading")
# The entries stay exactly where they are; a dated heading is inserted above
# them and a fresh, empty [Unreleased] is left at the top for the next fix.
# omaipsum's changelog carries no link definitions at the bottom (omapass's
# does), so there is nothing else to keep in step.
text = text.replace(marker, f"{marker}\n## [{version}] — {today}\n", 1)
open(path, "w").write(text)
PY
    say "CHANGELOG.md -> [$next] — $TODAY"
  fi

  run git add manifest.json CHANGELOG.md
  run git commit -q -m "Release $next"
  # The tag is created only now, with every check already passed and the commit
  # already made, so there is nothing left that could force it to be undone.
  run git tag -a "$tag" -m "omaipsum $next"

  # Commit first, tag second: a remote must never hold a tag whose commit it
  # has not got.
  run git push "$REMOTE" main
  run git push "$REMOTE" "$tag"

  if git remote get-url "$MIRROR" >/dev/null 2>&1; then
    if (( DRY_RUN )); then
      plan "run: git push $MIRROR main   (mirror, best-effort)"
      plan "run: git push $MIRROR $tag   (mirror, best-effort)"
    else
      # Best-effort by design. The release exists once the tag is at origin;
      # if the mirror is unreachable the fix is one command, not a re-tag.
      if git push "$MIRROR" main && git push "$MIRROR" "$tag"; then
        say "mirrored to $MIRROR"
      else
        echo "release: warning — could not push to the $MIRROR mirror." >&2
        echo "release: the release is complete at $REMOTE; re-run:" >&2
        echo "release:   git push $MIRROR main && git push $MIRROR $tag" >&2
      fi
    fi
  fi

  echo
  if (( DRY_RUN )); then
    if (( MISSING_TESTS )); then
      say "dry run complete — but it REFUSED above: no tests to run"
      exit 1
    fi
    say "dry run complete — nothing was written"
  else
    say "released $next — tag $tag is on $REMOTE"
  fi
}

main "$@"
