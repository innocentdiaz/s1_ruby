# Theory study — rails lens

Verified against THEORY.md, `s1` and `s1-rails` (probes run read-only). Ordered by severity. Terms in bold are THEORY.md's own.

## High

### 1. A float column keeps the expectation, not the mass
- Location: THEORY.md:277-279 vs typesafe-rails/lib/s1/measurable/writing.rb:103-112; typesafe-ruby/lib/s1/answer.rb:112
- Problem: "a float keeps the mass" holds only for a judge; for a score, a float or decimal column stores `Answer::Score#to_f`, which is the expectation — the expected rank, which the theory itself calls derived and not measured — so the row can hold a number that names no **level** (probe: mass {0: 0.5, 1: 0, 2: 0.5} on `scores :sev` → column `1.0`, audit `value=low`).
- Fix: reword THEORY.md:278 to "a float or decimal column keeps the mass on true for a judge and the expected rank for a score; such a column cannot hold a **category**, so `after:` it reads the **collapse** from the audit". Add `decimal` beside `float` (declarations.rb:45 treats them alike).

## Medium

### 2. An undeclared written column stays in the default form
- Location: THEORY.md:195-197 vs typesafe-rails/lib/s1/measurable/declarations.rb:74-77, writing.rb:56-65
- Problem: the default **form** omits only declared fields (built from `s1_registry.keys`), so a column a block writes into without a declaration (allowed by `collapses_into?`) is shown to the model on the next **measure** as its own last verdict — the thing THEORY.md:196 says never happens (probe: `chooses :kind` only, block writes `spam` → `s1_facts` includes `"spam"=>true`).
- Fix: since the theory wins, omit from the default **form** every column the row's `s1_answers` audit names, or refuse to write an undeclared column through the default **form**. Failing that, narrow THEORY.md:196 to "every declared field with its **siblings** — a column a block writes into without a declaration is still **evidence**".

### 3. A Rails measure is a plan run; its Result spans stages that are not independent
- Location: THEORY.md:75-76, 83-84, 213 vs typesafe-rails/lib/s1/measurable/staging.rb:303-311, measurable/result.rb; typesafe-ruby/lib/s1/answer.rb:74-76
- Problem: in Rails `measure` runs a plan and merges several provider calls over several states into one `S1::Measurable::Result`, so "**Result** — a batch of distributions from one measure" and "the answers are independent" do not hold across stages; `&` / `|` on **nouls** from different stages compute as if independent although the later was measured under the earlier's **collapse** as a **lens** (probe: `judges :b, after: :a`, `update_measure(:a, :b)` → 2 calls, one Result, `raw` of size 2, `(res[:a] & res[:b]).probability = 0.72` while `b` was asked with `{a: true}`).
- Fix: add a Plumbing entry: "**plan result** — the Results of a plan's batches merged into one, in the caller's order, usage summed, `raw` per call. Distributions from different **stages** are not independent — the later was measured given the earlier's **collapse** — so `&`, `|` and sums across stages are not joint probabilities." Qualify THEORY.md:75-76: in Rails, *measure* names the plan run, which may be more than one call.

### 4. The scale lives on the column only for booleans and enums
- Location: THEORY.md:140-141, 270-274 vs typesafe-rails/lib/s1/measurable/declarations.rb:45, 871, 914
- Problem: for `chooses` / `scores` on a string, text, integer, float or decimal column the **scale** is the declaration's categories or levels (the code raises "a chooses with no categories: give them, or declare the enum" / "a score with no levels — give them"); the column type is only the **collapse** rule, as THEORY.md:277 already says.
- Fix: reword THEORY.md:141 to "In Rails, `{ true, false }` on a boolean column, the enum's keys on an enum column, otherwise the categories or levels declared beside the column — or a method on the record when the scale is dynamic"; reword :274 to "the **scale** lives on the column when the column is a boolean or an enum, and beside it otherwise".

