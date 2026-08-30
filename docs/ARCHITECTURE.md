# Why omaipsum is shaped like this

The reasoning behind the code. Every decision here is visible in the code and
none of the options it beat are, which is what this file is for: the discarded
alternative and the reason it lost.

[DEVELOPER.md](DEVELOPER.md) has the layout, the local loop and the tests.
[DEVOPS.md](DEVOPS.md) has the remotes, CI, releasing and what the install
scripts do to a machine. [../README.md](../README.md) is for people using
omaipsum rather than working on it.

## The shape, in one paragraph

omaipsum is a bar icon with a pulldown. `Ipsum.js` turns a word list into
prose and knows nothing else. `BarWidget.qml` is the icon, the panel, and
everything that reaches outside the process. `corpora/` holds one JSON file
per text variant. There is no backend, no config file of omaipsum's own, and
nothing the plugin writes to disk at all; the only two binaries it runs are
`wl-copy` and `omarchy-notification-send`.

## The generator is a pure library

`Ipsum.js` is a `.pragma library`: no QML types, no module-level state, no
I/O. Every function in it is a function of its arguments.

That buys one thing, and it is the whole reason. The same call from the widget
and from node produces the same string, so `tests/generator.sh` can strip the
`.pragma library` line, evaluate the rest under node, and exercise exactly the
functions the widget calls with exactly the arguments it passes. A generator
that imported a QML type or read a file could only be tested by starting a
shell, a bar and a display — which in practice means not being tested.

The separation runs the other way too. Presentation — the buttons, the
per-unit ceilings, the clipboard — lives in the QML above, and none of it
belongs in that file. The state a run of generation carries (the words still
owed from the opening phrase, the last word emitted) is passed between
functions rather than held at module scope, so two generations cannot
interfere and nothing survives a call.

**Counts are exact.** Three paragraphs means three, so each unit gets its own
shaping rule rather than one loop that stops when the text is roughly long
enough. Words mode is the awkward one: the total cannot move, so sentence
lengths are chosen around it, and no non-final sentence may leave a tail too
short to be a sentence.

**The PRNG is written out rather than imported.** Xorshift32 for the stream
and FNV-1a for the seed, both spelled in shifts and xors only — mulberry32
would need `Math.imul`, and FNV's multiply by 16777619 would exceed the 2^53 a
double holds exactly and silently lose the low bits. QML's JavaScript engine
is old, and a generator that produces different text on different engines is
not reproducible at all, which would cost the preview its promise of being
exactly the string that gets copied. Seeding discards three rounds because
FNV's low bits barely move between seeds that differ only in their last
character, and `classic-1` next to `classic-2` is exactly how seeds get
written.

**The typography is the generator's job, not the corpus's.** Capitals, commas
and paragraph breaks are all decided in `Ipsum.js`, which is what keeps a
corpus a flat list of lowercase words that a person can extend without knowing
how sentences get built. A comma is barred from landing inside a variant's
opening phrase: "Lorem ipsum dolor sit, amet" is no longer the line anyone
recognises. `toUpperCase` rather than `toLocaleUpperCase`, because the Turkish
dotless i would otherwise make one seed produce different text for different
users.

## Corpora are data, discovered at runtime

A variant is one JSON file in `corpora/` and nothing else. `BarWidget.qml`
scans that directory with a `FolderListModel` and reads each file with a
`FileView` rather than importing a list, so a fourth variant is a fourth file
and no edit anywhere else. That promise — one new file — is what the discovery
is for, and several other decisions on this page exist to protect it.

The pools are bundled rather than fetched. The sites under *Prior art* are
places to read for ideas once, not a runtime dependency: a text generator that
needs the network to produce text is a worse generator.

They are authored rather than copied. The subject vocabulary of a domain is
nobody's property, but a curated list on somebody's site may be their
compilation, and a marketplace listing is a place where a claim about
provenance is made to people who cannot check it. Only `classic` carries real
source text, and only because Cicero died in 43 BC. The rule and the schema
are in [../corpora/README.md](../corpora/README.md); each file carries its own
attribution line.

