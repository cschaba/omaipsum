#!/bin/bash

# The generator, exercised without a shell, a bar or a display: Ipsum.js is a
# `.pragma library` with no QML types in it, so node can load it by stripping
# that one line and eval'ing the rest — the same trick omapass uses on
# PassStore.js. What passes here is what the widget gets, because the widget
# calls exactly these functions with exactly these arguments.
#
# Three things are worth testing and nothing else is:
#
#   the counts are exact        — "3 paragraphs" that gives four is the bug a
#                                 user notices first, and the one that comes
#                                 back every time the shaping is touched;
#   the shape holds             — sentences and paragraphs stay inside the
#                                 bounds Ipsum.js declares, or the prose reads
#                                 as a loop;
#   the same seed means the same text — the pulldown's preview and the string
#                                 that reaches the clipboard are two separate
#                                 calls, and they have to agree.
#
# The assertions live in a node harness written into a throwaway directory,
# which reports one line per check; bash counts them and owns the exit status.
# Nothing outside that directory is read for writing and nothing is written
# outside it at all.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Nothing here reads a config or a cache, but node and its version managers
# will happily invent one in a real home. Point HOME at the throwaway.
export HOME="$TMP/home"
export XDG_CONFIG_HOME="$TMP/config"
export XDG_STATE_HOME="$TMP/state"
export XDG_CACHE_HOME="$TMP/cache"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"

PASS=0
FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }

echo "omaipsum generator test"

if ! command -v node >/dev/null 2>&1; then
  echo
  # A skip, not a pass: the suite still exits 0 so a machine without node can
  # run the rest of the checks, but the line says plainly that nothing here ran.
  printf '  \033[33m—\033[0m node unavailable — skipped every generator check\n'
  echo
  echo "0 passed, 0 failed (skipped)"
  exit 0
fi

# --- the harness -----------------------------------------------------------
#
# Reports one tab-separated line per check: "S<tab>section", "P<tab>label", or
# "F<tab>label<tab>got<tab>want". `got` and `want` are JSON-encoded so a
# paragraph's newlines cannot break the line protocol.

cat > "$TMP/harness.js" <<'HARNESS_EOF'
// No "use strict": a strict eval gets its own scope and Ipsum.js's functions
// would never reach this file.
const fs = require("fs");
const path = require("path");

const ROOT = process.argv[2];

// `.pragma library` is QML's way of saying "no engine, just functions"; node
// only needs it gone. eval, not require, because the file has no exports —
// keeping it importable by node would mean writing it for node, and it is
// written for the widget.
let source = fs.readFileSync(path.join(ROOT, "Ipsum.js"), "utf8")
  .replace(".pragma library", "");
eval(source);

function emit(parts) { process.stdout.write(parts.join("\t") + "\n"); }
function section(name) { emit(["S", name]); }
function show(value) {
  const text = JSON.stringify(value === undefined ? "(undefined)" : value);
  return text.length > 220 ? text.slice(0, 217) + '..."' : text;
}
function check(label, got, want) {
  if (got === want) emit(["P", label]);
  else emit(["F", label, show(got), show(want)]);
}
function yes(label, got) { check(label, got === true, true); }
function throwsWith(label, body, needle) {
  let message = null;
  try { body(); } catch (error) { message = String(error && error.message || error); }
  if (message === null) check(label, "(returned without throwing)", "an error naming " + needle);
  else if (message.indexOf(needle) === -1) check(label, message, "an error naming " + needle);
  else emit(["P", label]);
}

// Words never contain a full stop — corpora are ^[a-z]+$ and the generator
// only ever appends "." or "," — so splitting on it is exact, not heuristic.
function sentencesOf(text) {
  return String(text).split(/\.(?:\s+|$)/).filter(s => s.trim() !== "");
}
function paragraphsOf(text) {
  return String(text).split("\n\n").filter(s => s.trim() !== "");
}

// A run of counts either all match or the check names the first that did not,
// so one line covers a whole sweep without hiding which value broke it.
function sweep(label, counts, measure) {
  for (const n of counts) {
    const got = measure(n);
    if (got !== n) { check(label, "asked " + n + ", got " + got, "asked " + n + ", got " + n); return; }
  }
  emit(["P", label]);
}

