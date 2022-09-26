---
title: "Verification Simplification"
description: "A description of Imandra's Simplification strategy"
kernel: imandra
slug: verification-simplification
key-phrases:
  - verification
  - simplification
  - forward-chaining
  - rewrite
  - generalization
  - elimination
  - permutative
expected-error-report: { "errors": 2, "exceptions": 0 }
---
# Simplification

At the heart of Imandra is a powerful symbolic simplifier and [partial
evaluator](https://en.wikipedia.org/wiki/Partial_evaluation). The simplifier is
integrated with the [inductive waterfall](Verification%20-%20Waterfall.md) (e.g., `[@@auto]`),
and is the main way in which previously proved lemmas are used during proofs,
through the automatic application of rules. The simplifier
can also be used as a pre-processing step before unrolling, via the `[@@simp]`
attribute.

As the name suggests, simplification is a process that attempts to transform a
formula into a "simpler" form, bringing the salient features of a formula or
conjecture to the surface. Simplification can also prove goals by reducing them
to `true`, and refute them by reducing them to `false`.

Notably, because the symbolic evaluation semantics of the simplifier operate on
a compact [digraph](https://en.wikipedia.org/wiki/Directed_graph) representation
of formulas and function definitions, simplification can be thought as having
[memoized](https://en.wikipedia.org/wiki/Memoization) semantics for free.

We can see an example of this by using the following naive recursive version of
the fibonacci function:

```{.imandra .input}
let rec fib n =
  if n <= 1 then
    1
  else
    fib (n-1) + fib (n-2)
```

If we try to use Imandra's simplification to search for a solution for `fib 200`,
Imandra comes back to us with a solution immediately:

```{.imandra .input}
#check_models false;;
instance (fun x -> x = fib 200) [@@simp];;
#check_models true;;
```

If, however, we tried to use normal OCaml evaluation to compute `fib 200`, OCaml
would take over 10 minutes in order to come back with a response (the
`#check_models false` command here is used to tell Imandra not to check the
instance Imandra computed using OCaml evaluation, as that requires the expensive
computation of `fib 200` via standard OCaml evaluation, which is not memoized).

<!-- TODO mention SMT decision procedures? -->

Now that we know what simplification does, let's learn about how to influence it
using rewrite and forward chaining rules.

## Rewrite Rules

A rewrite rule is a theorem of the form

```
h_1 && ... && h_k ==> lhs = rhs
```


which Imandra can use in further proofs to replace terms that match with `lhs`
(the "left hand side") with the appropriate instantiation of `rhs` (the "right
hand side"), provided that the instantiations of the hypotheses can be
established. Observe that rewrite rules are both _conditional_ (requiring in
general the establishment of hypotheses) and _directed_ (replacing `lhs` with
`rhs`). The `lhs` is also called the "pattern" of the rule.

An enabled rewrite rule causes Imandra to look for matches of the `lhs`,
replacing the matched term with the (suitably instantiated) `rhs`, provided that
Imandra can establish ("relieve") the (suitably instantiated) hypotheses of the
rule.

For example, consider the lemma `rev_len` below. This lemma expresses the fact
that the length of a list `x` is equal to the length of `List.rev x`, i.e., if
we reverse a list, we end up with a list of the same length. This rule is
unconditional: it has no hypotheses. Thus, it will always be able to fire on
terms that match its left-hand side. Notice that Imandra uses a previously
defined rewrite rule in order to prove this lemma! The lemma `rev_len` would
make an excellent rewrite rule, so we use the `[@@rw]` annotation to install it:

```{.imandra .input}
lemma rev_len x =
  List.length (List.rev x) = List.length x
[@@auto] [@@rw]
```

With this rule installed and enabled, if Imandra's simplifier encounters a term
of the form `List.length (List.rev <term>)`, it will replace it with the simpler
form `List.length <term>`.

Both the hypotheses and `rhs` can be omitted, in which case Imandra will default
them to `true`. That is, `h_1 && ... && h_k ==> lhs` is equivalent to
`h_1 && h_k ==> lhs = true` and `lhs = rhs` is equal to `true ==> lhs = rhs`.

Imandra's rewriting is:

- conditional: rewrite rules may contain conditions (hypotheses), and eligible
  rules are only applied when their hypotheses are established. Once the pattern
  of a rule has been matched, Imandra uses backward-chaining ("backchaining") to
  relieve the rule's hypotheses, recursively attempting to simplify them to
  `true` modulo the current simplification context. This is important to keep in
  mind when developing your theories: rewrite rules will not fire unless Imandra
  can simplify their instantiated hypotheses to `true`.

- oriented: given a rule whose conclusion is of the form `lhs = rhs`, rewriting
  happens by replacing the (instantiated) `lhs` with the (instantiated) `rhs`.

When adding a new rewrite rule, users should take care to orient the equality so
that `rhs` is _simpler_ or _more canonical_ than `lhs`. If it's not clear what
it means for an `rhs` to be "better" than the `lhs`, e.g., in the case of the
proof for the associativity of append `x @ (y @ z) = (x @ y) @ z`, a _canonical_
form should typically be chosen (e.g., associating to the left in this case)
and kept in mind for further rules.

By default, the `lhs` must contain all the top-level variables of the theorem
(i.e. the arguments to the _lambda term_ representing the goal). There is an
exception to this rule: if the `lhs` does not contain all the variables of the
theorem but the rule hypotheses have subterms containing the remaining free
variables, these terms can be annotated with `[@trigger rw]`, signaling Imandra
that the annotated terms should be used to complete the matching.

It's helpful to see an example where the use of `[@trigger rw]` is necessary.
Let's first define a `subset` function on lists:

```{.imandra .input}
let rec subset x y =
  match x with
  | [] -> true
  | x :: xs ->
    if List.mem x y then subset xs y
    else false
```

Let's now suppose that we want to verify the transitivity of `subset`:

```{.imandra .input}
#max_induct 1;;
verify (fun x y z -> subset x y && subset y z ==> subset x z) [@@auto];;
#max_induct 3;;
```

It looks like Imandra needs an additional lemma in order to prove this. By
inspecting the checkpoint, it looks like all we need is a rule relating `subset`
and `List.mem`. Let's attempt to prove it:

```{.imandra .input}
lemma mem_subset x y z =
  List.mem x y && subset y z ==> List.mem x z
[@@auto] [@@rewrite]
```

While Imandra was successful in proving this lemma, it raised an error while
trying to turn this lemma into a rewrite rule. As Imandra tells us, this is
because the free variable `y` does not appear in the `lhs` term `List.mem x z`.
If we, however, annotate the `subset y z` term with the appropriate `[@trigger
rw]` attribute, Imandra can then successfully turn this term into a valid
rewrite rule:

```{.imandra .input}
lemma mem_subset x y z =
  List.mem x y && (subset y z [@trigger rw]) ==> List.mem x z
[@@auto] [@@rewrite]
```

And finally, let's verify that the rewrite rule can indeed match as we expect:

```{.imandra .input}
verify (fun x y z -> subset x y && subset y z ==> subset x z) [@@auto]
```
### Permutative Restriction

The `@@permutative` annotation applies only to rewrite rules and is used to
restrict the rule so that it will only apply if the instantiated `rhs` is
lexicographically smaller than the matched `lhs`. This restriction can be
particularly useful in order to break out of infinite rewrite loops while trying
to "canonicalize" a form, for example distributing the "simplest" terms to the
left.

Let's say we want to prove the commutativity of `Peano_nat.plus` and install it as
a rewrite rule:

```{.imandra .input}
lemma comm_plus x y =
  Peano_nat.(plus x y = plus y x)
 [@@auto] [@@rw] [@@permutative]
```

Had we not restricted `comm_plus` as a permutative rule, the simplifier would have
entered a rewrite loop every time it encountered a term matching `plus <x> <y>`,
while with the permutative restriction in place, this has the effect of directing
all the "simplest" terms to the left of `plus`, which will help with making
further rewrite rules applicable and with simplification in general.

## Forward-chaining Rules

Forward chaining is the second type of rule that Imandra allows us to register
and participate automatically in proofs.

A forward chaining rule is a theorem containing a collection of _trigger_ terms
which must include all free variables of the theorem. If Imandra can
appropriately match the triggers with terms in the goal, then an instantiation
of the rule is added to the _context_. The context of a goal is not displayed in
the goal itself (i.e., when the goal is printed), but is rather used in the
background to aid the simplifier in closing branches, relieving hypotheses of
rewrite rules during backchaining, and so on.

For example, let us prove the following theorem and install it as a
forward-chaining rule:

```{.imandra .input}
lemma len_nonnegative x =
  List.length x [@trigger] >= 0
[@@simp] [@@fc]
```

Now when Imandra encounters a term of the form `List.length <term>`, the formula
`List.length <term> >= 0` will be added to the _context_ of the goal under
focus. In other words, a forward chaining rule allows Imandra to extend the
database of background logical facts it knows about a goal. These facts are made
available to the simplifier, and can thus be used to enhance simplification by
closing branches and relieving hypotheses of conditional rewrite rules.

A forward chaining rule can contain multiple _disjoint_ triggers. In this case, if
_either_ of the triggers matches, the forward chaining rule fires. For example,
the following forward chaining version of the `rev_len` rewrite rule we added
above will fire if either `List.length x` or `List.length (List.rev x)`
matches.

```{.imandra .input}
lemma rev_len_fc x =
   List.length x [@trigger] = List.length (List.rev x) [@trigger]
[@@auto] [@@fc]
```

Additionally, a forward chaining rule can contain multiple _conjoined_ triggers,
forming a _trigger cluster_. In this case, _all_ the triggers must match in
order for the forward chaining rule to apply.

To create a trigger cluster multiple terms must be annotated with
`[@trigger <x>i]`, where `<x>` is a numeric identifier common to all
the triggers in the cluster. For example:

```{.imandra .input}
theorem subset_trans l1 l2 l3 =
  (subset l1 l2 [@trigger 0i]) && (subset l2 l3 [@trigger 0i])
  ==>
  subset l1 l3
 [@@auto] [@@forward_chaining]
```

This forward chaining rule will match only if a goal contains terms that match
_both_ `subset l1 l2` and `subset l2 l3`.

It should be noted that Imandra supports _automatic trigger selection_, meaning
it's often not necessary to annotate the trigger terms manually. Imandra can
typically infer for us both simple triggers and trigger clusters. In fact for
both the single trigger examples above, we could have omitted the trigger
annotations altogether, and Imandra would have found some for us automatically.
