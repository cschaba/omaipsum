.pragma library

// The generator. No QML types, no state, no I/O — every function here is a
// function of its arguments, so the same call from a test and from the widget
// gives the same string. Presentation (buttons, counts, clipboard) lives in the
// QML above; nothing about it belongs in this file.
//
// A corpus is the plain object the files in corpora/ hold:
//
//   { id, name, blurb, attribution, source, opening: [...], words: [...] }
//
// `words` is flat, lowercase and unpunctuated, and `opening` is the phrase the
// variant is known by ("lorem ipsum dolor sit amet"). Corpora carry no capitals
// and no punctuation at all — deciding where the full stops and commas go is
// this file's job, which is what keeps a corpus a word list a person can extend
// without knowing anything about how sentences get built.

var UNITS = ["words", "sentences", "paragraphs"]

// The shape of the prose. Sentences vary between these bounds and paragraphs
// vary in how many sentences they hold, because output at a fixed length reads
// as a loop after about three lines.
var MIN_SENTENCE_WORDS = 5
var MAX_SENTENCE_WORDS = 15
var MIN_PARAGRAPH_SENTENCES = 3
var MAX_PARAGRAPH_SENTENCES = 6

// How often a sentence long enough to carry one gets a comma. Higher and the
// text reads as breathless; nought and every sentence has the same flat shape.
var COMMA_CHANCE = 0.35

// --- randomness -----------------------------------------------------------

// Seeds are whatever the caller has: a number from a counter, or a string like
// a corpus id. Both go through the same hash, so seeding with a word works as
// well as seeding with a number and 1 and "1" mean the same run.
//
// FNV-1a. The multiply is spelled out as shifts because 16777619 is
// 1 + 2^1 + 2^4 + 2^7 + 2^8 + 2^24: `hash * 16777619` would exceed the 2^53 a
// double holds exactly and silently lose the low bits, and Math.imul is too
// new to rely on in QML's JavaScript engine.
function hashSeed(seed) {
  var text = String(seed === undefined || seed === null ? "" : seed)
  var hash = 2166136261
  for (var i = 0; i < text.length; i++) {
    hash = (hash ^ text.charCodeAt(i)) >>> 0
    hash = (hash + ((hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24))) >>> 0
  }
  return hash >>> 0
}

// Xorshift32: shifts and xors only, so it behaves identically on every engine
// that has 32-bit bitwise operators — which is the whole point of writing one
// out instead of reaching for a dependency or for Math.random. Fine for prose;
// deliberately not fine for anything that needs to be unguessable.
function makeRng(seed) {
  var state = hashSeed(seed)
  if (state === 0) state = 0x9E3779B9   // zero is xorshift's one dead state

  function step() {
    state ^= state << 13
    state >>>= 0
    state ^= state >>> 17
    state ^= state << 5
    state >>>= 0
    return state / 4294967296
  }

  // FNV's low bits move very little between seeds that differ in their last
  // character, and "classic-1" next to "classic-2" is exactly how seeds get
  // written. A few discarded rounds spread that difference across the state,
  // so neighbouring seeds do not open with the same word.
  step(); step(); step()
  return step
}

// Inclusive on both ends. The clamp is for a caller-supplied rng that returns
// exactly 1.0 — ours never does, someone else's might, and an off-by-one there
// would show up as a rare out-of-bounds word.
function between(rng, min, max) {
  var value = min + Math.floor(rng() * (max - min + 1))
  if (value < min) return min
  if (value > max) return max
  return value
}

// --- corpus access --------------------------------------------------------

function corpusId(corpus) {
  return corpus && corpus.id ? String(corpus.id) : "(unknown)"
}

function corpusWords(corpus) {
  if (!corpus || !corpus.words || !corpus.words.length)
    throw new Error("omaipsum: corpus \"" + corpusId(corpus) + "\" has no words")
  return corpus.words
}

// `opening` is optional; a variant that has no signature phrase just omits it.
function openingWords(corpus) {
  if (!corpus || !corpus.opening || !corpus.opening.length) return []
  return corpus.opening.slice(0)
}

// The state a run of generation carries: the words still owed from the opening
// phrase, and the last word emitted. Passed around rather than held at module
// scope, so two generations can never interfere and nothing survives a call.
function newRun(corpus, rng) {
  return {
    words: corpusWords(corpus),
    rng: rng,
    pending: openingWords(corpus),   // opening words not yet placed
    taken: 0,                        // how many of them the last take used
    previous: ""
  }
}

// One word, never the same word twice in a row when there is any alternative —
// a repeat looks like a bug in the generator rather than like prose.
function nextWord(run) {
  var word = String(run.words[between(run.rng, 0, run.words.length - 1)])
  if (word === run.previous && run.words.length > 1)
    word = String(run.words[between(run.rng, 0, run.words.length - 1)])
  run.previous = word
  return word
}

