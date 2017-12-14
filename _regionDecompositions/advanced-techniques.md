---
title: "Advanced Techniques"
excerpt: ""
layout: pageSbar
permalink: /advancedTechniques/
colName: Region Printers
---
[block:api-header]
{
  "title": "Staged Symbolic Execution"
}
[/block]
'Staging' is an advanced feature that uses 'staged symbolic execution' to incrementally unroll top-level recursive functions during region decompositions. This is useful when you wish to analyse the effect of a sequence of 'events' (i.e., a sequence of instructions or messages) on a state vector. 

Here's a simple example. Notice how we 'stage' the top-level recursive ```run``` function. Notice also how the *shape* of the program we're analysing is given, but we allow it to have symbolic parameters. We then ask Imandra to symbolically execute the program from a starting initial state, and using an ```assuming``` statement we ask Imandra to solve for the regions where a property holds (in this case, where the ```x``` value of the state vector is non-negative).
```
type state = { x : int };;
type msg = Add of int
  | Sub of int
  | Replace of int
;;

let step (s, m) =
  match m with
    Add n -> {s with x = s.x + n}
    | Sub n -> {s with x = s.x - n}
    | Replace n -> {s with x = n}
;;

let rec run (s, ms) =
  match ms with
    [] -> s
    | m :: ms ->
      let s' = step (s, m) in
        run (s', ms)
;;

let init_state = { x = 0 };;
let run_example (n1,n2,n3,n4,n5) =
  run (init_state, [Add n1;
                    Sub n2;
                    Replace n3;
                    Add n4;
                    Sub n5])
;;

let run_example_gt_0 (n1,n2,n3,n4,n5) =
  (run_example (n1,n2,n3,n4,n5)).x > 0
;;

:stage run
:decompose run_example assuming run_example_gt_0

```

And here is the result:

```
# :decompose run_example assuming run_example_gt_0
----------------------------------------------------------------------------
Beginning principal region decomposition for run_example
----------------------------------------------------------------------------
- Assuming predicate run_example_gt_0 for all regions.
- Isolated region #1 (Goal 1, depth=1): --------------------

Name: Goal 1

Vars: {x1 : int; x2 : int; x3 : int; x4 : int; x5 : int}

Constraints:\n [ (x3 + x4 + (-x5)) > 0 ]

Invariant:\n { x = (x3 + x4 + (-x5)) } = F(x1, x2, x3, x4, x5).

----------------------------------------------------------------------------
Finished principal region decomposition for run_example s.t. run_example_gt_0
Stats: {rounds=2; regions=1; time=0.083sec}
----------------------------------------------------------------------------

```