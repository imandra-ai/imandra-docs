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
- [Region_idx](#Region-Indexer-%28Region_idx%29)
- [Region_probs](#Region-Probabilities-%28Region_probs%29)


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
  - a `c` variant type mapping to the concrete `event` type
  - a `concrete` function mapping `t` events to `c` events

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
    type c = State_machine.event
    type state = State_machine.state
    let concrete c t _state = match c, t with
        | Add, Model.Add _ -> true
        | Sub, Model.Sub _ -> true
        | Reset, Model.Reset -> true
        | Any, _ -> true
        | _ -> false
  end

end
```

We're now ready to create a decomposition recipe and apply it to an event template, simply instantiating `Idf` with `Decomp` in a module `IDF`.

We can use the `IDF` module to start decomposing any sequences of events, let's do that over a template of `[any; add; any]` events:

```{.imandra .input}
#program;;

module IDF = Idf.Make(Decomp);;

let g = IDF.decompose (Decomp.Template.[Any;Add;Any]);;
```

Since `IDF` generates a decomposition graph, we need to first create an empty graph via `IDF.G.create`, we can then list all the paths of the decomposition graph from the initial state to the final state:

```{.imandra .input}
let paths = IDF.paths g
let first_path = List.hd paths
```

This output is not very useful, but we can ask `Idf` to play out a sample execution of that path:

```{.imandra .input}
IDF.replay (first_path |> CCList.last_opt |> CCOpt.get_exn)
```

Or we can ask `Idf` to let us inspect the regions for that path (each region in the list will correspond to the constraints and invariant of the model up to each event in the template):

```{.imandra .input}
let first_path_regions = List.map (fun n -> Remote_ref.get_shared_block (IDF.region n)) first_path
```

For a full description of the `Idf` API and capabilities, check out the [Iterative Decomposition Framework](Iterative%20Decomposition%20Framework.md) page.

Looking at the above regions we can spot a common problem with decompositions: the regions become very hard to read, even with quite simple models.

This is a good moment to introduce a second `imandra-tools` module:

# Region Pretty Printer (Region_pp)

The purpose of the `Region_pp` module is twofold: it provides a _default_ drop-in pretty printer for regions, much more powerful than the default region printer _and_ it also provides an extensible framework for creating powerful printers with semantic and ontologic understanding of the model being decomposed.

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

let d = Modular_decomp.top "f";;

Modular_decomp.get_concrete d;;

let rs = Modular_decomp.get_concrete_regions d;;

```

It seems like `Region_pp` could do a better job here:

- `Set.subset x y` is printed as `Set.union x y = y`
- `Set.add x y` is printed as `Map.add x y true`
- `Set.add z (Set.empty)` is printed as `Map.add' (Map.const false) z true` instead of using a more desiderable set syntax like `{ z }`

Let's use the extension mechanisms of `Region_pp` to achieve just that:

```{.imandra .input}
open Region_pp_intf

module Custom = struct
  type 'ty c = Set of ('ty, 'ty c) node_ list

  let map f = function
    | Set els -> Set (List.map f els)

  let compare compare one two =
    match one, two with
    | Set s_one, Set s_two ->
      if
        List.length s_one = List.length s_two
        && CCList.for_all
             (fun el -> List.exists (fun x -> compare el x = Equivalent) s_two)
             s_one
      then
        Equivalent
      else
        UnComparable

  let print p ~focus out = function
    | Set s ->
      CCFormat.(fprintf out "@[<hv>{ %a@ }@]" (list ~sep:(return "@ ; ") p)) s
end

module PPrinter =
  Region_pp.Make
    (Custom)
    (Region_pp_intf.Type_conv.Make (Region_pp_intf.Type_conv.String_type))
open Custom
open PPrinter

let to_curried_types : PPrinter.ty -> PPrinter.ty list =
 fun t -> CCString.split ~by:"->" t |> CCList.map CCString.trim

let from_curried_types : PPrinter.ty list -> PPrinter.ty =
  CCString.concat " -> "

let get_input_types : PPrinter.ty list -> ty list =
 fun t -> CCList.take (CCList.length t - 1) t

let rec refine_ n =
  let union_to_subset ty =
    let types_of_union_input = to_curried_types ty |> get_input_types in
    let subset_type = types_of_union_input @ [ bool_type () ] in
    from_curried_types subset_type
  in
  match view n with
  | Funcall ({ view = Var "Map.add'"; _ }, _) when is_proper_set n ->
    mk ~ty:n.ty (Custom (Set (gather_keys n)))
  | Funcall ({ view = Var "Map.add'"; ty }, [ m; k; { view = Boolean true; _ } ])
    ->
    mk ~ty:n.ty (Funcall (mk ~ty (Var "Set.add"), [ m; k ]))
    (* verify (fun x y -> Set.union x y = y ==> Set.subset x y)  *)
  | Eq ({ view = Funcall ({ view = Var "Set.union"; ty }, [ x; y ]); _ }, z)
    when Comparator.(is_eq (compare y z)) ->
    let ty = union_to_subset ty in
    mk ~ty:n.ty
      (Eq
         ( mk ~ty:n.ty (Funcall (mk ~ty (Var "Set.subset"), [ x; y ])),
           mk ~ty:n.ty (Boolean true) ))
  | Neq ({ view = Funcall ({ view = Var "Set.union"; ty }, [ x; y ]); _ }, z)
    when Comparator.(is_eq (compare y z)) ->
    let ty = union_to_subset ty in
    mk ~ty:n.ty
      (Eq
         ( mk ~ty:n.ty (Funcall (mk ~ty (Var "Set.subset"), [ x; y ])),
           mk ~ty:n.ty (Boolean false) ))
  | Eq (z, { view = Funcall ({ view = Var "Set.union"; ty }, [ x; y ]); _ })
    when Comparator.(is_eq (compare y z)) ->
    let ty = union_to_subset ty in
    mk ~ty:n.ty
      (Eq
         ( mk ~ty:n.ty (Funcall (mk ~ty (Var "Set.subset"), [ x; y ])),
           mk ~ty:n.ty (Boolean true) ))
  | Neq (z, { view = Funcall ({ view = Var "Set.union"; ty }, [ x; y ]); _ })
    when Comparator.(is_eq (compare y z)) ->
    mk ~ty:n.ty
      (Eq
         ( mk ~ty:n.ty (Funcall (mk ~ty (Var "Set.subset"), [ x; y ])),
           mk ~ty:n.ty (Boolean false) ))
  | _ -> n

and gather_keys n =
  match view n with
  | Funcall ({ view = Var "Map.add'"; _ }, [ m; k; { view = Boolean true; _ } ])
    ->
    k :: gather_keys m
  | Funcall ({ view = Var "Map.const"; _ }, [ { view = Boolean false; _ } ]) ->
    []
  | _ ->
    failwith
      (Printf.sprintf "Unexpected set value: %s" (PPrinter.Printer.to_string n))

and is_proper_set x =
  try
    ignore (gather_keys x);
    true
  with _ -> false

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

Let's explore the next `imandra-tools` module

# Region Term Synthesizer (Region_term_synth)

`Imandra`'s ability to both reify failed proofs into counter-examples and sample values from regions provides a lot of power. `Region_term_synth` extends this power, allowing `Imandra` to synthesize any region's `Term` expression as code.

This, combined with `Imandra`'s decomposition facilities, allow us to generate powerful and complete regression test suites, analyse existing test suites to detect region coverage, and much more.

Let's see a quick example of how this works in practice:

```{.imandra .input}
Caml.List.mapi (fun i region ->
  let gs = "region_" ^ (string_of_int i) in (* Imandra_util.Util.gensym () *)
  let term = Term.and_l @@ Modular_region.constraints region in
  let body = Region_term_synth.synthesize ~default:Term.Syn.(mk ~loc:Iloc.none False) term in
  let args = Modular_region.args region |> List.map Var.name |> String.concat " " in
  let func = Printf.sprintf "let %s %s = %s" gs args body in
  System.eval func;
  gs)
  rs
```

The above should be quite straightforward:

- We extract the constraints from the region and we conjoin them into a single `Term`
- We ask `Region_term_synth` to synthesize our term, using `false` as a default value (we're synthesizing a boolean function)
- Finally we generate a string representation of a function using the synthesized term as its body, and evaluate it

We can start playing with those functions immediately:

```{.imandra .input}
region_0 (Set.of_list [1]) Set.empty 0;;
region_0 Set.empty (Set.of_list [1]) 0;;

region_1 Set.empty (Set.of_list [1]) 0;;
region_1 (Set.of_list [1]) Set.empty 0;;
```

Great! `region_0` is now a boolean function that checks whether or not certain values of `x` and `y` belong to the region of behaviour 0. `region_1` does the same for the region of behaviour 1.

This ability to generate _total_ functions from _partial regions of behaviour_ is fundamental to creating modules like `Idf` and `Region_idx`.

# Region Indexer (Region_idx)

It may be sometimes useful to know which region a particular input belongs to; while this can be done by using `Region_term_synth` and synthesizing recogniser functions for each region and testing them against the value until we find a match, this could get very computationally expensive in the presence of a large number of regions and constraints.

`Region_idx` provides a solution for this: it allows to create "indexing" functions that efficiently match input values against a single entry in a list of regions.
After providing a first class module specificing the types of the arguments to the function the regions belong to (as a tuple), `Region_idx.indexer_for` returns an index alist and an indexer function.

```{.imandra .input}
let idx, indexer =
  let args = (module struct type args = int Set.t * int Set.t * int end : Region_idx.Args with type args = _) in
  Region_idx.indexer_for args rs;;
```

The first value returned is an alist of index -> region, while the second value is the indexer function, taking as inputs the arguments of the regions (as a tuple) and returning the index of the matching region, or raising `Not_found` if the values don't match any regions (This can happen if the values provided don't satisfy the side condition, or if the list of regions passed to `indexer_for` was partial).

Let's say we want to know which region the arguments `Set.empty, (Set.of_list [1]), 0` belong to, we just need to find its index and find the matching region:

```{.imandra .input}
let i = indexer (Set.empty, (Set.of_list [1]), 0) in
  CCList.assq i idx;;
```

# Region Probabilities (Region_probs)

What if we want to not just identify the distinct regions of a program's behaviour, but how likely those behaviours are to occur? The `Region_probs` module allows us to do just that. In particular, users can easily create custom hierarchical statistical models defining joint distributions over inputs to their programs or functions, then sample from these models to get a probability distribution over regions, or query them with Boolean conditions. Alternatively, a dataset in the form of a `CSV` file can be imported and used as a set of samples when the underlying distribution is unknown. This introduction contains a short example, but for a more detailed tutorial of how to use the module, please see the dedicated [Region Probabilities notebook](Region%20Probabilities.md).

First we'll open the `Region_probs` module, then define some custom types and a function that we'll be decomposing:

```{.imandra .input}
#logic;;
open Region_probs;;

type colour = Red | Green | Blue;;
type obj = {colour : colour; broken : bool};;
type dom = (obj * Q.t * Z.t);;

let f' (obj, temp, num) =
  let a =
    if obj.colour = Red then
      if obj.broken then num else 7
    else
      num * 2 in
  let b =
    if temp >. 18.5 && obj.colour = Blue then
      temp +. 4.3
    else if obj.colour = Green then
      temp -. 7.8
    else
      14.1 in
  (a, b);;
```

Now we can define a joint distribution over inputs to `f` using some built-in probability distributions and a sequential sampling procedure. We can call this function with the unit argument `()` to generate samples:

```{.imandra .input}
let distribution () =
  let c = categorical ~classes:[Red; Green; Blue] ~probs:[0.5; 0.2; 0.3] () in
  let b = bernoulli ~p:0.4 () in
  let mu = if b then 20. else 10. in
  let temp = gaussian ~mu ~sigma:5. () in
  let num =
    if c = Green then
      poisson ~lambda:6.5 ~constraints:[(7, 10)] ()
    else
      poisson ~lambda:6.5 () in
  ({colour = c; broken = b}, temp, num) [@@program];;

distribution ();;
```

Now we have all these components we can find the regions of `f`, create a model from our `distribution` function, then estimate and display region probabilities:

```{.imandra .input}
let d = Modular_decomp.top ~prune:true "f'" [@@program];;

let regions = Modular_decomp.get_concrete_regions d [@@program];;

module Example = Distribution.From_Sampler (struct type domain = dom let dist = distribution end) [@@program];;

let probs = Example.get_probs regions () [@@program];;

print_probs probs;;
```

To see more of what can be done with the `Region_probs` module, including forming models based on existing datasets and querying models using Boolean conditions, along with additional options, please see the [Region Probabilities notebook](Region%20Probabilities.md).
