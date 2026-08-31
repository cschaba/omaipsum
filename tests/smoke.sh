#!/bin/bash

# Smoke test for everything that is not the generator: the manifest Omarchy
# reads, the settings schema the shell builds a panel from, the QML, and the
# shell scripts that install and release the plugin.
#
# None of it needs a running shell, a display or a network, and none of it
# writes anywhere but a throwaway directory — HOME is redirected there so a
# tool that decides to cache something cannot reach the real one.
#
# The check that earns its keep is the dispatcher one. omapass shipped
# `unlocked` dispatched to a function that had been deleted, twice, because
# bash only complains when the branch is actually taken: the script parses, the
# tests pass, and the subcommand nobody ran in testing is dead. Anything with a
# `case` in it gets walked here.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
export XDG_CONFIG_HOME="$TMP/config"
export XDG_STATE_HOME="$TMP/state"
export XDG_CACHE_HOME="$TMP/cache"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"

PASS=0
FAIL=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
skip() { printf '  \033[33m—\033[0m %s\n' "$1"; }

echo "omaipsum smoke test"

# --- the manifest, the schema and the dispatchers --------------------------
#
# Written as a python harness reporting one tab-separated line per check —
# "S<tab>section", "P<tab>label", "F<tab>label<tab>got<tab>want" — because
# every one of these questions is about parsed JSON or parsed bash, and asking
# them one `python3 -c` at a time turns the interesting part into quoting.

cat > "$TMP/checks.py" <<'CHECKS_EOF'
import json, os, re, sys

ROOT = sys.argv[1]

def emit(*parts):
    sys.stdout.write("\t".join(parts) + "\n")

def section(name):
    emit("S", name)

def show(value):
    # ensure_ascii off, or an em dash in a message comes out as \u2014.
    text = json.dumps(value if value is not None else "(none)", ensure_ascii=False)
    return text[:217] + '..."' if len(text) > 220 else text

def check(label, got, want):
    if got == want:
        emit("P", label)
    else:
        emit("F", label, show(got), show(want))

def yes(label, got):
    check(label, bool(got), True)

# --- manifest ---------------------------------------------------------------
#
# These mirror PluginRegistry.validateManifest in the running shell. A manifest
# it rejects produces no error a user ever sees — the plugin simply is not
# there — so the rejection has to happen here instead.

section("manifest")

manifest_path = os.path.join(ROOT, "manifest.json")
try:
    manifest = json.load(open(manifest_path, encoding="utf-8"))
    emit("P", "manifest.json parses")
except Exception as error:
    check("manifest.json parses", str(error), "valid JSON")
    sys.exit(0)

yes("manifest is an object", isinstance(manifest, dict))
# `!== 1` in the registry, so "1" and 1.0 are both rejected there and here.
check("schemaVersion is exactly 1", repr(manifest.get("schemaVersion")), repr(1))

required = ["id", "name", "version", "kinds", "entryPoints"]
missing = [k for k in required if manifest.get(k) is None]
check("every required field is present", ",".join(missing) or "(none)", "(none)")

plugin_id = str(manifest.get("id", ""))
check("the id is a bare, unescapable name",
      "bad" if (not plugin_id or "/" in plugin_id or ".." in plugin_id or plugin_id.startswith("/")) else "ok",
      "ok")
# The marketplace expects author.plugin, and an unnamespaced id collides with
# whoever else picked the obvious word.
yes("the id is namespaced", "." in plugin_id)

yes("kinds is a non-empty array", isinstance(manifest.get("kinds"), list) and len(manifest["kinds"]) > 0)
yes("entryPoints is an object", isinstance(manifest.get("entryPoints"), dict))

