# Lens: terminology

Standard applied: THEORY.md's own rule that bold terms are the only jargon and everything else is ordinary English, plus its claim that where theory and code disagree, the code is wrong. Findings are ordered by severity. Locations are file:line at the time of the study.

## High

### 1. The conformance suite does not test calibration
- Location: THEORY.md:304; lib/s1/rspec.rb:1-81; README.md:986
- Problem: the theory says the suite tests "shapes and calibration"; the suite checks class, keys, [0,1] bounds, sum ≈ 1, collapse types, `supports?` and integer usage, and the README says "it checks the shape, not the wisdom".
- Fix: reword :304 to "it is what the conformance suite tests — shapes, never a vendor's keys. Calibration is asserted by the provider and can only be checked against held-out labels (ECE / reliability), which no shape test can do." Calibration stays an axiom; stop claiming a test for it.

### 2. Two ordinal collapse rules under one word
- Location: THEORY.md:94; typesafe-rails/lib/s1/measurable/declarations.rb:350-364, :968; writing.rb:104
- Problem: **collapse** is defined as one rule per scale kind (ordinal: the most likely category), but a float/decimal score column stores the expected rank and `s1_collapsed` reads back the *nearest level* to it; on {low 0.45, mid 0.10, high 0.45} the collapse is "low" and the column yields "mid". `after:` already refuses such columns without an audit row, so the code knows the column cannot yield the collapse.
- Fix: either define a second bold term ("**nearest level** — the ordinal category read back from a stored expectation; not the collapse") or delete the nearest-level path and make `s1_collapsed` on a numeric score column require the audit row, as `after:` does. Two different Bayes actions (MAP vs. minimum squared rank error) must not share a word.

### 3. "Criteria" names the opposite thing in the adopter's domain
- Location: THEORY.md:143-151, :225, :243-254; README.md:136; lib/s1/state.rb:129; lib/s1/question.rb:11-14; mvp/app/models/law_firm_preferences.rb:93-99
- Problem: in the primary adopter, "criteria" means the firm's acceptance standard, which the theory classifies as a **lens**; the README's own example ("a firm's acceptance criteria … `given:`") confirms it. Inside the gem "criteria" is also the wire key for three differently-shaped values, and the judge kwarg for the same idea is `clarification`.
- Fix: rename the bold term to **definitions** (what counts as yes / what each category means / the ordered levels) and demote `criteria` to a wire-only name per the theory's rule at :225. Add the adjacent-category anchor to "The two adjustments": "a firm's acceptance criteria is a lens, never definitions." Keep `criteria:` accepted on the wire; no API break.

## Medium

