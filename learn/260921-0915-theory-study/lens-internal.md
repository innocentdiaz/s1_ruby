# Lens: internal — THEORY.md against itself and the code it names

Ordered by severity. Each item: location; the problem; the fix. Bold marks THEORY.md's own terms.

## High

1. **THEORY.md:304 vs lib/s1/rspec.rb:13-78, README.md:986** — The theory says the conformance suite tests "shapes and calibration"; every example in the suite checks shape only (classes, keys, [0,1] probabilities, scale, collapse, `supports?`, usage), and the README says "the shape, not the wisdom".
   Fix: reword 304 to "what the conformance suite tests is the shape; calibration is the provider's warranty and is not testable offline."

2. **THEORY.md:167-168 vs lib/s1/providers/cua.rb:49-50, README.md:964** — **Confidence** is defined as "distinct from the mass on the winning category", but the cua provider, which the theory claims to hold for, sets confidence to the winning mass.
   Fix: either define confidence as "a provider-reported reliability scalar; may coincide with the winning mass when the provider has no separate signal", or have cua report nil so `confident?` reads true and callers read `confidence` per line 171.

3. **THEORY.md:277-279 vs 63-64, 92, 296-297** — A float column is called a **collapse** rule that "keeps the mass", but the **category** entry says nothing probabilistic survives a collapse, and 296-297 says keeping the distribution is the alternative to collapsing; a dichotomous mass is the whole distribution.
   Fix: split the bullet: "the collapse rule is the column type — boolean at the threshold, enum/string the category, integer the level's rank; a float column is not a collapse but a sibling that keeps the mass."

4. **THEORY.md:54 vs 170-171, 223, lib/s1/answer.rb:40,51** — The **distribution** entry says `confident?` and `undecided?` read entropy; in code `confident?(at)` compares the provider's confidence scalar and `undecided?` is distance from a tunable threshold, neither of which is entropy (which is symmetric about 0.5). Probe: noul p=0.7, t=0.6 gives `confident?(0.8)=false`; a choice with confidence 1.0 gives `confident?(0.8)=true`.
   Fix: delete the parenthetical at 54, or replace it with "(the theory's reason to keep it; the code reads confidence and threshold-distance, not entropy)".

5. **THEORY.md:195-197 vs 286-288, 105** — Measured columns are declared "never evidence" and stripped from the default form, yet a **sequenced field** puts an earlier measured column's collapse into the later state as a **lens**, which line 105 defines as evidence added to the state.
   Fix: reword 195: "less what is never the record's own evidence — …; a measured column re-enters only by declaration, as the lens of a sequenced field (`after:`)."

## Medium

6. **THEORY.md:100-101 vs 69, 215-216, lib/s1/state.rb** — **Rendering** is "the function from evidence to state" at 100, but **prepare** at 69 "fixes its rendering and attaches its lens", and 215 defines **facts** as the evidence as rendered, alone. The code renders evidence to facts and renders the lens separately.
   Fix: 100: "the function from evidence to facts — what is shown, in what shape. The state is the facts with the lens beside them; rendering the lens is the same function applied to it."

7. **THEORY.md:244 vs 15, 27-64** — Criteria and lens are said to attach to "different positions", but the four positions are evidence, state, distribution, category; the question is a concept, not a position.
   Fix: 244: "they attach to different things: criteria to the question, the lens to the state."

8. **THEORY.md:183-186, 258 vs 249, lib/s1/predicate.rb:66,75-84, README.md:772** — A **predicate** is "a question not yet applied to a state", yet it carries a lens (`given:`) and a threshold, which the theory says attach to the state and the collapse; the code holds these as state options and re-applies them per element.
   Fix: 183: "Predicate — a question, with the lens and collapse rule it will be applied under, not yet applied to a state; applying it prepares each element under that lens, then measures."

9. **THEORY.md:86-88, 155, 177, 191, 197, 233, 263, 283, 290, 293, 296** — "Measurement" is used for the act at 86-88 and for the product (the thing a row stores, what `measurement(:col)` rebuilds) elsewhere; noun "measure" at 155/191/263 is a further undefined name for the **distribution**.
   Fix: add a dictionary entry: "**Measurement** — the product of one measure: the distribution together with the question, scale, threshold and confidence it was taken under; what a row stores and `measurement(:col)` rebuilds." Replace noun "measure" at 155/191/263 with "distribution".