Order is pinned twice — the `FolderListModel` sorts the scan by filename, and
the parsed corpora are sorted again by display name — because directory order
is whatever the filesystem hands back, and a picker whose entries move between
runs is worse than a picker in an order nobody asked for. The reads finish in
whatever order they finish, so without that second sort the opening selection
would be whichever file the disk returned first.

## There is no `bin/` backend

omapass, the sibling plugin most of this repository was copied from, has one,
because everything that touches a secret has to happen in a single place
outside the long-lived shell process. omaipsum handles nothing sensitive, so a
backend here would be a process boundary with nothing to protect on either
side of it.

The only things that leave the process are `wl-copy` and
`omarchy-notification-send`, both a `Process` in `BarWidget.qml`. The text
goes down `wl-copy`'s stdin rather than in argv: a few thousand words is past
what `ARG_MAX` promises, and the blank lines between paragraphs do not survive
a command line intact. Closing stdin afterwards is not optional either — that
EOF is what makes `wl-copy` stop reading and fork.

Both processes hang off the widget root rather than off the panel content,
because copying closes the pulldown, and a `Process` living inside it would be
racing the surface it was started from.

## A bar widget with a pulldown, and no overlay

The model is Tiny Ipsum, under *Prior art*: filler text is wanted in the
middle of doing something else, so the whole interaction has to fit in one
surface reached from the bar rather than a widget plus a full-screen overlay.
Closing the panel on copy comes from the same place.

That is also why the bar icon has two jobs. Left click copies from the
configured settings and opens nothing — the notification is the whole
feedback, and it already says what was copied, which is enough to know it
worked and enough to notice the settings were not what you thought. Right
click opens the pulldown. Middle click does nothing, deliberately: copying and
opening both already have a button, so anything a middle click did would be a
guess at which one was meant.

The configured defaults are applied on every open rather than once. The widget
is opened, taken from and dismissed, so carrying the last session's unit into
the next one would make the configured default mean nothing after first use.
Each open also rolls a fresh seed, for the same reason a second left click
does: a tool that hands you the same paragraph twice has done nothing.

Left click needed one extra rule, because it copies with no panel involved.
The defaults were only ever applied when the panel opened, so a widget nobody
had opened yet was still sitting on the property initialisers — 40 words, not
the configured 3 paragraphs — and would have copied something the user never
chose. The defaults are therefore applied when the panel is closed and left
alone when it is open: with the panel up, what is on screen is the settings,
and resetting them underneath somebody would be its own bug.

## The variant setting is a string, not an enum

`unit` is an enum in `manifest.json` and `variant` is not, which looks
inconsistent until you ask what an enum costs. An enum renders as a dropdown
in the bar's settings UI, but its options are fixed in the manifest — so every
new corpus would mean editing two files, and `corpora/` exists precisely so
that adding a variant is adding one. The three units are a different case:
they are `Ipsum.UNITS`, and they change only when the generator does.

The price is a field that accepts an id naming nothing. That is treated as a
request rather than an instruction: an unknown id falls through to the first
variant rather than leaving the picker empty.

## `barWidget.defaults` are not the runtime defaults

`manifest.json` states a default variant, unit and count, and so does
`BarWidget.qml`. They are not two halves of one mechanism, and only one of
them applies.

The bar builds a widget's `settings` from its `shell.json` entry minus the
`id` — `entrySettings` in `plugins/bar/BarModel.js` — and merges no defaults
into it. So `barWidget.defaults` is metadata for the settings UI alone and
never reaches the widget, and the fallbacks passed to `setting()` in the QML
are the values that actually apply.

The two therefore have to be kept in step by hand, and nothing checks it.
`tests/smoke.sh` and the CI manifest job check that the manifest agrees with
itself and that `defaults.variant` names a corpus that exists; neither reads
the QML fallbacks. The comment above them in `BarWidget.qml` is the only
warning there is.

## A copy is reported at handover, not at exit

`wl-copy` does not exit when it succeeds. It takes the text, forks, and stays
alive owning the selection until something else claims it, so its exit was
never the outcome of the copy.

Reading it as one broke in the most ordinary use there is. The second copy
reuses the same `Process`, which tears the previous run down, and that death
arrives as the new copy's non-zero exit — so every other copy raised a
critical "Nothing was copied" for text that was already on the clipboard.