// --- corpora ---------------------------------------------------------------

const CORPUS_DIR = path.join(ROOT, "corpora");
const FILES = fs.readdirSync(CORPUS_DIR).filter(f => f.endsWith(".json")).sort();
const CORPORA = [];

// A corpus written for the test rather than shipped, so the anchors below
// depend on the generator's shaping and on nothing else. Editing a real
// corpus's word list is expected and must not break a shaping test.
const FIXTURE = {
  id: "fixture",
  name: "Fixture",
  blurb: "a corpus that exists only in this file",
  attribution: "the Greek alphabet",
  source: "https://example.invalid",
  opening: ["fixture", "opening", "phrase"],
  words: ["alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta",
          "iota", "kappa", "lambda", "mu", "nu", "xi", "omicron", "pi", "rho",
          "sigma", "tau", "upsilon", "phi", "chi", "psi", "omega"]
};

section("corpus files");
check("corpora/ holds at least one variant", FILES.length > 0, true);
for (const file of FILES) {
  const stem = file.replace(/\.json$/, "");
  let corpus = null;
  try {
    corpus = JSON.parse(fs.readFileSync(path.join(CORPUS_DIR, file), "utf8"));
    emit(["P", file + " parses"]);
  } catch (error) {
    check(file + " parses", String(error.message), "valid JSON");
    continue;
  }
  CORPORA.push(corpus);

  // The fields are the contract in corpora/README.md. `attribution` and
  // `source` are shown to users and are a licensing claim, so a corpus that
  // lost them is not merely untidy.
  const required = ["id", "name", "blurb", "attribution", "source", "opening", "words"];
  const missing = required.filter(k => corpus[k] === undefined || corpus[k] === null || corpus[k] === "");
  check(file + " has every required field", missing.join(",") || "(none)", "(none)");

  // The widget finds a variant by its id and the file it came from; the two
  // disagreeing means a variant nobody can select.
  check(file + " id matches the filename", String(corpus.id), stem);

  check(file + " opening is an array", Array.isArray(corpus.opening), true);
  const badOpening = (corpus.opening || []).filter(w => !/^[a-z]+$/.test(String(w)));
  check(file + " opening is plain lowercase words", badOpening.join(",") || "(none)", "(none)");

  check(file + " words is an array", Array.isArray(corpus.words), true);
  const words = Array.isArray(corpus.words) ? corpus.words : [];
  // 120 is the point below which the same word starts coming round often
  // enough to read as a stutter rather than as prose.
  check(file + " has at least 120 words",
        words.length >= 120 ? "120 or more" : words.length + " words", "120 or more");

  // A duplicate is invisible in the output and quietly weights that word.
  const seen = Object.create(null);
  const dupes = [];
  for (const w of words) {
    if (seen[w]) { if (dupes.indexOf(w) === -1) dupes.push(w); }
    seen[w] = true;
  }
  check(file + " words are unique", dupes.slice(0, 5).join(",") || "(none)", "(none)");

  // Capitals and punctuation in a pool would come out mid-sentence: the
  // generator owns the typography, the corpus owns the vocabulary.
  const malformed = words.filter(w => !/^[a-z]+$/.test(String(w)));
  check(file + " words are all ^[a-z]+$", malformed.slice(0, 5).join(",") || "(none)", "(none)");
}

const ALL = CORPORA.concat([FIXTURE]);

// --- exact counts ----------------------------------------------------------

section("exact counts");
for (const corpus of ALL) {
  sweep(corpus.id + " — N words gives exactly N",
    [1, 2, 3, 4, 5, 6, 7, 13, 25, 60, 100],
    n => countWords(generate(corpus, "words", n, makeRng("count-" + n))));
  sweep(corpus.id + " — N sentences gives exactly N",
    [1, 2, 3, 5, 9, 20],
    n => sentencesOf(generate(corpus, "sentences", n, makeRng("count-" + n))).length);
  sweep(corpus.id + " — N paragraphs gives exactly N",
    [1, 2, 3, 5, 12],
    n => paragraphsOf(generate(corpus, "paragraphs", n, makeRng("count-" + n))).length);
}

