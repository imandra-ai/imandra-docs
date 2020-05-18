---
title: "Verification Waterfall"
description: "A description of Imandra's Inductive Waterfall"
kernel: imandra
slug: verification-waterfall
key-phrases:
  - waterfall
  - induction
  - verification
  - simplification
  - forward-chaining
  - rewrite
  - generalization
  - elimination
  - fertilization
---
# Waterfall

Imandra's inductive _waterfall_ is the core of its automated proof capabilities,
combining many lower-level proof strategies into a synergising pipeline.
Imandra's waterfall is deeply inspired by the pioneering work of Boyer-Moore,
and adapts many of their powerful ideas for automated induction to Imandra's
typed, higher-order logic.

The architecture of the waterfall is as follows:

![Imandra Waterfall](https://storage.googleapis.com/imandra-notebook-assets/waterfall.svg)

The top level goal we're trying to prove is transformed into a clause, which then
starts "flowing" through the waterfall.

Once a step in the waterfall successfuly transforms a clause, the clause is
pushed into a "pool" and the waterfall process recurses by picking clauses
from it.

If a clause flows through the entire waterfall unchanged, the top level goal can't
be automatically proved (or refuted!), thus solving is aborted and checkpoints are
suggested, informing the user what parts of the proof Imandra may need help with
and suggesting lemmas to be proved.

If a clause is refuted, the entire waterfall process is aborted and the top level
goal is refuted, possibly with an explicit counterexample.

If a clause is proved, it simply "evaporates" and the waterfall process
continues by picking new clauses from the pool. The toplevel goal is considered
to be proved if all the clauses in the pool evaporate.

## Simplification

As the first step in the waterfall process, the
full [simplifier](Verification%20-%20Simplification.md) is applied to a clause,
making use of all enabled rewrite and forward-chaining rules, decision
procedures for algebraic datatypes and arithmetic, and performing case-splits.

Once a clause cannot be simplified further, we call it "stable under simplification"
and let it flow through the waterfall.

Simplification is in may ways the most important part of the waterfall, and the
step that most often causes a clause to evaporate or the goal to be refuted (the
only other step that can do this is the [unrolling check](#Unrolling-check), but
this is less common).

For this reason, making good use
of [rewrite rules](Verification%20-%20Simplification.md#Rewrite-Rules) in order to
control simplification is perhaps the most powerful tool Imandra gives us. Thus
it's important to spend as much time as possible teaching Imandra a good set of
rules to apply.

## Unrolling check

Once a clause is stable under simplification, [unrolling](Verification%20-%20Unrolling.md)
is applied, with the unrolling depth controlled via the `#induct_unroll` global
limit, set to `10` by default (as opposed to the default global limit `#unroll`
which is set to `100` by default).

This step does not produce modified clauses, instead it is used as a lightweight
check trying to find a contradiction and refute the (sub)goal, or in certain lucky
instances proving it and thus evaporating the clause. This check (governed by the
`#induct_unroll` limit) is also used to validate candidate generalizations and 
cross-fertilizations.

## Destructor Elimination

Destructor elimination is a step that deals with transforming the representation
of a clause using "destructor" terms into an equivalent one that uses a
"constructor" term instead.

The term _destructor_ is used to indicate a function call that "decomposes" a
variable into its components under some representation, symmetrically the term
_constructor_ is used to indicate one that "combines" all the constituent
destructor terms to form the original variable.

As a concrete example, we know we can represent a non empty list `x` as
`(List.hd x) :: (List.tl x)`. In this example we have two instances of destructors:
`List.hd x` and `List.tl`, with `::` as the constructor function.

After applying destructor elimination to a clause containing destructor terms on
`x`, all instances of `List.hd x` become a new variable `a`, all instances of
`List.tl x` become a new variable `b` and all instances of `x` itself become the
term `a::b`. All the instances of the destructors are now replaced in favor of
simple variables, and the variable that got destructed is instead replaced with
an instance of the matching constructor.

This change of representation may seem counterintuitive at first, but it's one
of the strongest heuristics that Imandra uses in order to make a goal inductible.

Imandra automatically knows how to apply destructor elimination on lists and
algebraic datatypes, and allows users to register new ones through the
introduction of elimination rules.

### Elimination Rules

An elimination rule is a theorem of the form

```
h_1 && .. && h_k ==> lhs = x
```

which Imandra can use to register a new destructor elimination heuristic for
further use.

In order for a theorem to be a valid elimination rule, `lhs` must contain at
least one function invocation (called a _destructor term_) whose arguments must
contain every variable in the goal exactly once, and `x` must appear in the
`lhs` _only_ in such destructor terms.

As a concrete example, Imandra bakes in the list destructor elimination rule which
would look like this:

```
let hd_tl_elim x =
  x <> [] ==> (List.hd x) :: (List.tl x) = x
[@@elim]
```

Since this rule is in a sense built into Imandra, evaluation of this rule will not
actually work (the entire body is simplified to true before Imandra can attempt
to recognise and extract destructors). Nevertheless, this makes for a good conceptual
example.

We can see how this rule follows the pattern described above: the `lhs` contains
two destructor terms `List.hd x` and `List.tl x` which are then combined using
`::` to form `x`.

When Imandra encounters a term matching such a destructor, provided that the
instantiations of the hypotheses can be established, it will generalize all the
instantiated destructor terms in the conjecture to new variables, and will then
replace the instantiation of `x` in the conjecture with the newly instantiated
`lhs` term.

An example of an elimination rule as used in the wild is the following, trading
a representation in terms of `difference`, for one in terms of the easier to reason
about `plus` (the actual definitions are not included here, but they are the usual
functions over Peano numbers).

```
lemma difference_elim x y =
  not (lessp y x) ==> (plus x (difference y x)) = y
[@@auto] [@@elim]
```

## Fertilization

Once a clause is stable under simplification and no more destructors can be
eliminated, the next step in the waterfall is fertilization.

This step uses equalities in the hypothesis by substituting one side of the
equality for the other in the conclusion and subsequently throwing away the
original equality hypothesis. Cross-fertilization is preferred, which is
a restriction of fertilization designed to facilitate uses of an inductive
hypothesis.

After this step is performed the resulting term is sometimes more amenable
than the original for further simplification, but the main reason why this
heuristic is important is in order to simplify the conjecture as much as
possible preparing it for induction.

If fertilization is applied to a clause that is already under induction, Imandra
prefers to perform so called cross-fertilization instead of the more general
uniform fertilization, by restricting it so that the substitution only happens
into one side of the conclusion.

## Generalization

This step attempts to generalize a conjecture into a stronger one which may be
more amenable to proof by induction. It is only automatically applied when
an ongoing proof attempt is already under a top-level induction.

Whenever common subterms appear in multiple literals Imandra attempts to
generalize them into new variables, assuming that those subterms represent
place-holders for arbitrary objects whose properties are described by the
hypotheses.

For a term to be considered eligible for generalization, it must not be
an _explicit value template_, an equality or a destructor term.

A term is an explicit value template if it a variable (actually, a Skolem
constant) such as `x`, a constant value such as `1` or `Some [1;2;3]`, or 
the application of a constructor to explicit value templates such as `A [1;x;3]`.

This generalisation process can sometimes produce goals that are "too general"
and not theorems. This is called "over generalisation." In such a case, the
proof attempt involving the generalised goal will fail. Imandra attempts to
validate candidate generalisations by via recursive unrolling (up to
`#induct_unroll`). If unrolling is able to find a counterexample to the
candidate generalisation, then the generalisation is abandoned and the subgoal
being processed is unchanged.

### Generalization Rules

A generalization rule is a theorem that can be used to restrict generalisations.

For example, consider a function `square = (fun (n : int) -> n * n)`. If Imandra
decides to generalise the term `square x` in a goal by replacing `square x` with
a fresh variable `v`, it may be desirable for Imandra to "remember" the fact
that `v` is non-negative, i.e., to adjoin an additional hypothesis stating 
`v >= 0`.

Imandra can be instructed to do this through the a generalisation rule of the
following form:

```
lemma square_gen n =
 (square n) [@trigger] >= 0
[@@gen]
```

In general, such rules may have arbitrary boolean structure.

In order for a theorem to be a valid generalization rule, it must contain at least
one term which is a function application applied to at least one of the variables
of the theorem and is marked as a _trigger_ term using the `[@trigger]` annotation.

If Imandra has decided to generalise a term `tm`, it searches through its
database of generalisation rules for the most recent rule whose trigger matches
`tm`. If such a rule is found, it is instantiated based upon the trigger match,
and the corresponding instance is adjoined as an additional hypothesis to the
generalised goal.

## Induction

Finally, once a clause reaches the end of the waterfall, all that remains to be
tried is to apply [induction](Verification%20-%20Induction.md) on it.

If an induction scheme can be found and synthesized, Imandra applies it to the
clause by instantiating `phi` in the induction scheme to the goal being considered. This produces
a single clause that is then case-split into base and inductive cases by
simplification once the clause restarts the waterfall process.
