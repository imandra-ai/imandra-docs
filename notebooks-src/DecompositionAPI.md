---
title: "API"
description: "An API for performing decomposition."
kernel: imandra
slug: decomp-api
key-phrases:
  - decomposition
  - side-condition
  - target function
  - uninterpreted function
  - state space enumeration
  - region of behaviour
---

# API

At its very core, modular decomposition allows us to "splice" the state space of a function into (possibly infeasible) regions of behavior.

```{.imandra .input}
let f x = if x > 0 then if x * x < 0 then x else x + 1 else x;;
let d = Modular_decomp.top "f" [@@program];;
```


A side condition can be specified to inject extra constraints about the target function, this can be used to constrain and/or partition the explored state space

```{.imandra .input}
let g x = x < 0;;
let d1 = Modular_decomp.top ~assuming:"g" "f" [@@program];;

let h x = x < 0 && (x > -5 || x < -6);;
let d2 = Modular_decomp.top ~assuming:"h" "f" [@@program];;
```

Pruning instructs modular decomposition to solve all the regions for feasibility using unrolling and throw away infeasible ones

```{.imandra .input}
let d = Modular_decomp.top ~prune:true "f" [@@program];;
```

In some cases feasibility is not known via unrolling, so pruning may return regions of unknown feasibility

```{.imandra .input}
let i (x : int list) = if (x = List.rev @@ List.rev x) then 1 else 2;;

let d = Modular_decomp.top ~prune:true "i" [@@program];;

d |> Modular_decomp.get_regions |> CCList.map (fun r -> r, Modular_region.(string_of_status @@ status r));;
```

Recursive functions are not expanded, nor functions belonging to the "basis" (but pruning can still unroll them when solving for feasibility)

```{.imandra .input}
let j x = if f x = x then 1 else 2;;
let d = Modular_decomp.top ~prune:true ~basis:["f"] "j" [@@program];;
```

A model satisfying the region constraints can be extracted for feasible regions

```{.imandra .input}
Modular_decomp.(d |> get_regions |> CCList.map get_model);;
```

The model can be turned into a computable value by generating an extractor for the target function

```{.imandra .input}
Extract.eval ~signature:(Event.DB.fun_id_of_str "j") ~quiet:true ();;
Modular_decomp.(d |> get_regions |> CCList.map (get_model %> Mex.of_model));;
```

Regions can be manually refined with terms in order to add extra constraints (refining automatically prunes)

```{.imandra .input}
let d1 = Modular_decomp.(top ~prune:true "f" |> get_regions |> CCList.filter_map (fun r -> refine r [Term.false_])) [@@program];;

let d2 = Modular_decomp.(top ~prune:true "f" |> get_regions
                         |> CCList.filter_map
                           (fun r ->
                              refine r
                               (* x = 1 *)
                                [Term.eq ~ty:(Type.int())
                                   (Modular_region.args r |> List.hd |> Term.var)
                                     (Term.int 1)])) [@@program];;
```
