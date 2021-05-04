---
title: "A Quick Tour of Imandra"
description: "A quick tour through Imandra's basic features."
kernel: imandra
slug: welcome
key-phrases:
  - proof
  - counterexample
  - recursion
  - induction
assert:
  contains:
    - "output_html"
    - "fa-check-circle"
    - "<span>Proved</span>"
    - "fa-times-circle-o"
    - "<span>Refuted</span>"
    - "int = 105"
    - "Counterexample (after 0 steps"
    - "let x : int = 69"
    - "module CX : sig val x : int end"
    - "<span>termination proof</span>"
    - "<b>ground_instances</b>"
    - "Must try induction."
  excludes:
    - "error"
    - "exception"
---

# Welcome to Imandra!

Imandra is both a programming language and a reasoning engine with which you can analyse and verify properties of your programs.

![Imandra scope](https://storage.googleapis.com/imandra-notebook-assets/imandra-scope.svg)

As a programming language, Imandra is a subset of the functional language OCaml. We call this subset of OCaml “IML” or “ImandraML” (for “Imandra Modelling Language”).

With Imandra, you write your code and verification goals in the same language, and pursue programming and reasoning together.

Imandra has many advanced features, including first-class computable counterexamples, symbolic model checking, support for polymorphic higher-order recursive functions, automated induction, a powerful simplifier and symbolic execution engine with lemma-based conditional rewriting and forward-chaining, first-class state-space decompositions, decision procedures for algebraic datatypes, floating point arithmetic, and much more.

Before starting to use Imandra, it may be helpful to read this short [Introduction](Introduction.md).

This section will give you a quick, 5 minute overview of what Imandra can do. If
you want to play around with the code in any of the examples hit the 'Try this!'
buttons throughout, and you'll get a Jupyter notebook session where you can
experiment. (If you got here via try.imandra.ai, you're already in one of these
notebook sessions - if that's the case just run the cells using the Jupyter
controls!)

## Your first proof and counterexample

Let's define a couple of simple arithmetic functions and analyse them with
Imandra:

```{.imandra .input}
let g x =
  if x > 22 then 9
  else 100 + x

let f x =
  if x > 99 then
    100
  else if x < 70 && x > 23
  then 89 + x
  else if x > 20
  then g x + 20
  else if x > -2 then
    103
  else 99
```

Here, `g` and `f` are the names of our functions, and they each take a single
integer argument `x`. In Imandra,

```
let g x = <body>
```


is the equivalent of something like

```
function g (x : Int) { <body> }
```


in many other languages.

Notice how we did not have to declare the type of `x` in the definition of `f`
and `g`. Imandra's type system has inferred that `x` is an integer automatically
from how `x` is used. Sometimes it's advantageous to annotate our definitions
with types manually. We could write this explicitly by defining `g` with an
explicit type annotation, e.g.,

```
let g (x : int) = <body>
```


As `f` and `g` are functions, we can of course compute with them:

```{.imandra .input}
g 5
```

```{.imandra .input}
g 23017263820
```

```{.imandra .input}
f (- 1)
```

However, functions in Imandra are more than just code: they're also mathematical
objects that can be analysed and subjected to the rigours of mathematical proof.

For example, let's verify that for all possible integer inputs `x`, `g x`
never goes above `122`, which corresponds to the logical statement
`(forall (x : int), g x <= 122)`. We represent logical statements like these with OCaml
functions:

```{.imandra .input}
let g_upper_bound x =
   g x <= 122
```

Now let's ask Imandra to verify our statement!

```{.imandra .input}
verify g_upper_bound
```

Imandra has verified this fact for us automatically, by directly examining the
definition of our statement and the definitions of the other functions it refers
to (in this case, `g`).

Now, let's ask Imandra to verify that there exists no `x` such that `f x` is
equal to `158`. Giving our statements names can sometimes be a bit unwieldy
(although it can be helpfully descriptive in some situations). For simple
statements like these, the statements themselves are descriptive enough, so we
can also pass an anonymous function (a lambda term) to `verify` that represents our statement.
In Imandra, we use `fun` to create an anonymous function:

```{.imandra .input}
verify (fun x -> f x <> 158)
```

Imandra has found our statement to be false, and has also found us a concrete counterexample to demonstrate. Let's try executing `f` with that value to confirm:

```{.imandra .input}
f 69
```

Imandra has derived for us that if `x=69`, then `f x` is equal to `158`, so the conjecture `(fun x -> f x <> 158)` is not true! Imandra has given us a concrete counterexample _refuting_ this conjecture.

In Imandra, all counterexamples are "first-class" values, and are automatically reflected into the runtime in a module (namespace) called `CX`. So, another way to experiment with that counterexample is to utilise the `CX` module that the `verify` command constructed for us:

```{.imandra .input}
CX.x
```

```{.imandra .input}
f CX.x
```

## Region Decomposition

We can also ask Imandra to _decompose_ our function to get a symbolic representation of its state-space. This decomposes the (potentially infinite) state-space into a _finite_ number of symbolically described _regions_, each describing a class of behaviours of the function.

For each region it is proved that if the inputs of the function satisfy the _constraints_, then the output of the function satisfies the _invariant_. Furthermore, Imandra proves _coverage_: every possible concrete behaviour of the function is represented by a region in the decomposition:

```{.imandra .input}
Modular_decomp.top "f"
```

Click on the different full regions (those sub-diagrams of the Voronoi diagram starting with `R`) and inspect their constraints and invariant. Note that the invariant may depend on the input value (`x`), e.g., in regions corresponding to branches of the function `f` where it returns `x` plus some constant.

Region decompositions form the basis of many powerful Imandra features, including forms of reachability analysis and automated test-suite generation and auditing.

## Recursion and Induction

Imandra's reasoning power really shines in the analysis of recursive functions.

Let's define a simple recursive summation function, `sum : int list -> int`, and reason about it.

```{.imandra .input}
let rec sum x = match x with
 | [] -> 0
 | x :: xs -> x + sum xs
```

```{.imandra .input}
sum []
```

```{.imandra .input}
sum [1;2;3]
```

We can ask Imandra lots of interesting questions about our functions. For example, we can use Imandra's `instance` command to ask Imandra to "solve" for inputs satisfying various constraints:

```{.imandra .input}
instance (fun x -> List.length x >= 10 && sum x = List.length x + 17)
```

We can compute with this synthesized instance, as Imandra installs it in the `CX` module:

```{.imandra .input}
List.length CX.x
```

```{.imandra .input}
sum CX.x
```

Now, let's ask Imandra to prove a conjecture we have about `sum`.

For example, is it always the case that `sum x >= 0`?

```{.imandra .input}
verify (fun x -> sum x >= 0)
```

Imandra tells us the (obvious) answer: This conjecture is false! Indeed, we can compute with the counterexample to see:

```{.imandra .input}
sum CX.x
```

Ah, of course! How can we refine this conjecture to make it true? Well, we can add an additional hypothesis that every element of the list `x` is non-negative. Let's define a function `psd` to express this:

```{.imandra .input}
let psd = List.for_all (fun x -> x >= 0)
```

Now, let's ask Imandra to prove our improved conjecture:

```{.imandra .input}
verify (fun x -> psd x ==> sum x >= 0)
```

When we gave this fact to Imandra, it attempted to prove it using a form of _bounded model checking_. As it turns out, this type of reasoning is not sufficient for establishing this conjecture. However, Imandra tells us something very useful: that up to its current _recursion unrolling bound_ of `100`, there exist no counterexamples to this conjecture.

For many practical problems, this type of _bounded model checking_ establishing _there exist no counterexamples up to depth k_ is sufficient. You may enjoy inspecting the `call graph` of this bounded verification to understand the structure of Imandra's state-space exploration.

But, we can do even better. We'll ask Imandra to prove this fact _for all possible cases_. To do this, we'll ask Imandra to use _induction_. In fact, Imandra has a powerful `[@@auto]` proof strategy which will apply induction automatically. Let's use it!

```{.imandra .input}
verify (fun x -> psd x ==> sum x >= 0) [@@auto]
```

Excellent. Imandra has proved this property for us *for all possible inputs* automatically by induction.

We hope you enjoyed this quick introduction!
