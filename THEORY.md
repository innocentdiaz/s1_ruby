# Theory

The code implements this. Where they disagree, the code is wrong.

Terms in **bold** are defined in the dictionary below and mean only what it says. Everything
else is ordinary English.

## The movement

```
evidence  ──prepare──▶  state  ──measure──▶  distribution  ──collapse──▶  category
   x                     ψ(x)     by a question       over a scale         a point on it
```

Four positions, three arrows. Every piece of the gem is one of these seven things, or plumbing
under them, or sugar over them.

In one sentence: ψ prepares evidence; a **question** is a **concept** on a **scale**;
measuring yields a calibrated **distribution** over that scale; collapsing picks the point;
and the program does its real work between the last two.

## Dictionary

Each term has what it is in the theory and what it is in the code.

### Positions

**Evidence**
*Theory*: the particular — the thing a judgement will be about, before any presentation. A list
of candidates, a transcript, a record.
*Code*: any object but nil. Not yet **measurable**: it has no fixed presentation and no **lens**.

**State**
*Theory*: the particular *as presented for judgement*. Not the thing; the thing as rendered,
fixed, with its lens attached. Every **rendering** leaves things out, so a state is also a
decision about what counts as evidence. A judgement is about the state; whatever the rendering
omitted does not exist to it.
*Code*: `S1::State` (`Subject` kept as an alias); `rendered` is the value. Text or JSON; bounded
by what the model can read; computed once and immutable, so every question asked of it sees
identical evidence. With a lens: `{ this: <rendered evidence>, **lens }`.

**Distribution**
*Theory*: the product of a judgement — the degree to which the particular falls under *each*
**category** of the **scale**, all at once. Nothing about the judgement has been discarded yet.
*Technically*: a calibrated **categorical distribution over the scale** — a Bernoulli
distribution for a judge (one number determines it), a categorical distribution over an
unordered support for a choose, over an ordered support for a score (which is why a score
alone also has an expectation: the expected rank). Other disciplines' names for the same
object, each true: the *soft prediction* or *class probabilities* (machine learning — the
output before the hard label); the *predictive distribution* or *posterior* (statistics —
"posterior" earned only under calibration); a *credence* (epistemology — a degree of belief
with a warranty: it tracks frequency); a *belief state* awaiting a decision rule (decision
theory — the reason to keep it); a thing with *entropy* (information theory — how undecided it
is; the gem does not compute it: `undecided?` reads distance from the **threshold**,
`confident?` the provider's **confidence** on a choice or score, and that same distance on a
noul).
*Code*: `S1::Distribution` (`Answer::Base` kept as an alias), one subclass per scale kind. Mass
over a finite scale (sums to 1); `scale`, the `S1::Scale` it was measured over (`[true, false]`
for a noul; `to_a` is the categories in the scale's own type — a Scale is not an Array, and `==`
against one is false); `kind`, the scale kind by its wire name; and for nominal and ordinal
scales a **confidence**. The object
that reads as a number: comparison, ranges, `& | ~`, sums and sorts through Ruby's coercion (a
Numeric on the left), expected values, ranking. It is a **collapsable** — the code's name for it,
after the one thing the program does with it.

**Category**
*Theory*: one point on the scale — the verdict. What the rest of the program acts on. A
category spelled as a bare literal elsewhere in a program (`lvl == "degraded"`, `case … when
"degraded"`, `in { severity: "degraded" }`) is not checked against its scale: rename the label
at the declaration and every such spelling goes silently false. Reference it through the scale
(`Severity[:degraded]`, `lvl.degraded?`) so a typo or a rename fails where it is used.
*Code*: a value of the scale's type: a boolean; a symbol; a **level**. Nothing probabilistic
survives.

### Arrows

**Prepare** (ψ)
*Theory*: makes evidence measurable — fixes its rendering and attaches its lens, so a question
can be applied. "Fixes" means: renders once, into a value, not a live reference to the thing.
*Code*: `ψ(x)` = `S1.to_state(x)` — `x.to_s1` when it answers, else `S1::State.new(x)`; in
Rails, a **form** with the record's declared lens. The output is a state.

