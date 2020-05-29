---
title: "Verification Commands"
description: "A description of Imandra's verification commands"
kernel: imandra
slug: verification-commands
key-phrases:
  - verification
  - commands
  - syntax
---
# Commands

Imandra has a number of powerful verification commands:

- `verify <upto> <func>`: takes a function representing a goal and attempts to prove it.
  If the proof attempt fails, Imandra will try to synthesize a concrete
  counterexample illustrating the failure. Found counterexamples are installed
  by Imandra in the `CX` module. When verifying a formula that doesn't depend on
  function parameters, `verify (<expr>)` is a shorthand for `verify (fun () -> <expr>)`.
  If `<upto>` is provided as one of `~upto:<n>` or `~upto_bound:<n>`, verification
  will be bound by [unrolling limits](Verification%20-%20Unrolling.md#Unrolling-limits).

- `instance <upto> <func>`: takes a function representing a goal and attempts to
  synthesize an instance (i.e., a concrete value) that satisfies it. It is
  useful for answering the question "What is an example value that satisfies
  this particular property?". Found instances are installed by Imandra in the
  `CX` module.
  If `<upto>` is provided as one of `~upto:<n>` or `~upto_bound:<n>`, instance search
  will be bound by [unrolling limits](Verification%20-%20Unrolling.md#Unrolling-limits).

- `theorem <name> <vars> = <body>`: takes a name, variables and a function of
  the variables representing a goal to be proved. If Imandra proves the goal,
  the named theorem is installed and may be used in subsequent proofs. Theorems
  can be tagged with attributes instructing Imandra how the theorem should be
  (automatically) applied to prove other theorems in the future. Found
  counterexamples are installed by Imandra in the `CX` module.

- `lemma <name> <vars> = <body>`: synonym of `theorem`, but idiomatically often used
   for "smaller" subsidiary results as one is working up to a larger `theorem`.

- `axiom <name> <vars> = <body>`: declares an axiom, effectively the same as
   `theorem` but forcing Imandra to *assume* the truth of the conjecture, rather
   than verifying it. This is of course dangerous and should be used with
   extreme care.

## Examples

```{.imandra .input}
verify (fun x -> x + 1 > x)
```

```{.imandra .input}
instance (fun x y -> x < 0 && x + y = 4)
```

```{.imandra .input}
theorem succ_mono n m = succ n > succ m <==> n > m
```

```{.imandra .input}
verify (fun n -> succ n <> 100)
```
