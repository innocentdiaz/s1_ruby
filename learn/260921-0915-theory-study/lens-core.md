# Lens: core — THEORY.md against `s1` (typesafe-ruby)

Verified by probe against lib/ on 2026-09-21. Ordered by severity. Each entry: location, problem, fix.

## High

1. **confident? means two opposite things** — lib/s1/answer.rb:40 vs lib/s1/distribution.rb:31; THEORY.md:170-171
   Problem: the dictionary says `confident?(at)` is true when the provider reports no confidence, but a noul's `confident?` takes a margin from the threshold and is false in exactly those cases (noul p=0.9: `confident?(0.8)` false, `confident?(0.3)` true; choice conf=1.0: `confident?(0.8)` true).
   Fix: split the Code line — "nominal/ordinal: `confident?(at)` is confidence >= at, true when confidence is nil; dichotomous: `confident?(margin)` is `!undecided?(margin)`, at least margin from the threshold" — or rename the noul form (`decided?(margin)`) so one name does not carry two directions.

2. **`&` as joint probability is only exact under independence** — THEORY.md:156, THEORY.md:84; lib/s1/answer.rb:53-58
   Problem: the code multiplies unconditionally and its comment says "the model guarantees it", conflating the provider scoring each question without seeing the others with statistical independence of the events (two near-synonymous properties at 0.9 each give `&` = 0.81, `|` = 0.99; the true joint is about 0.9).
   Fix: THEORY.md:156 — "`&` and `|` as the product / complement-product — exact when the two properties are independent given the state, a bound otherwise". THEORY.md:84 — "the answers are computed independently (no question sees another's answer); this is not statistical independence of what they measure." Fix the answer.rb:53 comment to match.

3. **A record is silently measured as a choice over its field names** — lib/s1/state.rb:173,227-233; THEORY.md:148-151
   Problem: `categories_shaped?` treats any Hash with two or more String/nil values as candidates, so `{ ticket: 'Refund my order', customer: 'Ann Lee' }.choose('Which team?')` asks the model to pick between "ticket" and "customer"; without the inference the same call raises "choice needs at least 2 options (got 0)" — a loud error becomes a silent wrong question.
   Fix: narrow the inference to Arrays of Strings and Hashes with String keys whose values are all nil or all Strings (records render with Symbol keys), or state the rule in the dictionary exactly as coded.

4. **cua reports the winning mass as confidence** — lib/s1/providers/cua.rb:49; THEORY.md:167-168
   Problem: confidence is defined as "distinct from the mass on the winning category", but cua.rb:49 passes `probabilities.max_by { |_, p| p }` as the confidence, and the stub does the same in spirit; no shipped provider reports a scalar that is the model's own estimate separate from the distribution (jev derives it from the distribution's shape).
   Fix: THEORY.md:167 — "a scalar the provider reports for a nominal or ordinal judgement; jev derives it from the distribution's shape; a provider with no such scalar reports nil, never a proxy such as the winning mass". Then cua.rb:49 passes `confidence: nil`.

## Medium

5. **A default-threshold noul does not carry its threshold** — lib/s1/answer.rb:26, lib/s1/client.rb:28, lib/s1/result.rb:87; THEORY.md:177
   Problem: `Client#measure` stores nil and `Noul#threshold` reads `S1.config.threshold` at collapse time, so measuring under 0.5 then setting config to 0.95 flips `collapse` from true to false.
   Fix: stamp `threshold || S1.config.threshold` at measure time, or reword THEORY.md:177 — "carries the threshold it was taken under when one was given; otherwise the config's, read at collapse".

6. **Level compares by rank only on the left** — lib/s1/level.rb:34-42; THEORY.md:181
   Problem: `lvl >= 'Degraded'` is true but `'Degraded' <= lvl` is false and `[lvl, 'Degraded'].max` returns the label; two Levels with the same text and different ranks are `==` but `<=>` 1.
   Fix: THEORY.md:181 — "compares by rank when it is the receiver (a label on the left compares as text); `==` is String equality on the label" — or define `Level#==` by rank when the other is a Level.

7. **ψ(x) and State.new(x) diverge on prepared evidence** — lib/s1.rb:57, lib/s1/state.rb:72-75, lib/s1/rendering.rb:31; THEORY.md:71
   Problem: `State.new(state, given: {z: 1})` nests the old state under a new `this` and drops its per-state options, while `S1.to_state` merges the lens and keeps them.
   Fix: THEORY.md:71 Code line — "ψ(x) = S1.to_state(x) (x.to_s1 when x answers it, else S1::State.new(x))"; or make `State.new` delegate to `to_state` when the evidence responds to `to_s1`.

8. **A Result placed in evidence renders as its inspect string** — lib/s1/result.rb:47, lib/s1/rendering.rb:30-35; THEORY.md:102, THEORY.md:213
   Problem: the theory names `to_h` as the rendering, `Result#to_h` is the collapse, and `Rendering.render(result)` yields `#<S1::Result:0x...>`; a noul in a lens renders as `'0.5'`, a score as `'0 "low"'`.
   Fix: render a Collapsable via its collapse (matching THEORY.md:286-288), or state "a measurement is not evidence and does not render; put its collapse or probabilities in the lens explicitly"; reword THEORY.md:102 so `to_h` is not named as the rendering.