// Words mode is the awkward one: the caller's number is not the number of the
// thing being shaped, so the sentence lengths have to be chosen around a total
// that cannot move. Sweep every seed rather than one.
let drift = "(none)";
for (let seed = 0; seed < 200 && drift === "(none)"; seed++) {
  for (const n of [5, 11, 17, 23, 41]) {
    const got = countWords(generate(CORPORA[0] || FIXTURE, "words", n, makeRng("drift-" + seed)));
    if (got !== n) { drift = "seed " + seed + " asked " + n + " got " + got; break; }
  }
}
check("words mode holds its total over 200 seeds", drift, "(none)");

// --- shape -----------------------------------------------------------------

section("shape");
for (const corpus of ALL) {
  let offender = "(none)";
  for (let seed = 0; seed < 40 && offender === "(none)"; seed++) {
    for (const s of sentencesOf(generate(corpus, "sentences", 12, makeRng("shape-" + seed)))) {
      const n = countWords(s);
      if (n < 5 || n > 15) { offender = n + " words: " + s; break; }
    }
  }
  check(corpus.id + " — every sentence is 5-15 words", offender, "(none)");

  let paragraph = "(none)";
  for (let seed = 0; seed < 40 && paragraph === "(none)"; seed++) {
    for (const p of paragraphsOf(generate(corpus, "paragraphs", 6, makeRng("shape-" + seed)))) {
      const n = sentencesOf(p).length;
      if (n < 3 || n > 6) { paragraph = n + " sentences"; break; }
    }
  }
  check(corpus.id + " — every paragraph is 3-6 sentences", paragraph, "(none)");

  // Prose mode still has to break into readable sentences: a one-word tail is
  // the failure the "never leave less than the minimum" rule exists to stop.
  let tail = "(none)";
  for (let seed = 0; seed < 40 && tail === "(none)"; seed++) {
    for (const s of sentencesOf(generate(corpus, "words", 47, makeRng("tail-" + seed)))) {
      const n = countWords(s);
      if (n < 5 || n > 15) { tail = n + " words: " + s; break; }
    }
  }
  check(corpus.id + " — words mode leaves no runt sentence", tail, "(none)");
}

// Every sentence ends in a full stop and starts with a capital, in every mode.
for (const corpus of ALL) {
  let broken = "(none)";
  for (const unit of UNITS) {
    const text = generate(corpus, unit, 7, makeRng("typo"));
    for (const s of sentencesOf(text)) {
      if (!/^[A-Z]/.test(s.trim())) { broken = unit + ": " + s; break; }
    }
    if (!/\.$/.test(text.trim())) broken = unit + " does not end in a full stop";
  }
  check(corpus.id + " — sentences open with a capital and close with a stop", broken, "(none)");
}

// --- determinism -----------------------------------------------------------

section("determinism");
for (const corpus of ALL) {
  let mismatch = "(none)";
  for (const unit of UNITS) {
    const a = generate(corpus, unit, 5, makeRng("same"));
    const b = generate(corpus, unit, 5, makeRng("same"));
    if (a !== b) { mismatch = unit; break; }
  }
  check(corpus.id + " — the same seed gives byte-identical text", mismatch, "(none)");
}
check("a different seed gives different text",
  generate(FIXTURE, "paragraphs", 2, makeRng("seed-a")) !== generate(FIXTURE, "paragraphs", 2, makeRng("seed-b")),
  true);
// Ipsum.js promises 1 and "1" name the same run, because a seed arrives as
// whatever the caller had — a counter, or a corpus id.
check("a numeric seed and its string spelling agree",
  generate(FIXTURE, "words", 30, makeRng(1)), generate(FIXTURE, "words", 30, makeRng("1")));
// Neighbouring seeds are exactly how a Regenerate button numbers its runs, and
// FNV's low bits barely move between them — hence the discarded rounds in
// makeRng. If those go, these two open with the same word.
check("neighbouring seeds do not open alike",
  generate(FIXTURE, "words", 20, makeRng("run-1")).split(" ")[3] !==
  generate(FIXTURE, "words", 20, makeRng("run-2")).split(" ")[3],
  true);
