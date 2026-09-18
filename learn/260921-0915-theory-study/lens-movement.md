# Lens: movement — verified findings

Movement: how a **distribution** travels from **evidence** through **collapse** to a **category**,
across providers (jev, Laya, cua-s1-forms) and across the Rails column store. Ordered by severity.
Every finding was reproduced by probe against the current code.

## 1. High — `&` is sold as an exact joint probability; calibration only licenses the marginals

**Location**: THEORY.md:155-156; README.md:401-403 and 675-677; lib/s1/answer.rb:53-58.

**Problem**: the theory says calibration licenses "`&` as joint probability", and the README says
jev's independence makes probability algebra on batched results "exact" — but jev's independence
is procedural (no answer is context for another) and fixes each marginal only, so the product
`p * q` is the joint only when the two propositions are unrelated given the state, which is false
for the README's own example (`is_lead`, `qualified`, `prior_rep` are strongly related on any
one call; probe C4: `0.7 & 0.7 = 0.49` regardless of overlap).

**Fix**: reword THEORY.md:155-156 to "sums as expected counts, thresholds as decision rules,
collapsing late at all. `&` and `|` are exact only for questions that are unrelated given the
state — the batch guarantees that one answer is not context for another, not that the world
keeps them apart; for overlapping questions ask the conjunction as one question." Mirror the
same sentence at README.md:401-403 and 675-677, and drop the "exact" claim and the `=> 0.84`
worked example (or relabel it as an upper bound with a threshold that reflects that).

## 2. Medium — the theory says `confident?` and `undecided?` read entropy; neither does

**Location**: THEORY.md:53-54; lib/s1/distribution.rb:32; lib/s1/answer.rb:51.

**Problem**: `confident?(at)` reads the provider's scalar (`confidence.nil? || confidence >= at`)
and `undecided?` reads distance from the **threshold**, so a maximally undecided distribution can
be "confident" (probe P1: `{a: 0.5, b: 0.5}` with confidence 0.95 passes `confident?(0.9)`; a
sharply peaked one with `confidence: nil` also passes).

**Fix**: delete the entropy clause, or make it true: "a thing with *entropy* (information theory —
how undecided it is; the gem reads it only for a **noul**, as distance from the **threshold**
(`undecided?`); `confident?(at)` on a choose or score reads the provider's **confidence**, not the
shape)."

## 3. Medium — cua and Stub report a decorated confidence the theory says confidence is not

**Location**: lib/s1/providers/cua.rb:49-50; lib/s1/providers/stub.rb:43; THEORY.md:166-168.

**Problem**: the **Confidence** entry says it is "distinct from the mass on the winning category",
yet cua returns exactly that mass as `confidence` (probe C1: equal to the winning mass), and Stub
returns a constant 1.0; by the theory's own rule ("where they disagree, the code is wrong") both
are wrong.

**Fix**: either add to the Confidence entry "a provider with no separate estimate reports none
(nil), never a copy of the winning mass" and change cua.rb:49-50 and stub.rb:43 to pass
`confidence: nil`; or, since jev itself derives confidence from the distribution's shape, rewrite
the entry as "a scalar the provider derives from the distribution's shape, kept because the
derivation differs per provider" — and then cua's choice is one such derivation and is allowed.
Pick one; the current wording forbids what two of three providers do.

## 4. Medium — the Rails gem has a second ordinal collapse rule the theory does not name

**Location**: typesafe-rails/lib/s1/measurable/declarations.rb:350-367 and staging.rb:246;
typesafe-rails/README.md:416-419; against THEORY.md:94 and 286-288.

**Problem**: THEORY.md:94 gives one rule for ordinal — the most likely **category** — but
`s1_level_of` on a float column rounds the stored expectation to the nearest level, which can
name a level with zero mass, so one stored measurement collapses two ways depending on whether
the `s1_answers` audit row exists (probe R1-R4: mass `{0: 0.45, 1: 0.0, 2: 0.55}`, expectation
1.1 → audit says "blocking"; with `s1_answers: {}` the **lens** reads "degraded", mass 0.0).

**Fix**: either delete the nearest-level branch of `s1_level_of` and raise at boot as
`s1_verify_predecessor_readable!` already does — a float score column without its audit row has
"not been measured"; or add to THEORY.md **Collapse**: "a float column keeps a score's
expectation, which is no category; reading a category back from it is a third rule, the nearest
level, and it is the one rule that can name a level with no mass — prefer rehydration."

## 5. Medium — "a float keeps the mass" is true for a noul only; the column table mixes three projections

**Location**: THEORY.md:277-279; typesafe-rails/lib/s1/measurable/writing.rb:95 and 109;
typesafe-rails/README.md:816-820.

**Problem**: for a **noul** a float column keeps the whole distribution (one number, lossless),
but for a score it keeps the expectation, which is neither a mass nor a point on the scale
(probe R1: column holds 1.1 for a three-label scale); the README table titled "The column type is
the collapse rule" lists "expectation", which is not a **collapse** by the theory's definition.

**Fix**: reword THEORY.md:277-279 to "the column type says what the row keeps: a boolean column
collapses a judge at the **threshold**; a float column keeps a judge's whole distribution (its
one number) or a score's expectation (a summary that is not on the scale); an enum or string
keeps the **category**; an integer keeps the level's index." Reserve "collapse" for the rows
that yield a category, and rename the README table "What the column keeps".

## 6. Low — "Evidence" names the un-rendered thing in the dictionary and the rendered thing in the code

**Location**: THEORY.md:28-31 and 83; lib/s1/state.rb:66; THEORY.md:216.

**Problem**: the dictionary defines **Evidence** as "the particular … before any presentation",
but the formula `P(category | state, question)` conditions on the **state**, and `State#evidence`
is an alias for `facts` — the rendered thing — so the word sits at two positions.

**Fix**: retire the `evidence` alias on `State` (it names the wrong position), or add to the
Evidence entry: "in the statistical sense the evidence a judgement conditions on is the state;
this entry names the thing before rendering."
