---
title: "Iterative Decomposition Framework"
description: "IDF is a framework for decomposition of state machine models"
kernel: imandra
slug: 'idf'
key-phrases:
  - imandra-tools
  - state machine
  - iterative decomposition
  - sampling decomposition
  - symbolic decomposition
  - lazy decomposition
---

# Iterative Decomposition Framework

Imandra has the ability to enumerate the state space of a function via its [decomposition](Imandra%20Decomposition%20Flags.md) feature.

`IDF` is a framework that builds on top of that and adds the ability to enumerate the state space of a [(possibly infinite) state machine](https://en.wikipedia.org/wiki/Finite-state_machine) after a bounded number of abstract transitions; moreover it can do this in a distributed fashion, bringing terrific performance improvements over single-process decompositions.

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

module D = Imandra_tools.Idf.Make(Decomp)

module IDF = D.Symbolic
```

We are now ready to decompose a `SM` state machine under a particular `TPL.t` template using either of the available strategies provided by `D`, both conforming to the [Idf_intf.SIG](https://docs.imandra.ai/imandra-docs/odoc/imandra-tools/Imandra_tools/Idf_intf/module-type-SIG/index.html) signature:

- `Sampling`: this decomposition strategy is a _non complete search_ that can be used to get an _approximate_ view of the entire state space, as it uses
  concrete sample values for each event instead of purely symbolic constraints.

- `Symbolic`: this decomposition strategy is complete but significantly more computationally expensive than the `Sampling` strategy, as all the symbolic
  events are expressed as pure constraints instead of concrete samples.

While the two decomposition strategies work in quite fundamentally different ways, their API is identical and thus switching between one or the other is simply a matter
of using `D.Symbolic` over `D.Sampling` or vice-versa.

Once we've decided which decomposition strategy to use (we're going to use `D.Symbolic` in this example, aliased to `IDF` for simplicity), we need to chose whether to use the in-process, synchronous and potentially lazy entrypoint `decompose`, or the eager, non blocking and distributed entrypoint `decompose_par`.

As per `Symbolic` vs `Sampling`, we've tried our best to keep the APIs of the two entrypoints as identical as possible, let's look at their similarities and differences:


```{.imandra .input}
#show IDF.decompose_par;;
#show IDF.decompose;;
```

We can see that both functions return a function with type `IDF.decompose` after a few initial setup differences:

- `decompose` takes an optional `lazily` named argument, which defaults to true and controls whether the decomposition will be lazy or eager
- `decompose_par` takes a `schedule` named argument of type `IDF.scheduler` which is needed to control the parameters of its parallel/distributed behavior and an optional `active_regions` named argument, which defaults to true and controls whether the returned regions must be "active" (i.e. usable to be refined or manually extract sample points) in the current process.

Apart from those initial different parameters, the API is then completely identical so swapping between one entrypoint and the other should be just a few lines of difference in the initial setup, looking at the signature of `IDF.decompose` (printed above), we can see that most of the optional flags are identical to the ones of Imandra's "native" `decompose` facility, so we'll just defer to its [docs](Imandra%20Decomposition%20Flags.md) for those.

Notable omissions are `assuming`, which is fundamentally incompatible with `Idf`, (`State_machine.is_valid` takes that space), and `interpret_basis`, which `Idf` needs to hardcode to true in order to work correctly.

The extra flags are:
- `g`: a `G.t` mutable graph that is a view of the decomposition state of the state machine, defaults to a throwaway graph that will only be used internally. Paths can be extracted from such a graph using the `IDF.paths` function
- `traversal`: the traversal strategy of the decomposition graph, either `DF` (depth first, default) or `BF` (breadth first)
- `from`: the initial node to start the decomposition from, defaults to a node representing the initial state of the state machine, can be used when running multiple decompositions over a same shared graph

Let's now showcase, using the slightly simpler `IDF.decompose`, how to start using the `IDF` module:

```{.imandra .input}
let paths, close = IDF.decompose TPL.[Any;AddInt]
```

We've invoked `D.Symbolic.decompose` over a template of `[Any;AddInt]`, which means we'll try to symbolically decompose the state space of a state machine after the following steps (`_` is used to indicate a symbolic value):

```ocaml
SM.
(init_state
 |> step _
 |> step (Add (Int _)))
```

Calls to `decompose` (and `decompose_par`) return a tuple of two values: the first value is a `paths` generator, while the second is a `unit -> unit` function to be invoked once all the regions one needs have been computed, in order to release all the resources.

In order to consume concrete paths from the `paths` generator we must `reify` them (we'll just reify a single path for this example):

```{.imandra .input}
let first_path = IDF.reify 1i paths |> List.hd;;
```

Since we're decomposing lazily (i.e. we haven't invoked `IDF.decompose ~lazily:false`), the process of reifying a path for the first time will actually be responsible for starting the decomposition process until a first path is available.

Reifying the nth path multiple times will only cause it to be computed the first time, subsequent reifications will simply return the cached path.


Now that we have a `path` value available, we can explore what we can do with it:

- We can ask for sample event values for the current path, which will return a sample for each event in the path:

```{.imandra .input}
let samples = IDF.samples first_path
```

- We can ask for a sample execution replay of the current path, which will return a list of tuples of `input state * input event * output state` for each sample event in the path:
```{.imandra .input}
let replayed_path = IDF.replay first_path
```

- We can ask for the concrete regions representing the constraints of the state machine up to each event in the path:
```{.imandra .input}
#install_printer Imandra_tools.Region_pp.print;;

let regions = IDF.regions first_path
```

It is to be noted that the each symbolic event in those constraints is represented as the `nth` element of the list `e`, thus the first `Any` event will be `List.hd e`, the second `AddInt` will be `List.hd (List.tl e)`, and since we've asked `IDF` to decompose a path of _exactly_ two events, there will be no third or more events, and thus we can find a constraint to that effect: `List.tl (List.tl e) = []`.

- We can ask for the unique ids of each `state` and `event` values in a `path`, the string repr of each `uuid` is used as labels in the `G.t` graph
```{.imandra .input}
#install_printer Uuidm.pp;;

let ids = IDF.ids first_path
```

Finally, let's showcase what it would take to set up a parallel decomposition:

```ocaml
let scheduler = IDF.scheduler ~par:1i ~load:"idf_setup.iml" ~idf:"D.Symbolic" ()
let paths, close = IDF.decompose_par ~schedule:scheduler TPL.[Any;AddInt]
```

The first thing we've created is a scheduler telling it to:
- use a parallelism level of 1, meaning that 1 extra worker will be started (the parallel decomposer uses by default a minumum of 2 processes, a coordinator and worker)
- setup idf from a local file called `idf_setup.iml`: the file should contain all the code we've shown above up to (and including) the insantiatiation of the `D` module
- the name of the module implementing [Idf_intf.SIG](https://docs.imandra.ai/imandra-docs/odoc/imandra-tools/Imandra_tools/Idf_intf/module-type-SIG/index.html) to be used to decompose the model from the worker processes

After having created a scheduler, all the remains to do is merely to invoke `decompose_par` with the appropriate `schedule` argument, and the usage is identical to what we've already described for `decompose`.