// Generation must leave nothing behind: two runs interleaved would share state
// if any of it lived at module scope.
const first = generate(FIXTURE, "sentences", 3, makeRng("reuse"));
generate(FIXTURE, "paragraphs", 4, makeRng("other"));
check("a run carries no state into the next", generate(FIXTURE, "sentences", 3, makeRng("reuse")), first);

section("regression anchors");
// Exact strings, so a change to the shaping — comma placement, sentence
// lengths, the paragraph separator — has to be looked at rather than absorbed.
// These use the fixture corpus, so editing a shipped corpus's word list (which
// the README invites) cannot break them.
check("anchor: fixture / words / 12 / \"anchor\"",
  generate(FIXTURE, "words", 12, makeRng("anchor")),
  "Fixture opening phrase rho beta, tau xi lambda chi delta zeta psi.");
check("anchor: fixture / sentences / 3 / \"anchor\"",
  generate(FIXTURE, "sentences", 3, makeRng("anchor")),
  "Fixture opening phrase beta tau, xi lambda chi delta zeta psi lambda. " +
  "Psi alpha iota chi xi iota alpha delta beta omicron xi tau. " +
  "Eta epsilon kappa theta eta omega omicron gamma xi upsilon gamma tau epsilon iota.");
check("anchor: fixture / paragraphs / 2 / \"anchor\"",
  generate(FIXTURE, "paragraphs", 2, makeRng("anchor")),
  "Fixture opening phrase tau xi. Lambda chi delta zeta psi lambda zeta epsilon rho. " +
  "Iota chi xi iota alpha. Beta omicron, xi tau chi phi. " +
  "Theta eta omega omicron, gamma xi upsilon gamma tau." +
  "\n\n" +
  "Beta mu lambda theta omicron iota omega gamma epsilon beta sigma beta sigma pi lambda. " +
  "Phi zeta sigma pi zeta beta, phi alpha rho omicron pi psi xi. " +
  "Nu rho theta iota upsilon alpha zeta pi beta omega sigma beta omega. " +
  "Upsilon iota zeta upsilon gamma tau phi sigma delta chi rho chi omicron zeta epsilon. " +
  "Theta rho phi gamma alpha lambda omega theta, sigma epsilon.");

// One anchor against a real corpus, because the shipped data is half of what a
// user sees. Editing corpora/classic.json changes this string legitimately —
// when it fails, check the diff before changing the line.
const classic = CORPORA.filter(c => c.id === "classic")[0];
if (classic) {
  check("anchor: classic / words / 12 / \"omaipsum-anchor\"",
    generate(classic, "words", 12, makeRng("omaipsum-anchor")),
    "Lorem ipsum dolor sit amet provident animi ipsam soluta tempor voluptate rem.");
} else {
  emit(["P", "no classic corpus — skipped its anchor"]);
}

// --- the opening convention ------------------------------------------------

section("the opening");
for (const corpus of ALL) {
  const opening = corpus.opening || [];
  if (!opening.length) {
    // No signature phrase is a legitimate choice (bacon, corporate): the only
    // promise is that the text still starts like prose.
    let broken = "(none)";
    for (const unit of UNITS) {
      if (!/^[A-Z]/.test(generate(corpus, unit, 3, makeRng("open")))) { broken = unit; break; }
    }
    check(corpus.id + " — no opening, still starts like prose", broken, "(none)");
    continue;
  }

  const head = opening.join(" ");
  const capitalised = head.charAt(0).toUpperCase() + head.slice(1);
  let missed = "(none)";
  for (const unit of UNITS) {
    // Words mode counts words, so the count has to clear the phrase before the
    // phrase can appear whole — asking for fewer is the truncation case below.
    const count = unit === "words" ? opening.length + 8 : 4;
    const text = generate(corpus, unit, count, makeRng("open"));
    if (text.indexOf(capitalised) !== 0) { missed = unit + ": " + text.slice(0, 60); break; }
  }
  check(corpus.id + " — every unit opens with the phrase, capitalised", missed, "(none)");

  // Fewer words than the phrase has must cut the phrase short, not run past
  // the count the user asked for.
  let overrun = "(none)";
  for (let n = 1; n <= opening.length; n++) {
    const text = generate(corpus, "words", n, makeRng("truncate"));
    const want = capitalised.split(" ").slice(0, n).join(" ") + ".";
    if (text !== want) { overrun = "n=" + n + ": " + text; break; }
  }
  check(corpus.id + " — a short count truncates the phrase", overrun, "(none)");

  // The phrase is what people recognise; a comma dropped inside it is not.
  let comma = "(none)";
  for (let seed = 0; seed < 60 && comma === "(none)"; seed++) {
    const text = generate(corpus, "sentences", 3, makeRng("comma-" + seed));
    if (text.indexOf(capitalised) !== 0) { comma = "seed " + seed + ": " + text.slice(0, 60); }
  }
  check(corpus.id + " — no comma lands inside the phrase", comma, "(none)");
}

