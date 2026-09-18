# Lens: providers

Read-only study of THEORY.md against `s1` (core) and `s1-rails`, judged against the three providers the theory must hold for: TypeSafe jev (hosted, one-pass category scorer, calibrated), Laya (self-hosted, same HTTP contract) and cua-s1-forms (choice-only option scorer). Ordered by severity; duplicates merged.

## High

### 1. The two contract clauses no suite can test are stated as tested, and in the wrong place
**Location.** THEORY.md:304, :158 (Calibration), :83-84 (Measure, *Code*); lib/s1/rspec.rb:42-47; README.md:986, :675; support/laya_server.py:24-27.
**Problem.** The theory says the conformance suite tests "shapes and calibration", and states batch independence under Measure's *Code* as a fact of the gem; the suite asserts only `be_between(0.0, 1.0)` and `sum within 0.02 of 1.0` on one canned request, calibration is a frequency property no stubbed call can check, no example touches independence, Laya's wrapper passes all questions to one `router.predict` call without saying whether answers condition on each other, and README.md:986 already admits "It checks the shape, not the wisdom".
**Fix.** Reword THEORY.md:304 to "shapes only, never a vendor's keys; calibration and batch independence are the two clauses no suite can test, and are taken on the provider's word." Move the independence sentence from Measure's *Code* into **Provider** ("honours calibration and answers a batch's questions independently — no answer is context for another"), leave Measure's *Code* at "one provider call", and mark the **Calibration** entry "asserted, not tested".

### 2. `&` is licensed as a joint probability; batch independence only buys a product of marginals
**Location.** THEORY.md:155-156; lib/s1/answer.rb:53-54; README.md:401-403, :675-677.
**Problem.** "No answer is context for another" gives P(A|state) and P(B|state) answered separately; their product equals the joint only when A and B are independent given the state, so the theory's "`&` as joint probability" and the code's "these are exact" are wrong for nested or correlated concepts (probe: `is_lead` 0.5 & `qualified` 0.5 → 0.25, but every qualified caller is a lead, so the joint is 0.5).
**Fix.** Replace with "`&` is the product of the marginals — the joint only when the two concepts are independent given the state. The provider promises something weaker: no answer is context for another. On nested concepts (qualified ⊂ is_lead) `&` understates." Drop "exact" from answer.rb:53-54 and README.md:402, :676.

### 3. Confidence is defined as separate from the winning mass; on every shipped provider it is a function of the masses
**Location.** THEORY.md:167-168; lib/s1/providers/cua.rb:49; lib/s1/providers/stub.rb:43,49; jev contract.
**Problem.** The theory defines **confidence** as "distinct from the mass on the winning category", but cua sets it to exactly that mass (`pick, confidence = probabilities.max_by { |_, p| p }`, probe confirms `confidence == probabilities[pick]`), jev derives it from the distribution's shape, and the stub fabricates 1.0 — so a reader routing on `confident?(at)` believes it carries evidence the probabilities do not.
**Fix.** Redefine: "**Confidence** — a scalar the provider reads off the distribution's shape (jev: from the shape; cua: the winning mass). It carries nothing the masses do not; it is the provider's chosen summary, kept so routing does not re-derive one per provider." Delete "distinct from the mass on the winning category".

### 4. cua never sends the concept, yet is counted as an instance of the same arrow
**Location.** lib/s1/providers/cua.rb:45-50; THEORY.md:116-120, :305.
**Problem.** cua builds `options` from `question.criteria` and scores them against `context_for(request.state)`; `question.instructions` is never referenced, so "Which team should handle this?" and "Which team should NOT handle this?" return identical distributions on the same state, while the theory says a question is "a concept on a scale" and calls cua one of "three instances" of measure.
**Fix.** Either fold `instructions` into cua's context string (the model's TASK line is where a concept lives) so the arrow is whole, or amend "Providers, in these terms": "cua reads the scale and the state only; the concept must be written into the state (its TASK line) because the model has no slot for one — the arrow with the concept moved into ψ."

## Medium

### 5. The theory says the expected position is derived; the HTTP providers require it from the wire and prefer it
**Location.** THEORY.md:138-139; lib/s1/providers/system_one_http.rb:114; lib/s1/answer.rb:115.
**Problem.** The theory says "a score's expected position is derived from the ordinal distribution, not measured", but the normalizer does `expectation: a.fetch("score")` (missing key → ValidationError) and `Answer::Score` derives only when nothing was sent (probe: wire `score: 0.0` with masses 0.05/0.22/0.73 → expectation 0.0 where the derived value is 1.68).
**Fix.** By the theory's own rule ("the code is wrong"): always derive (`expectation: nil`, let `Answer::Score` compute) and treat wire `score` as raw telemetry. Otherwise reword the theory: "the provider may send the expected position; the gem derives it when absent and never checks the two agree."