10. **THEORY.md:319-330 vs lib/s1/question.rb:124,131, answer.rb:107, result.rb:64-66, state.rb:96-107,131** — The naming rule (verb returns the distribution, noun the thing it names, `?` a boolean) has undeclared exceptions: `Questions#choice`/`#noul` return the builder; `Answer::Score#score` returns a Float expectation; `Result#choices` returns distributions while `choice` names the category; `given`/`with`/`collapse` are verbs returning a state or a category; `ask` is the batch measure but `ask?` is a single judge.
    Fix: scope the rule at 319 to "the question-asking methods on a state and a predicate" and add a declared-exceptions line: "`collapse`, `given`, `with`, `to_s1` are not question methods; on the batch builder the verbs and their aliases add a question and return the builder; `Score#score` is the expectation (legacy alias)." Or drop the `choice`/`noul` aliases on `Questions`.

11. **THEORY.md:216, lib/s1/state.rb:76-77 vs 28-31** — `State#evidence` is kept as an alias of `facts`, so a noun named for the **evidence** position returns the **state**'s rendered content, which 28-31 says evidence is not.
    Fix: mark the alias deprecated in the entry ("`evidence` is a pre-theory alias and misnames it") and remove it in the next major.

12. **THEORY.md:166-171 vs lib/s1/answer.rb:40, README.md:474-479** — `confident?` has two meanings under one name: `confident?(at)` is a floor on the provider's confidence for nominal/ordinal answers; `confident?(margin)` on a noul is the complement of `undecided?`. The theory records only the first, so a reader applying it to a noul inverts the argument's sense.
    Fix: extend the **confidence** entry: "On a noul, `confident?(margin)` is the complement of `undecided?` — at least `margin` from the threshold; the positional is a margin there, not a floor."

13. **THEORY.md:5-6 vs 31, 45, 77, 280, 283, 286, 289** — Bold is reserved for dictionary terms, but seven bold terms have no entry: measurable (31), categorical distribution over the scale (45), probabilistic classification (77), sibling column (280; the dictionary has "siblings"), rehydration (283), sequenced field (286; used at 239 before its introduction), dynamic scale (289).
    Fix: unbold 45 and 77 (emphasis, not terms). Add entries for measurable ("an object that is a state or answers `to_s1`; in Rails the record through a form — `S1::Measurable`"), rehydration, sequenced field, dynamic scale; rename "siblings" to "sibling column" or the reverse.

14. **THEORY.md:196, 233-235, 281, 284, 297** — "The audit", "the `s1_answers` row", "a JSON column beside it", the `_probabilities` sibling and "the declaration" name overlapping stores without saying which is which.
    Fix: define once under Plumbing: "**audit** — the `s1_answers` JSON column: every measurement as taken (question digest, scale, threshold, confidence, probabilities), the source rehydration reads. A `_probabilities` sibling is a per-field copy of one part of it." Define "declaration" as the `judges`/`chooses`/`scores` line.

## Low

15. **THEORY.md:75-76 vs 88, 310, lib/s1/predicate.rb:43** — *measure* is restricted at 75-76 to "when several questions share one state" but is elsewhere the generic act, and `Predicate#measure` is one question.
    Fix: 75-76: "or generically (*measure*: the arrow's name; on a state, the batch form)."

16. **THEORY.md:94-95 vs 323-326, README.md:665** — The list of **collapse** spellings omits the nouns `choice` and `level` and `Result#to_h`, which the naming section and README define as collapses.
    Fix: 95: "Spelled `?`, `collapse`, `!!`, `case … in`, `to_h` on a batch, and the nouns `choice` and `level`."

17. **THEORY.md:235 vs 320, typesafe-rails/lib/s1/measurable.rb:183, relation.rb:69** — `stale` is written without `?` though it reads as a boolean; the code has `stale?(id)` on the record (boolean) and `stale(column)` on the relation (rows).
    Fix: 235: "is `stale?`; `Model.stale(:col)` is the relation of such rows."

18. **THEORY.md:71 vs 193-194, 276, README.md:767** — A Rails **form** is once an instance of **prepare** (rendering plus lens) and once "a named rendering" with the lens declared beside it.
    Fix: 71: "a Rails form together with the record's declared lens"; README 767: "a form can carry what a lens would."