// --- edge cases ------------------------------------------------------------

section("edge cases");
const any = CORPORA[0] || FIXTURE;
check("a count of 0 gives nothing", generate(any, "words", 0, makeRng(1)), "");
check("a negative count gives nothing", generate(any, "words", -5, makeRng(1)), "");
check("a fractional count floors", countWords(generate(any, "words", 2.7, makeRng(1))), 2);
check("a numeric string counts", countWords(generate(any, "words", "4", makeRng(1))), 4);
check("a non-numeric count gives nothing", generate(any, "words", "many", makeRng(1)), "");
check("an undefined count gives nothing", generate(any, "words", undefined, makeRng(1)), "");
check("a null count gives nothing", generate(any, "words", null, makeRng(1)), "");
check("an infinite count gives nothing", generate(any, "words", Infinity, makeRng(1)), "");
check("NaN gives nothing", generate(any, "words", NaN, makeRng(1)), "");
check("zero sentences and zero paragraphs too",
  generate(any, "sentences", 0, makeRng(1)) + generate(any, "paragraphs", 0, makeRng(1)), "");

throwsWith("an unknown unit throws, naming it", () => generate(any, "lines", 3, makeRng(1)), 'unknown unit "lines"');
throwsWith("an empty unit throws", () => generate(any, "", 3, makeRng(1)), "unknown unit");
throwsWith("an undefined unit throws", () => generate(any, undefined, 3, makeRng(1)), "unknown unit");
throwsWith("a wordless corpus throws, naming its id",
  () => generate({ id: "hollow", words: [] }, "words", 3, makeRng(1)), '"hollow"');
throwsWith("a corpus with no words key throws",
  () => generate({ id: "keyless" }, "words", 3, makeRng(1)), '"keyless"');
throwsWith("no corpus at all throws rather than returning junk",
  () => generate(null, "words", 3, makeRng(1)), "(unknown)");
// The unit is checked before the corpus, so a caller passing both wrong hears
// about the one it can fix.
throwsWith("a bad unit is reported before a bad corpus",
  () => generate(null, "lines", 3, makeRng(1)), "unknown unit");

// generate() defaults to Math.random when no rng is given — the widget relies
// on it for the un-seeded first draw.
check("generate works without an rng", countWords(generate(any, "words", 9)), 9);

check("UNITS is exactly the three the manifest offers", UNITS.join(","), "words,sentences,paragraphs");

section("countWords");
check("empty text counts nothing", countWords(""), 0);
check("whitespace counts nothing", countWords("   \n  "), 0);
check("undefined counts nothing", countWords(undefined), 0);
check("null counts nothing", countWords(null), 0);
check("runs of whitespace count once", countWords("  one   two \n three  "), 3);
check("a paragraph break does not add a word", countWords("one two\n\nthree"), 3);
check("punctuation hangs off a word", countWords("sit amet, consectetur."), 3);
HARNESS_EOF

# Run it once and keep the output, so a crash in the harness is reported as a
# failure with its stderr rather than as a silently short run.
if ! node "$TMP/harness.js" "$ROOT" >"$TMP/report" 2>"$TMP/stderr"; then
  bad "the harness itself failed to run"
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
    *) [[ -z "$kind" ]] || bad "unreadable harness line: $kind" ;;
  esac
done <"$TMP/report"

echo
echo "$PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