Success now belongs to `onStarted`, where the handover actually happens, and
an exit after the handover is ignored. The trade is stated where it is made: a
genuine failure after a successful handover goes unreported. It is rare, and
indistinguishable from a supersede, while the false alarm fired constantly and
taught the user to stop believing the toast.

The two failures that stay reported are the ones that cannot be confused with
a supersede: a run that never starts, which is a missing `wl-copy`, and a
non-zero exit arriving before the text was handed over. Neither may be silent.
The failure mode this is all guarding against is the user pasting whatever was
on the clipboard before and finding out much later.

Where the message goes depends on where the user is looking. A missing
`wl-copy` leaves the panel open — the close lives in `onStarted`, so it cannot
have fired — and lights a line above the Copy button; the same failure after a
bar left click has no panel to write to and becomes a toast instead.

Detecting a missing binary at all needed a probe of the real Quickshell rather
than a guess: when the binary is not on `PATH`, *neither* `started` nor
`exited` ever fires, and the only observable is `running` settling back to
false. So both the startup check and the copy path start pessimistic and let
an exit talk them out of it, rather than waiting for an error that never
arrives.

## The bar icon is an outline glyph

`nf-md-alpha_l_box_outline` (U+F0C0C): an L in a square frame. The first icon
was Omarchy's own document glyph, so the widget wore a borrowed face and said
"document" rather than "lorem ipsum".

Outline rather than the filled `nf-md-alpha_l_box`, for a reason that only
shows up on a real bar. A bar running transparent paints no background of its
own — `plugins/bar/Bar.qml` fills with `"transparent"` in that mode — so in a
filled tile the L is a counter with no ink in it, and the letter becomes
whatever wallpaper happens to sit behind it. The outline's L is ink in every
theme and over any background.

The two obvious alternatives lost for reasons worth keeping. A bare
`nf-md-alpha_l`, like a plain "L", draws thin and goes weightless at bar size
beside the lock and the robot next to it. U+2112, the script capital L and the
prettiest candidate, is not in the font the bar actually resolves: `fc-match
monospace` gives JetBrainsMono Nerd Font, `fc-list :charset=f0c0c` lists it,
and `fc-list :charset=2112` does not — so it would have arrived from a
fallback serif at the wrong weight, or as nothing at all. A missing glyph is
the failure mode a bar widget gives you no warning about.

The copy notification carries the same glyph. Two different icons for one
plugin is how a toast stops looking like it came from the thing you clicked.

## Typed counts apply the unit before the count

The pulldown takes counts the way vim does: `4w` is four words, `2s` two
sentences, `3p` three paragraphs, and a bare `w` is words at whatever count is
already set. The digits are a prefix to the unit key, so the grammar adds one
idea rather than a second way to do everything.

The ordering inside that is the whole trick. `maxCount` is a function of the
unit, so `40p` typed while the unit is still words would be clamped by the
words ceiling and then clamped again by `setUnit` against the paragraph one —
wrong twice, and silently. Unit first, count second, clamped once, against the
ceiling the user just asked for.

Three digits, then the ceiling the unit already has. 500 is the largest
reachable count and needs exactly three, so a fourth digit is a typo — dropped
rather than shifted in, because `1000` quietly becoming `000` is the kind of
thing you only notice after pasting. Typed counts obey `maxCount` like every
other route to the count; a second limit that applied only to typing would be
a rule nobody could predict from the UI.

A pending count loses to an `h`/`l` nudge. The buffer is cleared at the top of
`setCount()`, the choke point every other route to the count passes through,
and all of those routes are answers to the question the buffer is still
asking; a stale `4` overriding a number the user just nudged, one keystroke
later, is worse than retyping a digit.

The buffer is on screen in the hint line, in the accent colour. Invisible
modal state is the thing people dislike about modal editors, and a `12`
sitting there has to explain why the next keystroke did something surprising.
It went in the hint line rather than beside the unit chips because a live
screenshot showed three digits clipped by the panel's right edge there.

The per-unit ceilings are three numbers rather than one because the units are
not one size: 500 words is about a page, and at ten words a sentence and four
or five sentences a paragraph, 100 sentences and 40 paragraphs both land near
the same amount of text. All three are already past what anyone pastes as
placeholder.

## A binding into a control the user can drive will not survive

