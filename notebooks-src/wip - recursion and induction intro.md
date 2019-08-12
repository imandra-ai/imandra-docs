---
title: "wip - recursion and induction intro"
description: "A quick tour through Imandra's basic features (second half of the welcome notebook)"
kernel: imandra
slug: wip-recursion-induction-intro
key-phrases:
  - proof
  - counterexample
  - recursion
  - induction
---
# Recursion and Induction

Imandra's reasoning power really shines in the analysis of recursive functions.

Whenever a recursive function is defined in Imandra, it is analysed automatically for _termination_ through a call-graph based analysis of _ordinal_ measures of its recursive calls. We'll go into details on computing with ordinals and termination measures in subsequent notebooks.

For many common forms of recursion, Imandra is able to automatically prove termination without any hints from the user.

Let's define a simple recursive function, `sum : int list -> int` and reason about it.

```{.imandra .input}
let rec sum x = match x with
 | [] -> 0
 | x :: xs -> x + sum xs
```

We can of course compute with `sum`:

```{.imandra .input}
sum []
```

```{.imandra .input}
sum [1;2;3]

```

Now, let's ask Imandra some questions about `sum`.

For example, is it always the case that `sum x >= 0`?

```{.imandra .input}
verify (fun x -> sum x >= 0)
```

Imandra tells us the (obvious) answer: This conjecture is false! Indeed, we can compute with the counterexample to see:

```{.imandra .input}
sum CX.x
```

Now let's ask Imandra something more complex. For example, are there any lists of integers `x` such that `sum x = List.length x + 17`?

```{.imandra .input}
verify (fun x -> sum x <> List.length x + 17)
```

Ah! Of course. What if we make the task a bit more involved, by requiring, e.g., that the list in question is of length at least `10`?

```{.imandra .input}
verify (fun x -> List.length x >= 10 ==> sum x <> List.length x + 17)
```

This counterexample is a bit more complex - let's compute with it to better understand it:

```{.imandra .input}
List.length CX.x
```

```{.imandra .input}
sum CX.x
```

```{.imandra .input}
List.length CX.x + 17
```

Now, let's try to prove something more interesting: a seemingly true fact about the _entire_ infinite state-space of possible inputs to `sum`: If the elements of the list `x` are all non-negative, then `sum x` will always be non-negative.

Let's start by defining a predicate `psd : int list -> bool` that checks whether or not an `int list` consists of non-negative integers (i.e., is "positive semidefinite"):

```{.imandra .input}
let rec psd x = match x with
 | [] -> true
 | x :: xs -> x >= 0 && psd xs
```

We can compute with this function to get a feel for it:

```{.imandra .input}
psd [1;2;3;4]
```

```{.imandra .input}
psd [3;2;-1;7]
```

And let us now ask Imandra to verify our conjecture:

```{.imandra .input}
verify (fun x -> psd x ==> sum x >= 0)
```

When we gave this fact to Imandra, it attempted to prove it using a form of _bounded model checking_. As it turns out, this type of reasoning is not sufficient for establishing this conjecture. However, Imandra tells us something very useful: that up to its current _recursion unrolling bound_ of `100`, there exist no counterexamples to this conjecture. 

For many practical problems, this type of _bounded model checking_ establishing _there exist no counterexamples up to depth k_ is sufficient. You may enjoy inspecting the `call graph` of this bounded verification to understand the structure of Imandra's state-space exploration.

But, we can do even better. We'll ask Imandra to prove this fact _for all possible cases_. To do this, we'll ask Imandra to use _induction_:

```{.imandra .input}
verify (fun x -> psd x ==> sum x >= 0) [@@induct]
```

Imandra proves this fact for us automatically, using a structural induction principle derived from the datatypes involved in the conjecture. We can go and inspect the inductive proof, for example by clicking `Load graph` under the `proof` tab. 

If we use Imandra in the [terminal](../terminals/try), we'll even get English prose output describing the inductive proof in readable mathematical detail, live as it is constructed!

[![asciicast](https://asciinema.org/a/e1oRBCKwvivZTlvLNuu5Lfafh.png?autoplay=1&t=2&speed=2&size=small&cols=100)](https://asciinema.org/a/e1oRBCKwvivZTlvLNuu5Lfafh?autoplay=1&t=2&speed=2&size=small&cols=100)

This concludes our small tour of Imandra. Continue on to subsequent notebooks to learn more!

## What next?

Check out the [list of notebooks](https://docs.imandra.ai/imandra-docs/) on for some more examples.

You can also [try Imandra in the terminal](../terminals/try).
