---
title: "Verification Attributes"
description: "A description of Imandra's verification attributes"
kernel: imandra
slug: verification-attributes
key-phrases:
  - verification
  - attributes
  - rules
  - syntax
---

# Attributes

Attributes can be used to give Imandra verification hints, and to instruct
Imandra how it should use a proved theorem in subsequent verification efforts,
via the installation of a theorem as a "rule".

## Verification Hints

- `[@@auto]`: apply Imandra's [inductive waterfall](Verification%20-%20Waterfall.md)
  proof strategy, which combines [simplification](Verification%20-%20Simplification.md)
  (including automatic subgoaling, conditional rewriting and forward-chaining
  using previously proved lemmas, decision procedures for datatypes and
  arithmetic, etc.), and may decide to do induction. This is the most common way
  to prove a `theorem` in Imandra.

- `[@@induct <flag?>]`: apply Imandra's [inductive waterfall](Verification%20-%20Waterfall.md)
  proof strategy, but control the top-level [induction](Verification%20-%20Induction.md).
  The `<flag?>` can be one of:
  - `functional <func_name>` - perform functional induction using an induction
    scheme derived from `<func_name>`
  - `structural <args?>` - perform structural induction on the arguments
    `<args?>` if given, else on a heuristically chosen collection of variables.
    The types of the induction variables must be algebraic datatypes / variant
    types. An additive approach (linear in the total number of constructors) is
    taken for combining the schemes of individual variables into a composite
    induction scheme.
  - `structural_mult <args?>` - like `structural`, except uses a
    "multiplicative" scheme, rather than an additive one
  - `structural_add <args?>` - a synonym for `structural`

<!-- TODO -->
<!-- - `[@@otf]`: apply Imandra's [inductive waterfall](Verification%20-%20Waterfall.md) -->
<!--   proof strategy, proceeding ["onward through the fog"](../verification-induction#Onward-Through-the-Fog), -->
<!--   disabling backtracking during induction. <\!-- ? -\-> -->

- `[@@simp]` or `[@@simplify]`:
  apply [simplification](Verification%20-%20Simplification.md) to the goal before
  [unrolling](Verification%20-%20Unrolling.md).

- `[@@disable <f_1>,...,<f_k>]`: If `f_i` is a rule, instructs Imandra to ignore
  `f_i` during the proof attempt. If `f_i` is a function, instructs Imandra to
  leave the function definition unexpanded during the proof attempt. This is
  especially useful in the presence of rewrite rules about non-recursive
  functions, as such rules will typically not apply unless the relevant
  non-recursive function is disabled. Imandra might choose to ignore this hint
  if ignoring it leads to immediate closure of the goal, or to the construction
  of a valid counterexample. Note that rules and functions can be globally
  disabled, using the `#disable` directive.

- `[@@enable <f_1>,...,<f_k>]`: The dual of `@@disable`. Note that rules and
  functions can be globally enabled, using the `#enable` directive.

- `[@@apply <thm <arg_1> ... <arg_k>>]`: instantiate `thm` with the given
  arguments and add its instantiation to the hypotheses of the goal. This is
  especially useful when `thm` is not naturally useable as a `@@rewrite` or
  `@@forward-chaining` rule, but is nevertheless needed (in an instantiated
  form) to prove a given theorem.

- `[@@blast]`: apply Imandra's [blast](Verification%20-%20Blast.md) procedure, which combines symbolic
   execution and SAT-based bit-blasting. This is useful for difficult
   combinatorial problems, and problems involving nontrivial (i.e., nonlinear)
   arithmetic over bounded discrete domains.

## Rule Classes

Theorems may be installed as rules, which instructs Imandra to apply them in
certain ways during subsequent proof attempts. The development of an appropriate
collection of rules can be used to "teach" Imandra how to reason in a new
domain.

- `[@@rw]` or `[@@rewrite]`: install theorem as a [rewrite rule](../verification-simplification#Rewrite-Rules)
- `[@@permutative]`: restrict rewrite rule as [permutative](../verification-simplification#Permutative-Restriction)
- `[@@fc]` or `[@@forward-chaining]`: install theorem as a [forward chaining rule](../verification-simplification#Forward-chaining-Rules)
- `[@@elim]` or `[@@elimination]`: install theorem as an [elimination rule](../verification-waterfall#Elimination-Rules)
- `[@@gen]` or `[@@generalization]`: install theorem as a [generalization rule](../verification-waterfall#Generalization-Rules)

## Examples

```{.imandra .input}
verify (fun x y -> List.length (x@y) = List.length x + List.length y) [@@auto]
```

```{.imandra .input}
verify (fun x -> x @ [] @ x = x @ x) [@@simp]
```

```{.imandra .input}
lemma len_append x y = List.length (x@y) = List.length x + List.length y [@@auto] [@@rw]
```

```{.imandra .input}
theorem len_non_neg x = (List.length x) [@trigger] >= 0 [@@simp] [@@fc]
```

```{.imandra .input}
lemma foo = (fun x -> x @ [] = x) [@@induct x] [@@disable List.append_to_nil]
```