version = str(manifest.get("version", ""))
yes("version is semver (%s)" % version,
    re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?", version) is not None)

entry_points = manifest.get("entryPoints") if isinstance(manifest.get("entryPoints"), dict) else {}
for key, value in sorted(entry_points.items()):
    text = str(value)
    # isSafeEntryPoint: relative, and no way out of the plugin directory.
    check("entry point %s is a safe relative path" % key,
          "bad" if (not text or text.startswith("/") or ".." in text) else "ok", "ok")
    yes("entry point %s exists on disk (%s)" % (key, text),
        os.path.isfile(os.path.join(ROOT, text)))

# A kind with no entry point is a plugin the shell will list and then fail to
# load — the manifest's two halves have to agree.
if "bar-widget" in (manifest.get("kinds") or []):
    yes("the bar-widget kind has a barWidget entry point", "barWidget" in entry_points)

bar = manifest.get("barWidget") if isinstance(manifest.get("barWidget"), dict) else {}
if "defaultSection" in bar:
    check("barWidget.defaultSection is a real section",
          str(bar["defaultSection"]), str(bar["defaultSection"])
          if str(bar["defaultSection"]) in ("left", "center", "right") else "left|center|right")

# The manifest names a licence; the file has to be there for the marketplace
# claim about it to be true.
if manifest.get("license"):
    yes("the licence named in the manifest has a file", os.path.isfile(os.path.join(ROOT, "LICENSE")))

# --- the settings schema ----------------------------------------------------
#
# Omarchy builds the plugin's settings panel from barWidget.schema and seeds it
# from barWidget.defaults. Nothing validates that the two agree, and nothing
# validates that either one describes something the code still has.

section("settings schema")

schema = bar.get("schema")
defaults = bar.get("defaults")
yes("barWidget.schema is an array", isinstance(schema, list))
yes("barWidget.defaults is an object", isinstance(defaults, dict))
schema = schema if isinstance(schema, list) else []
defaults = defaults if isinstance(defaults, dict) else {}

incomplete = []
for entry in schema:
    if not isinstance(entry, dict):
        incomplete.append("(not an object)")
        continue
    for field in ("key", "type", "defaultValue"):
        if entry.get(field) is None:
            incomplete.append("%s has no %s" % (entry.get("key", "?"), field))
check("every schema entry has key, type and defaultValue", "; ".join(incomplete) or "(none)", "(none)")

schema_keys = [str(e.get("key")) for e in schema if isinstance(e, dict) and e.get("key")]
check("schema keys are unique",
      ",".join(sorted({k for k in schema_keys if schema_keys.count(k) > 1})) or "(none)", "(none)")

check("every default has a schema entry",
      ",".join(sorted(set(defaults) - set(schema_keys))) or "(none)", "(none)")
check("every schema entry has a default",
      ",".join(sorted(set(schema_keys) - set(defaults))) or "(none)", "(none)")

# Two spellings of the same value are one edit away from disagreeing, and the
# one the user sees depends on which the shell happened to read.
disagree = [e["key"] for e in schema
            if isinstance(e, dict) and e.get("key") in defaults
            and defaults[e["key"]] != e.get("defaultValue")]
check("defaults and defaultValues agree", ",".join(sorted(disagree)) or "(none)", "(none)")

by_key = {str(e.get("key")): e for e in schema if isinstance(e, dict)}

for key, entry in sorted(by_key.items()):
    if entry.get("type") == "enum":
        options = entry.get("options")
        yes("%s offers a non-empty list of options" % key, isinstance(options, list) and len(options) > 0)
        if isinstance(options, list):
            yes("%s defaults to one of its own options" % key, entry.get("defaultValue") in options)
    if entry.get("type") == "integer":
        low, high = entry.get("min"), entry.get("max")
        value = entry.get("defaultValue")
        if low is not None and high is not None:
            yes("%s defaults inside its own min/max" % key, low <= value <= high)
            yes("%s has min below max" % key, low < high)

# The unit enum and Ipsum.js's UNITS are the same list written twice. Read the
# one that is executable and compare, rather than trusting them to stay in step.
ipsum_path = os.path.join(ROOT, "Ipsum.js")
yes("Ipsum.js is where the manifest's entry point expects it", os.path.isfile(ipsum_path))
ipsum = open(ipsum_path, encoding="utf-8").read() if os.path.isfile(ipsum_path) else ""
found = re.search(r"var\s+UNITS\s*=\s*(\[[^\]]*\])", ipsum)
if not found:
    check("Ipsum.js still declares UNITS", "(not found)", "var UNITS = [...]")
else:
    units = json.loads(found.group(1))
    unit_entry = by_key.get("unit", {})
    check("the unit enum is exactly Ipsum.js's UNITS",
          ",".join(str(o) for o in (unit_entry.get("options") or [])), ",".join(units))
    check("the unit default is one Ipsum.js knows", str(unit_entry.get("defaultValue")),
          str(unit_entry.get("defaultValue")) if unit_entry.get("defaultValue") in units else "|".join(units))

# The drift this whole section exists for. `variant` is a free-text string
# rather than an enum, precisely so a fourth corpus is one new file and no
# manifest edit — which also means nothing stops the default from naming a
# corpus that was renamed or deleted. The widget would fall back to the first
# variant and the setting would look like it does nothing.
corpus_dir = os.path.join(ROOT, "corpora")
yes("corpora/ is there at all", os.path.isdir(corpus_dir))
corpora = sorted(f[:-5] for f in os.listdir(corpus_dir) if f.endswith(".json")) \
    if os.path.isdir(corpus_dir) else []
variant = str(by_key.get("variant", {}).get("defaultValue", ""))
check("the default variant names a corpus that exists",
      variant if variant in corpora else "%s (corpora/: %s)" % (variant, ", ".join(corpora)),
      variant)

# --- dispatchers ------------------------------------------------------------
#
# Walk every `case` branch in every shell script and confirm that whatever it
# calls resolves to something: a function defined in the same file, a shell
# builtin or keyword, or a program on PATH. A name that resolves to none of the
# three is a subcommand that dies the first time a user picks it.

section("dispatchers")

KEYWORDS = {"if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done",
            "case", "esac", "function", "in", "select", "time", "coproc"}
BUILTINS = {"echo", "printf", "exit", "return", "cd", "read", "local", "export", "unset",
            "shift", "eval", "exec", "set", "shopt", "trap", "true", "false", "break",
            "continue", "source", "type", "command", "declare", "readonly", "test", "wait",
            "umask", "pwd", "hash", "let", "mapfile", "readarray", "builtin", "alias",
            "unalias", "getopts", "jobs", "disown", "times", "ulimit", "compgen", "complete",
            "caller", "enable", "logout", "pushd", "popd", "dirs", "history", "bind", "kill",
            "suspend", "fg", "bg", "help"}
# Externals are allowlisted rather than looked up on PATH, on purpose. PATH
# makes the answer depend on the machine, in both directions: a tool missing
# from CI would fail a branch that is fine, and — the reason this list exists —
# this development box has a /usr/bin/usage, which quietly resolved a
# release.sh branch calling a `usage` function that had been deleted. That is
# precisely the failure the check is here to catch. A new external dependency
# in a case branch is a one-line addition here, and the failure says so.
EXTERNALS = {"awk", "basename", "cat", "chmod", "cmp", "cp", "curl", "cut", "date", "diff",
             "dirname", "du", "env", "find", "gawk", "git", "grep", "head", "hyprctl", "id",
             "install", "jq", "ln", "ls", "mkdir", "mktemp", "mv", "node", "python3",
             "qmlformat", "readlink", "realpath", "rm", "rmdir", "sed", "sh", "bash", "sleep",
             "sort", "stat", "systemctl", "tail", "tee", "touch", "tput", "tr", "uname",
             "uniq", "wc", "xargs",
             "omarchy", "omarchy-shell", "omarchy-notification-send", "notify-send",
             "wl-copy", "wl-paste", "xdg-open"}
# Stripping these off the front of a segment gets at the command they modify.
# `for` and `case` are deliberately not here: the word after them is a variable
# name or a value, not a command.
LEADERS = {"if", "elif", "then", "else", "while", "until", "do", "!", "time"}

# A case branch's body is bash, not a word list: quoted strings, arithmetic,
# tests and here-doc bodies all contain words that are not commands. Blank them
# out before looking for one. Under-detecting is fine here; a false failure
# against a script this test does not own is not.
def strip_noise(text):
    text = re.sub(r"'[^']*'", " '' ", text)
    text = re.sub(r'"[^"]*"', ' "" ', text)
    text = re.sub(r"\$\([^()]*\)", " ", text)
    text = re.sub(r"`[^`]*`", " ", text)
    text = re.sub(r"\(\(.*?\)\s*\)", " ", text)   # (( arithmetic ))
    text = re.sub(r"\[\[.*?\]\]", " ", text)      # [[ test ]]
    text = re.sub(r"(^|\s)\[\s.*?\s\]", " ", text)
    text = re.sub(r"(^|\s)#.*$", " ", text)
    return text

def candidates(body):
    body = strip_noise(body)
    # A construct left open at the end of the line spills words that are not
    # commands into the next segment. Say nothing rather than guess.
    if "((" in body or "[[" in body:
        return []
    out = []
    for segment in re.split(r"\|\||&&|[;|&\n]", body):
        tokens = segment.strip().split()
        # Leading VAR=value assignments belong to the command that follows.
        while tokens and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", tokens[0]):
            tokens.pop(0)
        while tokens and tokens[0] in LEADERS:
            tokens.pop(0)
        if not tokens:
            continue
        word = tokens[0].lstrip("!")
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_.-]*", word or ""):
            out.append(word)
    return out