**Measure**
*Theory*: **judgement** — determining the degree to which the particular falls under each
category of a scale. One act, named by its scale kind (*judge*, *choose*, *score*) or
generically (*measure*: the arrow's name; on a state, the batch form).
*Technically*: **probabilistic classification** — zero-shot, calibrated, over a query-supplied
scale. The classes are the scale's categories and nothing else: binary (judge), multiclass
(choose), ordinal (score). The categories and the concept arrive with the question, not with
the model; the model reads the state once and scores every category in that one pass, without
generating text. There is no continuous class: a score is ordered classes, not a gradient. The
only continuum is the mass each class receives, and that is the distribution, not the category.
*Code*: `P(category | state, question)`: one **provider** call. A batch is several questions on
one state in one call; each is answered as if it were the only one — no answer is context for
another. That is not independence of what they measure.
The same act has three names from three disciplines: *judgement* (philosophy: a particular
placed under a concept, by degree), *measurement* (measurement theory: a point on a scale, here
as a distribution over it), and *classification* (statistics: a conditional categorical
distribution, estimated). The gem's verb is *measure*, because its three kinds are Stevens'
scale kinds; *classification* is what it technically is.

**Collapse**
*Theory*: a decision rule — the distribution becomes one category. This is the moment
information is discarded, so it is the moment to postpone.
*Code*: per scale kind — a **threshold** for the dichotomous scale, the most likely category for
nominal and ordinal. Spelled `?`, `collapse`, `!!`, `case … in`, `to_h` on a batch, and the
nouns *choice* and *level*.

### Concepts

**Rendering**
*Theory*: the function from evidence to **facts** — what is shown, and in what shape; the state
is the facts with the lens beside them, rendered by the same function. Every rendering omits,
and the omission is invisible to the judgement.
*Code*: `Rendering.render`, a form block; bounded by context size; done once, at preparation. A
measurement is not evidence and has no rendering of its own: placed in evidence, a distribution
or a Result is refused (`ValidationError`) — put its collapse or its probabilities in the lens
explicitly.

**Lens** (`given`, `against`)
*Theory*: evidence added to the state to judge *against* — a standard, a policy, a context —
which makes the judgement relative. "Qualified, per `qualifications`."
*Code*: attaches to the **state**: `{ this: evidence, qualifications: … }`. The instruction
names it by backtick.

**Judgement**
*Theory*: placing a particular under a concept (Kant's use of the word). Here it is
probabilistic: not "is it C" but "to what degree, over the scale".
*Code*: what a provider does; what *measure* names.

**Question**
*Theory*: a concept on a scale, with its working definition: *what* is asked, *onto what* the
answer must land, and *where the boundaries are*. (The physics image for this is an
observable; the image is not part of the theory.)
*Code*: `{ type, instructions, criteria }` in one of three shapes (`criteria` is the wire word
for the definition). Immutable; this is the wire form. A score's `criteria` are the texts shown,
so a described scale's labels are not on the wire: whoever crosses a boundary carries them beside
it (Rails: `stores`, and the digest).

**Concept**
*Theory*: the property being judged — "angry", "which team", "how severe". Includes any
relation the judgement must perform ("do `this` and `other` describe the same thing").
*Code*: the instruction string, or a structured hash.

**Scale**
*Theory*: the finite set of categories a judgement can land on. Three kinds, and only three —
the first three of Stevens' scale types:

| kind | scale | the verb | the judgement |
|---|---|---|---|
| dichotomous | `{ true, false }` | judge | does *x* fall under concept *C* |
| nominal | `{ a, b, c }`, unordered | choose | which class |
| ordinal | `l₀ < l₁ < l₂` | score | which grade |

Interval and ratio scales ("how much", "what date") are not judgement but extraction — a
different operation with different failure modes — and are out of scope. The one interval-like
number, a score's expected position, is derived from the ordinal distribution, not measured.
A scale is a value: the set with its definitions, ordered or not. A category is a point on it
and knows which scale it belongs to — a level does; a nominal category is a Symbol, and the
scale checks it. Two scales are equal by kind and labels (ordinal in order, nominal as a set);
definitions and name are not part of identity — the digest carries them. Labels are distinct,
and so are the definitions, which are text: the wire carries them. A level of another scale is
off this one — `include?` says so and `fetch` raises — so a distribution keeps its question's
scale only when the wire answered on it, and raises otherwise.
*Code*: `S1::Scale` — `S1.scale(*labels)` ordinal, `S1.scale(**definitions)` nominal (a
category named `name` or `ordered` goes in a positional Hash), `S1.scale(-> { … })` dynamic
(resolved on the record: a list ordinal, a Hash nominal, unless `ordered:` said); `Scale#[]` /
`fetch` give the category and raise `KeyError` off the scale (`to_a[i]` is by position),
`Scale#===` checks one; `Level#scale` and `Distribution#scale` return it, and an inline list
or hash on a question builds one. The dichotomous scale stays `[true, false]`. In Rails,
`{ true, false }` on a boolean column, the enum's keys on an enum column, otherwise the
categories or levels declared beside the column — `Model.<fields>` (the plural; `Model.<field>_scale`
on every static field, the only one on an enum column, whose plural stays Rails' mapping; a
dynamic field, and `scale_methods: false`, generate none — `Model.s1_scale` always) is that
declaration's scale — or a method on the record when the scale is dynamic, evaluated by the
declaration's kind.

**Definition**
*Theory*: the working definition of the scale — what counts as yes; what each option means; the
ordered levels. The human's adjustment to the *meaning* of the concept. For a choose the
definitions are the scale's own (`{ option => description }`); for a judge, `true:` / `false:`
clarify a scale that needs no definitions, and are not a scale. *Criteria* is the wire word, and
the keyword `criteria:` in code; the theory's word is definition.
*Code*: attaches to the **question**: `true:` / `false:` on a judge, `{ option => description }`
on a choose, `*levels` on a score.
*Choosing among the evidence*: when the particular is itself the set of candidates — a list of
labels, or label → description — its labels are the scale, and the choose needs no categories
of its own. Spelled `names.choose "the most skilled"`, `names` being the labels themselves
(`%w[Michael Bob]`); a list of records is not candidates-shaped and takes `categories:`. The
inference is by shape: an Array of Strings, or a Hash with String keys whose values are all nil
or all Strings. A Symbol-keyed Hash is a record and takes `categories:`. A String-keyed Hash of
Strings — a parsed JSON record — passes the shape test; give it `categories:`.

**Calibration**
*Theory*: the axiom. A mass of 0.7 means that among such judgements, seven in ten are true. It
is what makes the distribution a *measure* rather than a label with a decoration, and it is
what licenses every operation performed before collapse: sums as expected counts, thresholds as
decision rules, collapsing late at all. `&` and `|` are the product and complement-product of
marginals — exact only when the two properties are independent given the state, which the
provider does not promise; for overlapping properties ask the conjunction as one question.
*Code*: the provider contract. A provider that is not calibrated does not produce collapsables;
it produces labels.

**Collapsable**
*Theory*: anything that holds a distribution and can collapse.
*Code*: the interface — one method, `collapse`. Implemented by each distribution kind and by a
batch result, elementwise.

**Confidence**
*Theory*: a scalar the provider reports beside a nominal or ordinal distribution, derived by the
provider from the distribution's shape (jev), or the winning mass where it has nothing better
(cua); it carries nothing the masses do not, and is kept so routing does not re-derive one per
provider. A dichotomous judgement has none; distance from the threshold is it.
*Code*: `confident?(at)` is confidence ≥ at, true when the provider reports none — read
`confidence` to escalate those. On a noul, `confident?(margin)` (`decided?`) is the complement
of `undecided?`: at least `margin` from the threshold.

**Threshold**
*Theory*: the parameter of the dichotomous decision rule — the mass at or above which "true" is
the verdict. The one collapse rule that is tunable, so the one that travels with the
measurement.
*Code*: config, per-field (a Rails declaration), per-state, or per-call; a measurement carries
the threshold it was taken under, stamped at measure: the config's when none was given. A noul
built by hand carries the config's as of its construction. A cached Result served to a
threshold-less State is re-stamped at serve time — the field's, else the config's then — so a
hit collapses as the fresh call would have.

**Level**
*Theory*: a point on an ordinal scale — a label with a rank, on a scale it knows.
*Code*: a String that knows its position and its scale; compares by rank on its own scale — a
Level from another scale is incomparable and `<=>` raises, while `==` is the label's (String
equality, any scale) or, against a Numeric, the position's; answers a predicate per key of its
scale (`Scale#keys`: `lvl.degraded?`) unless it already has a method of that name — String's
`empty?`, ActiveSupport's `present?` — which then answers; stores and prints as text.

**Predicate**
*Theory*: a question, with the lens and collapse rule it will be applied under, not yet applied
to a state; applying it prepares each element under that lens, then measures.
*Code*: `ψ.judge(…)`; callable, `to_proc`, `===`. Applied to each element of a stream, a verb
yields one distribution per element, a noun the thing it names, a `?` a boolean.

**Stream**
*Theory*: many particulars under one question.
*Code*: any `Enumerable`. Filtering, ranking, bucketing and counting are the collection's own
operations, applied to per-element measures.

**Form**
*Theory*: a named rendering of a persistent particular.
*Code*: `measurable_as(:name) { … }` on a record, selected by `as: :name` (on a verb, a
predicate, a declaration); the default form is its attributes less what is never the record's
own evidence — the key, the timestamps, the audit, every declared column with its siblings. A
measured column re-enters only by declaration, as the lens of a **sequenced field** (`after:`).
Not an HTML form.

**Provider**
*Theory*: an implementation of *measure* that honours calibration.
*Code*: `call(Request) → Result` for the scale kinds it declares (`supports?`); a question of a
kind it lacks is refused before the wire (`UnsupportedError`), never emulated. Owns transport
and wire format, translates into the normalized distributions, never leaks its own keys.

**Noul**
*Theory*: the name of the dichotomous distribution — the product of a judge — as *choose* and
*score* name the acts whose products are the nominal and ordinal distributions; those
distributions have no name of their own. Only the dichotomous distribution has a proper name.
*Code*: `Answer::Noul`; `x.noul(q)` is `x.judge(q)`. Also the wire name of the dichotomous
scale kind — the provider's key — which is where the word came from.

### Plumbing

- **measurement** — one measure's product as taken: the distribution with the question, scale,
  threshold and confidence it was taken under; what a row stores (the question as its digest)
  and, less the question, `measurement(:col)` rebuilds.
- **Result** — a batch of distributions from one measure, plus telemetry. `S1::Result`.
- **plan result** — the Results of a plan's batches merged into one, in the caller's order,
  usage summed, `raw` per call; distributions from different stages are not independent.
- **Request** — what a provider receives: rendered state, questions, options. `S1::Request`.
- **facts** — the evidence as rendered, alone: what sits at `this` under a lens, the whole
  rendering without one. `State#facts` (`evidence` kept as its alias); `State#lens` is the
  Hash beside it, `{}` with none.
- **Questions** — the batch builder: `id => question`, one method per scale kind. `S1::Questions`.
- **raw** — a provider's wire payload: on a distribution, that answer's; on the Result, the
  whole response.
- **transport** — a provider's own: model, timeouts, retries, error classes, settings, hooks,
  logging. Calibration is per model, so `model:` is the one transport choice that reaches the
  theory.
- **owner** — the object a call's cost is attributed to; rides on the Request's options.
- **telemetry** — usage, model, provider, duration_ms; on the Result.
- **id** — a question's key within a batch; the distribution carries it.
- **position** — a level's rank on its scale, counted from zero. `Level#position` (`to_i`).
- **expectation** — a score's mass-weighted rank, adjacent levels one step apart (the program's
  assumption); `score` is its legacy alias; what a float column keeps for a score.