### 6. The normalizer trusts the wire: scale, mass sum and pick all come from the payload unchecked
**Location.** THEORY.md:55-56, :79-80; lib/s1/answer.rb:72-81, :111; lib/s1/providers/base.rb:41-54; lib/s1/providers/system_one_http.rb:114; lib/s1/rspec.rb:45.
**Problem.** The theory says categories arrive with the question and mass sums to 1, but `scale` is `probabilities.keys` and a server `legend` beats `question.levels` (probe: question `a, b, c`, wire `{a:, b:}` → scale `[:a, :b]`; wire legend `LOW/MID/HIGH/EXTRA` → level `"EXTRA"`), masses `{a: 0.5, b: 0.5, c: 0.5}` are accepted at sum 1.5, an off-scale `choice: "z"` is silently replaced by argmax, and the suite tolerates 0.02 without the theory saying so.
**Fix.** In `Providers::Base#distribution`, check wire keys / legend against `question.categories` / `question.levels`, normalize or reject masses that do not sum to 1, and raise ValidationError on an off-scale pick; take `scale` from the question, never the payload. Add to **Provider**: "an answer keyed by anything but the question's scale is malformed"; state the tolerance if one is kept.

### 7. `confident?` / `undecided?` are said to read entropy; neither computes it
**Location.** THEORY.md:53-54; lib/s1/distribution.rb:31; lib/s1/answer.rb:40, :51.
**Problem.** The theory says a distribution has "entropy … which is what `confident?` and `undecided?` read off"; `confident?` compares the provider's scalar to `at`, `undecided?` measures distance from the threshold (probe: p = 0.5, maximum entropy, threshold 0.9 → `undecided?` false, `confident?` true).
**Fix.** Delete the parenthetical, or replace with "a thing with entropy (information theory — how undecided it is; the gem does not compute it: `undecided?` reads distance from the threshold, `confident?` the provider's confidence)". Pair with finding 3.

### 8. Partial providers (`supports?`, `UnsupportedError`) have no place in the theory
**Location.** THEORY.md:199-201, :211-241 (Plumbing), :305; lib/s1/providers/base.rb:31; lib/s1/client.rb:22-26; lib/s1/errors.rb:27; lib/s1/rspec.rb:69-76.
**Problem.** **Provider** is "an implementation of *measure* that honours calibration" and cua is called an instance of the same arrow, yet cua overrides `supports?`, `Client#measure` raises `UnsupportedError` ("cannot answer a #{q.type}") and the suite checks the refusal; neither word appears in THEORY.md.
**Fix.** Extend **Provider**: "an implementation of *measure* for one or more of the three scale kinds, declared (`supports?`); a question of a kind it lacks is refused before the wire (`UnsupportedError`), never emulated." List both in Plumbing.

### 9. "Without generating text" sits beside 86 output tokens
**Location.** THEORY.md:80-81; README.md:420; spec/s1/providers/typesafe_spec.rb:25; support/laya_server.py; lib/s1/providers/cua.rb:52.
**Problem.** The theory says the model "scores every category in that one pass, without generating text", but the README example and the jev fixture report `output_tokens: 86` while Laya and cua report 0; live_spec only checks `>= 0`.
**Fix.** Say in Plumbing's telemetry line what an output token is for a non-generative model (scored category tokens? billing units?), or set the README example to `output_tokens: 0` if jev reports none.

## Low

### 10. Plumbing omits transport: model choice, timeouts, retries, error classes, settings, hooks, logging
**Location.** THEORY.md:15-16, :211-241; lib/s1/providers/system_one_http.rb:27, :57-72; lib/s1/providers/laya.rb:15-16; lib/s1/errors.rb; lib/s1/client.rb:56; lib/s1/providers/base.rb:16.
**Problem.** The theory claims every piece is one of seven things, plumbing or sugar, but `request.model || @model`, Laya's three checkpoints with "Choice degrades past ~20 options" (a per-model calibration bound), backoff retries, Transient/Permanent errors, `on_result` and `settings` appear nowhere.
**Fix.** One Plumbing line: "**transport** — a provider's own: which model, timeouts, retries, auth, error classes (transient vs permanent), settings, hooks, logging. Calibration is per model, so `model:` is the one transport choice that reaches the theory."

### 11. cua's "truncated to the model's byte limits" is false in Ruby and forbidden by the theory if true in the sidecar
**Location.** lib/s1/providers/cua.rb:22-23, :63-69; THEORY.md:69-70.
**Problem.** The comment says options are truncated; Ruby refuses context over `context_tokens` and never reads `option_tokens`, and any truncation in the sidecar's collator would be a second rendering, which "renders once" forbids.
**Fix.** Change the comment to "refused past the model's byte limits", check `option_tokens` the way `context_tokens` is checked, and add to **Provider**: "a provider may refuse a state it cannot read; it never re-renders one."

### 12. Question's wire form omits `type`
**Location.** THEORY.md:120; lib/s1/question.rb:24.
**Problem.** The theory gives the wire form as `{ instructions, criteria }`; `to_h` sends `{ type:, instructions:, criteria: }`.
**Fix.** `{ type, instructions, criteria }`.
