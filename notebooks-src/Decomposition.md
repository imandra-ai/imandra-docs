---
title: "Decomposition"
description: "A description of Imandra's various decomposition methods"
kernel: imandra
slug: decomposition
key-phrases:
  - decomposition
  - side-condition
  - target function
  - uninterpreted function
  - state space enumeration
  - region of behaviour
---

# Region Decomposition

The term Region Decomposition refers to a ([geometrically inspired](https://en.wikipedia.org/wiki/Cylindrical_algebraic_decomposition)) "slicing" of an algorithm’s state-space into distinct regions where the behavior of the algorithm is invariant, i.e., where it behaves "the same."

Each "slice" or region of the state-space describes a family of inputs and the output of the algorithm upon them, both of which may be symbolic and represent (potentially infinitely) many concrete instances.

The entrypoint to decomposition is the `Modular_decomp.top` function, here's a quick basic example of how it can be used:

```{.imandra .input}
let f x =
  if x > 0 then
    1
  else
    -1
;;

let d = Modular_decomp.top "f"
```

Imandra decomposed the function "f" into 2 regions: the first region tells us that whenever the input argument `x` is less than or equal to 0, then the value returned by the function will be `-1`, the second region tells us that whenever `x` is positive, the output will be 1.

When using Region Decomposition from a REPL instead of from the jupyter notebook, we recommend installing the vornoi printer (producing the above diagram) via the `Imandra_voronoi.Voronoi.print` printer

# Advanced Usage

- [Imandra Tools Introduction](Imandra-tools%20Introduction.md)
- [Iterative Decomposition Framework](Iterative%20Decomposition%20Framework.md)
- [Region Probabilities](Region%20Probabilities.md)