- **index** — the integer an integer column stores for a level: declared, else its position.
  `Score#key` is the most likely level's rank — its position — and `Score#index` its legacy
  alias, neither this index; a provider's legend keys never reach a score, only its `raw`.
- **undecided?** — within a margin of the threshold; the dichotomous form of "not by me".
- **to_s1** — the conversion protocol ψ uses: anything that answers it prepares itself.
- **wire** — what crosses to and from a provider. Wire names are the provider's (`noul`, `choice`,
  `score`, `criteria`, `answers`); theory names are ours.
- **psi** — the setting that installs ψ (`c.psi = true`, or any identifier).
- **core extension** — `c.primitives`: String, Hash and Array as receivers of the verbs. Sugar.
- **siblings** — the parts of a distribution kept in columns beside its collapse, by the
  `<field>_<part>` convention; in Rails, the registry's `siblings:`. A score's `_probabilities`
  sibling is keyed by label; the audit's by rank.
- **audit** — the `s1_answers` JSON column: every measurement as taken (digest, scale,
  threshold, confidence, probabilities), the source **rehydration** reads.
- **rehydration** — `measurement(:col)`: the stored distribution rebuilt as a collapsable from
  the audit, over the scale, at the threshold, with the confidence it was taken with.
- **sequenced field** — a field declared `after:` another: judged once that one is collapsed,
  with its collapse in the lens.
