# THEORY.md — study summary

Read against `s1` (lib, spec, README), `s1-rails` (lib, spec, README) and the three providers the theory must hold for (jev, Laya, cua-s1-forms). Six lens digests consolidated; every item below that names code was reproduced by probe on 2026-09-21. Forty-eight raised claims were refuted and are listed in `refuted.md`; nothing refuted appears here. Bold marks THEORY.md's own terms.

## 1. Verdict on the movement

**It holds.** evidence → **state** → **distribution** → **category**, by **prepare** / **measure** / **collapse**, is what the code does and where it draws its lines: `State.new` renders once and freezes; `Client#measure` sends `state.rendered` plus questions and gets back one `Distribution` per question; each distribution kind names its own collapse and the Rails column type picks the rule. Every attempt in the study to add a position (abstain, cost, provider, lens, render-vs-lens) or to move an arrow name was refuted by text the theory already contains.

**The strongest alternative formulation** is not a new position but a correction to what sits at the third one. The theory treats a batch's distributions as one probability object — enough that **calibration** is said to license "`&` as joint probability" (155-156) and the README calls the algebra "exact" (401-403, 675-677). What the code has, and what jev promises, is a *family of marginals over one state*: each question answered as if it were the only one. Procedural independence (no answer is context for another) fixes each marginal; it says nothing about whether the two properties co-occur in the world. `Noul#&` multiplies unconditionally (answer.rb:58; probe: `0.85 & 0.85 = 0.7225` for any overlap, and the README's own `is_lead & qualified` is a nested pair whose joint is the smaller marginal, not the product). Does the alternative win? Not as a diagram change: the diagram's unit is one question, and the Result is plumbing. It wins one sentence each in **Calibration**, **Measure** and README: the licence for `&` / `|` is conditional independence given the state, which the provider does not promise; the provider promises only that one answer is not context for another. Ask overlapping questions as one question.

**Diagram amendment** (one caption, no new position): under **distribution**, "over a scale" → "over a scale — one per question; a batch is several marginals over one state". This is a distinction the code already makes twice: `Result` is a Hash of independent `Distribution`s and is `Collapsable` only elementwise, and the Rails plan result (`merged`, staging.rb:303-311) glues distributions from *different states* into one Result where a later one was measured under an earlier one's collapse as a lens — so "independent" is false across stages by construction.

Two smaller things the movement's text gets wrong about its own third position: nothing in lib reads entropy (53-54 says `confident?` and `undecided?` do), and the Rails "collapse rule" table puts a non-collapse (a float column keeping a noul's whole distribution, or a score's expectation) under **collapse**. Both are wording, both are in §2.

## 2. Confirmed inconsistencies, ranked

Rule applied: where the theory's sentence is right and the code diverges, the fix is in code and is marked *[code]*; otherwise the rewording is given. Each: location — contradiction — rewording.

1. **THEORY.md:155-156 (and 84; README 401-403, 675-677; answer.rb:53-54)** — Calibration is said to license `&` as joint probability, but the product of two calibrated marginals is the joint only when the properties are independent given the state, which the provider never promises. → "sums as expected counts, thresholds as decision rules, collapsing late at all. `&` and `|` are the product and complement-product of marginals — exact when the two properties are independent given the state; the provider promises only that no answer is context for another. For overlapping properties, ask the conjunction as one question." Line 84: "the answers are computed independently (no answer is context for another); this is not statistical independence of what they measure." Same change in the README, and drop "exact" and the `=> 0.84` worked example from the comment in answer.rb.

2. **THEORY.md:304 (rspec.rb:13-81; README:986)** — "what the conformance suite tests — shapes and calibration"; the suite checks class, keys, [0,1], sum≈1, scale, collapse type, `supports?`, integer usage; README says "the shape, not the wisdom". → "it is what the conformance suite tests — shapes, never a vendor's keys. Calibration and batch independence are the two clauses no offline suite can test; they are the provider's warranty."

3. **THEORY.md:53-54 (distribution.rb:31, answer.rb:40, 51)** — "entropy … is what `confident?` and `undecided?` read off"; `confident?(at)` reads the provider's scalar (a 50/50 choice with confidence 0.95 passes `confident?(0.9)`; a 99/1 choice with nil confidence also passes) and `undecided?` reads distance from the threshold. → "a thing with *entropy* (information theory — how undecided it is; the gem does not compute it: `undecided?` reads distance from the **threshold**, `confident?` the provider's **confidence**)."