This is the most transferable thing in the repository, so it is stated as a
rule rather than as two bugs: **a `value:` binding into a component the user
can also drive is a binding that will be gone by the second interaction.**

Two components of the Omarchy shell's own kit do it, which is what makes it a
rule rather than a quirk. `NumberField`'s SpinBox stops honouring
`value: root.value` the first time the user types in the field.
`Dropdown.selectCurrent()` assigns `root.value` directly, and assigning to a
bound property destroys the binding permanently — so `value: root.variantId`
survived exactly until the first time somebody picked a variant, after which
the trigger showed whatever was last clicked no matter what `variantId` said.
Picking a variant, closing the panel and reopening it left the label naming
one variant while the blurb, the preview and the copied text were all another.

The fix in both cases is the same: **push the value back rather than trust the
binding.** Anything that moves such a property behind the user's back has to
push it — in this widget that is `setCount()` for the count, and
`syncVariantPicker()` called from both `applyDefaults()` and the async corpus
load for the variant.

The unit row's `ButtonGroup` still takes a `value:` binding and has not been
seen to lose it. That is where to look first if the unit ever labels something
the panel is not generating. It has a separate trap of its own: it carries two
focus models, and the Tab one has to be switched off inside a panel that
drives its own cursor, or the two fight.

## The version lives only in `manifest.json`

Omarchy requires it there and `scripts/release.sh` writes it there, so any
second copy is a copy a release leaves behind. That is why the version at the
foot of the pulldown is read out of `manifest.json` at runtime with a
`FileView`, exactly as the corpora are, rather than written into the QML.

The same rule shapes the release script: it rewrites that one field with `sed`
instead of re-serialising the JSON, so the change is one line of diff rather
than a reformatted manifest.

## GitHub is origin, Gitea is a backup

`origin` is `git@github.com:cschaba/omaipsum.git`, public, and holds the code,
the issues, the releases and CI. `gitea`, at
`ssh://gitea@gitea.s10r.de:2811/carsten/omaipsum.git`, is private and is a
backup of the code: pushed to, never worked in.

The project started the other way round, so the reason for the swap is written
down here rather than left in a commit nobody re-reads. The Gitea instance has
no Actions runner. A workflow committed there could never run, and CI that
cannot run is not CI — it is a file that looks like a promise. GitHub has
runners; it was also already the address `manifest.json` gave as its homepage
and the one the README told people to clone, because a private instance is no
use to somebody installing a plugin; and the marketplace lists **a repository,
not a release**, so a reviewer and then anyone running `omarchy plugin add`
follows the listing straight to a repository. The code had to be where those
three things already pointed.

The issues followed the code rather than staying behind. Leaving them would
have left every `Fixes #N` in the history rendering as a dead link on the
public repository — nineteen commits pointing at nothing, on the repository a
marketplace listing sends people to.

It was safe for one specific reason, and the reason is worth recording,
because fear of it not holding is what kept the split alive for as long as it
lasted. Renumbering would have repointed every `Fixes #N` — but GitHub had
zero issues and zero pull requests, and the two share one numbering space, so
a fresh tracker numbers from 1, and Gitea's issues were a contiguous 1 to 19.
Recreating them in order therefore reproduced every original number, checked
one at a time with an abort on the first mismatch, because one wrong number
would have silently repointed every reference after it. Creation dates cannot
be set through the API, so each body carries a footer recording the original
date rather than silently claiming today's.

Nothing mirrors issues. Gitea push-mirrors code and has no equivalent for a
tracker, so its copy is frozen history rather than a second live tracker, and
filing anywhere but GitHub would mean two trackers drifting apart.

## Prior art

Where the ideas came from, kept here because [../README.md](../README.md) is
for people using omaipsum. **None of these is where any bundled text came
from.** [../corpora/README.md](../corpora/README.md) is explicit that a word
pool is written from scratch rather than copied out of somebody's generator or
off their curated list, and the three shipped variants were.

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
it, and omaipsum is a bar icon with a pulldown for the same reason: filler
text is wanted in the middle of doing something else, so the whole interaction
has to fit in one surface reached from the bar. `BarWidget.qml` names it twice
— "the Tiny Ipsum shape" for that decision, and "the Tiny Ipsum behaviour" for
closing the panel on copy.
