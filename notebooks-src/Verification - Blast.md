---
title: "Verification Blast"
description: "A description of Imandra's blast strategy"
kernel: imandra
slug: verification-blast
key-phrases:
  - verification
  - blast
  - unrolling
---

# Blast

Sometimes, Unrolling gets lost in the search space. Imandra has an alternative strategy called **blast**, that can be invoked in any context where unrolling is accepted:

```{.imandra .input}
verify (fun a b -> a >= 0 && b >= 0 && a <= 1_000 && b <= 1_000 ==> (a-b) * (a-b) * (b-a) * (b-a) + 1 >= 0) [@@blast];;
```

**blast** is usually handy in problems that present some form of combinatorial explosion. A more detailed example shows [how to solve a sudoku](./Sudoku.md) with Imandra, and [how to cross a river safely](Crossing_the_river_safely.md).

Blast is our name for a [symbolic execution](https://en.wikipedia.org/wiki/Symbolic_execution) technique for Imandra's core logic of recursive functions and algebraic datatypes. The way it works is by exploring progressively the space of its inputs (e.g. lists of size 0, then size 1, then size 2, etc.) and encoding the computations into [SAT](https://en.wikipedia.org/wiki/Boolean_satisfiability_problem) by executing "simultaneously" all possible paths. It views all logic-mode definitions through the prism of computation — blast doesn't know that `x = x` is always true, for example, it will try to expand `x` progressively and computing the predicate `x = x` as it goes.

This means that `[@@blast]` shines when there's a counter-example (or `instance`) to find: expanding the input(s) progressively and computing whether the goal holds is exactly what `[@@blast]` is designed for. On the other hand, if you're trying to prove a theorem about `List.rev (List.rev x) = x`, the space of possible values for `x` is infinite and `[@@blast]` will never be able to explore it all. Induction is generally more adequate for proving such universal statements. Conversely, to [solve a sudoku](./Sudoku.md), it's appropriate to explore the space of sudoku grids `s` until one is found that satisfies `is_sudoku s && is_solution_of s the_initial_grid` (meaning this expression evaluates to `true`).
