# s1-ruby
![preview](https://github.com/innocentdiaz/s1_ruby/blob/master/preview.png?raw=true)

> AI built for interfacing with code (useful) — not with people (too good to be true).

> The AI race has revealed the operation that computation was missing: `collapse` over meaning.

# Overview

**System One (S1) measurement** — and the *collapse* that follows it — native to Ruby.
An S1 model answers a typed question about data with a calibrated probability. It does not
generate, and it does not decide. Code asks; code decides.

 - For the **Ruby on Rails** implementation, see: [s1-rails](https://github.com/innocentdiaz/s1_rails)
 - For the terms, see [THEORY.md](THEORY.md). Where this README and the theory disagree, the theory is right.

**TABLE of CONTENTS**

- [TL;DR](#tldr)
- [The idea: collapse](#the-idea-collapse) · [Why](#why)
- [Install](#install)
- [Grammar: verbs, nouns, `?`](#grammar-verbs-nouns-)
- [The three kinds](#the-three-kinds) — noul · choice · score · [Level](#level) · [Scales](#scales-one-place-for-the-labels) · [Distribution](#distribution) · [Batch](#batch-many-questions-one-call) · [Structured state](#structured-state-and-structured-questions) · [Reading distributions](#reading-distributions)
- [Experimental: making it native](#experimental-making-it-native) — the core extension · ψ · pattern matching · `===`
- [Keeping the probability: collapse late](#keeping-the-probability-collapse-late) — `&` `|` `~` · ranges · `undecided?` · `collapse`
- [Collections: judgments as predicates](#collections-judgments-as-predicates) — select / group_by / sort_by / sum / grep · the lens (`given:`)
- [Dictionary and aliases](#dictionary-and-aliases)
- [Errors](#errors) · [Testing](#testing) · [Observing calls](#observing-calls) · [Providers](#providers) · [Development](#development)

## TL;DR

Illustrative code:

```ruby
# Pull from a database:
people = [
  {
    name: "Michael",
    occupations: [
      "owner @ large self-sustaining family homestead",
      "software engineer @ MedicalTech startup ($2M/arr)"
    ]
  },
  {
    name: "Bob",
    occupations: [
      "Exotic beast/animal hunter & trader (pokemon hunter)",
      "Professional Sportsman (office ping pong master)",
      "Front-Counter Point of Sale (POS) Operator (MacDonalds in Hunstville, Alabama)"
    ]
  }
]

(ψ people).choose "the most skilled individual", categories: people.map { _1[:name] }   # => Michael — one call; .ranked lists everyone
people.max_by(&ψ.score("How skilled is this person?", "novice", "competent", "expert", "exceptional"))   # => the Michael hash; one call per person
```

`(ψ people)` prepares the list: it is now a **state**, something questions can be asked about,
none asked yet. Measuring it — *choose* the most skilled — is, by default, the model's own sense
of "skilled". To make the judgement relative, hand the model something to judge *against*: a
**lens**, with `given` (or `against`):

```ruby
(ψ people).given(rubric: "skill = breadth of trades").choose "the most skilled, per `rubric`", categories: people.map { _1[:name] }   # => Bob
```

The same list, with the categories built from the data, is under [choice](#the-three-kinds).

Another example:

```ruby
class EscalateToHuman < StandardError; end

def handle_chat(chat)
  triage = (ψ chat).measure do |q|                                        # several measurements, one call
    q.judge  :escalate,   "Is the customer asking for a supervisor?"
    q.judge  :new_matter, "Is this a new matter?"
    q.score  :severity,   "How severe is the injury?", "None", "Minor", "Serious", "Catastrophic"
  end

  raise EscalateToHuman if triage.true?(:escalate)                        # ? collapses; a bare distribution is always truthy
  create_case(triage[:severity].level) if triage.true?(:new_matter) && triage[:severity].level.position >= 1
end

chat = { messages: [] }
inbox.each do |message|            # whatever feeds you messages: a queue, a webhook, a socket
  chat[:messages] << message
  handle_chat(chat)                # one call per message; every question answered fresh
rescue EscalateToHuman
  hand_to_person(chat)
end
```

## The idea: collapse

Software is rows and associations. Its input is human: a form, a phone call transcript, a
review, a chat, a résumé. Its output is what a person sees on the other side: a web UI, an
API, an MCP. Between the two sits the one thing computers could never do — read the human
input and *judge* it.

For AI to be useful it has to tap that **stream** of human input — the data, one transcript
or a list of calls, tickets, candidates — and categorize it, sort it, judge it. Not write about
it: decide something about it that code can act on. That operation is the movement this gem
is built around — four positions, three arrows:

```
evidence  ──prepare──▶  state  ──measure──▶  distribution  ──collapse──▶  category
   x                     ψ(x)     by a question       over a scale         a point on it
```

Two of the arrows have a symbol. **ψ prepares**: `(ψ chat)` is a state — the evidence rendered
once, fixed, with calibrated answers to any question, none yet taken. Rendering happens at
preparation and never again: mutating `chat` afterwards does not change what is judged.
**The verbs measure**: `judge`, `choose`, `score` — three kinds of measurement, always one of
the three — or several at once with `measure { |q| q.judge …; q.choose …; q.score … }`. Each
returns a distribution over its scale, calibrated and kept. **`?` collapses**: the distribution
becomes a category. That is Ruby's own suffix with Ruby's own meaning (`empty?`, `any?`: the
decision, not the thing). Between the last two arrows there is nothing new — arithmetic,
ranges, `sum`, `case` — because once a judgement is a number, Ruby already knows what to do
with a number.

```
Human stream  +  Lens  ──ψ──▶  state  ──judge / choose / score──▶  distribution  ──?──▶  category
                                                                        │
                                                                 & | ~  ranges  sum  case
```

One point where the physics image is loose: S1 answers are deterministic and repeatable; the
probability is calibrated credence, not a coin waiting to be flipped. "Collapse" names the
code's choice to stop carrying the distribution — and it is a choice; the section *Keeping the
probability* is about not making it too early.

The human adjusts a judgement in exactly two places. The **definition** attaches to the question
and changes what the concept *means*: a clarification of yes / no, a description per category,
the ordered levels (`criteria:` is its wire word, and the keyword in code). The **lens** attaches
to the state and changes what the concept is *applied to*: a firm's acceptance criteria, a
role's requirements, a return policy — `given:`, or a Rails form. If it changes the meaning, it
is the definition; if it changes the evidence, it is the lens — a firm's "criteria" is a
standard to judge against, so it is a lens.

**The judgement** is semantic categorization, with a probability. A regex categorizes by
characters; this categorizes by meaning — the same *kind* of tool (a predicate you filter and
match with), applied where characters run out. And the judgement is *probabilistic*: every
distribution is kept whole, so "need more info / maybe / probably / sure" is as native as
true / false, and a sum of nouls is an expected count.

The thing that changes:

```ruby
name = "Andrew"
male_name = true if ???                       # there was never a way to write this line
preference_color = male_name ? "blue" : "pink"
```

```ruby
male_name = (ψ name).is? "a man's name"       # now there is: ψ prepares, is measures, ? collapses
(ψ name).is "a man's name"                    # => 0.97 — the distribution alone, when the number is what you want
"Andrew".noul "Is this a man's name?"         # => 0.97 — the same distribution by its name, with the core extension on
```

That is the whole foundation: make the movement native to the language, then give it the same
surface everything else in Ruby has — filter, group, sort, sum, match, pattern-match, batch — so
a stream can be judged with `Enumerable` the way it is counted with `Enumerable`. Everything in
this README is one of those two moves. The model behind it (jev, today) is what makes it
possible; the grammar is what makes it usable.

## Why

An S1 model does one thing: measure (judge, choose, score). Three kinds cover it:
- Choice — group, classify, route (`choose`)
- Score — a level on an ordered scale (`score`)
- Yes / no, with a probability (`judge`)

It is not a free-form assistant for people (an LLM). It interfaces with code.
Code-in-the-loop, not human-in-the-loop.

The most basic usage:

```ruby
chat = { messages: [ "How may I help you?" ... ]}
escalate_to_human if chat.judge? "is the customer asking for a human agent?"    # core extension on (c.primitives = true)
escalate_to_human if (ψ chat).is? "asking for a human agent"                     # ψ on (c.psi = true)
```

Under the hood, both are:

```ruby
state = S1::State.new("I have asked three times now. Can I just talk to a real person?")
escalate_to_human if state.judge?("Is the customer asking for a human agent?")
```

## Install

```ruby
gem "s1"
```

```ruby
# config/initializers/s1.rb (or anywhere at boot)
S1.configure do |c|
  c.provider   = :typesafe                  # default; a name under Providers, or an instance
  c.timeout    = 30                         # seconds per request
  c.threshold  = 0.5                        # a noul at or above this reads as true
  c.logger     = Rails.logger               # optional; debug lines per request, warns on retry
  c.primitives = false                      # true extends String, Hash, Array; see "Experimental"
  c.psi        = false                      # true defines ψ(x); see "Experimental"

  c.typesafe.api_key     = ENV["TYPESAFE_API_KEY"]   # default: read from the environment
  c.typesafe.model       = "jev-latest"
  c.typesafe.base_url    = "https://api.typesafe.ai"
  c.typesafe.max_retries = 2                         # transient failures before raising

  c.cua.checkpoint = "cua-s1-forms"                  # only when c.provider = :cua

  c.protocol.base_url = ENV["S1_BASE_URL"]           # Laya, or any self-hosted server
  c.protocol.path     = "/v1/systemone"              # default; or ENV["S1_PATH"]
  c.protocol.api_key  = ENV["S1_API_KEY"]            # sent as a bearer token when set
end
```

Every value has a default; an initializer is only needed to change one. Each provider keeps its
own settings under its name (`c.typesafe`, `c.cua`), declared by the provider class. Ruby ≥ 3.2.
No runtime dependencies.

## Grammar: verbs, nouns, `?`

One rule names every method in this README: **a verb measures and returns the distribution; a
noun returns the thing it names; a `?` returns a boolean.**

**States carry verbs.** A state is anything a question can be asked about: an `S1::State`; a
String, Hash or Array with the core extension on; a Rails record. A `ψ.` predicate carries the
same verbs unapplied.

| verb | asks | returns |
|---|---|---|
| `judge` (`is` and `same_as` fill the question in) | "Is this true?" | `Answer::Noul` |
| `choose` | "Which of these?" | `Answer::Choice` |
| `score` | "Which level?" | `Answer::Score` |
| `measure` (`ask`, `batch`, `ask_about`) | several at once | `Result` |

**Distributions collapse.** One contract: `collapse(threshold)`. The threshold only matters to a
noul, and a noul carries the one it was measured under (`S1::State.new(x, threshold: 0.9)`; the
config's as of the measure otherwise — stamped then, not read at collapse; a noul built by hand
carries the config's as of its construction); the others accept and ignore it, so a `Result`
collapses every distribution
through one call, each noul at its own threshold, and `to_h`, `true?` and `case … in` follow.
Each kind names its collapse and exposes Ruby's own conversions.

| collapsable | `collapse` returns | its own name | Ruby idioms |
|---|---|---|---|
| `Answer::Noul` | `true` / `false` | `true?` (`false?`) | `!` so `!!`, `to_f`, `Comparable`, `&` `\|` `~` |
| `Answer::Choice` | a Symbol | `choice` | `to_sym`, `to_s`, loose `==` |
| `Answer::Score` | an `S1::Level` | `level` | `key` (the most likely level's rank), `to_f` (weighted position), `levels` |
| `Result` | `{ id => collapsed value }` | `to_h` | `deconstruct_keys`, so `case … in` |

**Nouns name; `?` decides.** On every state:

```ruby
x.noul(q)            == x.judge(q)                        # the dichotomous distribution, by its proper name — an Answer::Noul
x.choice(q, **cats)  == x.choose(q, **cats).collapse      # the category picked — a Symbol
x.level(q, *levels)  == x.score(q, *levels).collapse      # the point on the ordinal scale — an S1::Level
x.judge?(q)          == x.judge(q).collapse(threshold)    # a boolean; noul?, ask? are the same; on an S1::State (and a ψ. predicate) is? and same_as? fill the question in
```

The asymmetry is deliberate. Only the dichotomous distribution has a proper name — *noul* — so
its noun returns the distribution itself. The nominal and ordinal distributions have none, so
their nouns can only name the category: `choice` is a Symbol, `level` is a point on the scale.
And a `?` method returns a boolean — Ruby's convention — so `?` exists only for a noul: there is
no `choice?` and no `judge?` on a Choice or a Score.

## The three kinds

Every question is one of three kinds — the first three of Stevens' scales: dichotomous, nominal,
ordinal. Pick by what the answer *is*. Each kind has a verb that measures and a noun that names.
The examples use `state = S1::State.new(text)`; a `# ψ:` line gives the same call with ψ on. A
`Noul` prints as its probability, so `# => 0.98` below is a `Noul` at 0.98.

**noul — "Is this true?"** The dichotomous distribution: a probability, 0 to 1, over
`{ true, false }`. The probability is the signal. `judge` measures it; `noul` is its name, and
returns the same thing; `judge?` (`noul?`) is true at or above the threshold; `is` / `is?` take a
phrase and ask "Is this …?".

```ruby
state.judge("Is the customer asking for a human agent?")    # => #<S1::Answer::Noul 0.98>  compares like a number
state.noul("Is the customer asking for a human agent?")     # the same distribution, by its name
state.judge?("Is the customer asking for a human agent?")   # => true  (at or above the threshold)
# ψ: (ψ text).judge "…" / (ψ text).is? "the customer asking for a human agent"

# Optional definition — what counts as yes / no:
state.judge("Has the customer contacted support about this before?",
            true:  "mentions a prior attempt, ticket, or having asked before",
            false: "no sign of any previous contact")
```

**choice — "Which of these categories?"** The nominal distribution: mass over an unordered set.
`choose` measures — the pick plus a distribution over every category; `choice` is the pick alone,
a Symbol.

```ruby
dept = state.choose("Which team should handle this?",
                    returns:  "Exchanges, refunds, wrong or damaged items",
                    shipping: "Delivery status, delays, lost packages",
                    billing:  "Charges, invoices, payment problems")
dept.to_sym          # => :returns
dept[:shipping]      # => 0.0
dept.confidence      # => 1.0
state.choice("Which team should handle this?", returns: "…", shipping: "…", billing: "…")   # => :returns
# ψ: dept = (ψ text).choose "Which team should handle this?", returns: "…", shipping: "…", billing: "…"
```

Categories can be built from the state itself. `people` is the list from the [TL;DR](#tldr); that
example asks one question over the whole list, this one shows the four ways to pass the categories
(core extension on, so the Array is the receiver):

```ruby
categories = people.to_h { |person| [person[:name], "Occupations: #{person[:occupations].join(", ")}"] }

people.choose "The most skilled individual", **categories                          # => #<S1::Answer::Choice Michael>  ([:Michael] # => 0.98)
people.choose "The most skilled individual", categories: categories                # same
people.choose "The most skilled individual", categories: people.map { _1[:name] }  # labels only, no descriptions
categories.choose "The most skilled individual"                                    # choosing among the evidence: the state IS the categories
```

`categories:` takes `{ category => description }` or a bare list; `choices:`, and the wire name
`criteria:`, still work. With none given, a state of that shape — an Array of Strings, or a Hash
with String keys and all-nil or all-String values — is the scale. A Symbol-keyed Hash is a
record, not candidates: `{ ticket: "…", customer: "…" }.choose "Which team?"` raises until it is
given `categories:`. A String-keyed Hash of Strings — a parsed JSON record — has the candidates'
shape and would be asked as one; give it `categories:`.

**score — "Which level?"** The ordinal distribution: mass over an ordered spectrum, worst → best.
`score` measures — the most likely level, and the probability-weighted position; `level` is the
level alone: an `S1::Level`, the label, that knows its position.

```ruby
sev = state.score("How severe is the reported issue?",
                  "Cosmetic; no impact to functionality",
                  "Broken or degraded feature, but a workaround exists",
                  "Blocking issue; no workaround exists")
sev.level    # => "Blocking issue; no workaround exists"   an S1::Level
sev.key      # => 2      the rank of the most likely level — sev.level.position (`index` is the legacy name); the wire's key is in raw
sev.to_f     # => 1.68   (expectation: the weighted position across the levels, always derived from the masses)
state.level("How severe is the reported issue?", "Cosmetic…", "Broken…", "Blocking…")   # => "Blocking issue; no workaround exists"
# ψ: sev = (ψ text).score "How severe is the reported issue?", "Cosmetic…", "Broken…", "Blocking…"
```

### Level

A score collapses to a `Level`: a String — the label — that knows its position on its scale.
That one fact is what makes a level usable both where code wants a number and where it wants
text.

```ruby
sev = state.score("How severe is the reported issue?", "Cosmetic…", "Broken…", "Blocking…")
lvl = sev.collapse            # => "Blocking issue; no workaround exists", an S1::Level

lvl >= 1                      # => true    by position, not alphabet
lvl >= "Broken or degraded feature, but a workaround exists"   # => true    a label on the scale, by its position
lvl.position                  # => 2       (lvl.to_i is the same)
lvl.scale                     # => #<S1::Scale Cosmetic… < Broken… < Blocking…>   the S1::Scale (lvl.labels: the Strings)
lvl.index("no")               # => 16      String's own methods are all still String's
YAML.dump(lvl)                # => "--- Blocking issue; no workaround exists\n"   the label alone; safe_load reads it back

case state.measure { |q| q.score :severity, "How severe?", "Cosmetic", "Broken", "Blocking" }
in { severity: "Blocking" }   then page_someone      # the label matches — the literal spelling; see Scales for the pinned form
in { severity: 1.. }          then open_ticket       # so does an integer range (`when 2..`, never a bare `when 2`)
end

tickets.sort_by(&ψ.score("How severe?", "cosmetic", "broken", "blocking"))   # ordered by expected position
tickets.max_by(&ψ.score("How severe?", "cosmetic", "broken", "blocking"))
by_level = tickets.group_by(&ψ.level("How severe?", "cosmetic", "broken", "blocking"))
by_level["blocking"]          # keys are the labels; a plain String looks them up

"severity: #{lvl}"            # a String: interpolates
ticket.update!(severity: lvl) # stores as the label
{ severity: lvl }.to_json     # => {"severity":"Blocking issue; no workaround exists"}
```

One caveat. Put the level on the left of a comparison with a label: `lvl >= "Broken…"` is
by position, `"Broken…" <= lvl` is String's own compare, by alphabet. Ranges of integers match
a level; ranges of labels do not.

### Scales: one place for the labels

A label spelled twice is a foot-gun. The question declares `"blocking"`; somewhere else the
program compares against it; then someone renames the level at the declaration:

```ruby
# app/questions.rb — the declaration, renamed today
Severity = S1.scale :cosmetic, :degraded, :blocked                 # was :blocking
lvl = (ψ text).level "How severe?", Severity
r   = (ψ text).measure { |q| q.score :severity, "How severe?", Severity }

# app/routing.rb — the literal spellings: silently false, and they stay false
page_someone if lvl == "blocking"                                  # false: no error, no page
case lvl
when "blocking" then page_someone                                  # falls through
end
case r
in { severity: "blocking" } then page_someone                      # never matches …
in { severity: 1.. }        then open_ticket                       # … so a blocked issue opens a ticket
end

# the same three through the scale: each raises at the reference, the day of the rename
page_someone if lvl == Severity[:blocking]                         # KeyError: :blocking is not on the scale (cosmetic, degraded, blocked)
page_someone if lvl.blocking?                                      # NoMethodError
case r
in { severity: ^(Severity.fetch(:blocking)) } then page_someone    # KeyError — pinned; unpinned, `in { severity: Severity[:blocking] }`
end                                                                # is Ruby's array pattern on the constant and silently never matches
```

`S1.scale` makes the scale a value — the labels, ordered or not, with their definitions — so
the label is spelled once and every other mention is a lookup that fails loud. A question takes
the scale where the list or hash went:

```ruby
Severity = S1.scale :cosmetic, :degraded, :blocking                # ordinal: order is rank
Severity                                                           # => #<S1::Scale cosmetic < degraded < blocking>
lvl = state.level("How severe?", Severity)                         # => "blocking", an S1::Level on Severity
lvl.scale.equal?(Severity)                                         # => true

Severity[:degraded]                                                # => "degraded"   an S1::Level, position 1; Severity[:sever] raises KeyError
Severity.fetch(:degraded)                                          # the same: ":sever is not on the scale (cosmetic, degraded, blocking)"
Severity.to_a[1]                                                   # by position — [] is by label or key, never an index
lvl.blocking?                                                      # => true        a predicate per label, by its snake-cased key (Severity.keys)
lvl >= Severity[:degraded]                                         # => true        by position
lvl < S1.scale(:low, :high)[:high]                                 # ArgumentError: different scales
case lvl when Severity then … end                                  # === is membership: a Level of this scale, or a label / key on it
Severity.to_a                                                      # the Levels; Enumerable, so Severity.max, Severity.map(&:position)

Team = S1.scale returns: "Exchanges, refunds, wrong or damaged items",   # nominal: label => definition
                billing: "Charges, invoices, payment problems"
Team                                                               # => #<S1::Scale returns | billing>
dept = state.choose("Which team should handle this?", categories: Team)   # the Scale where the hash went
dept.scale.equal?(Team)                                            # => true
Team[:billing]                                                     # => :billing    a nominal category is a Symbol; the scale checks it
Team.fetch(:biling)                                                # KeyError: :biling is not on the scale (returns, billing)
Team.fetch(row["team"]) == Team[:billing]                          # a String from a column or the wire is a category once fetched — never `row["team"] == Team[:billing]`
Team.definitions                                                   # => { "returns" => "Exchanges, …", "billing" => "Charges, …" }

case state.measure { |q| q.score :severity, "How severe?", Severity; q.choose :team, "Which team?", categories: Team }
in { severity: ^(Severity.fetch(:blocking)) } then page_someone   # a pinned reference: a typo here raises
in { team: ^(Team.fetch(:billing)) }           then route_to_billing
end

tickets.group_by(&ψ.level("How severe?", Severity))              # keys are Levels on Severity; by_level[Severity[:blocking]]
```

`S1.scale(*labels)` is ordinal, `S1.scale(**definitions)` nominal (`ordered: false` makes a bare
list nominal, `ordered: true` a hash ordinal — its definitions are then what the model sees as
the levels, and the distribution speaks the labels); `name:` is what messages print, so a
category named `name` or `ordered` goes in a positional Hash (`S1.scale({ name: "…", email: "…" })`;
beside keyword definitions `name:` is refused). Two scales are equal by kind and labels (a
nominal one as a set; definitions and name are not identity — the digest carries them); a Scale
is not an Array, and `==` against one is false (since 0.3.0 `Distribution#scale` and
`Level#scale` are an `S1::Scale`, not an Array: compare with `.to_a` / `.labels`, index with
`to_a[i]`). Labels are Strings, Symbols or Integers (a Scale, a list or a Hash beside other
labels is refused — `S1.scale(Severity)` raises), distinct and non-blank; so are the
definitions, which are text (`Team.definition(:billing)` reads one; `definitions` / `to_h` are
keyed by label String), and labels do not mix with definitions (`S1.scale("a", b: "…")` raises).
A label whose key spells a method the Level already has (`"empty"`, `"frozen"`; `"present"`,
`"blank"` under ActiveSupport) keeps that method's answer on the Level — reference it through
the scale, or a record's `<field>_<key>?`. A Level of another scale is off this one: `include?`
says false and `fetch` raises `KeyError`. A dynamic scale — `S1.scale(-> { … })` or
`S1.scale(:method)` — holds its source and reads as dynamic until `resolve(record)` — a list
resolves ordinal, a Hash nominal, unless `ordered:` said, and a Scale of the other kind than
`ordered:` said raises, as a dynamic one does (in Rails, the declaration evaluates it per
record, by the macro's kind); every other reader raises until then.
A score given a Scale beside other levels is refused, as is a choose. The inline forms
still work and build a Scale: `state.score("…", "low", "mid", "high").scale` is
`#<S1::Scale low < mid < high>`, equal to `S1.scale(:low, :mid, :high)` — the difference is where
the labels are spelled. A label whose snake-cased key collides with another's (`"A+"`, `"A-"`),
or has none (`"🔥"`), gets no key and no predicate; `Severity["A+"]` still reaches it. Marshal
keeps a Scale whole; a YAML round trip reads its categories back as plain Strings.

### Distribution

Every measurement returns an `S1::Distribution` (`Answer::Base` remains an alias): mass over
every category of the scale, summing to 1 (`probabilities`, keyed by the wire name of each
category), plus `scale` — an `S1::Scale` for a choice or a score, `[true, false]` for a noul —
and `kind` — the scale kind by its wire name. *Wire* is what crosses to and from a provider; wire names are the provider's,
the rest of the vocabulary is ours.

```ruby
state.judge("Is the customer angry?").scale                        # => [true, false]
state.judge("Is the customer angry?").kind                         # => "noul"
state.choose("Which team?", returns: "…", billing: "…").scale      # => #<S1::Scale returns | billing>   an S1::Scale; to_a is [:returns, :billing]; a category the wire left out has mass 0
state.choose("Which team?", returns: "…", billing: "…").kind       # => "choice"
state.score("How severe?", "low", "mid", "high").scale             # => #<S1::Scale low < mid < high>   to_a is the S1::Levels
state.score("How severe?", "low", "mid", "high").kind              # => "score"
```

## Batch: many questions, one call

A measurement is always one of the three kinds — `judge`, `choose`, `score`; the kind is part
of what a measurement is. `measure` is the plural: the same three, several at once.

```
measure  =  judge | choose | score              one measurement, one kind
measure { judge; choose; score; … }             several, one call, independent
```

Two things make the plural more than a loop. **One call**: the state goes over once, and N
questions cost one call. **Independence**: the model answers each question as if it were the
only one — one distribution is never hidden context for another. That is what makes the batch the
natural unit: several *independent* measurements of one state. It is not independence of what
they measure: `&` and `|` on the results are products of marginals, exact only when the two
properties are independent given the state — for overlapping properties, ask the conjunction as one
question. `ask`, `batch` and `ask_about` are aliases of `measure`. It is the only way to get
several distributions from one call — a verb per line is a call per line.

```ruby
result = state.measure do |q|        # ψ: (ψ text).measure do |q|
  q.judge  :escalate,   "Is the customer asking for a human agent?"
  q.judge  :repeat,     "Has the customer contacted support about this before?",
                        true: "mentions a prior attempt", false: "no sign of one"
  q.choose :department, "Which team should handle this?", returns: "Refunds", shipping: "Delays", billing: "Charges"
  q.score  :severity,   "How severe is the issue?", "Cosmetic", "Degraded, workaround exists", "Blocking"
end

result[:escalate].true?        # => true
result[:department].to_sym     # => :returns
result[:severity].level        # => "Blocking"
result.distributions           # => { escalate: #<S1::Answer::Noul …>, … }   (result.answers still works)
result.usage                   # => { input_tokens: 490, output_tokens: 86 }
result.duration_ms             # => 398
```

Ask **speculatively**: include questions whose answers you only need conditionally, then let
your code decide which to use. That keeps it to one call.

```ruby
r = state.measure do |q|             # ψ: (ψ text).measure do |q|
  q.judge :is_lead,  "Is there a potential new case or matter?"
  q.judge :qualified, "Is this a qualified lead, based on `firm.criteria`?"
  q.judge :prior_rep, "Does the lead already have an attorney?"   # asked regardless,
end                                                               # used only when relevant

if r[:is_lead].true? && r[:qualified] >= 0.85
  flag_conflict if r[:prior_rep].true?
end
```

## Structured state and structured questions

A state can be a string, or a hash/array (braced — bare keywords to `State.new` are options,
not evidence). A measurement is not evidence either: a distribution or a `Result` placed in the
state or a lens is refused (`ValidationError`) — put its `collapse` or its `probabilities` there.
With a hash, instructions can point at fields with backticked paths:

```ruby
state = S1::State.new({
  transcript:   utterances,
  case_details: { date_of_incident: "2026-08-15", sol_deadline: "2027-08-15" }
})

state.judge?("Judging from `transcript` and `case_details.sol_deadline`, is the claim still within the statute of limitations?")
# ψ: (ψ({ transcript: utterances, case_details: {...} })).is? "still within the statute of limitations, judging from `transcript` and `case_details.sol_deadline`"
```

The hash is rendered once, when the state is built — `state.rendered` is that value, frozen —
so appending to `utterances` afterwards does not change what any later question sees.

Instructions can be structured too — the verification pattern:

```ruby
state = S1::State.new({ source_text: "Invoice #4471 issued March 3, 2026 to Beaver Dam Logistics for $12,840.00, net 30." })

state.judge?({ field: { name: "invoice_number", type: "string", description: "The identifier printed on the invoice." },
               extracted_value: "4471",
               question: "Does `extracted_value` match the `field` as it appears in `source_text`?" })
# ψ: (ψ({ source_text: "…" })).judge?({ field: …, extracted_value: "4471", question: "…" })
```

## Reading distributions

All distributions carry `probabilities` and `confident?`; use it to route — act automatically when
confident, escalate to a person or a reasoning model when not. Choice and score distributions carry
the provider's `confidence`, and `confident?(at)` is that confidence at or above `at` — and true when
the provider reported none (`confidence` is nil), so read `confidence` itself to escalate those. A noul has
no separate confidence — distance from the threshold is it: `confident?(margin = 0.1)` is at least
`margin` away from the threshold (its own, or `threshold:`), on either side; `undecided?` is its
exact complement, and `decided?` is its alias — the name that says the positional is a margin, not
the floor `confident?(at)` takes on a choice or a score. (The positional is the margin: the pre-theory `confident?(threshold)`,
`p >= t || p <= 1 - t`, was symmetric about 0.5, not about the threshold the noul was measured
under, and is gone — `confident?(0.8)` on a 0.85 noul is now false, 0.35 from a 0.5 threshold
being under that margin.)

| distribution | reads as |
|---|---|
| `Answer::Noul` | `to_f`, `true?` / `false?`, compares to numbers (`a >= 0.85`) |
| `Answer::Choice` | `to_sym`, `to_s`, `[category]`, `== :returns`, `ranked` |
| `Answer::Score` | `level` (an `S1::Level`), `key`, `to_f`, `levels` |

```ruby
dept = result[:department]
if dept.confident?(0.8)
  route_to(dept.to_sym)
else
  hold_for_review(dept.probabilities)
end
```

## Experimental: making it native

Everything above works through `S1::State`. The pieces below are opt-in — off by default,
each behind its own config switch — and exist to make asking a question feel native to the
language. Use them where they read better; leave them off where a codebase would rather not
extend core classes.

**The core extension.** `c.primitives = true` extends `String`, `Hash` and `Array` with
`judge` / `judge?` (`noul`, `noul?`, `ask?`), `choose` / `choice`, `score` / `level` and
`measure` (`ask`, `batch`, `ask_about`). A class's own method with one of those names always
wins, since the module is included beneath it. `to_s1` gives the State, for per-call options.

```ruby
S1.configure { |c| c.primitives = true }      # String, Hash, Array; or a subset: [String]
require "s1/core_ext"                                # equivalent, require-style

"Can I speak to a person?".judge? "the customer is asking for a human agent"
{ ticket: text }.choose "Which team?", returns: "Refunds", billing: "Charges"
chat.measure { |q| q.judge :escalate, "..." }
chat.to_s1(threshold: 0.9).judge?("...")             # the State, for per-call options
```

**ψ.** `c.psi = true` defines **ψ** on `Kernel`, like `Integer()` or `Pathname()`: anything
becomes a State. ψ prepares; the verbs measure; the `?` on whatever follows is the collapse. Any
identifier works in its place (`c.psi = "⍣"`). Anything that defines `to_s1` converts itself —
that is how a typesafe-rails record becomes its default form. The explicit spelling is
`S1.to_state(x)` — `x.to_s1` when `x` defines it, otherwise `S1::State.new(x)`.

Is that just `is?` for the sake of reading like English? No — ψ is the convention the rest of
this section hangs off:

- **any object**, not the three core classes the extension covers: a record, `params`, a `Mail::Message`,
  a Struct, a Time — `(ψ mail).is? "an out-of-office reply"`;
- **options at the point of asking** — `(ψ text, threshold: 0.95)`, `provider:`, `model:`,
  `owner: phone_call` for the ledger, `metadata: { call_type: "routing" }` for why it was asked ([Observing calls](#observing-calls));
  on a verb — `measure` included — `given:` is the fluent `.given(…)` inline
  (`choose("…", a: "A", given: { p: 1 })`, `(ψ text, given: { p: 1 })`, `(ψ state, given: { p: 1 })`), and `threshold:` belongs to a collapse alone
  (`judge?`, `is?`, `same_as?` — on `choose` / `score` / `judge` / `measure` it is an `ArgumentError`, never an option);
- **a state** — `state = (ψ x)` is rendered once and asked many times; nothing about `x` is re-read
  between questions, and mutating `x` afterwards changes nothing the state will be asked about;
- **the English forms** that live only on `State`: `is?`, `is`, `same_as?`, `same_as`;
- **no monkeypatching** — one private `Kernel` method; `c.primitives` can stay off and code still
  reads as sentences.

```ruby
(ψ"Michael").is? "a man's name"          # => true
(ψ"Michael").is "a man's name"           # => 0.98
(ψ text).is? "a man's name"              # a variable needs the space: ψtext is one identifier
```

That is all ψ does: `(ψ x)` is `S1.to_state(x)` — `x.to_s1` when `x` defines it, otherwise
`S1::State.new(x)` — and `ψ.` with no evidence builds a
[predicate](#collections-judgments-as-predicates). It takes no block.

**Pattern matching.** A batch `Result` deconstructs: nouls as booleans, each at its threshold, choices as
symbols, scores as Levels — which match an integer range and a label alike — so Ruby's own
`case … in` is the gate logic.

```ruby
case (ψ chat).measure { |q| q.judge :escalate, "…"; q.choose :department, "…", returns: "…", billing: "…"; q.score :severity, "…", "low", "mid", "high" }
in { escalate: true, severity: 2.. }  then page_someone
in { department: :billing }           then route_to_billing
else                                       hold_for_triage
end
```

**Semantic equality — with the right operator.** `(ψ "Acme Inc").same_as? "ACME, Incorporated"` asks
"Do `this` and `other` describe the same thing?" (`same_as` for the distribution). The operator
form is `===`, case equality — Ruby's "does this match?", the one `Range`, `Regexp` and `Proc`
define, called only in explicit matching contexts:

```ruby
case vendor.name
when (ψ "Acme Inc") then merge_into(acme)
end

names.grep(ψ "Acme Inc")            # every name that describes the same company
names.any?(ψ "Acme Inc")
```

Not a regex. A regex (or `similarity()`) compares strings; `same_as?` compares what the strings
are about. Two calls about one accident, transcribed a week apart:

```ruby
transcript = "Caller: Hi, this is Juan, I was rear-ended on Michael Street on the fifteenth, my neck hurts, the other driver ran the light."
recent     = ["Caller: John here, calling back about my accident on Manor Street, August 15th, the guy went through the red light and hit me from behind.",
              "Caller: This is Maria, I slipped at the grocery store on Manor Street last week and hurt my knee.",
              "Caller: Juan Perez, I want to know if you handle wills."]

recent.any?(ψ transcript)                             # => true   (one run: 0.67 / 0.03 / 0.06)
recent.any? { |t| t =~ /Juan.*Michael Street/ }       # => false  — "John", "Manor Street", "August 15th"
```

Juan/John and Michael/Manor are transcription noise; "the fifteenth" and "August 15th" are the same
day; the third caller shares the name and nothing else. No pattern over characters gets that
right, and every regex you tighten toward one case breaks another. One call per candidate, so
narrow with SQL first (same firm, same week, same phone) and ask about the survivors.

Why not `==`? Ruby calls `==` for you — inside `Hash#[]`, `Array#include?`, `uniq`, RSpec's `eq` —
so a model-backed `==` puts a network call, a cost and a non-deterministic answer into every one of
those, and `==` is expected to be reflexive, symmetric and transitive, which a judgment is not.
`===` carries none of that: it is only ever a question about a match. `==` on a State is plain Ruby equality — never a model call.

**Aliases.** The batch is `measure`, `ask`, `batch` or `ask_about` — `(ψ chat).ask_about { |q| … }` reads
best when the state is right there. Every alias is a plain Ruby `alias`; see the [dictionary](#dictionary-and-aliases).

Typing ψ on macOS: add the *Unicode Hex Input* keyboard (System Settings → Keyboard → Input
Sources → +), switch to it, then hold Option and type `03C8`.

**Explicit vs native.** Every form has an explicit spelling; the native one is the same call
with the plumbing removed.

| you want | explicit | native |
|---|---|---|
| a yes/no | `S1::State.new(text).judge?("Is the customer angry?")` | `(ψ text).is? "angry"` · `text.judge? "…"` |
| the noul | `S1::State.new(text).judge("…")` | `(ψ text).judge "…"` |
| the probability | `S1::State.new(text).judge("…").to_f` | `(ψ text).judge("…").to_f` |
| one of a set | `S1::State.new(text).choose("Which team?", returns: "…", billing: "…")` | `text.choose "Which team?", returns: "…", billing: "…"` |
| the category alone | `S1::State.new(text).choose("…", **cats).to_sym` | `text.choice "…", **cats` |
| a level on a spectrum | `S1::State.new(text).score("…", *levels).level` | `text.level "…", *levels` |
| the best of a list | `S1::State.new(list).choose("the best", categories: labels)` | `(ψ list).choose "the best", categories: labels` |
| several at once | `S1::State.new(text).measure { \|q\| … }` | `(ψ text).measure { \|q\| … }` · `text.measure { \|q\| … }` |
| filter a stream | `list.select { \|x\| S1::State.new(x).judge?("…") }` | `list.select(&ψ.is?("…"))` |
| bucket a stream | `list.group_by { \|x\| S1::State.new(x).choose("…", **cats).to_sym }` | `list.group_by(&ψ.choice("…", **cats))` |
| rank a stream | `list.sort_by { \|x\| S1::State.new(x).score("…", *levels).to_f }` | `list.sort_by(&ψ.score("…", *levels))` |
| the same thing? | `S1::State.new({ this: a, other: b }).judge?("Do this and other describe the same thing?")` | `(ψ a).same_as? b` · `case b when (ψ a)` |
| against a lens | `S1::State.new({ this: x, prefs: p }).judge?("… per prefs")` | `(ψ x).given(prefs: p).is? "… per prefs"` |

**What Ruby will not do.** `ψ"Michael".is? "…"` without parens is one method call whose argument is
`"Michael".is?("…")` — the dot binds before any prefix, symbol or operator — so the parens around the
evidence are load-bearing: `(ψ"…")`, `(ψ text)`. A hash literal needs its own parens too — `(ψ({ … }))` — because
`ψ { … }` is a block to Ruby, and ψ takes none. And `is?` (the English form: "Is this …?") lives on `State` only, never on
core classes, where it would sit beside equality methods.

## Keeping the probability: collapse late

Collapse is one operation, and it is lossy. The measurement returns a distribution; turning it
into a boolean, a symbol or a level throws the rest away. Both layers are tools, and the
convention that separates them is Ruby's own: **no `?` keeps the probability, `?` collapses.**
`collapse` is the same step with a name, for when you want to see it. There is no second symbol
for it because Ruby already has one — the trailing `?` — and a reader who has never seen this
gem reads `judge` / `judge?`, `is` / `is?` correctly (see [The idea](#the-idea-collapse)).

**What the collapse hides.** Three calls, one question, one boolean each:

```ruby
clear = "I was rear-ended yesterday, the other driver ran a red light and got a ticket, my neck hurts."
murky = "there was a fender bender, not sure who was at fault, I feel a bit sore maybe."
none  = "I want to know your office hours."

(ψ clear).judge "Does the caller have a viable injury claim?"    # => 0.84   collapse → true
(ψ murky).judge "Does the caller have a viable injury claim?"    # => 0.52   collapse → true
(ψ none).judge  "Does the caller have a viable injury claim?"    # => 0.03   collapse → false
```

`clear` and `murky` collapse to the same `true`. What the boolean threw away: that one is a
case and the other is a coin flip — the difference between "call them now" and "have someone
look". `(ψ murky).judge(…).undecided?(0.15)` is `true`; `collapse` cannot say so. Every
downstream count, dashboard and decision built on the booleans inherits that erasure. The
distribution is the information; the collapse is a summary of it — take it last.

**The five conventional ways to use the distribution** — three keep it, and are plain Ruby;
two end it, and are `?`s:

| | you write | what it is |
|---|---|---|
| compose | `r[:is_lead] & r[:qualified] & ~r[:prior_rep]` | products of marginals, exact only for independent properties — keeps the distribution |
| route | `case p when 0.85.. then … when 0.5...0.85 then … else … end` | `Comparable` + ranges — keeps it |
| count | `calls.sum(&ψ.judge("…"))` | expected count from calibrated probabilities — keeps it |
| abstain | `p.undecided?(0.1)` → hand off | a `?` whose answer is "not by me" |
| collapse | `p.collapse`, `p.true?`, `judge?`, `is?`, `choice`, `level` (an `S1::Level`), `r.collapse` / `r.to_h`, `case r in { … }` | the decision — ends it |

```ruby
r = (ψ transcript).measure do |q|
  q.judge :is_lead,   "Is this a potential new personal-injury client?"
  q.judge :qualified, "Was the caller not at fault and injured?"
  q.judge :prior_rep, "Does the caller already have an attorney?"
end
```

**Compose before you collapse.** `&` both, `|` either, `~` not — products of marginals. jev
documents batched distributions as independent in the sense that no answer is context for another;
the products are exact only when the two properties are independent given the state, which the
provider does not promise. For overlapping properties (`is_lead` and `qualified` nest), ask the
conjunction as one question.

```ruby
viable = r[:is_lead] & r[:qualified] & ~r[:prior_rep]     # still a Noul
r[:is_lead] & 0.5                                           # a number in 0..1 is a marginal already known; nil or true raises
```

**Route on the number, not the bit.** A Noul compares like a Float, so `case`/`when` with
ranges is the routing table — three outcomes from one probability, where a boolean gives two.

```ruby
case viable
when 0.85..      then call_now        # act automatically
when 0.5...0.85  then queue_review    # a person decides
else                  archive
end
```

**Abstain near the threshold.** `undecided?(margin)` is "too close to call": hand off instead of
collapsing. `decided?(margin)` — `confident?(margin)` is the same method — is its exact complement
on a noul; `confident?(at)` is the counterpart for choices and scores, a floor on the provider's
confidence rather than a margin.

```ruby
return hold_for_human if viable.undecided?(0.1)
```

**Count without collapsing.** A sum of calibrated probabilities is an expected count; a count of
collapsed booleans rounds every 0.6 up and every 0.4 down.

```ruby
calls.sum(&ψ.judge("Is the customer angry?"))     # => 37.4 expected angry calls
calls.count(&ψ.is?("an angry customer"))          # => 41, with the rounding baked in
```

**Then collapse, explicitly.** `collapse` on a distribution or a whole `Result`; `?` on a method;
`!!` on a noul (`!noul` is "not true at the threshold"); `case … in { escalate: true }` on a
batch. All four are the same step. What is *not* a collapse: a bare `if noul` — Ruby's `if`
never calls `!`, so a distribution is always truthy there.

```ruby
viable.collapse            # => true          (at the noul's own threshold — the State's, else the config's when measured — or pass one)
viable.collapse(0.9)       # => false
r.collapse                 # => { is_lead: true, qualified: true, prior_rep: false }   (r.to_h is the same)
```

A choice collapses to its Symbol, a score to its `S1::Level` (the label, ordered by position),
and a `Result` to a Hash of all three.

## Collections: judgments as predicates

S1 models are at their best over *streams* — transcripts, tickets, candidates, calls — where
each item gets the same typed question and the distributions are calibrated enough to filter,
bucket, rank and count on. This section is the data-science surface: `Enumerable` with
judgments in the blocks.

ψ with no argument is a question not yet applied to a state — a **predicate**, with `to_proc` and
`===`, so it goes wherever Ruby expects a block or a pattern. Applied to an element it follows
the naming rule: a verb yields one distribution per element — `judge` a noul (which sums as its
probability), `choose` a choice (which buckets by category), `score` a score (which sorts by
expected position) — a noun the thing it names (`choice` the Symbol, `level` the `S1::Level`,
so `group_by` keys by category or label), a `?` a boolean. `measure(x)` on a predicate is the
distribution under any name. A verb in a boolean slot is always truthy — a distribution is
never `false` — so `select`, `grep`, `count`, `find` and `partition` take the `?` form; `sum`
and `sort_by` take the verb; `group_by` takes the noun.

```ruby
angry = ψ.is?("an angry customer")

calls.select(&angry)                                   # filter        (or calls.grep(angry), via ===)
calls.partition(&ψ.is?("a new matter"))
calls.count(&ψ.judge?("Was it resolved on the call?"))
inbox.find(&ψ.is?("a cancellation request"))

calls.group_by(&ψ.choice("Which team?", returns: "Refunds, exchanges", shipping: "Delivery, damage", billing: "Charges"))
# => { returns: [...], shipping: [...] }               # classify

tickets.sort_by(&ψ.score("How urgent?", "can wait", "today", "right now")).reverse   # rank
tickets.max_by(&ψ.score("How severe?", "cosmetic", "degraded", "blocking"))

calls.sum(&ψ.judge("Is the customer angry?"))          # => 2.0   expected count, no threshold
calls.sum(&ψ.judge("…")) / calls.size                  # share

calls.each_with_object([]) { |c, seen| seen << c unless seen.any?(ψ c) }   # dedupe, via ===
```

**The lens.** A stream is judged *against* something — a firm's acceptance criteria, a role's
requirements, a return policy. That is the lens, and it attaches to the state: `given` (or
`against` — "judged against") puts the element under `this` and the lens beside it, so
instructions can name both (a lens keyed `this`, or `other` on `same_as`, is refused — it would
replace the facts). It is distinct from the definition, which attaches to the question:
`true:`/`false:` on a noul, the descriptions of a choice, the levels of a score. (In
typesafe-rails a form does the lens's job: `measurable_as(:qualification) { { transcript:, preferences: } }`.)

```ruby
qualifications = { must_have: ["5+ years Ruby", "shipped a Rails app"], disqualifiers: ["cannot work US hours"] }

qualified = ψ.is?("qualified for the role, per `qualifications`", given: { qualifications: qualifications })
candidates.select(&qualified)                                                # => Michael, Dana

candidates.group_by(&ψ.choice("Per `qualifications`, which bucket?",
                              qualified: "meets every must_have, no disqualifier",
                              disqualified: "hits a disqualifier",
                              unclear: "not enough information",
                              given: { qualifications: qualifications }))    # => { qualified: [...], disqualified: [Bob] }

S1::State.new({ candidates: candidates, qualifications: qualifications })
  .choose("the candidate most qualified per `qualifications`", categories: %w[Michael Bob Dana]).ranked   # one call
```

Same shape for intake: calls stream → the firm's qualification preferences → qualified /
disqualified / unclear, and every other judgment the firm configures.

Two of these deserve a note. **Expected counts**: nouls are calibrated probabilities, so their sum
is the expected number of positives — a fractional headcount with no cutoff bias, where
`count(&ψ.is?(…))` would round every 0.6 up and every 0.4 down. **Ranking a set** is one call, not
N: `choose` over the items returns a distribution over all of them, and `ranked` reads it out.

```ruby
S1::State.new(calls).choose("the call most likely to become a chargeback").ranked
# => [:"Caller: …", …]   the transcripts as Symbols, most likely first; one call for the whole list
candidates.choose("the most qualified for this role", categories: names).ranked.first   # add given: for the role's requirements
```

Cost model: every `&predicate` is one call per element (~400ms, run in parallel where you can —
typesafe-rails' `where_judged` takes `concurrency:`); prefer one `choose` over the items when the
question is "which of these", and reserve per-element predicates for "which of these are".

**One question, one or many.** A predicate is the question as a value, so define it once and
apply it to a single state with `[]` (what `Enumerable` sees: the distribution for a verb, the thing
named for a noun, a boolean for a `?`) or `measure` (always the distribution), and to a stream with
`&`. No question text is written twice.

```ruby
team  = ψ.choice "Which team?", returns: "Refunds", support: "Product help", billing: "Charges"
angry = ψ.judge  "Is the customer angry?"

team[ticket]                          # => :returns
team.measure(ticket).probabilities    # => { "returns" => 0.91, "support" => 0.09, "billing" => 0.0 }
tickets.group_by(&team)               # => { returns: [...], support: [...] }

angry[ticket]                         # => Answer::Noul, 0.98
tickets.sum(&angry)                   # => 2.29
```

Predicates are built by `ψ` with no argument, or without ψ by `S1.predicates`.
Inside `select(…)`, write the predicate with parentheses — `&ψ.is?("…")` — Ruby's grammar does not
allow a command call after `&`.

## Dictionary and aliases

The terms are defined in [THEORY.md](THEORY.md); this is the short form, with the code names.
The classes, one per idea:

```
ψ(x)         S1::State            the state — judge · choose · score · measure
             S1::Predicate        a question not yet applied to a state (ψ.is? "…"), for select / group_by / sum
             S1::Question::*      the question on the wire: Noul | Choice | Score
             S1::Providers::*     who measures (TypeSafe's jev, Protocol, cua-s1-forms, the Stub)

measure →    S1::Distribution     what comes back: mass over the scale, and collapse
               Answer::Noul         the dichotomous distribution    collapse → true / false   (the `?`)
               Answer::Choice       the nominal distribution        collapse → the category, a Symbol
               Answer::Score        the ordinal distribution        collapse → the level (S1::Level)
               Result               several, from measure { }       collapse → { id => value }; pattern-matches
             S1::Level            the label, a String that knows its position on the scale
             S1::Scale            the scale as a value: the labels, ordered or not, with their definitions (S1.scale)
```

Evidence is prepared into a state; a state is measured by a question; measuring returns a
distribution over a scale; collapsing picks a category.

| term | meaning | code |
|---|---|---|
| **evidence** | the particular — a transcript, a record, a list of candidates — before any presentation | any object |
| **state** | the evidence as presented for judgement: rendered once, fixed, with its lens attached. Whatever the rendering omitted does not exist to the judgement | `S1::State.new(x)` (`Subject` is an alias); `ψ(x)` with `c.psi = true`; `x.to_s1`; `rendered` is the value |
| **distribution** | the product of a judgement: mass over every category of the scale, kept whole; `scale`, `kind`, and on nominal and ordinal scales a confidence | `S1::Distribution` (`Answer::Base` is an alias): `Answer::Noul` / `Choice` / `Score` |
| **category** | one point on the scale — the verdict; what the program acts on. Spelled as a bare literal it is unchecked; referenced through the scale (`Severity[:degraded]`, `lvl.degraded?`) a rename fails where it is used | a boolean, a Symbol, an `S1::Level` |
| **prepare** | ψ — makes evidence measurable: renders once and attaches the lens. Measures nothing | `S1::State.new`, `ψ(x)`, `to_s1`, a Rails form |
| **measure** | the judgement: the degree to which the state falls under each category of a scale, in one provider call. Named by scale kind (judge, choose, score) or generically when several questions share a state | `judge` / `choose` / `score`; `measure` (`ask`, `batch`, `ask_about`) for a batch, a `Result` |
| **collapse** | the decision rule: the distribution becomes one category. The moment information is discarded, so the moment to postpone | `collapse(threshold)` on every collapsable; `?`, `!!`, `case … in` |
| **rendering** | the function from evidence to state — what is shown, in what shape; done once at preparation | `S1::Rendering.render`: Strings copied, Hashes and Arrays rebuilt and frozen |
| **lens** | evidence added to the state to judge *against*; makes the judgement relative | `given(…)` / `against(…)`; `given:` on any verb (`measure` too), predicate, or `State.new` |
| **question** | a concept on a scale, with its definition; immutable; the wire form | `S1::Question::Noul` / `Choice` / `Score`: `{ type, instructions, criteria }` |
| **scale** | the finite set of categories: dichotomous `{ true, false }`, nominal (unordered), ordinal (ordered). Three kinds, only three. A value — the labels with their definitions — that a category is a point on | `S1::Scale`: `S1.scale(*labels)` ordinal, `S1.scale(**definitions)` nominal, `S1.scale(-> { … })` dynamic; `[]`, `fetch`, `===`, `keys`, `definitions`; `Distribution#scale`, `Level#scale`; a choice's `categories` are the labels; a question's `levels` are the texts shown (the labels when the scale has no definitions), a distribution's `levels` the Levels |
| **definition** | the working definition of the scale — what counts as yes, what each category means, the ordered levels. Attaches to the question; *criteria* is the wire word | `true:` / `false:` on a judge; `categories:` (or the wire word `criteria:`) on a choose; `*levels` on a score; a Scale's `definitions` |
| **choosing among the evidence** | when the state is itself the set of candidates — a list of labels, or label → description — its labels are the scale | `names.choose "the most skilled"` — `names` the labels themselves, `%w[Michael Bob]`: an Array of Strings, or a Hash with String keys and all-nil or all-String values; a Symbol-keyed Hash is a record and takes `categories:` |
| **calibration** | the axiom: 0.7 means seven in ten such judgements are true; what licenses arithmetic before collapse (sums, thresholds; `&` / `|` only for properties independent given the state) | the provider contract — untestable offline, with batch independence |
| **collapsable** | anything that holds a distribution and can collapse | `S1::Collapsable`: every distribution, and a `Result` elementwise |
| **confidence** | a scalar the provider reports beside a nominal or ordinal distribution, derived from the distribution's shape (jev) or the winning mass (cua) — it carries nothing the masses do not; a noul has none — distance from the threshold is it | `confidence`, `confident?(at)` — a floor; on a noul `confident?(margin)` / `decided?`, the complement of `undecided?` |
| **threshold** | the parameter of the dichotomous decision rule — the mass at or above which "true" is the verdict; travels with the measurement, stamped at measure (the config's when none was given) | `S1.config.threshold`, `S1::State.new(x, threshold: 0.9)`, `judge?("…", threshold: 0.9)`, `Answer::Noul#threshold` |
| **level** | a point on an ordinal scale — a label with a rank, on a scale it knows | `S1::Level`: a String with `position` (`to_i`), `scale` (an `S1::Scale`; `labels` the Strings), a predicate per label (`lvl.blocking?`); compares by rank on its own scale, across scales `<=>` raises; matches integer ranges and labels; keep it on the left of a comparison with a label |
| **noul** | the dichotomous distribution, by its proper name — the product of a judge; also the wire name of the kind | `Answer::Noul`; `x.noul(q) == x.judge(q)`; `noul?` is `judge?` |
| **choice** | the category a choose picked | `Answer::Choice#choice`, a Symbol; `x.choice(q, …) == x.choose(q, …).collapse` |
| **predicate** | a question not yet applied to a state; applied to each element of a stream a verb yields one distribution per element, a noun the thing it names, a `?` a boolean | `ψ.is?(…)`, `ψ.judge(…)`, `ψ.choose(…)`, `ψ.score(…)`, the nouns `ψ.choice`, `ψ.level`; `S1.predicates`; `to_proc`, `===`, `[x]`, `measure(x)` |
| **stream** | many particulars under one question; filtering, ranking, bucketing and counting are the collection's own operations | any `Enumerable` with `&predicate` |
| **form** | a named rendering of a persistent particular | typesafe-rails `measurable_as(:name) { … }` |
| **provider** | an implementation of *measure* that honours calibration; owns its transport and wire format | `call(Request) → Result`: `:typesafe`, `:protocol`, `:cua`, the `Stub` |
| **result** | a batch of distributions from one measure, plus telemetry | `S1::Result`: `distributions` (`answers` is an alias), `usage`, `model`, `provider`, `duration_ms`, `raw` |
| **request** | what a provider receives: rendered state, questions, options | `S1::Request` |
| **wire** | what crosses to and from a provider; wire names are the provider's, the rest are ours | `noul`, `choice`, `score`, `criteria`, `answers`; `Distribution#raw` keeps the payload |
| **core extension** | String, Hash and Array as receivers of the verbs — sugar | `c.primitives = true`, or `require "s1/core_ext"` |
| **psi** | the setting that installs ψ | `c.psi = true` (`c.symbol` is an alias), or any identifier |

Aliases are plain Ruby `alias`es, so a class's own method with the same name always wins.

## Errors

Rescue by intent, not by HTTP code:

```ruby
begin
  result = state.measure { |q| ... }
rescue S1::TransientError => e     # RateLimitError, ServerError, ConnectionError, TimeoutError — retry later
  retry_later(e)
rescue S1::PermanentError => e     # AuthenticationError, InvalidRequestError, ValidationError — fix the request
  raise
end
```

Transient failures already retry inside the provider (`c.typesafe.max_retries`, honoring `Retry-After`) before surfacing.

## Testing

`Providers::Stub` answers without the network. Give it the distributions that matter; everything
else gets a neutral default (noul 0.5, the first category, the first level).

```ruby
S1.configure do |c|
  c.provider = S1::Providers::Stub.new(escalate: 0.9, department: :billing, severity: 2)
end
```

Single-question calls are keyed by the wire name of their kind — `noul` (for `judge`, `judge?`,
`is?`, `same_as?`), `choice`, `score`: `Stub.new(noul: 0.9, choice: :billing, score: 2)`. A
score's shorthand is a position, a label (`"blocking"`, `Severity[:blocking]`) or the text
shown; a choice's the category. The full fields — `{ probability: }`, `{ choice:, probabilities:, confidence: }`, `{ legend:,
probabilities:, confidence: }` — are taken as a Hash, kept whole as the distribution's `raw`; a
score's expectation is derived from the masses, so a `score:` or `expectation:` in it is read
only from `raw`.

A block form receives the request when a distribution should depend on the state:

```ruby
S1::Providers::Stub.new { |req| { escalate: req.state.include?("real person") ? 0.95 : 0.1 } }
```

## Observing calls

Hook every completed call for telemetry or a cost ledger. Extra keyword arguments to
`State.new` ride along on the request, so you can attribute a call to its owner:

```ruby
S1.on_result do |result, request|
  Ledger.record(owner: request.options[:owner], model: result.model, **result.usage)
end

S1::State.new(transcript, owner: phone_call).judge?("...")
# ψ: (ψ transcript, owner: phone_call).is? "…"
```

### metadata: why the call was made

`metadata:` is the caller's label for a call — a Hash on the request as `request.metadata`
(`{}` when none), for ledgers, logs and traces. It is never sent to the provider or shown to the
model. Set it on a state, add to it with `with(metadata:)`, or pass it to any verb; each merges
over the last, key by key:

```ruby
S1.on_result do |result, request|
  AiCosts.create!(request_name: request.metadata[:call_type] || "unlabelled", model: result.model,
                  input_tokens: result.input_tokens, output_tokens: result.output_tokens)
end

state = S1::State.new(transcript, metadata: { call_type: "triage" })
state.judge?("Is the caller asking for a human?")                        # { call_type: "triage" }
state.choose("Which team?", returns: "…", billing: "…", metadata: { queue: "night" })
                                                                         # { call_type: "triage", queue: "night" }
```

It holds JSON's values only — strings, symbols, numbers, booleans, nil, and arrays or hashes of
them, keys symbolized — checked when set, so it survives a background job and a log line
(`S1::ValidationError` otherwise). Put an object you want to attribute to in `owner:`.

## Providers

A provider is the code that talks to a model: any object responding to `call(request) → Result`.
The gem owns the shape — `Request`, `Question`, `Distribution`, `Result`, the method signatures
on `State`, the error taxonomy; a provider owns only translation: how the state and questions go
on the wire, how answers come back as distributions, how failures map to `TransientError` /
`PermanentError`. A provider declares which question kinds it answers (`supports?`); the rest
are refused before any call (`UnsupportedError`). Configure by name — `:typesafe` resolves to
`S1::Providers::TypeSafe`, built from its section of the config — or pass an instance.

```ruby
S1.configure { |c| c.provider = :typesafe }
S1::State.new(text, provider: MyProvider.new)   # per-state override   ψ: (ψ text, provider: MyProvider.new)
```

Four ship. TypeSafe and Protocol share the System One HTTP contract. TypeSafe is jev, hosted.
Protocol is for Laya or any self-hosted server. Cua and Stub share nothing with them but the
distributions:

| provider | what | kinds | transport |
|---|---|---|---|
| `TypeSafe` | TypeSafe's jev, hosted | noul, choice, score | HTTPS `/v1/systemone` |
| `Cua` | [cua-s1-forms](https://huggingface.co/cua-ai/cua-s1-forms), a 2.8 MB jev-like option scorer for GUI forms | choice | a local Python sidecar over stdin/stdout (`support/cua_s1_sidecar.py`; needs `cua-s1` + torch, checkpoint as safetensors + json) |
| `Protocol` | Laya, or any self-hosted server | noul, choice, score | HTTP to a `base_url` and `path` you set (`path` defaults to `/v1/systemone`) |
| `Stub` | canned distributions for tests | all | none |

```ruby
S1.configure { |c| c.provider = :cua; c.cua.checkpoint = "cua-s1-forms" }
S1.configure { |c| c.provider = :protocol; c.protocol.base_url = "http://127.0.0.1:8765" }   # Laya, or any self-hosted server
S1.configure { |c| c.provider = :protocol; c.protocol.base_url = "http://localhost:3005"; c.protocol.path = "/sysone" }
S1::State.new('ELEMENT Edit "Phone number"').choose("Fill the form: which entity?", phone: "555-0100", email: "a@b.c", skip: nil)
```

Translation Cua owns, as an example of what a provider decides: the context string is in the
checkpoint's own shape — a `TASK <text>` line, then the state on the next (as given, or JSON
for structured state), the delimiter cua-s1's `render_context` uses — with the question's
instructions as the task, the model having no other slot for the concept; a state that already
opens with a `TASK` line keeps it, the instructions spliced in after `; `, so the model never
sees two; category descriptions become
`"key: description"`; the whole context is held to the model's byte limit; the argmax is the
pick and its probability the confidence; and noul / score are refused rather than emulated —
the model is trained on form elements, not propositions.

**Writing one.** Subclass `S1::Providers::Base` and do five things: declare `settings` (its
section of `S1.config`, with defaults — `settings :name, key: default` defines `c.name.key`,
handed to `new` when the provider is named); answer `supports?(question)` honestly; implement
`call(request) → Result` by building every distribution with `distribution(id, question, raw:, **fields)` —
the only constructor, which is what makes every provider's distributions identical and keeps a
vendor's wire keys out of consumers' hands — and returning `build_result(distributions:, model:,
usage:, raw:)`; map failures onto `S1::TransientError` / `S1::PermanentError`; leave `name`
alone. Then run the conformance suite the gem ships:

```ruby
require "s1/rspec"
RSpec.describe MyProvider do
  it_behaves_like "an S1 provider", -> { MyProvider.new(client: fake) }             # all three kinds
  it_behaves_like "an S1 provider", -> { ChoiceOnly.new }, supports: %i[choice]      # or fewer
end
```

It checks the shape, not the wisdom: a `Result` that is a `Collapsable`, every id answered with
the class its kind demands, probabilities in [0, 1] summing to 1, choices keyed by category and
scores by rank whatever keys the wire used (`key` is the level's position), every distribution
carrying its question's `scale`, `collapse` yielding a
boolean / Symbol / `S1::Level`, `supports?` telling the truth, integer usage. Shape only:
calibration and batch independence are the two clauses no offline suite can test — they are the
provider's warranty. All four providers here pass it; that is the standard.

## Development

`bin/setup`, then `bundle exec rake` runs the specs and rubocop. `bin/console` opens IRB with the
gem loaded. `TYPESAFE_LIVE=1 TYPESAFE_API_KEY=… bundle exec rspec spec/s1/live_spec.rb`
hits the real API.

## License

MIT.
