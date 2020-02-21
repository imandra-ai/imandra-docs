---
title: "Iterative Decomposition Framework"
description: "IDF is a framework for decomposition of state machine models"
kernel: imandra
slug: 'idf'
key-phrases:
  - imandra-tools
  - state machine
  - iterative decomposition
  - lazy decomposition
---

# Iterative Decomposition Framework

Imandra has the ability to enumerate the state space of a function via its [decomposition](Imandra%20Decomposition%20Flags.md) feature.

`IDF` is a framework that builds on top of that and adds the ability to enumerate the state space of a [(possibly infinite) state machine](https://en.wikipedia.org/wiki/Finite-state_machine) after a bounded number of abstract transitions.

Let's define one such state machine and see how `IDF` can help us navigating its state space: we must define a module conforming to [Idf_intf.SM_SIG](https://docs.imandra.ai/imandra-docs/odoc/imandra-tools/Imandra_tools/Idf_intf/module-type-SM_SIG/index.html).
An additional constraint which is not enforciable by the OCaml type system but is enforced at runtime by `IDF` is that the type of `event` must be an algebraic variant type (or an alias to one).

```{.imandra .input}
module SM = struct

  type i = Int of int | Zero

  (* type of state machine events *)
  type event = Add of i | Sub of int | Reset

  (* type of state machine state *)
  type state = int

  (* initial state of the state machine *)
  let init_state = 0

  (* transition function of the state machine *)
  let step event state =
    if state = 1337 then
      state
    else
      match event with
      | Reset -> 0
      | Add (Zero) -> state
      | Add (Int n) ->
        if n < 0 then
          state
        else if n = 0 || n + state > 9000 then
          0
        else
          state + n
      | Sub n ->
        if n > state then
          state
        else
          state - n

  (* validity function for an event transition *)
  let is_valid event state =
    match event with
    | Add (Int n) when state < 3 -> n > 50
    | Add (Int 0) -> false
    | Sub n -> (n > 0 && n <= state) || (n < 0)
    | _ -> true

end
```

We can try to compute with this state machine:


```{.imandra .input}
SM.
(init_state
|> step (Add Zero)
|> step (Add (Int 15))
|> step Reset
|> step (Sub (-1)))
```

Now that we have a model to decompose, we must create a symbolic template of `SM` events, by creating a module conforming to [Idf_intf.TPL_SIG](https://docs.imandra.ai/imandra-docs/odoc/imandra-tools/Imandra_tools/Idf_intf/module-type-TPL_SIG/index.html)

Note that there's not necessarily a 1:1 correspondence between the variant constructors of `SM.event` and the ones of `TPL.t`, for example `TPL.Any` is an empty mapping, meaning that no constructor will be constrained for that symbolic event, `TPL.AddInt` on the other hand fixes the event to be a `SM.Add (SM.Int _)`, thus excluding `SM.Add SM.Zero`.

```{.imandra .input}
module TPL = struct
  (* type of a symbolic state machine event *)
  type t = Add | AddInt | Sub | Reset | Any
  type c = SM.event

  (* mapping function from a symbolic state machine event to a concrete event *)
  let concrete t c = match t,c with
    | Any, _ -> true
    | Add, SM.Add _ -> true
    | AddInt, SM.Add(SM.Int _) -> true
    | Sub, SM.Sub _ -> true
    | Reset, SM.Reset -> true
    | _ -> false
end
```

Next we need to hook the `SM` and `TPL` modules into a module conforming to [Idf_intf.DSM_SIG](https://docs.imandra.ai/imandra-docs/odoc/imandra-tools/Imandra_tools/Idf_intf/module-type-DSM_SIG/index.html):

```{.imandra .input}
module Decomp = struct

  module State_machine = SM

  module Template = TPL

  let module_name = "Decomp"

end
```

And finally we can instantiate `Idf` using `Decomp`:


```{.imandra .input}
#program;;

module IDF = Imandra_tools.Idf.Make(Decomp)
```

We are now ready to decompose a `SM` state machine under a particular `TPL.t` template
```{.imandra .input}
let g = IDF.G.create ();;
IDF.decompose ~g TPL.[Any;AddInt] ()
```

We've invoked `IDF.decompose` over a template of `[Any;AddInt]`, which means we'll try to symbolically decompose the state space of a state machine after the following steps (`_` is used to indicate a symbolic value):

```ocaml
SM.
(init_state
 |> step _
 |> step (Add (Int _)))
```

In order to consume concrete paths, we must extract them from the decomposition graph `g`:

```{.imandra .input}
let first_path = IDF.paths g |> List.hd;;
let full_node = first_path |> CCList.rev |> CCList.hd
```

Now that we have a `path` value available, we can explore what we can do with it:

- We can ask for sample event values for the current path, which will return a sample for each event in the path:

```{.imandra .input}
let samples = IDF.sample full_node
```

- We can ask for a sample execution replay of the current path, which will return a list of tuples of `input state * input event * output state` for each sample event in the path:
```{.imandra .input}
let replayed_node = IDF.replay full_node
```

- We can ask for the concrete regions representing the constraints of the state machine up to each event in the path:
```{.imandra .input}
#install_printer Imandra_tools.Region_pp.print;;

let regions = List.map IDF.region first_path
```

It is to be noted that the each symbolic event in those constraints is represented as the `nth` element of the list `e`, thus the first `Any` event will be `List.hd e`, the second `AddInt` will be `List.hd (List.tl e)`, and since we've asked `IDF` to decompose a path of _exactly_ two events, there will be no third or more events, and thus we can find a constraint to that effect: `List.tl (List.tl e) = []`.