### 5. An earlier collapse also shapes a later question's scale
- Location: THEORY.md:286-290 vs typesafe-rails/lib/s1/measurable/declarations.rb:296-301, 338-345; spec/spec_helper.rb:71-77; staging.rb:12-14
- Problem: the theory says the earlier **collapse** "enters the later state as a **lens**", but a dynamic **scale** (`categories: :subtypes, after: :department`) is evaluated on the record with that collapse provisionally in place, so the earlier verdict also shapes the later **question**'s scale — **criteria**, not only state.
- Fix: append to the sequenced-field line: "when the later field's **scale** is dynamic, it is read from the record with that **collapse** in place — the earlier verdict then shapes the later question's scale as well as its state. This is still **criteria** (it changes what the answer lands on), evaluated per particular."

### 6. "index" names three different numbers
- Location: THEORY.md:279 vs typesafe-ruby/lib/s1/answer.rb:117; typesafe-rails/lib/s1/measurable/writing.rb:108, audit.rb:23; README.md:508-509
- Problem: the theory's and the rails DSL's index is the declared stored integer (`indexes:`, `_index`); core `Answer::Score#index` is the provider's legend key; the rank is `position` — a reader of THEORY.md:279 who calls `score(:col).index` gets the wire key (probe: legend `{5,6,7}`, `scores :sev2, {low: 10, mid: 20, high: 30}` → `Score#index=6`, `level.position=1`, column and `sev2_index` `=20`).
- Fix: define in the dictionary "**index** — the integer an integer column stores for a **level**: declared, else its rank" and "**position** — a level's rank on its **scale**". Rename core `Answer::Score#index` to `key` (or `wire_index`); keep `index` as an alias only if it returns the rank.

## Low

### 7. Rails-section terms are bolded outside the dictionary; code words the theory never names
- Location: THEORY.md:5, 232-233, 280-294; typesafe-rails/lib/s1/measurable/staging.rb:12-14, 122-127; declarations.rb:193-195, 714-715; README.md:414
- Problem: THEORY.md:5 says bold terms are defined in the dictionary, yet the Rails section bolds **sibling column**, **rehydration**, **sequenced field** and **dynamic scale** in prose; code and README lean on "predecessor", "provisional" and "home batch", which the theory never defines; and the **stage** entry's "asked in one pass" reads as one call although a stage runs several batches, one call each.
- Fix: move the four terms into Plumbing as one-line entries. Reword **stage** to "the questions asked together — as one or more batches — once the fields they come `after:` are collapsed; inside `measure` the collapses are put on the record for the later stages and taken back". Either define "predecessor" ("a field named in `after:`") or have code and README say "the fields it comes after".

### 8. A score's probabilities are stored in two encodings
- Location: typesafe-rails/lib/s1/measurable/writing.rb:125-131 vs audit.rb:24, 133-136; THEORY.md:231, 280-282; README.md:485, 510
- Problem: the `_probabilities` **sibling** of a score is keyed by label while the same part in the `s1_answers` audit is keyed by rank ("0", "1", …) — one part of the **distribution** in two encodings, and the theory's sibling lines do not say which is which.
- Fix: pick one encoding (by label — the audit stores `scale` beside it, and **rehydration** can map either way), or add to THEORY.md:280-282: "`_probabilities` by label; the audit's by rank, beside the `scale` that names them".

### 9. The gate applies only to a plan run
- Location: THEORY.md:239-241 vs typesafe-rails/lib/s1/measurable/state.rb:84-91, 213-222; staging.rb:168-170; README.md:432-433
- Problem: the **gate** "decides whether to ask", but a bare verb on a sequenced field (`choose(:case_type)`) and `s1_request` set `ungated` and ask regardless; the theory does not say the gate is read only by a plan run.
- Fix: append to the **gate** entry: "It is read by a plan run — a **trigger**, `measure`, `update_measure`, `measure_all`; a single verb, and `s1_request`, ask regardless."