# `<<EOF` and `<<-'EOF'`, but not the `<<<` here-string.
HEREDOC = re.compile(r"(?<!<)<<-?\s*(?!<)(?:'([^']+)'|\"([^\"]+)\"|([A-Za-z_][A-Za-z0-9_]*))")

def scan(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    defined = set(re.findall(r"^[ \t]*(?:function[ \t]+)?([A-Za-z_][A-Za-z0-9_.-]*)[ \t]*\(\)[ \t]*\{",
                             text, re.M))
    depth = 0
    branches = 0
    unresolved = []
    here = None
    for line in text.split("\n"):
        if here is not None:
            if line.strip() == here:
                here = None
            continue
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        opener = HEREDOC.search(line)
        if opener:
            here = opener.group(1) or opener.group(2) or opener.group(3)
        if re.match(r"^(?:.*;\s*)?case\b.*\bin\b\s*$", stripped):
            depth += 1
            continue
        if depth == 0:
            continue
        if re.search(r"(^|;|\s)esac\b", stripped):
            depth -= 1
            continue
        # `pattern) body ;;` — a pattern is what sits before the first `)` when
        # nothing in it opens a paren of its own (which would make it a
        # substitution, i.e. already the body).
        match = re.match(r"^\(?\s*([^()]*?)\)\s*(.*)$", stripped)
        body = match.group(2) if match else stripped
        if match:
            branches += 1
        for word in candidates(body.rstrip(";")):
            if word in defined or word in KEYWORDS or word in BUILTINS or word in EXTERNALS:
                continue
            unresolved.append(word)
    return branches, sorted(set(unresolved))

dispatchers = []
for path in sys.argv[2:]:
    branches, unresolved = scan(path)
    if branches:
        dispatchers.append((path, branches, unresolved))

if not dispatchers:
    # Said out loud rather than passed quietly: as install.sh, uninstall.sh and
    # scripts/release.sh land, this section starts doing work on its own.
    emit("P", "no script dispatches on a case statement yet — nothing to walk")
else:
    for path, branches, unresolved in dispatchers:
        name = os.path.relpath(path, ROOT)
        check("%s: every case branch calls something that exists (%d branches)" % (name, branches),
              ", ".join(unresolved) + " — not a function in this file, not a shell builtin, "
              "and not in EXTERNALS in tests/smoke.sh" if unresolved else "(none)", "(none)")

# --- release plumbing -------------------------------------------------------

section("release plumbing")

changelog = os.path.join(ROOT, "CHANGELOG.md")
yes("CHANGELOG.md exists", os.path.isfile(changelog))
if os.path.isfile(changelog):
    text = open(changelog, encoding="utf-8").read()
    # scripts/release.sh moves this section's contents under the new version.
    # Without it there is nothing to move and the release notes come out empty.
    yes("CHANGELOG.md keeps an [Unreleased] section",
        re.search(r"^##\s*\[Unreleased\]", text, re.M) is not None)

# --- the screencast and its CDN copy ----------------------------------------
#
# The repository is master and the copy behind the README's player is a copy.
# GitHub renders a player only for an uploaded attachment URL, and there is no
# API to upload one — so the two are refreshed by different means and will drift
# the moment somebody re-records the video and forgets the second half.
#
# Nobody rereads their own README often enough to notice a player showing last
# month's take, so this is checked rather than remembered: the hash beside the
# file is the hash of the video that was uploaded. If they disagree, the upload
# did not happen.
#
# This cannot prove the CDN copy holds the same bytes — the URL is signed and
# expires, so a test cannot fetch it. It proves the repository copy has not
# moved without the upload, which is the failure that actually occurs.

section("the screencast")

video = os.path.join(ROOT, "docs", "screencast.mp4")
recorded = os.path.join(ROOT, "docs", "screencast.mp4.sha256")
readme_path = os.path.join(ROOT, "README.md")

readme = open(readme_path, encoding="utf-8").read() if os.path.isfile(readme_path) else ""

# The hash only means something while a CDN copy is actually in use. The README
# does not embed one today, so enforcing it would fail an honest re-record with
# advice about refreshing something nobody is serving. Gated on the embed, the
# check arrives with the thing it protects and stays quiet until then.
embedded = "user-attachments/assets/" in readme

if os.path.isfile(video) and embedded:
    yes("docs/screencast.mp4.sha256 records the uploaded video's hash",
        os.path.isfile(recorded))
    if os.path.isfile(recorded):
        import hashlib
        actual = hashlib.sha256(open(video, "rb").read()).hexdigest()
        want = open(recorded, encoding="utf-8").read().strip()
        # check() rather than yes(): when these disagree the two hashes are
        # the useful part of the failure, and yes() would only say "False".
        check("the committed screencast matches the hash of the uploaded copy"
              " — if this fails, re-upload docs/screencast.mp4 to GitHub, put"
              " the new user-attachments URL in README.md, and write the new"
              " hash into docs/screencast.mp4.sha256",
              actual, want)

# Unconditional: a <video> tag renders as nothing at all on GitHub whether or
# not an attachment is in use, and it fails silently, so it is worth refusing
# outright rather than only while the embed exists.
yes("the README does not use a <video> tag, which GitHub strips",
    "<video" not in readme)
CHECKS_EOF

# The scripts the dispatcher scan is handed. Globbed, not listed, so install.sh,
# uninstall.sh and scripts/release.sh join in the moment they exist and nothing
# fails today because they do not.
shopt -s nullglob
CANDIDATES=("$ROOT"/*.sh "$ROOT"/scripts/*.sh "$ROOT"/tests/*.sh "$ROOT"/bin/*)
shopt -u nullglob

SCRIPTS=()
for f in "${CANDIDATES[@]}"; do
  [[ -f "$f" ]] || continue
  # Extensionless files under bin/ are scripts only if they say so.
  if [[ "$f" == *.sh ]] || head -n 1 "$f" | grep -qE '^#!.*\b(bash|sh)\b'; then
    SCRIPTS+=("$f")
  fi
done

if ! python3 "$TMP/checks.py" "$ROOT" "${SCRIPTS[@]}" >"$TMP/report" 2>"$TMP/stderr"; then
  bad "the manifest checks themselves failed to run"
  sed 's/^/        /' "$TMP/stderr"
  echo
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

while IFS=$'\t' read -r kind label got want; do
  case "$kind" in
    S) echo; echo "$label" ;;
    P) ok "$label" ;;
    F) bad "$label"; printf '        got:  %s\n        want: %s\n' "$got" "$want" ;;
    *) [[ -z "$kind" ]] || bad "unreadable check line: $kind" ;;
  esac
done <"$TMP/report"

# --- QML --------------------------------------------------------------------
#
# qmlformat, not qmllint. `qs.Commons` and `qs.Ui` resolve only inside the
# running Omarchy shell, and qmllint treats an unresolved import as an error —
# so it rejects every file here regardless of whether the syntax is sound.
# qmlformat ignores imports and still refuses to parse a broken file.

echo
echo "qml"
if ! command -v qmlformat >/dev/null 2>&1; then
  skip "qmlformat unavailable — skipped the QML parse checks"
else
  shopt -s nullglob globstar
  QML=("$ROOT"/**/*.qml)
  shopt -u nullglob globstar
  if [[ ${#QML[@]} -eq 0 ]]; then
    bad "no .qml files found — the plugin has no entry point to load"
  fi
  for f in "${QML[@]}"; do
    name="${f#"$ROOT"/}"
    if qmlformat "$f" >/dev/null 2>"$TMP/qmlformat.err"; then
      ok "$name parses"
    else
      bad "$name does not parse"
      # qmlformat usually says nothing and just exits non-zero, so point at
      # the tool that will name the line rather than printing an empty block.
      if [[ -s "$TMP/qmlformat.err" ]]; then
        sed 's/^/        /' "$TMP/qmlformat.err"
      else
        printf '        run: qmllint -I /usr/share/omarchy/shell %s\n' "$name"
      fi
    fi
  done
fi

# --- shell scripts ----------------------------------------------------------

echo
echo "shell scripts"
if [[ ${#SCRIPTS[@]} -eq 0 ]]; then
  skip "no shell scripts found yet — install.sh and friends are still to come"
fi
for f in "${SCRIPTS[@]}"; do
  name="${f#"$ROOT"/}"
  if bash -n "$f" 2>"$TMP/bash.err"; then
    ok "$name parses"
  else
    bad "$name does not parse"
    sed 's/^/        /' "$TMP/bash.err"
  fi
  # A script the user is told to run has to be runnable. tests/ included: the
  # release script runs them.
  if [[ -x "$f" ]]; then
    ok "$name is executable"
  else
    bad "$name is not executable"
  fi
done

echo
echo "$PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
