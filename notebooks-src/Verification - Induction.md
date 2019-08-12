---
title: "Verification Induction"
description: "A description of Imandra's Induction strategy"
kernel: imandra
slug: verification-induction
key-phrases:
  - verification
  - induction
  - recursion
---

# Induction

While techniques such as unrolling and simplification can get us a long way
towards formally verifying our software, variants of mathematical
[induction](https://en.wikipedia.org/wiki/Noetherian_induction) are in general
required for verifying properties of systems with infinite state-spaces.

Induction is a proof technique that can be used to prove that some property
`φ(x)` holds _for all_ the elements `x` of a recursively defined structure (e.g.
natural numbers, lists, trees, execution traces, etc). The proof consists of:

- a proof that `φ(base)` is true for each _base case_
- a proof that if `φ(c)` is true (called the _inductive hypothesis_), then
  `φ(step(c))` is also true, for all the recursive steps of the property we're
  trying to prove

Induction can be done in many ways, and finding the "right" way to induct is
often the key to difficult problems. Imandra has deep automation for finding and
applying the "right" induction for a problem. If this fails, the user can
instruct Imandra how to induct, with various forms of instructions.

A method of induction is given by an _induction scheme_.

Induction schemes can automatically be derived by Imandra in many ways. By
default, with `[@@auto]` or `[@@induct]`, Imandra analyses the recursive
functions involved in the conjecture and constructs a _functional induction
scheme_ derived from their recursive structure, in a manner that is justified by
the _ordinal measures_ used to prove their termination. Imandra also supports
_structural induction_ principles derived from the definitions of (well-founded)
algebraic datatypes such as lists and trees.

Some example induction schemes are:

- for the natural numbers, `φ(Zero) && φ(n) ==> φ(Succ(n))`
- for lists, `φ([]) && (lst <> [] && φ(List.tl(lst)) ==> φ (lst))`
- for the function `repeat` as defined below, `n <= 0 ==> φ(n, c) && (n > 0 && φ(n - 1, c)) ==> φ(n, c)`

```{.imandra .input}
let rec repeat c n =
  if n <= 0 then
    []
  else
    c :: (repeat c (n-1))
```

In Imandra, induction schemes are "destructor style." So, an actual scheme
Imandra would produce for a goal involving `n : nat` (where `type nat = Zero | Succ of nat`)
is:

```
 (n = Zero ==> φ n)
 && (not (n = Zero) && φ (Destruct(Succ, 0, n)) ==> φ n).
```


Let us see a few example inductions.

```{.imandra .input}
lemma assoc_append x y z =
 x @ (y @ z) = (x @ y) @ z [@@auto] [@@rw]
```

```{.imandra .input}
lemma rev_append x y =
 List.rev (x @ y) = List.rev y @ List.rev x
 [@@auto]
```

```{.imandra .input}
verify (fun lst ->
  List.for_all (fun x -> x > 0) lst ==>
    List.fold_right (+) ~base:1 lst > 0)
[@@auto]
```

## Functional Induction

By default, Imandra uses _functional induction_ (also known as _recursion induction_).

A functional induction scheme is one derived from the recursive structure of a
function definition. The termination measure used to admit the function is also
used to justify the soundness of the functional induction scheme. Unless
instructed otherwise, Imandra will consider all recursive functions in a goal,
analyse their recursions and instances, and apply various heuristics to merge
and score them and adapt them to the conjecture being proved. In general, there
may be more than one plausible induction scheme to choose from, and selecting
the "right" way to induct can often be a key step in difficult proofs. Imandra
will often make the "right" decision. However, in case it doesn't, it is also
possible to manually specify the induction that Imandra should do.

Let us return to the function `repeat` above and see functional induction in
action.

```{.imandra .input}
lemma repeat_len c n =
  n >= 0 ==>
  List.length (repeat c n) = n [@@auto]
```

Functional induction schemes tailored to a problem can also be manually specified.

In order to manually specify a functional induction, one must define a recursive
function encoding the recursion scheme one wants available in induction (Imandra
doesn't care what the function _does_, it only looks at how it recurses).
As always, Imandra must be able to prove that the recursive function terminates
in order for it to be admitted into the logic. The ordinal measures used in the
termination proof are then used to justify subsequent functional induction
schemes derived from the function.

Let's see a simple example. Note that we could trivially prove this goal with
`[@@auto]`, but we shall use it to illustrate the process of manual induction
schemes nevertheless! For fun, we'll make our custom induction scheme have two
base-cases.

```{.imandra .input}
let rec sum n =
 if n <= 0 then 0
 else n + sum (n-1)

let rec induct_scheme (n : int) =
 if n <= 0 then true
 else if n = 1 then true
 else induct_scheme (n-1)
```

```{.imandra .input}
verify (fun n -> n >= 0 ==> sum n = (n * (n+1)) / 2) [@@induct functional induct_scheme]
```

Note that it's rare to have to manually instruct Imandra how to induct in this
way. Usually, if you need to instruct Imandra to use a different scheme than the
one it automatically picked, you'll simply need to give Imandra the hint of
"inducting following key recursive function `foo`" in your goal. For example, if
Imandra had made a wrong selection in a goal involving `sum` and some other
recursive functions, we might tell Imandra `[@@induct functional sum]` to get it
to select a scheme derived from the recursive structure of `sum`.

## Structural Induction

Imandra also supports structural induction. Unlike functional induction schemes
which are derived from recursive functions, structural induction schemes are
derived from type definitions.

For example, we can define a type of binary trees and prove a property about
them by structural induction.

```{.imandra .input}
type 'a tree = Node of 'a * 'a tree * 'a tree | Leaf
```

```{.imandra .input}
let rec size (x : 'a tree) =
 match x with
 | Node (_, a,b) -> size a + size b
 | Leaf -> 1
```

```{.imandra .input}
verify (fun x -> size x > 0) [@@induct structural x]
```

Structural induction comes in both _additive_ and _multiplicative_ flavors.

This distinction only manifests when one is performing structural induction over
multiple variables simultaneously. It affects the way base cases and inductive
steps are mixed. Let's assume one needs to do induction on `x, y`:

- addictive structural induction gives you 3 cases: two base cases
  `φ(x_base, y)`, `φ(x, y_base)` and one inductive step `φ(x,y) ==> φ(step(x), step(y))`

- multiplicative structural induction gives you 4 cases: one base case
  `φ(x_base, y_base)` and three inductive steps `φ(x, y_base) ==> φ(step(x), y_base)`,
  `φ(x_base, y) ==> φ(x_base, step(y))` and `φ(x,y) ==> φ(step(x), step(y))`

We can see the difference using the following function:

```{.imandra .input}
let rec interleave_strict x y = match x, y with
  | [], _ | _ , [] -> []
  | x::xs, y::ys -> x::y::(interleave_strict xs ys)
```

Let's prove that the length of `interleave_strict x y` is always less than or
equal to the sum of the lengths of `x` and `y`. We'll do it first using
additive and then using multiplicative structural induction:

```{.imandra .input}
verify (fun x y ->
  List.length @@ interleave_strict x y <= List.length x + List.length y)
[@@induct structural_add (x,y)]
```

```{.imandra .input}
verify (fun x y ->
  List.length @@ interleave_strict x y <= List.length x + List.length y)
[@@induct structural_mult (x,y)]
```

Imandra was able to prove the property using both flavors of structural
induction, but we can see that the proof using the additive flavor was shorter.
Multiplicative schemes will often result in longer proofs than additive schemes,
and thus Imandra uses the additive flavor by default when
`[@@induct structural ...]` is used.

<!-- TODO -->
<!-- ## Onward Through the Fog -->
