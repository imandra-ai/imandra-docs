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
[block:code]
{
  "codes": [
    {
      "code": "type state = { x : int };;\n\ntype msg = Add of int\n         | Sub of int\n         | Replace of int\n;;\n\nlet step (s, m) =\n  match m with\n    Add n -> {s with x = s.x + n}\n  | Sub n -> {s with x = s.x - n}\n  | Replace n -> {s with x = n}\n;;\n\nlet rec run (s, ms) =\n  match ms with\n    [] -> s\n  | m :: ms ->\n     let s' = step (s, m) in\n     run (s', ms)\n;;\n\nlet init_state = { x = 0 };;\n\nlet run_example (n1,n2,n3,n4,n5) =\n  run (init_state, [Add n1;\n                    Sub n2;\n                    Replace n3;\n                    Add n4;\n                    Sub n5])\n;;\n\nlet run_example_gt_0 (n1,n2,n3,n4,n5) =\n  (run_example (n1,n2,n3,n4,n5)).x > 0\n;;\n\n:stage run\n\n:decompose run_example assuming run_example_gt_0",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
And here is the result:
[block:code]
{
  "codes": [
    {
      "code": "# :decompose run_example assuming run_example_gt_0\n----------------------------------------------------------------------------\nBeginning principal region decomposition for run_example\n----------------------------------------------------------------------------\n- Assuming predicate run_example_gt_0 for all regions.\n- Isolated region #1 (Goal 1, depth=1): --------------------\n\nName: Goal 1\n\nVars: {x1 : int; x2 : int; x3 : int; x4 : int; x5 : int}\n\nConstraints:\n [ (x3 + x4 + (-x5)) > 0 ]\n\nInvariant:\n { x = (x3 + x4 + (-x5)) } = F(x1, x2, x3, x4, x5).\n\n----------------------------------------------------------------------------\nFinished principal region decomposition for run_example s.t. run_example_gt_0\nStats: {rounds=2; regions=1; time=0.083sec}\n----------------------------------------------------------------------------",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
