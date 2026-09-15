# Corpora

One JSON file per text variant. Adding a fourth variant means adding one file here and
changing nothing else — the widget discovers variants by reading this directory.

## Schema

```json
{
  "id": "classic",
  "name": "Classic",
  "blurb": "one short sentence for the variant picker",
  "attribution": "who wrote it / where it came from, and its licence status",
  "source": "https://…",
  "opening": ["lorem", "ipsum", "dolor", "sit", "amet"],
  "words": ["consectetur", "adipiscing", "elit", "…"]
}
```

| Field | Rule |
| --- | --- |
| `id` | Lowercase, and identical to the filename stem (`bacon.json` → `"bacon"`). |
| `name` | What the picker shows. One or two words, at most 32 characters, no `<` or `>`, one line. |
| `blurb` | One short sentence describing the variant, at most 160 characters, no `<` or `>`, one line. No trailing period needed. |
| `attribution` | Human-readable line naming the source and its licence status. Published to users — be accurate and conservative. |
| `source` | A URL a reader can check: the source text, or a page documenting the genre. |
| `opening` | Words emitted verbatim at the very start of generated text (the "lorem ipsum dolor sit amet" convention). Every entry matches `^[a-z]+$`, exactly as `words` does — these *are* words, and they reach the preview untouched. Use `[]` when the variant has no canonical opening. |
| `words` | Flat array, at least 120 unique words. Every entry must match `^[a-z]+$`: no capitals, no punctuation, no digits, no spaces, no multi-word strings, no empty strings. |

The generator does the typography. It capitalises sentence openings, inserts commas and
full stops, and groups words into sentences and paragraphs — so the pools stay plain
lowercase words and contain no formatting of their own.

## What the widget checks before it shows a variant

None of the above is on trust. `acceptCorpus()` in `BarWidget.qml` applies every
rule in the table when the file is read, and a file that breaks one is not
loaded at all: it goes into the red `Couldn't read …` line under the picker,
by name, and the other variants carry on. There is no partial acceptance and no
silent repair.

That is aimed at exactly one situation, and it is the situation this file
invites: a corpus you did not write, dropped into `corpora/` by someone else.
The strings in a corpus are drawn by the panel, by Omarchy's own dropdown, and
by a desktop notification, and Qt renders a string that looks like markup *as*
markup — an `<img src="http://…">` in a variant name or an opening phrase is a
request leaving your machine. Plain lowercase words and one plain line cannot
do that, in any of the three, whatever any one of them sets `textFormat` to.

The id rule carries its own weight: because the id is the identity the picker,
the settings and the de-duplication all key on, a file whose id does not match
its own filename could otherwise claim a shipped variant's name and take its
place in the list.

`tests/generator.sh` holds the six variants shipped here to the same rules, so
a corpus added to this repository fails the suite rather than the panel.

## Licensing rule

Word pools are bundled data, not fetched at runtime, and they ship with the plugin. So:

- **Author your own pool.** The subject vocabulary of a domain — meat, buzzwords, sailing —
  is not anyone's property, but a *curated list* on someone's site may be their
  copyrightable compilation. Write the words yourself; do not copy a list or generator
  output out of funnylorem.com, baconipsum.com or similar.
- **Only copy text that is provably free**, e.g. public domain by age (`classic.json` is
  Cicero, died 43 BC) or under a licence that permits redistribution. Name the licence in
  `attribution`.
- **Do not claim a licence that is not ours to claim.** If a source's status is unclear,
  leave it out.
