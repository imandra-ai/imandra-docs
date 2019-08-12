---
title: "Verification Unrolling"
description: "A description of Imandra's Unrolling strategy"
kernel: imandra
slug: verification-unrolling
key-phrases:
  - verification
  - unrolling
  - recursion
---
# Unrolling

The first tool that Imandra makes available in our verification toolbox is
recursive function unrolling, a form of bounded model checking backed by
Satisfiability Modulo Theories (SMT) solving. This technique is completely
automatic, and is in general not influenced by the presence of proved rules or
enabled/disabled functions (except with used in conjunction with the `[@@simp]`
attribute).

## Completeness

For many classes of problems, unrolling is "complete" in various senses. For
example, for goals involving only non-recursive functions, algebraic datatypes
and linear arithmetic, unrolling will always be able to prove a true goal or
refute a false goal in a finite amount of time and space. Moreover, for an even
wider class of problems involving recursive functions, datatypes and arithmetic,
unrolling is "complete for counterexamples." This means that if a counterexample
to a goal exists, unrolling will in principle always be able to synthesize one.
This relies on Imandra's "fair" strategy for incrementally expanding the
"interpretation call-graph" of a goal.

That said, part of the beauty of unrolling is that you don't need to understand
it to apply it!

## Strategy

In general, it's recommended to apply unrolling to a goal before you attempt
other methods such as the inductive waterfall (`[@@auto]`). It's amazing how
often seemingly true goals are false due to subtle edge cases, and the ability
of unrolling to construct concrete counterexamples can be an invaluable filter
on your conjectures.

## Examples

To use unrolling, we simply use the `verify` or `instance` commands.

Let's use unrolling to find an instance of two lists of integers, whose sum
equals the length of the two lists concatenated. We shall constrain the total
length of the two lists to be positive (for fun, at least 10), so we obtain
something more interesting than the simple `x=[],y=[]` solution!

```{.imandra .input}
instance
  (fun x y -> List.length (x@y) > 10
    && List.fold_left (+) 0 (x@y) = List.length (x@y))
```

Imandra was able to find a solution instantly, and reflected it into our runtime
in the `CX` module. Let's compute with it to better understand it:

```{.imandra .input}
List.length (CX.x@CX.y);;
List.fold_left (+) 0 (CX.x@CX.y);;
```

## Unrolling limits

Unrolling works by creating a symbolic call graph for the _negation_ of the goal
we've asked Imandra to `verify` (or dually the positive version of the goal in
the case of `instance`), and by iteratively extending this graph with
incremental interpretations of recursive functions, _up to a given unrolling
bound_, checking at each step for satisfiability.

The unrolling bound defaults to `100` and can be controlled globally using the
`#unroll <n>` directive, or local to a given `verify` or `instance` call using the
`~upto:<n>` parameter.

If at any step of the unrolling process the negation of our original goal is
satisfiable w.r.t. the interpreted approximations of the recursive functions,
then Imandra has found a counterexample for our original goal, which has thus
been refuted. In this case, Imandra will report `Counterexample (after m steps)`
and install the found counterexample in the `CX` module.

If, on the other hand, Imandra is able to prove that there is no counterexample
in a manner that is independent of the bound on the approximations, then our
original goal is indeed a _theorem_ valid for all possible inputs, and Imandra
will report `Theorem Proved`. This can always be done for a wide class of
theorems on [catamorphisms](https://en.wikipedia.org/wiki/Catamorphism) (e.g.,
`List.fold_right`), for example.

Otherwise, if Imandra failed to find a counterexample or proof and stopped
unrolling at the unrolling bound, we obtain a weaker result of the form
`Unknown (verified up to depth k)`, which effectively means: this may or may not
be a theorem, but there are no counterexamples up to depth `k`. Such bounded
results can nevertheless be very useful.

Let's try to understand in practice how the unrolling bound plays into
unrolling. Consider this simple function that recursively decreases an integer
until it reaches `0`, then returns `1`:

```{.imandra .input}
let rec f x =
  if x <= 0 then
    1
  else
    f (x - 1)
```

Let's verify that for all `x < 100`, the function will return 1:

```{.imandra .input}
verify (fun x -> x < 100 ==> f x = 1)
```

But watch what happens if we ask Imandra to verify this for `x < 101`,
thus exceding the number of recursive calls that Imandra unrolls by
default:

```{.imandra .input}
verify (fun x -> x < 101 ==> f x = 1)
```

As expected, since the recursion depth needed to prove this exceeds the
unrolling bound we set, Imandra could only prove this property _up to bound
`k`_. This goal is in fact a property that is better suited for verification by
[induction](Verification%20-%20Induction.md) (indeed, you might try adding the
`[@@auto]` annotation to the above goal to invoke the Imandra's inductive waterfall
and prove it).

As a minor note, if we reach a local unrolling depth instead of hitting the global one,
Imandra will be a bit more positive in its message, telling us that the conjecture has
been proved up to the number of steps we've specified instead of a weaker "Unknown":

```{.imandra .input}
verify ~upto:100 (fun x -> x < 101 ==> f x = 1)
```

### Datatype bounds

Imandra offers an orthogonal, more advanced form of bounding for unrolling, using
`~upto_bound:<n>`. This bound works in a fundamentally different way than the
"normal" unrolling limit: instead of acting as a limit on the number of recursive
steps that Imandra unrolls, this limit instructs Imandra to synthesize a recursive
depth function for the datatypes involved in the goal and to transform the goal
such that it will include this bound check as part of the hypotheses.

This means that Imandra will be actually _proving_ a bounded theorem involving the
depth of datatypes.

```{.imandra .input}
verify ~upto_bound:5 (fun x -> List.rev (List.rev x) = x)
```

When using unrolling with `~upto_bound`, one should remember that the global
unrolling limit still applies and may cause Imandra to abort solving before
reaching the datatype bound.

This datatype bound limit can also be used with the [blast](Verification%20-%20Blast.md)
strategy, while the unrolling limit can't, as _blast_ doesn't work by
recursive unrolling.
