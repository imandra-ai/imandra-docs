---
title: "Imandra-tools Introduction"
description: "In this notebook we’re going to introduce the imandra-tools library and explore how it extends Imandra's principal region decomposition utilities."
kernel: imandra
slug: 'imandra-tools-intro'
key-phrases:
  - imandra-tools
  - state machine
  - pretty-printing
  - term synthesis
  - iterative decomposition
  - concrete decomposition
  - symbolic decomposition
---

# An introduction to `imandra-tools`

In this notebook, we'll introduce the `imandra-tools` library and go through how to use its powerful modules to augment Imandra's decomposition facilities.

Normally, before using `imandra-tools`, one would have to require it in their Imandra toplevel by executing the require statement `#require "imandra-tools"`. Since the `#require` directive is disabled for security reasons in this notebook, this step won't be necessary as we've pre-loaded imandra-tools.

Let's make sure this is actually the case before starting.

```{.imandra .input}
#show Imandra_tools;;
```

Great! Let's start exploring `imandra-tools`.

- [Idf](#Iterative-Decomposition-Framework-%28Idf%29)
- [Region_pp](#Region-Pretty-Printer-%28Region_pp%29)
- [Region_term_synth](#Region-Term-Synthesizer-%28Region_term_synth%29)


<div style="margin-top: 1em; background-color: #ffcc66; padding: 1em">
Note: this is an introductory walkthrough of the capabilities of `imandra-tools`, much more than what's described in this notebook is possible with it, but we'll defer a more in-depth explanation of each module in future notebooks.
</div>

# Iterative Decomposition Framework (Idf)

The first module we're going to explore is `Imandra_tools.Idf`. Its broad purpose is to provide a framework allowing for iterative, lazy decomposition of state-machine models.

Before diving into its usage, let's first define a simple example of such a model.

```{.imandra .input}
module Model = struct
  type message = Add of int | Sub of int | Reset

  type counter_state = { counter : int
                       ; default : int }

  let one_step msg state =
    if state.counter = 1337 then
      { state with counter = state.default }
    else
      match msg with
      | Reset -> { state with counter = 0 }
      | Add n ->
         if state.counter + n > 9000 then
           { state with counter = 0 }
         else
           { state with counter = state.counter + n }
      | Sub n ->
         if n > state.counter then
           state
         else
           { state with counter = state.counter - n }
  end
```

The above model is not very interesting but it exemplifies all that's needed for a model to be suitable for usage with `Idf`:

- An algebraic type describing all the possible messages a model can react to (`message`)
- A type describing the current state of the model (`counter_state`)
- A transition function from message and state to new state (`one_step`)

Now that the module is defined, we need to set-up `Idf` for its decomposition.

We need to do is define a module implementing the `Idf_intf.DFSM_SIG` module signature:

- a `State_machine` module implementing the `Idf_intf.SM_SIG` module signature:
  - an `event` type mapping to the model message type
  - a `state` type mapping to the model state type
  - an `init_state` value of type `state`
  - a `step` transition function mapping to the model transition function
  - an `is_valid` function that takes an `event` and a `state` and checks whether that `<event,state>` transition is valid or not
- a `module_name` value mapping to the name of the module being defined (this is necessary for reflection purposes)
- a `Template` module implementing the `Idf_intf.TPL_SIG` module signature:
  - a `t` variant type symbolically describing events from our model
  - a `concrete` function from `t` to a list of strings mapping the symbolic event to concrete `event` type names

```{.imandra .input}
open Imandra_tools

module Decomp = struct

  module State_machine = struct
    open Model

    type event = message
    type state = counter_state

    let init_state : state =
      { counter = 0 ; default = 23 }

    let step (event : event) (state : state) : state =
       one_step event state

    let is_valid (event : event) (state : state) : bool =
      match event with
      | Reset -> true
      | Add n -> n > 0
      | Sub n -> n > 0 && n <= state.counter

  end

  let module_name = "Decomp"

  module Template = struct
    type t = Add | Sub | Reset | Any

    let concrete = function
        | Add -> ["Model.Add"]
        | Sub -> ["Model.Sub"]
        | Reset -> ["Model.Reset"]
        | Any -> []
  end

end
```

We're now ready to create a decomposition recipe and apply it to an event template, simply instantiating `Idf` with `Decomp` in a module `D`.

We can use the `D` module to start decomposing any sequences of events, by using either `D.Symbolic` or `D.Sampling`, depending on which decomposition strategy we want:

- sampling: this strategy will decompose the first event in the sequence, sample a value off each region and continue decomposition using the sampled value as next initial state when decomposing the next event. Because of its reliance on random sampling, this strategy is not complete, but is quite fast.
- symbolic: this strategy will synthesize the constraints and invariants of each region as ocaml code and inject them into the decomposition of the next event, no sampling is done and thus this strategy is complete, but can also be much slower than concrete.

Let's use `D.Symbolic.decompose` for this notebook, over a template of `[any; add; any]` events:

```{.imandra .input}
#program;;

module D = Idf.Make(Decomp);;
module IDF = D.Symbolic;;

let paths, _ = IDF.decompose (Decomp.Template.[Any;Add;Any]);;
```

Something odd has happened: we've asked `Idf` to decompose our template, but nothing happened!

This is because `Idf` is a _lazy_ framework, we need to tell it how many paths we want to produce:

```{.imandra .input}
let first_path = IDF.reify 1i paths |> List.hd
```

This output is not very useful, but we can ask `Idf` to play out a sample execution of that path:

```{.imandra .input}
IDF.replay first_path
```

Or we can ask `Idf` to let us inspect the regions for that path (each region in the list will correspond to the constraints and invariant of the model at each event in the template):

```{.imandra .input}
#install_printer Decompose.print;;

let first_path_regions = IDF.regions first_path
```

For a full description of the `Idf` API and capabilities, check out the [Iterative Decomposition Framework](Iterative%20Decomposition%20Framework.md) page.

Looking at the above regions we can spot a common problem with decompositions: the regions become very hard to read, even with quite simple models.

This is a good moment to introduce a second `imandra-tools` module:

# Region Pretty Printer (Region_pp)

The purpose of the `Region_pp` module is twofold: it provides a _default_ drop-in pretty printer for regions, much more powerful than `Decompose.print` _and_ it also provides an extensible framework for creating powerful printers with semantic and ontologic understanding of the model being decomposed.

Behind the scenes, the printer has phases for constraint unification, merging, normalisation and pruning, symbolic evaluation, and much more - all of it is user-extensible and customizable.

All it takes to start reaping the benefits is to install the default pretty printer:

```{.imandra .input}
#install_printer Region_pp.print;;

first_path_regions
```

We can immediately appreciate that just under half the total constraints have been identified as redundant and eliminated.

Let's look at another example:

```{.imandra .input}
#logic;;

let f (x : int Set.t) y z =
  if Set.subset x y then
    Set.add z x
  else
    Set.add z (Set.empty);;

#program;;

let rs = Decompose.top "f";;
```

It seems like `Region_pp` could do a better job here:

- `Set.subset x y` is printed as `Set.union x y = y`
- `Set.add x y` is printed as `Map.add x y true`
- `Set.add z (Set.empty)` is printed as `Map.add' (Map.const false) z true` instead of using a more desiderable set syntax like `{ z }`

Let's use the extension mechanisms of `Region_pp` to achieve just that:

```{.imandra .input}
open Region_pp_intf

module Custom = struct

  type t =
    | Set of t node_ list

  let map f = function
    | Set els -> Set (List.map f els)

  let compare one two =
    match one, two with
    | Set s_one, Set s_two ->
       if List.length s_one = List.length s_two &&
            CCList.for_all (fun el -> List.mem el s_two) s_one then
         Equivalent
       else
         UnComparable

  let print p ~focus out = function
    | Set s -> CCFormat.(fprintf out "@[<hv>{ %a@ }@]" (list ~sep:(return "@ ; ") p)) s
end

module PPrinter = Region_pp.Make(Custom)

open Custom
open PPrinter

let rec refine_ = function
  | Funcall ("Map.add'", _) as ks when is_proper_set ks ->
     Custom (Set (gather_keys ks))

  | Funcall ("Map.add'", [m; k; Boolean true]) ->
     Funcall ("Set.add", [m; k])

    (* verify (fun x y -> Set.union x y = y ==> Set.subset x y)  *)

  | Eq (Funcall ("Set.union", [x;y]), z) when Comparator.(is_eq (compare y z)) ->
     Eq (Funcall ("Set.subset", [x;y]), Boolean true)

  | Neq (Funcall ("Set.union", [x;y]), z) when Comparator.(is_eq (compare y z)) ->
     Eq (Funcall ("Set.subset", [x;y]), Boolean false)

  | Eq (z, Funcall ("Set.union", [x;y])) when Comparator.(is_eq (compare y z)) ->
     Eq (Funcall ("Set.subset", [x;y]), Boolean true)

  | Neq (z, Funcall ("Set.union", [x;y])) when Comparator.(is_eq (compare y z)) ->
     Eq (Funcall ("Set.subset", [x;y]), Boolean false)

  | x -> x

and gather_keys = function
  | Funcall ("Map.add'", [m; k; Boolean true]) -> k::gather_keys m
  | Funcall ("Map.const", [Boolean false]) -> []
  | x -> failwith (Printf.sprintf "Unexpected set value: %s" (PPrinter.Printer.to_string x))

and is_proper_set x =
  try ignore(gather_keys x); true with _ -> false

let refine ast = XF.walk_fix refine_ ast |> CCList.return

let print = PPrinter.print ~refine ()
```

Let's look at what we've done:

- first we've defined a `Custom` module whose signature includes the signature of `Region_pp_intf.SIG`, defining `map`ping, `print`ing and `compare`ing functions for an abstract `Set` value
- next we instantiate `Region_pp.Make` using this `Custom` module, creating a `PPrinter` module that is `Set`-aware
- finally we define a `refine` function that transforms a `PPrinter.node` into custom `Set` values or converts `Map.` invocations into appropriate `Set.` ones.

Let's install this printer and look at the regions again:

```{.imandra .input}
#install_printer print;;
rs
```

Great! Exactly what we wanted to be printed.

`Region_pp` provides more extension hooks and utilities than just the `PP` functor and `~refine`, but we'll go over that in more detail in a dedicated notebook.

Let's explore the last `imandra-tools` module

# Region Term Synthesizer (Region_term_synth)

`Imandra`'s ability to both reify failed proofs into counter-examples and sample values from regions provides a lot of power. `Region_term_synth` extends this power, allowing `Imandra` to synthesize any region's `Term` expression as code.

This, combined with `Imandra`'s decomposition facilities, allow us to generate powerful and complete regression test suites, analyse existing test suites to detect region coverage, and much more.

Let's see a quick example of how this works in practice:

```{.imandra .input}
Caml.List.mapi (fun i region ->
  let gs = "region_" ^ (string_of_int i) in (* Imandra_util.Util.gensym () *)
  let term = Term.and_l @@ Decompose_region.constraints region in
  let body = Region_term_synth.synthesize ~default:Term.Syn.False term in
  let args = Decompose_region.args region |> List.map Var.name |> String.concat " " in
  let func = Printf.sprintf "let %s %s = %s" gs args body in
  Reflect.eval func;
  gs)
  rs
```

The above should be quite straightforward:

- We extract the constraints from the region and we conjoin them into a single `Term`
- We ask `Region_term_synth` to synthesize our term, using `false` as a default value (we're synthesizing a boolean function)
- Finally we generate a string representation of a function using the synthesized term as its body, and evaluate it

We can start playing with those functions immediately:

```{.imandra .input}
region_0 (Set.of_list [1]) Set.empty Set.empty;;
region_0 Set.empty (Set.of_list [1]) Set.empty;;

region_1 Set.empty (Set.of_list [1]) Set.empty;;
region_1 (Set.of_list [1]) Set.empty Set.empty;;
```

Great! `region_0` is now a boolean function that checks whether or not certain values of `x` and `y` belong to the region of behaviour 0. `region_1` does the same for the region of behaviour 1.

This ability to generate _total_ functions from _partial regions of behaviour_ is immensely powerful and at the core of `Idf` and other powerful analysis tools we build.