### 4. "Level" in two senses in one passage
- Location: THEORY.md:129 vs :179-181
- Problem: :129 uses "levels of measurement" (Stevens' scale types) while :179 defines **level** as a point on one ordinal scale; Stevens' own title is "scales of measurement".
- Fix: :129 → "the first three of Stevens' scale types". Keep **level** for the point; the log-level collision is harmless (`S1::Level` is namespaced).

### 5. **Form** collides with HTML/GUI forms and duplicates **rendering**
- Location: THEORY.md:193-197; typesafe-rails/lib/s1/measurable.rb:86-99; measurable/state.rb:37; audit.rb:31; README.md:953; mvp/config/initializers/s1.rb
- Problem: the theory defines a form as "a named rendering", so it adds no concept; in Rails "form" means an HTML form, the same README describes cua-s1-forms as a "GUI forms" scorer, and the adopter's initializer already reads "form" as a noun of its own.
- Fix: fold **form** into **rendering** ("a rendering declared under a name via `measurable_as(:name)`"); keep `measurable_as`/`as:`; rename the request option `form:` → `rendering:`; the persisted audit key may stay "form" as a wire/legacy name.

### 6. "Measure" and "measurement" are used but never defined
- Location: THEORY.md:191, :263; "measurement" at :177, :197, :234, :283, :290, :293; typesafe-rails/lib/s1/measurable.rb:154
- Problem: "measure" appears as a noun for the distribution (:263 "once each element is a measure"), "measurement" appears twelve times and as a public method (`record.measurement(:col)`), and neither is a bold term; three words name one object.
- Fix: add **measurement** to the dictionary: "a distribution as taken — with the threshold, scale and question digest it was taken under; what `measurement(:col)` rebuilds". Replace noun "measure" at :191 and :263 with "measurement".

### 7. "Evidence" drifts between particular, facts, and lens
- Location: THEORY.md:28-31, :40, :50, :106, :215-216, :253; lib/s1/state.rb:68
- Problem: **evidence** is defined as the particular before any presentation, yet :106 calls the lens "evidence added to the state" and :253 says the lens "changes the evidence"; the code aliases `evidence` to `facts`, and :50 invokes "posterior" beside a word that in Bayesian usage means the marginal likelihood.
- Fix: :253 → "if it changes what the question is applied to, it is the lens"; :106 → "material set beside the facts to judge against". Keep `facts` as the code word; the lens is part of the state, not of the evidence.

### 8. Rails registry stores the concept under `:question`
- Location: typesafe-rails/lib/s1/measurable/declarations.rb:246-248, :603; THEORY.md:116-125
- Problem: the theory's **question** is concept + scale + criteria and `S1::Question` is that object, but the registry key `:question` holds only the instruction String; the code's own comment ("the concept alone. s1_questions is the old name") names the mismatch and keeps it.
- Fix: rename the registry key `:question` → `:instructions` (matching `S1::Question#instructions`); keep `s1_questions` only as the existing alias of `s1_instructions`.

### 9. Confidence is not "distinct from the mass on the winning category"
- Location: THEORY.md:167; lib/s1/providers/cua.rb:22, :49
- Problem: the theory calls confidence the model's own estimate, distinct from the winning mass; for cua it is exactly the winning mass (`probabilities.max_by`), and for jev it is derived from the distribution's shape — never information beyond the distribution.
- Fix: :167 → "a provider-reported summary of the distribution's shape (jev: shape; cua: the winning mass) — a convenience, not independent information; a dichotomous judgement needs none because its shape is one number."

### 10. "Stage" is read as a pipeline phase
- Location: THEORY.md:231-232; mvp/config/initializers/s1.rb:11
- Problem: the theory's stage is an `after:` depth within one plan run, but the adopter already uses "stage" for routing/scoring pipeline steps (the ordinary Rails/ops sense), so the word carries the wrong picture on first contact.
- Fix: rename to **pass** ("the questions asked in one pass once the fields they come `after:` are collapsed; a plan is passes of batches"), and change `s1_plan` output "stage 1" → "pass 1". Minimum: append "not a pipeline phase" to the definition.

## Low

### 11. Expected rank silently assumes equally spaced levels
- Location: THEORY.md:137-139; lib/s1/answer.rb:96-114; typesafe-rails/lib/s1/measurable/writing.rb:104
- Problem: the expected position treats adjacent levels as one step apart — the statistic Stevens says an ordinal scale does not license — and the code sorts (`<=>`), compares and stores by it without the assumption being stated.
- Fix: state it where the number is introduced: "derived by treating adjacent levels as one step apart — an assumption the program makes, not the model". Optionally note median rank as the ordinal-licensed alternative.

### 12. Rails dictionary row conflates scale with scale kind
- Location: typesafe-rails/README.md:1110; declarations.rb:256; THEORY.md:56
- Problem: the **scale** row says `s1_kind` "names it by the wire name", but `s1_kind` returns the kind (noul/choice/score), which the theory distinguishes from the scale (the categories).
- Fix: → "the column type or the enum; `s1_kind` names its *kind* by the wire name".

## Cross-cutting note
Findings 3, 5, 6 and 10 are all the same failure: a bold term chosen from the gem's internals rather than from the reader's ordinary vocabulary, so the term either collides with an adjacent everyday sense (form, stage, criteria) or leaves a used word undefined (measurement). The fix pattern is the same each time: pick the ordinary-English word, define it once, and let the code's wire name stay as an alias.