9. **Nothing reads entropy** — THEORY.md:53-54; lib/s1/distribution.rb:31, lib/s1/answer.rb:40,51
   Problem: the theory says entropy is "what `confident?` and `undecided?` read off"; one reads the provider's confidence scalar, the other the distance of one mass from a threshold; no entropy is computed in lib.
   Fix: THEORY.md:54 — "a thing with entropy (information theory — how undecided it is; the code approximates this with the provider's confidence on nominal/ordinal scales and distance from the threshold on the dichotomous one)".

10. **"per-call threshold" depends on the door** — THEORY.md:177; lib/s1/state.rb:114,222; lib/s1/client.rb:13
    Problem: `threshold:` is refused on every State verb and on `State#measure` but accepted on `S1.measure` and on the `?` collapses.
    Fix: THEORY.md:177 — "config, per-state (`State.new(x, threshold:)`), or per-collapse (`judge?(threshold:)`, `collapse(t)`); a verb never takes one"; drop `threshold:` from `Client#measure` or list it as the plumbing exception.

11. **Questions#choice is a verb wearing a noun** — lib/s1/question.rb:131; THEORY.md:319-326
    Problem: `alias choice choose` makes the noun build a distribution-yielding question, against the rule that a noun names the collapsed thing; there is no `level` alias, so it is a leftover, not a pattern.
    Fix: delete the alias (keep `noul`, which is the wire and distribution name), or add the exception at THEORY.md:319.

12. **`as:` is reserved but undefined** — lib/s1/predicate.rb:35,66; THEORY.md:193-197
    Problem: `STATE_OPTIONS = %i[given as]` in core; State verbs refuse `as:`, Predicates strip it silently, `State.new('x', as: :short)` carries it to the Request; the Form entry names only `measurable_as`.
    Fix: add to the Form entry — "`as: :name` selects the form; on a Predicate it shapes the state, on a State it is an error until Rails is loaded" — or move `as` into the rails gem's Predicate extension.

13. **The conformance suite does not test calibration** — THEORY.md:304; lib/s1/rspec.rb:42-47
    Problem: the only probabilistic check is that masses sum to 1 within 0.02; no calibration check exists.
    Fix: THEORY.md:304 — "what the conformance suite tests: shapes, never a vendor's keys; calibration is the provider's promise and is not testable without labelled data".

14. **Four ordinal integers are undefined** — lib/s1/answer.rb:109-134, lib/s1/level.rb:19-28; THEORY.md:179-181, THEORY.md:278-279
    Problem: legend (key => label), index (legend key of the mode), position/rank (0-based order), expectation (mass-weighted rank) are never defined; the Rails section uses "index" for the legend key while `Level#to_i` is the rank; `Score#score` is an alias of `expectation`.
    Fix: add plumbing entries — "legend: a score's key => label map, keys as declared or 0..n-1; index: the legend key of the most likely level; rank: the level's 0-based order on the scale (`Level#position`, `Level#to_i`); expectation: the mass-weighted rank (`score` is its wire alias)".

## Low

15. **Seven bold terms have no dictionary entry** — THEORY.md:31,45,77,280,283,286,289
    Problem: measurable, categorical distribution over the scale, probabilistic classification, sibling column (entry is "siblings"), rehydration, sequenced field, dynamic scale are bold without entries.
    Fix: unbold the first three; add plumbing entries for rehydration, sequenced field and dynamic scale, or unbold them and point at the rails README.

16. **`options` names four things** — lib/s1/question.rb:39,84; lib/s1/answer.rb:80; lib/s1/result.rb:93; lib/s1/state.rb:62; lib/s1/predicate.rb:41
    Problem: a choice's categories, the Request's ride-along hash, a State's ride-along hash, and a Predicate's keyword bag all answer to `options`; THEORY.md:214 uses it only for the Request.
    Fix: delete the `options` aliases on `Question::Choice` and `Answer::Choice` (categories is the theory word; `choices:` covers the wire spelling).

17. **nil is not "any object"** — lib/s1/state.rb:70; THEORY.md:31
    Problem: `State.new(nil)` raises "state can't be nil" while nested nil renders fine.
    Fix: THEORY.md:31 — "any object but nil".

18. **Distributions do not support arithmetic** — THEORY.md:59; lib/s1/answer.rb:29-34,119-121
    Problem: `p1 + p2` is a NoMethodError; only a Numeric on the left works via `coerce` (`0.1 + p1`, `[p1, p2].sum`).
    Fix: THEORY.md:59 — "The object that reads as a number: comparison, ranges, `& | ~`, sums and sorts through Ruby's coercion (a Numeric on the left), expected values, ranking."

19. **`raw` is per-answer on a distribution, whole-body on the Result** — lib/s1/result.rb:15 vs lib/s1/distribution.rb:14; THEORY.md:219
    Problem: the definition says "for one distribution"; `Result#raw` is the whole response payload (system_one_http.rb:102,104).
    Fix: THEORY.md:219 — "raw: a provider's wire payload — on a distribution, that answer's; on the Result, the whole response".

20. **rendered is never JSON** — THEORY.md:38-39; lib/s1/rendering.rb:18-26
    Problem: `Rendering.render` returns a frozen String/Hash/Array; JSON appears only in `snapshot` and the HTTP provider.
    Fix: THEORY.md:38 — "a String, or a Hash/Array of plain values (what JSON can carry)".