// Takes the next `count` words, opening phrase first while any of it is left.
// `run.taken` records how many of them came from the opening, because those
// words have to be handed back to the reader untouched.
function takeWords(run, count) {
  var out = []
  while (out.length < count && run.pending.length > 0) {
    var word = String(run.pending.shift())
    run.previous = word
    out.push(word)
  }
  run.taken = out.length
  while (out.length < count) out.push(nextWord(run))
  return out
}

// --- shaping --------------------------------------------------------------

function capitalise(word) {
  // toUpperCase, not toLocaleUpperCase: the Turkish dotless i would make the
  // same seed produce different text depending on the user's locale.
  return word.charAt(0).toUpperCase() + word.substring(1)
}

// A comma somewhere in the middle, sometimes. Never after the first word and
// never inside the last two, where a clause break reads as a typo rather than
// as a pause. It hangs off a word, so it changes no word count anywhere.
//
// `protect` is the number of leading words that came from the opening phrase:
// "Lorem ipsum dolor sit, amet" is no longer the phrase people recognise, so
// the comma goes after it or nowhere.
function punctuate(words, rng, protect) {
  var out = words.slice(0)
  var first = Math.max(1, protect || 0)
  if (out.length >= 6 && first <= out.length - 3 && rng() < COMMA_CHANCE) {
    var at = between(rng, first, out.length - 3)
    out[at] = out[at] + ","
  }
  out[0] = capitalise(out[0])
  return out.join(" ") + "."
}

// One sentence of the given length. The opening phrase is consumed here so it
// lands verbatim at the very start of whatever is being generated, whichever
// unit that is.
function sentence(run, length) {
  var wanted = length
  // An opening longer than a sentence's upper bound would otherwise be cut in
  // half. Better a first sentence over the bound than a mangled signature line.
  if (run.pending.length > wanted) wanted = run.pending.length
  var words = takeWords(run, wanted)
  return punctuate(words, run.rng, run.taken)
}

function sentences(run, count) {
  var out = []
  for (var i = 0; i < count; i++)
    out.push(sentence(run, between(run.rng, MIN_SENTENCE_WORDS, MAX_SENTENCE_WORDS)))
  return out.join(" ")
}

// Words mode is the one where the count is not the count of the thing being
// shaped: the caller asked for N words and gets prose, so the sentence lengths
// have to be chosen around a total that cannot move. The rule that keeps that
// from producing a one-word final sentence is to never leave a tail shorter
// than a sentence's lower bound.
function prose(run, wordCount) {
  var words = takeWords(run, wordCount)
  var opening = run.taken
  var out = []
  var index = 0

  while (index < words.length) {
    var remaining = words.length - index
    var length = between(run.rng, MIN_SENTENCE_WORDS, MAX_SENTENCE_WORDS)

    if (remaining <= MAX_SENTENCE_WORDS) length = remaining
    else if (remaining - length < MIN_SENTENCE_WORDS) length = remaining - MIN_SENTENCE_WORDS

    out.push(punctuate(words.slice(index, index + length), run.rng, opening - index))
    index += length
  }

  return out.join(" ")
}

function paragraphs(run, count) {
  var out = []
  for (var i = 0; i < count; i++)
    out.push(sentences(run, between(run.rng, MIN_PARAGRAPH_SENTENCES, MAX_PARAGRAPH_SENTENCES)))
  return out.join("\n\n")
}

// --- public ---------------------------------------------------------------

// Counts what a person would count: whitespace-separated tokens. Punctuation
// hangs off a word rather than standing on its own, so "sit amet, consectetur"
// is three words here and three words in the generator that produced it.
function countWords(text) {
  var value = String(text === undefined || text === null ? "" : text).trim()
  if (!value) return 0
  return value.split(/\s+/).length
}

// The whole API the widget needs. `rng` is optional and defaults to
// Math.random; pass one from makeRng() and the output is reproducible.
//
// Counts are exact — three paragraphs means three — which is why each unit has
// its own shaping function rather than one generator that stops when it is
// roughly long enough.
function generate(corpus, unit, count, rng) {
  if (UNITS.indexOf(unit) === -1)
    throw new Error("omaipsum: unknown unit \"" + unit + "\" — expected one of " + UNITS.join(", "))

  var run = newRun(corpus, rng || Math.random)

  // A count arrives from a spinner or a config file, so it may be a string or
  // a fraction. Floor it, and treat anything that is not a number as nothing
  // asked for rather than as an error the widget would have to handle.
  var wanted = Math.floor(Number(count))
  if (!isFinite(wanted) || wanted <= 0) return ""

  if (unit === "words") return prose(run, wanted)
  if (unit === "sentences") return sentences(run, wanted)
  return paragraphs(run, wanted)
}
