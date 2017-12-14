---
title: "Dashing VGs"
excerpt: "Introduction to `dash`, Imandra's randomised testing framework."
layout: pageSbar
permalink: /dashingVGs/
colName: Dashing VGs
---

#### Overview

Imandra's `dash` functionality makes it easy to randomly test VGs before you invest the time and effort to verify them. 

Dash is enabled by turning on `dash_mode` via the directive `:dash_mode on`.

When in `dash_mode`, two key things occur: 
* Imandra is placed in `:program` mode (i.e., `:shadow off`), so that all `type` and `function` definitions are not reflected into the Imandra logic. This makes the processing of definitions (i.e., the loading of models) fast. The definitions are processed as pure OCaml and are compiled on the fly.
* Random value generators are created for all types that are defined. By default, when a type `ty` is defined, a value generator named `gen_ty : Valgen.RS.t -> ty` is automatically created and reflected into the Imandra runtime.

We can then use these randomised value generators to test our functions and conjectures.

#### Dashing verification goals

The simplest way to dash is through the `dash` command. This command has the same syntax as `verify`, but performs randomised testing rather than formal logical reasoning.

Let's see a simple example:
```
# :dash_mode on
> type order = Market | Limit | Quote;;
type order = Market | Limit | Quote
> let f x = match x with
  Market -> 50
  | _     -> 100;;
val f : order -> int = <fun>
> dash _ x = f x < 100;;
dash _ = <dashed:2>
> DX.xs;;
- : order list = [Limit; Quote]
> dash _ x = f x > 0;;
dash _ = <passed:100>
```

When we `dash` a goal, there are two possible outcomes:
 * The goal passes the random testing, in which case the number of tests that passed is reported.
 * The goal fails (is *dashed by*) the random testing, in which case the number of counterexamples found is reported, and the list of computed counterexamples is reflected into the runtime and bound within the `DX` module as the value `DX.xs`. 

In `dash_mode`, we may use arbitrary OCaml code to compute with the `DX.xs` counterexamples.

Dash is designed to scale with little to no performance impact as the state-spaces of our models become more complex:
```
> type state = { order_type : order;
  qty        : int;
  price      : float option;
  top        : float option;
  tick       : int };;
type state = {
    order_type : order;
    qty : int;
    price : float option;\
    top : float option;
    tick : int;
  }
> let step (x : state) =
if x.order_type = Limit && x.qty > 0 then
{ x with price = None }
else
{ x with tick = x.tick + 1 }
;;
val step : state -> state = <fun>
> dash _ x = (step x).tick <> x.tick;;
dash _ = <dashed:26>
> List.length DX.xs;;
- : int = 26
> List.hd DX.xs;;
- : state = 
{order_type = Limit; qty = 4; price = None; top = None; tick = 68}
```

#### Using the Dash and Valgen modules interactively

We can also use the `Dash` and `Valgen` modules interactively, and build and compile Imandra tools that make use of them.

Recall that in `dash_mode`, all type definitions `ty` give rise to random value generators ```gen_ty : Valgen.RS.t -> ty```. 

A value of type `Valgen.RS.t` is a pseudo-random number generator (PRNG) state. We may create these states with `Valgen.RS.make : int array -> Valgen.RS.t`. The argument we pass to `Valgen.RS.make` is a PRNG *seed*. 
```ocaml
> let st = Valgen.RS.make [| 1983; 1984; 2017 |];;
val st : Valgen.RS.t = <abstr>
```
Given `st`, we can now apply our type inhabitant generator functions and obtain a pseudo-random sequence of values of our types:

```
> gen_order st;;
- : order = Market
> gen_order st;;
- : order = Limit
> gen_order st;;
- : order = Quote
> gen_order st;;
- : order = Limit
> gen_order st;;
- : order = Limit
> gen_order st;;
- : order = Quote
> gen_state st;;
- : state =
  {order_type = Quote; qty = 49; price = None; top = Some 26.0844866625078957; tick = 72}
> gen_state st;;
- : state =
  {order_type = Limit; qty = 59; price = None; top = Some 58.2841969041644887; tick = 61}
> gen_state st;;
- : state =
  {order_type = Market; qty = 58; price = Some 44.5605671641410197; top = None; tick = 33}
> gen_state st;;
- : state =
  {order_type = Market; qty = 33; price = Some 59.3532384193087523; top = None; tick = 89}
> gen_state st;;
- : state =
  {order_type = Market; qty = 15; price = Some 97.7772441348000569; top = None; tick = 34}
> gen_state st;;
- : state = {order_type = Limit; qty = 1; price = None; top = None; tick = 9}
```
We may also construct Dash `tests` using the `Dash.make` function:
```
> Dash.make;;
- : ?n:int ->
    ?name:string ->
    ?size:('a -> int) ->
    ?limit:int -> 'a Valgen.t -> 'a Valgen.Prop.t -> 'a Dash.test
  = <fun>
```
For example, we can duplicate the functionality of our previous `dash` call with the following manually constructed and executed test:
```
> let test = Dash.make ~n:100
  ~name:"small example"
  gen_order
  (fun x -> f x < 100);

val test : order Dash.test =
Dash.Test
  {Dash.n = 100; prop = <fun>; gen = <fun>; name = "small example";
  limit = 10; size = None}

> Dash.run test;;
dash small example = <dashed:2>
- : order list = [Limit; Quote]
```

#### Configuration

The execution of a `dash` command is affected by a number of configuration options.

## Search depth

By default, `dash` will search for counterexamples by generating a random sequence of `100` values of the given type. You can increase this default value through the `:dash_depth` directive, e.g., `:dash_depth 1000`.