4. **THEORY.md:166-171 (answer.rb:40 vs distribution.rb:31)** — the Code line says `confident?(at)` is "true when the provider reports none"; on a noul `confident?(margin)` is `!undecided?` — noul 0.85: `confident?(0.8)` false, `confident?(0.3)` true — the positional is a margin, not a floor, and the two senses invert. → Code line: "on a nominal or ordinal distribution, a scalar beside it; `confident?(at)` is confidence ≥ at, true when the provider reports none — read `confidence` itself to escalate those. On a noul, `confident?(margin)` is the complement of `undecided?`: at least `margin` from the threshold, on either side."

5. **THEORY.md:167-168 (cua.rb:49; stub.rb:43, 49; jev's contract)** — confidence is "distinct from the mass on the winning category"; cua reports exactly that mass, the stub reports 1.0, and jev derives its confidence from the distribution's shape — no shipped provider reports information the masses do not carry. → "a scalar the provider reports beside a nominal or ordinal distribution, derived by the provider from the distribution's shape (jev), or the winning mass where it has nothing better (cua); kept because the derivation is the provider's, so routing does not re-derive one per provider. It carries nothing the masses do not."

6. **THEORY.md:277-279 (writing.rb:95-112; README 816-820) vs 63-64, 92, 296-297** — a float column is listed under "the collapse rule is the column type" as "keeps the mass"; for a noul the float is the whole distribution (no collapse happened), for a score it is the expectation (probe: masses .45/.10/.45 → column 1.0, a number naming no level). The **category** entry says nothing probabilistic survives a collapse. → "the column type says what the row keeps: a boolean column collapses a judge at the **threshold**; an enum or string keeps the **category**; an integer keeps the level's index; a float or decimal column is not a collapse — it keeps a judge's whole distribution (its one number) or a score's expectation (a summary that is not on the scale)." Rename the README table "What the column keeps".

7. **THEORY.md:94 (declarations.rb:350-367; staging.rb:246)** — ordinal collapse is "the most likely category", but `s1_level_of` on a float score column reads the level *nearest the stored expectation*: on .45/.10/.45 the collapse is "low", the column yields "mid" — a level with a tenth of the mass. `after:` already refuses such a column without its audit row, so the code knows the column cannot yield the collapse. → *[code]* delete the nearest-level branch; a float score column reads its category from the audit or raises "not measured". Failing that, name it: "**nearest level** — the category read back from a stored expectation; not the collapse, and the one rule that can name a level with no mass."

8. **THEORY.md:177 (answer.rb:26; client.rb:28; result.rb:87)** — "a measurement carries the threshold it was taken under" is false by default: `Client#measure` stamps nil and `Noul#threshold` reads config at collapse time (probe: measure at 0.5, set config to 0.95, `collapse` flips true → false). → *[code]* stamp `threshold || S1.config.threshold` in `Client#measure`. Otherwise: "carries the threshold it was taken under when one was given; otherwise the config's, read at collapse."

9. **THEORY.md:138-139 (system_one_http.rb:114; answer.rb:115)** — "a score's expected position is derived from the ordinal distribution, not measured", but the normalizer fetches the wire `score` (missing → ValidationError) and `Answer::Score` prefers it (probe: wire 0.0 with masses .05/.22/.73 → expectation 0.0; derived is 1.68). → *[code]* always derive; keep the wire `score` in `raw`. Otherwise: "the provider may send it; the gem derives it when absent and never checks the two agree."

10. **THEORY.md:148-151 (state.rb:173, 227-233)** — "a list of records is not candidates-shaped and takes `categories:`", but one record rendered as a Hash of Strings *is*: `{ ticket: "Refund my order", customer: "Ann Lee" }.choose("Which team?")` asks the model to pick between "ticket" and "customer" (probe: scale `[:ticket, :customer]`). Without the inference the same call raises "choice needs at least 2 options" — a loud error became a silent wrong question. → *[code]* narrow the inference to Arrays of Strings and Hashes with String keys; a Symbol-keyed Hash is a record. And state the rule in the entry exactly.

11. **THEORY.md:195-197 vs 286-288 (declarations.rb:74-77)** — "a measurement is not its own evidence" and the default form strips every measured column, yet a sequenced field re-enters an earlier column's collapse as a **lens** (which 106 calls evidence), and a column a block writes without a declaration stays in the default form (it strips `s1_registry.keys` only). → "less what is never the record's own evidence — the key, the timestamps, the audit, every declared column with its siblings. A measured column re-enters only by declaration, as the lens of a sequenced field (`after:`)." *[code]* strip every column the audit names, or refuse an undeclared write through the default form.

12. **THEORY.md:116-120, 305 (cua.rb:45-50)** — a question is "a concept on a scale" and cua is "an instance of the same arrow", but cua never sends `question.instructions`: options come from criteria, context from the state; "Which team should handle this?" and "…should NOT handle this?" get identical distributions. → *[code]* fold the instructions into the context string (a TASK line). Otherwise amend "Providers, in these terms": "cua reads the scale and the state only; the concept must be written into the state."

13. **THEORY.md:199-201 (base.rb:31; client.rb:22-26; errors.rb; rspec.rb:69-76)** — the provider entry has no room for a provider that answers one kind only, yet cua overrides `supports?`, `Client#measure` raises `UnsupportedError`, and the suite tests the refusal. → Provider, Code: "`call(Request) → Result` for the scale kinds it declares (`supports?`); a question of a kind it lacks is refused before the wire (`UnsupportedError`), never emulated."

14. **THEORY.md:83-84, 213 (staging.rb:303-311; measurable/result.rb)** — in Rails `measure` runs a plan: several calls over several states merged into one Result; "a batch of distributions from one measure" and "independent" do not hold across stages, and `&` on nouls from two stages computes as if independent though the later was asked given the earlier's collapse. → Plumbing: "**plan result** — the Results of a plan's batches merged into one, in the caller's order, usage summed, `raw` per call. Distributions from different stages are not independent."

15. **THEORY.md:141, 274 (declarations.rb:45, 871, 914)** — "the scale lives on the column"; for a choose or score on a string, integer or float column the scale is the declaration's categories or levels (the code raises without them); the column is only the collapse rule. → 141: "In Rails, `{ true, false }` on a boolean column, the enum's keys on an enum column, otherwise the categories or levels declared beside the column, or a method on the record when the scale is dynamic." 274: "the **scale** lives on the column when it is a boolean or an enum, and beside it otherwise".

16. **THEORY.md:286-290 (declarations.rb:296-301, 338-345)** — the earlier collapse "enters the later state as a lens" only; with a dynamic scale it is also evaluated on the record with that collapse in place, so it shapes the later question's scale. → append: "when the later field's scale is dynamic it is read with that collapse in place — the earlier verdict then shapes the later question's scale as well as its state."

17. **THEORY.md:239-241 (measurable/state.rb:84-91, 213-222)** — the gate "decides whether to ask", but a bare verb on a sequenced field and `s1_request` set `ungated` and ask regardless. → append: "read by a plan run — a trigger, `measure`, `update_measure`, `measure_all`; a single verb and `s1_request` ask regardless."

18. **THEORY.md:100 vs 69, 215-216** — rendering is "the function from evidence to state" at 100 and to facts (state minus lens) at 215; the code renders facts and lens separately. → "the function from evidence to facts — what is shown, in what shape. The state is the facts with the lens beside them; the lens is rendered by the same function."

19. **THEORY.md:244 vs 15** — "they attach to different positions"; the question is not a position. → "they attach to different things: criteria to the question, the lens to the state."

20. **THEORY.md:183-186 (predicate.rb:35-66)** — "a question not yet applied to a state", yet it carries `given:`, `as:` and a `threshold:` — things the theory attaches to the state and the collapse. → "a question, with the lens and collapse rule it will be applied under, not yet applied to a state; applying it prepares each element under that lens, then measures."

21. **THEORY.md:5-6 vs 31, 45, 77, 280, 283, 286, 289** — seven bold terms have no entry. → unbold *measurable*, *categorical distribution over the scale*, *probabilistic classification*; add plumbing lines for **rehydration**, **sequenced field**, **dynamic scale**; make **sibling** and "sibling column" one spelling.

22. **THEORY.md:279 (answer.rb:124; writing.rb:108; level.rb:28)** — "index" is three numbers: the theory's and the DSL's declared stored integer, core `Score#index` (the provider's legend key), and the rank (`Level#position`, `to_i`). Probe: legend {5,6,7}, `indexes: {10,20,30}` → `Score#index` 6, `position` 1, column 20. → define **index** (the integer an integer column stores: declared, else the rank) and **position** (the rank on the scale); *[code]* rename `Score#index` to `key`.

23. **THEORY.md:129 vs 179** — "levels of measurement" beside **level** as a point. → "the first three of Stevens' scale types".

24. **THEORY.md:75-76 vs 88, 310 (predicate.rb:43)** — *measure* restricted to "several questions" then used as the generic act; `Predicate#measure` is one question. → "or generically (*measure*: the arrow's name; on a state, the batch form)."

25. **THEORY.md:319-326 (question.rb:131)** — `Questions#choice` is an alias of `choose` (no `level` twin), so the batch builder's noun builds a distribution-yielding question. → *[code]* delete the alias; keep `noul` (the distribution's name).

26. **THEORY.md:71 (s1.rb:57; state.rb:72-75; rendering.rb:31)** — ψ(x) is `S1.to_state(x)`, not `State.new(x)`: on evidence that already prepares itself `State.new(state, given:)` nests the old state under `this` and drops its options; `to_state` merges. → "`ψ(x)` = `S1.to_state(x)` (`x.to_s1` when it answers, else `S1::State.new(x)`)".

27. **THEORY.md:102, 213 (result.rb:47; rendering.rb:30-35)** — `to_h` is named as the rendering; `Result#to_h` is the collapse, and a Result placed in evidence renders as its inspect string (probe: `#<S1::Result:0x…>`). → drop `to_h` from the rendering entry; add "a measurement is not evidence and does not render — put its collapse or its probabilities in the lens explicitly." *[code]* render a Collapsable by its collapse, or raise.

28. **THEORY.md:94-95 vs 323-326** — collapse spellings omit the nouns *choice* and *level* and `Result#to_h`. → "Spelled `?`, `collapse`, `!!`, `case … in`, `to_h` on a batch, and the nouns *choice* and *level*."

Trivia, one line each: 120 wire form is `{ type, instructions, criteria }`; 31 "any object but nil" (`State.new(nil)` raises); 59 "arithmetic" → "reads as a number through Ruby's coercion (a Numeric on the left; `p1 + p2` is not defined)"; 181 "compares by rank when it is the receiver; `==` is String equality on the label"; 219 `raw` is per answer on a distribution and the whole payload on a Result; 235 `stale` → `stale?` on a record, `Model.stale(:col)` the relation; 38 "Text or JSON" → "a String, or a Hash/Array of plain values"; 280-282 a score's `_probabilities` sibling is keyed by label, the audit's by rank — say so; 264 "a verb yields one distribution per element" also names `Score#score` as a Float (legacy alias of `expectation`).

## 3. Gaps — concepts the code has that the theory does not name

Proposed one-line entries (Plumbing unless noted), or the reason it is plumbing without one.

- **measurement** — the product of one measure as taken: the distribution with the question, scale, threshold and confidence it was taken under; what a row stores and `measurement(:col)` rebuilds. (Used twelve times and as a public method; the noun "measure" at 155/191/263 should become this.)
- **audit** — the `s1_answers` JSON column: every measurement as taken (digest, scale, threshold, confidence, probabilities), the source rehydration reads; a `_probabilities` sibling is a per-field copy of one part of it.
- **plan result** — see §2 item 14.
- **expectation** — a score's mass-weighted rank, treating adjacent levels as one step apart (the program's assumption, not the model's); `score` is its legacy alias; what a float column keeps.
- **index** / **position** — see §2 item 22.
- **legend** — stays ordinary English (refuted); but say once that on the wire it is the provider's key → label map and `Score#legend` is that map.
- **supports?** / `UnsupportedError` — belong in the **Provider** entry (§2 item 13).
- **rehydration**, **sequenced field**, **dynamic scale** — already bold; need the entries (§2 21).
- **nearest level** — only if the code path survives (§2 item 7).
- *provisional assignment* — the mid-plan write of an earlier collapse onto the record so a later stage can read it, taken back after; belongs inside the **stage** entry: "inside `measure` the collapses are put on the record for the later stages and taken back."
- *predecessor* — code and README's word for "the fields it comes `after:`"; plumbing, but pick one phrase and use it in both.
- *ungated* — belongs inside the **gate** entry (§2 item 17).
- `as:` — selects a **form**; reserved in core (`STATE_OPTIONS`), refused on a State until Rails loads. One clause in the **Form** entry.
- *transport* — model choice, timeouts, retries, error classes (transient / permanent), settings, hooks, logger, cache. Plumbing; one line: "a provider's own. Calibration is per model, so `model:` is the one transport choice that reaches the theory."
- `on_result` hooks, `owner`, `telemetry` — plumbing already; fine.
- Output tokens on a non-generative model (README example shows 86) — say what they count, or show 0.

## 4. Terminology

Current → proposed; the confusion removed; the cost.

- **criteria** → **definition** (the theory's own gloss at 144: "the working definition of the scale"). Removes: in the primary adopter "criteria" is the firm's acceptance standard, which the theory classifies as a **lens** (README's own example says so), so the bold word points at the wrong adjustment on first contact; it is also the wire key for three differently-shaped values. Costs: prose only — `criteria:` stays as the code and wire spelling, per 225-226. If kept, add the anchor: "a firm's acceptance criteria is a lens, never criteria."
- *measure* (noun), *measurement* → **measurement**, defined. Removes a third and fourth name for the distribution-as-taken. Costs nothing.
- **confidence** entry → keep the word; document the noul's margin sense (§2 item 4). Optional code: alias `decided?(margin)` on a noul so the two senses can be spelled apart. Cost: one alias.
- `State#evidence` → deprecate. It returns the facts (rendered), which the **Evidence** entry says evidence is not. Cost: an alias marked pre-theory.
- `Score#index` → `key` (§2 item 22). Removes the three-way "index". Cost: API rename in core and one call in rails writing; keep `index` as a deprecated alias.
- `Questions#choice` → delete (§2 item 25). Cost: none found in specs or adopter.
- **form** → keep. The collision with HTML forms is real, but the term is short, `measurable_as` is settled and the audit key is persisted; folding it into **rendering** would cost an API rename for a small gain. Add "not an HTML form" to the entry.
- **stage** → keep. The adopter uses "stage" for pipeline steps, but the candidate "pass" collides with the theory's own "one pass" for the model's forward pass (line 80). Append "an `after:` depth inside one plan run, not a pipeline phase."
- "levels of measurement" (129) → "scale types". Removes **level** carrying two senses in one paragraph. Cost: none.
- **sibling** / "sibling column" → **sibling**. Cost: none.
- `kind` returning the wire name — keep (refuted; documented at 56).
- **lens**, **stream**, **predicate**, **collapsable**, **noul**, **category** — keep (refuted).

| term | keep / rename | to |
|---|---|---|
| criteria (bold) | rename (prose only) | definition; `criteria:` stays in code |
| measure (noun) / measurement | define | measurement |
| confidence | keep + document noul margin sense | optional `decided?` alias |
| `State#evidence` | deprecate | `facts` |
| `Score#index` | rename | `key` |
| `Questions#choice` | delete | — |
| form | keep | add "not an HTML form" |
| stage | keep | add "not a pipeline phase" |
| levels of measurement | reword | scale types |
| sibling column | unify | sibling |
| kind, lens, stream, predicate, collapsable, noul, category, level, gate, trigger | keep | — |

## 5. Proposed THEORY.md patch (not applied)

Before / after per section. Line numbers are today's.

**Distribution (53-54)**
> before: a thing with *entropy* (information theory — how undecided it is, which is what `confident?` and `undecided?` read off).
> after: a thing with *entropy* (information theory — how undecided it is; the gem does not compute it: `undecided?` reads distance from the **threshold**, `confident?` the provider's **confidence**).

**Distribution, Code (59)**
> before: The object that supports arithmetic: comparison, ranges, `& | ~`, expected values, ranking.
> after: The object that reads as a number: comparison, ranges, `& | ~`, sums and sorts through Ruby's coercion (a Numeric on the left), expected values, ranking.

**Prepare, Code (71)**
> before: `ψ(x)`, `S1::State.new(x)`, `x.to_s1`, a Rails **form**.
> after: `ψ(x)` = `S1.to_state(x)` — `x.to_s1` when it answers, else `S1::State.new(x)`; in Rails, a **form** with the record's declared lens.

**Measure (75-76, 83-84)**
> before: or generically (*measure*, when several questions share one state).
> after: or generically (*measure*: the arrow's name; on a state, the batch form).
> before: A batch is several questions on one state in one call; the answers are independent of one another.
> after: A batch is several questions on one state in one call; each is answered as if it were the only one — no answer is context for another. That is not independence of what they measure.

**Collapse, Code (94-95)**
> before: Spelled `?`, `collapse`, `!!`, or `case … in`.
> after: Spelled `?`, `collapse`, `!!`, `case … in`, `to_h` on a batch, and the nouns *choice* and *level*.

**Rendering, Theory/Code (100-102)**
> before: the function from evidence to state — what is shown, and in what shape. … `to_h`, a form block, JSON serialization
> after: the function from evidence to **facts** — what is shown, and in what shape; the state is the facts with the lens beside them, rendered by the same function. … a form block, `Rendering.render`; a measurement is not evidence and does not render — put its collapse or its probabilities in the lens explicitly

**Question, Code (120)**
> before: `{ instructions, criteria }` in one of three shapes.
> after: `{ type, instructions, criteria }` in one of three shapes.

**Scale (129, 140-141)**
> before: the first three of Stevens' levels of measurement
> after: the first three of Stevens' scale types
> before: In Rails, the column type or the enum, or a method on the record when the scale is dynamic.
> after: In Rails, `{ true, false }` on a boolean column, the enum's keys on an enum column, otherwise the categories or levels declared beside the column, or a method on the record when the scale is dynamic.

**Criteria, "Choosing among the evidence" (148-151)** — append:
> The inference is by shape: an Array of Strings, or a Hash with String keys whose values are all nil or all Strings. A Symbol-keyed Hash is a record and takes `categories:`.

**Calibration (155-157)**
> before: sums as expected counts, `&` as joint probability, thresholds as decision rules, collapsing late at all.
> after: sums as expected counts, thresholds as decision rules, collapsing late at all. `&` and `|` are the product and complement-product of marginals — exact only when the two properties are independent given the state, which the provider does not promise; for overlapping properties ask the conjunction as one question.

**Confidence (166-171)**
> before: the model's own estimate of how reliable a nominal or ordinal judgement is — distinct from the mass on the winning category. … gated by an explicit `confident?(at)`, which is true when the provider reports none (`confidence` is nil) — read `confidence` itself to escalate those.
> after: a scalar the provider reports beside a nominal or ordinal distribution, derived by the provider from the distribution's shape (jev), or the winning mass where it has nothing better (cua); it carries nothing the masses do not, and is kept so routing does not re-derive one per provider. A dichotomous judgement has none; distance from the threshold is it. *Code*: `confident?(at)` is confidence ≥ at, true when the provider reports none — read `confidence` to escalate those. On a noul, `confident?(margin)` is the complement of `undecided?`: at least `margin` from the threshold.

**Threshold, Code (177)** — if the code fix lands, unchanged; else:
> after: config, per-state, or per-collapse (`judge?(threshold:)`, `collapse(t)`); a verb never takes one. A measurement carries the threshold it was taken under when one was given, otherwise the config's, read at collapse.

**Predicate (184)**
> before: a question not yet applied to a state.
> after: a question, with the lens and collapse rule it will be applied under, not yet applied to a state; applying it prepares each element under that lens, then measures.

**Form, Code (195-197)**
> before: less what is never evidence — the key, the timestamps, the audit, and every measured column with its siblings: a measurement is not its own evidence.
> after: less what is never the record's own evidence — the key, the timestamps, the audit, every declared column with its siblings. A measured column re-enters only by declaration, as the lens of a sequenced field (`after:`). `as: :name` selects the form; it is reserved in core and an error on a State until Rails is loaded.

**Provider, Code (201-202)**
> before: `call(Request) → Result`; owns transport and wire format, translates into the normalized distributions, never leaks its own keys.
> after: `call(Request) → Result` for the scale kinds it declares (`supports?`); a question of a kind it lacks is refused before the wire (`UnsupportedError`), never emulated. Owns transport and wire format, translates into the normalized distributions, never leaks its own keys.

**Plumbing** — add:
> - **measurement** — one measure's product as taken: the distribution with the question, scale, threshold and confidence it was taken under; what a row stores and `measurement(:col)` rebuilds.
> - **audit** — the `s1_answers` JSON column: every measurement as taken, the source rehydration reads. A `_probabilities` sibling is a per-field copy of one part of it (by label; the audit's by rank).
> - **expectation** — a score's mass-weighted rank, adjacent levels one step apart (the program's assumption); `score` is its legacy alias.
> - **index** — the integer an integer column stores for a level: declared, else its **position**, the rank on the scale.
> - **plan result** — the Results of a plan's batches merged into one, in the caller's order, usage summed, `raw` per call; distributions from different stages are not independent.
> - **rehydration**, **sequenced field**, **dynamic scale** — one line each, lifted from 283-290.
> - **transport** — a provider's own: model, timeouts, retries, error classes, settings, hooks, logging. Calibration is per model, so `model:` is the one transport choice that reaches the theory.
> Amend **stage**: "…asked together, as one or more batches, once the fields they come `after:` are collapsed; inside `measure` those collapses are put on the record for the later stages and taken back. Not a pipeline phase." Amend **gate**: append "read by a plan run; a single verb and `s1_request` ask regardless." Amend **raw**: "on a distribution, that answer's; on the Result, the whole response." Amend **digest**: "`stale?`; `Model.stale(:col)` is the relation."

**The two adjustments (244-245)**
> before: they attach to different positions
> after: they attach to different things: criteria to the question, the lens to the state

**Rails (274, 277-279, 286-290, 293-294)**
> before: the **scale** lives on the column;
> after: the **scale** lives on the column when it is a boolean or an enum, and beside it otherwise;
> before: the **collapse** rule is the column type — a boolean column collapses at the threshold, a float keeps the mass, an enum or string keeps the category, an integer keeps the level's index (its rank when none is declared);
> after: the column type says what the row keeps — a boolean column collapses a judge at the threshold, an enum or string keeps the category, an integer keeps the level's index (its rank when none is declared); a float or decimal column is not a collapse: it keeps a judge's whole distribution or a score's expectation, and a category is read back from the audit;
> 286-290 — append: "when the later field's scale is dynamic it is read with that collapse in place, so the earlier verdict shapes the later question's scale as well as its state."
> 293-294 — after "asks at all": "a plan run reads the gate; a single verb asks regardless."

**Providers, in these terms (304)**
> before: it is what the conformance suite tests — shapes and calibration, never a vendor's keys.
> after: it is what the conformance suite tests — shapes, never a vendor's keys. Calibration and batch independence are the two clauses no offline suite can test; they are the provider's warranty.
> append: cua reads the scale and the state only; the concept must reach it inside the context — the arrow with the concept moved into ψ. (Delete this sentence if cua is changed to send the instructions.)

**Names (319-326)** — after "nouns:": "On the batch builder every method adds a question and returns the builder; `choice` is not an alias there." (Or delete the alias and say nothing.)

## 6. Checked and found sound

- Four positions, three arrows: `State.new` (prepare, once, frozen), `Client#measure` (one provider call per batch), `collapse` per kind — the code is the diagram.
- Threshold placement: config / per-state / per-collapse, refused on every verb, stamped by `Client#measure`, `Result#threshold` reads it back; `S1.measure(threshold:)` is the plumbing door.
- Lens: rendered beside the facts at `this`; `this` and `other` refused as lens keys; `given` merges over an existing lens; `same_as` puts the comparand in the state, not the question.
- Rendering: once, a value never a live reference; `to_s1` protocol honoured inside nested evidence.
- Question is immutable and provider-agnostic; wire names (`noul`, `choice`, `score`, `criteria`) are the provider's and the theory says so.
- Noul is the only distribution with a proper name; `x.noul(q) == x.judge(q)`, `choice`/`level` are verb-plus-collapse; the naming rule holds on State and Predicate.
- A verb in a boolean slot is always truthy; `!` and `!!` are the collapse; `case … in` sees the collapsed view.
- Stream: Predicate through `call`, `[]`, `to_proc`, `===`; collection operations are Ruby's own.
- Scale from the question: `Distribution#scale` in the scale's own type; `Level` is a String that knows its position; a Level on the left compares by rank.
- Provider contract: `Base#distribution` is the one normalizer; no vendor key leaks; Stub is a test double and the axiom holds for it by construction; Laya sends a confidence for scores.
- One provider call per batch for every provider including cua (N sidecar round-trips are transport).
- Rails: scale on boolean/enum columns; question beside the column; default form omits key, timestamps, audit and declared fields; digest and `stale?`; rehydration at the stored threshold; a measurement's own write is never a trigger; `if:` is a gate only on a sequenced field; the Proc trigger is the save trigger with an `if:`.
- Sequenced field: the earlier collapse enters the later state as a lens, keyed by the column name, refused if unmeasured or off-scale.
- Cost attribution (`owner`), telemetry on the Result, `on_result` hooks — plumbing, correctly outside the theory.
- The theory's discipline (bold = jargon) is coherent and, applied, disposes of most terminology objections; the residue is in §4.