- **dynamic scale** — a scale read from the record (`categories: :case_types`); the question is
  then per particular, and the audit keeps the scale it was taken over.
- **stage** — the questions asked together, as one or more batches, once the fields they come
  `after:` are collapsed; a plan is stages of batches, one provider call each. Inside `measure`
  those collapses are put on the record for the later stages and taken back. `Model.s1_plan`.
  Not a pipeline phase.
- **digest** — SHA-256 of a question as asked (instructions, definitions, the evaluated scale, a
  score's stored labels), stored with the measurement; a row whose digest is not the
  declaration's is `stale?`, and `Model.stale(:col)` is the relation.
- **trigger** — the lifecycle moment a declared field is measured at (`measure_on:`); fields on
  one trigger are one plan run. A measurement's own write is never a trigger, nor is a commit
  whose saves changed nothing (a `touch`).
- **gate** — a sequenced field's `if:` / `unless:`, read on the record with the earlier
  collapses in place; decides whether to ask, never what — neither a trigger, a lens nor
  a definition. A gated-out field is not asked and is absent from the Result. Read by a plan run —
  a trigger, `measure`, `update_measure`, `measure_all`; a single verb and `s1_request` ask
  regardless.

## The two adjustments

The human adjusts a judgement in exactly two places, and they attach to different things —
the definition to the question, the lens to the state:

- The **definition** attaches to the question. It changes what the concept *means*. "Angry
  means a raised voice or a threat."
- The **lens** attaches to the state. It changes what the concept is *applied to*. "Judge this
  ticket against this refund policy."

The rule for telling them apart: if it changes the meaning, it is the definition; if it changes
the evidence, it is the lens. A firm's acceptance criteria — a standard the particular is judged
against — is a lens, whatever it is called. Confusing the two is the most common way the boundary of this theory
goes soft.

## The stream

A stream is many states under one question. The question unbound is the **predicate**.
Applying it to each element yields, per element, what the naming rule says — a verb the
distribution, a noun the thing it names, a `?` a boolean — and the collection's own
operations are then the right ones: filter (collapse each), rank (compare distributions),
bucket (collapse to a nominal category), count (sum the masses). Nothing new is needed, because
once each element is a measure, Ruby's collection algebra is already the algebra of measures.

One rule follows from *collapse*: a verb in a place that expects true or false is always
truthy — a distribution is never false. So `select`, `grep`, `count`, `find` and `partition`
take the `?` form; `sum` and `sort_by` take the verb.

## Rails, in these terms

Rails already has the three scales as column types: `boolean` is dichotomous, `enum` is
nominal, an integer with a legend is ordinal. So in Rails:

- the **scale** lives on the column when it is a boolean or an enum, and beside it otherwise;
- the **question** is declared beside the column;
- the **state** is the record rendered through a **form**, with a declared **lens** if any;
- the column type says what the row keeps — a boolean column collapses a judge at the
  threshold (the call's, else the field's declared `threshold:`, else the config's), an enum or
  string keeps the category, an integer keeps the level's **index** (its **position** when none
  is declared); a float or decimal column is not a collapse: it keeps a judge's whole
  distribution or a score's expectation, and a category is read back from the audit — a
  judge's at the threshold stamped there, the call's winning; without an audit a judge reads
  at a declared `threshold:` (a stamp by declaration) and otherwise the read raises;
- a **sibling column** keeps one part of the distribution in the schema — `<field>_probability`,
  `_expectation`, `_index`, `_confidence`, `_probabilities` beside the measured column, written
  with the collapse, found by name;
- **rehydration** rebuilds the stored distribution as a collapsable — `measurement(:col)` from the
  `s1_answers` row, over the scale, at the threshold, with the confidence it was taken with — so
  the row is a source and a re-collapse asks nothing;
- a **sequenced field** (`after: :kind`) is judged against an earlier category: that field's
  collapse enters the later state as a **lens**, `{ kind: "new_case" }`, so the later stage is a
  judgement relative to an earlier verdict; when the later field's scale is dynamic it is read
  with that collapse in place, so the earlier verdict shapes the later question's scale as well
  as its state;
- a **dynamic scale** (`categories: :case_types`) is the scale read from the record: the question
  is then per particular, and the measurement stores the scale it was taken over;
- a **trigger** (`measure_on: :transcript`) is when a declared question is asked — a lifecycle
  moment of the record, or an attribute's change in any save of the transaction; the collapse of
  a measurement is a write the trigger does not see as a change, and a **gate** (`if:` on a
  sequenced field) decides whether the later stage asks at all — a plan run reads the gate; a
  single verb asks regardless.

A measured column is a question whose scale is the schema. Writing a boolean, enum, string or
integer column is the collapse; a float or decimal column and the JSON audit keep the distribution.

## Providers, in these terms

The gem owns the four positions and the three arrows. A provider owns one thing: the
translation of *measure* into and out of its own wire format. It receives a state and
questions, returns distributions, and is held to calibration. That is the entire contract, and
it is what the conformance suite tests — shapes, never a vendor's keys. Calibration and batch
independence are the two clauses no offline suite can test; they are the provider's warranty.
jev, Laya and cua-s1-forms are three instances of the same arrow.

## Names, settled against this

- **ψ** — prepare. It makes evidence measurable and measures nothing.
- **measure** — the act, generic over scales. Chosen over *observe* because it is both the
  measurement-theory word and the physics word.
- **judge / choose / score** — the act, named by its scale kind. Not three operations.
- **noul** — the dichotomous distribution, by name; also the wire name. The act is *judge*.
- **collapsable** — the distribution, seen through its one capability.
- **collapse** — the decision rule. In physics, measuring and collapsing are one event; here
  they are two, and the second belongs to the program. That split is the feature.
- **level** — a point on an ordinal scale.
- **definition / lens** — the two adjustments, by what they attach to. *Criteria* is the wire
  word for the first, kept as `criteria:` in code.
- **the rule for methods** — a verb measures and returns the distribution; a noun returns the
  thing it names; a `?` returns a boolean.
  - verbs: *judge*, *choose*, *score* (one question each); *measure* (several at once; aliases
    *ask*, *batch*, *ask_about*).
  - nouns: *noul* names the dichotomous distribution, so `x.noul(q)` is `x.judge(q)` (an
    `Answer::Noul`). *choice* names the category picked, so `x.choice(q, …)` is
    `x.choose(q, …).collapse` (a Symbol). *level* names the point on the ordinal scale, so
    `x.level(q, *levels)` is `x.score(q, *levels).collapse` (an `S1::Level`). On the batch
    builder every verb (*judge* / *noul*, *choose*, *score*) adds a question and returns the
    builder; `choice` is not a method there.
  - `?`: *judge?* (aliases *noul?*, *ask?*), *is?*, *same_as?* — booleans,
    `judge(…).collapse(threshold)`.
  - The asymmetry is deliberate: only the dichotomous distribution has a proper name (noul);
    nominal and ordinal distributions have none, so their nouns can only name the category.