```
> dash _ x = (step x).tick <> x.tick;;
dash _ = <dashed:26>
> :dash_depth 1000
dash_depth set to 1000.
> dash _ x = (step x).tick <> x.tick;;
dash _ = <dashed:312>
> List.nth DX.xs 150;;
- : state =
  {order_type = Limit; qty = 50; price = None; top = Some 84.8722978134515529; tick = 26}

```
## PRNG seed

The sequence of random values computed by `dash` is a function of a pseudo-random number generator (PRNG) state. The PRNG state is parameterized by an initial value called a *seed*. Given the same seed value, two otherwise identical `dash` queries will lead to the generation of the same random sequence of type inhabitants. PRNG states are created fresh for every `dash` call, and are initialized by the global seed.

By default, the PRNG seed is initialised to a standard (configurable) value. This can be modified through the `:dash_seed` directive.

```
> dash _ x = (step x).tick <> x.tick;;
dash _ = <dashed:26>
> let old_dxs = ref [];;
val old_dxs : '_a list ref = {contents = []}
> let () = old_dxs := DX.xs;;
> dash _ x = (step x).tick <> x.tick;;
dash _ = <dashed:26>
> DX.xs = !old_dxs;;
- : bool = true
> :dash_seed 371289 832622 387736
Dash seed set.
> dash _ x = (step x).tick <> x.tick;;
dash _ = <dashed:36>
> DX.xs = !old_dxs;;
- : bool = false
```

## Printing counterexamples

By default, `dash` does not automatically print the counterexamples it finds. Instead, it prints a number `k`, e.g., `<dashed:k>`, indicating that `k` counterexamples have been computed and stored in the list `DX.xs`.  

```
> dash _ (x,y) = x + y < 10;;
dash _ = <dashed:100>
```

This behaviour is intentional: Dash is designed to compute lists of counterexamples, not single (counter-)examples like `verify`, `instance`, and `check`. Moreover, `dash` is designed to be fast, and printing large counterexamples can be computationally expensive. By reflecting the found counterexamples into the `DX.xs` list, `dash` places control of the display of counterexamples into the hands of the user.
```
> DX.xs;;
- : (int * int) list =
[(2, 12); (3, 49); (4, 51); (5, 12); (5, 39); (5, 64); (6, 68); (8, 60);
 (10, 32); (11, 29); (12, 3); (12, 7); (12, 58); (14, 4); (14, 54); (15, 19);
 (16, 76); (17, 14); (18, 49); (18, 61); (19, 55); (21, 99); (23, 68);
 (25, 70); (25, 91); (27, 9); (28, 7); (29, 28); (30, 48); (31, 38);
 (31, 44); (33, 15); (33, 40); (36, 67); (37, 86); (38, 38); (38, 93);
 (39, 26); (39, 63); (40, 33); (41, 60); (43, 7); (43, 77); (43, 79);
 (45, 82); (46, 61); (47, 77); (47, 78); (47, 87); (48, 74); (50, 82);
 (52, 22); (52, 29); (52, 59); (54, 55); (54, 76); (56, 39); (56, 54);
 (57, 91); (58, 6); (60, 15); (60, 74); (60, 81); (61, 67); (62, 97);
 (63, 56); (64, 5); (64, 21); (64, 86); (65, 63); (66, 41); (66, 75);
 (66, 77); (67, 16); (72, 49); (72, 50); (73, 91); (74, 70); (75, 10);
 (75, 26); (77, 77); (78, 9); (78, 65); (78, 68); (79, 31); (80, 42);
 (81, 47); (86, 44); (87, 77); (88, 14); (88, 52); (88, 82); (89, 88);
 (92, 6); (93, 46); (95, 24); (95, 84); (97, 75); (97, 99); (99, 32)]
```
That said, `dash` can be configured to automatically print a single counterexample from each `dash` command that computes one. This is done by enabling the `dash_dx` printer option via the `:set_print` directive, i.e., `:set_print dash_dx`. When this option is enabled, the first counterexample (i.e., `List.hd DX.xs`) will be printed. This option can be disabled with `:unset_print dash_dx`.

```
> :set_print dash_dx
> dash _ (x,y) = x + y < 10;;
dash _ = <dashed:100>

Counterexample (List.hd DX.xs):
- : int * int = (2, 12)

> dash _ x = (step x).tick <> x.tick;;
dash _ = <dashed:36>

Counterexample (List.hd DX.xs):
- : state =
  {order_type = Limit; qty = 1; price = Some 69.1502421389093769; top = Some 8.99170783937942; tick = 52}
  
> :unset_print dash_dx
> dash _ (x,y) = x + y < 10;;
dash _ = <dashed:100>

```

Note that the format of the printed counterexamples differs slightly from that of other commands such as `verify`, `instance` and `check`. The key differences are as follows:

* The counterexample is presented as tuple, not a record. This is consistent with how the values are stored in `DX.xs`.
* The type of the tuple is printed before the counterexample is displayed, using the printing format of OCaml toplevel evaluation results, e.g., `- : int * int = (2, 12)`. 

This display of counterexamples is also affected by the standard OCaml `#print_depth` and `#print_length` values. These can be changed by executing `#print_depth k` and `#print_length k`. The default Imandra printer values are `#print_depth 1000` and `#print_length 1000`. If a counterexample is printed and its display will exceed these bounds, ellipses `...` are printed in place of the offending value nodes.

See the documentation on [Printing](doc:printing-1) for how custom printers can be used to display `dash` counterexamples.
