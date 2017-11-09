---
title: "Dashing VGs"
excerpt: "Introduction to `dash`, Imandra's randomised testing framework."
layout: pageSbar
permalink: /dashingVGs/
colName: Dashing VGs
---
[block:api-header]
{
  "title": "Overview"
}
[/block]
Imandra's `dash` functionality makes it easy to randomly test VGs before you invest the time and effort to verify them. 

Dash is enabled by turning on `dash_mode` via the directive `:dash_mode on`.

When in `dash_mode`, two key things occur: 
* Imandra is placed in `:program` mode (i.e., `:shadow off`), so that all `type` and `function` definitions are not reflected into the Imandra logic. This makes the processing of definitions (i.e., the loading of models) fast. The definitions are processed as pure OCaml and are compiled on the fly.
* Random value generators are created for all types that are defined. By default, when a type `ty` is defined, a value generator named `gen_ty : Valgen.RS.t -> ty` is automatically created and reflected into the Imandra runtime.

We can then use these randomised value generators to test our functions and conjectures.
[block:api-header]
{
  "title": "Dashing verification goals"
}
[/block]
The simplest way to dash is through the `dash` command. This command has the same syntax as `verify`, but performs randomised testing rather than formal logical reasoning.

Let's see a simple example:
[block:code]
{
  "codes": [
    {
      "code": "# :dash_mode on\n> type order = Market | Limit | Quote;;\ntype order = Market | Limit | Quote\n> let f x = match x with\n    Market -> 50\n   | _     -> 100;;\nval f : order -> int = <fun>\n> dash _ x = f x < 100;;\ndash _ = <dashed:2>\n> DX.xs;;\n- : order list = [Limit; Quote]\n> dash _ x = f x > 0;;\ndash _ = <passed:100>",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
When we `dash` a goal, there are two possible outcomes:
 * The goal passes the random testing, in which case the number of tests that passed is reported.
 * The goal fails (is *dashed by*) the random testing, in which case the number of counterexamples found is reported, and the list of computed counterexamples is reflected into the runtime and bound within the `DX` module as the value `DX.xs`. 

In `dash_mode`, we may use arbitrary OCaml code to compute with the `DX.xs` counterexamples.

Dash is designed to scale with little to no performance impact as the state-spaces of our models become more complex:
[block:code]
{
  "codes": [
    {
      "code": "> type state = { order_type : order;\n                 qty        : int;\n                 price      : float option;\n                 top        : float option;\n                 tick       : int };;\ntype state = {\n  order_type : order;\n  qty : int;\n  price : float option;\n  top : float option;\n  tick : int;\n}\n> let step (x : state) =\n   if x.order_type = Limit && x.qty > 0 then\n     { x with price = None }\n   else\n     { x with tick = x.tick + 1 }\n  ;;\nval step : state -> state = <fun>\n> dash _ x = (step x).tick <> x.tick;;\ndash _ = <dashed:26>\n> List.length DX.xs;;\n- : int = 26\n> List.hd DX.xs;;\n- : state =\n{order_type = Limit; qty = 4; price = None; top = None; tick = 68}",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]

[block:api-header]
{
  "title": "Using the Dash and Valgen modules interactively"
}
[/block]
We can also use the `Dash` and `Valgen` modules interactively, and build and compile Imandra tools that make use of them.

Recall that in `dash_mode`, all type definitions `ty` give rise to random value generators ```gen_ty : Valgen.RS.t -> ty```. 

A value of type `Valgen.RS.t` is a pseudo-random number generator (PRNG) state. We may create these states with `Valgen.RS.make : int array -> Valgen.RS.t`. The argument we pass to `Valgen.RS.make` is a PRNG *seed*. 
[block:code]
{
  "codes": [
    {
      "code": "> let st = Valgen.RS.make [| 1983; 1984; 2017 |];;\nval st : Valgen.RS.t = <abstr>",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Given `st`, we can now apply our type inhabitant generator functions and obtain a pseudo-random sequence of values of our types:
[block:code]
{
  "codes": [
    {
      "code": "> gen_order st;;\n- : order = Market\n> gen_order st;;\n- : order = Limit\n> gen_order st;;\n- : order = Quote\n> gen_order st;;\n- : order = Limit\n> gen_order st;;\n- : order = Limit\n> gen_order st;;\n- : order = Quote\n> gen_state st;;\n- : state =\n{order_type = Quote; qty = 49; price = None; top = Some 26.0844866625078957;\n tick = 72}\n> gen_state st;;\n- : state =\n{order_type = Limit; qty = 59; price = None; top = Some 58.2841969041644887;\n tick = 61}\n> gen_state st;;\n- : state =\n{order_type = Market; qty = 58; price = Some 44.5605671641410197; top = None;\n tick = 33}\n> gen_state st;;\n- : state =\n{order_type = Market; qty = 33; price = Some 59.3532384193087523; top = None;\n tick = 89}\n> gen_state st;;\n- : state =\n{order_type = Market; qty = 15; price = Some 97.7772441348000569; top = None;\n tick = 34}\n> gen_state st;;\n- : state = {order_type = Limit; qty = 1; price = None; top = None; tick = 9}",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
We may also construct Dash `tests` using the `Dash.make` function:
[block:code]
{
  "codes": [
    {
      "code": "> Dash.make;;\n- : ?n:int ->\n    ?name:string ->\n    ?size:('a -> int) ->\n    ?limit:int -> 'a Valgen.t -> 'a Valgen.Prop.t -> 'a Dash.test\n= <fun>",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
For example, we can duplicate the functionality of our previous `dash` call with the following manually constructed and executed test:
[block:code]
{
  "codes": [
    {
      "code": "> let test = Dash.make ~n:100 \n                       ~name:\"small example\" \n                        gen_order \n                       (fun x -> f x < 100);;\nval test : order Dash.test =\n  Dash.Test\n   {Dash.n = 100; prop = <fun>; gen = <fun>; name = \"small example\";\n    limit = 10; size = None}\n> Dash.run test;;\ndash small example = <dashed:2>\n- : order list = [Limit; Quote]",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]

[block:api-header]
{
  "title": "Configuration"
}
[/block]
The execution of a `dash` command is affected by a number of configuration options.

## Search depth

By default, `dash` will search for counterexamples by generating a random sequence of `100` values of the given type. You can increase this default value through the `:dash_depth` directive, e.g., `:dash_depth 1000`.
[block:code]
{
  "codes": [
    {
      "code": "> dash _ x = (step x).tick <> x.tick;;\ndash _ = <dashed:26>\n> :dash_depth 1000\ndash_depth set to 1000.\n> dash _ x = (step x).tick <> x.tick;;\ndash _ = <dashed:312>\n> List.nth DX.xs 150;;\n- : state =\n{order_type = Limit; qty = 50; price = None; top = Some 84.8722978134515529;\n tick = 26}",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
## PRNG seed

The sequence of random values computed by `dash` is a function of a pseudo-random number generator (PRNG) state. The PRNG state is parameterized by an initial value called a *seed*. Given the same seed value, two otherwise identical `dash` queries will lead to the generation of the same random sequence of type inhabitants. PRNG states are created fresh for every `dash` call, and are initialized by the global seed.

By default, the PRNG seed is initialised to a standard (configurable) value. This can be modified through the `:dash_seed` directive.
[block:code]
{
  "codes": [
    {
      "code": "> dash _ x = (step x).tick <> x.tick;;\ndash _ = <dashed:26>\n> let old_dxs = ref [];;\nval old_dxs : '_a list ref = {contents = []}\n> let () = old_dxs := DX.xs;;\n> dash _ x = (step x).tick <> x.tick;;\ndash _ = <dashed:26>\n> DX.xs = !old_dxs;;\n- : bool = true\n> :dash_seed 371289 832622 387736\nDash seed set.\n> dash _ x = (step x).tick <> x.tick;;\ndash _ = <dashed:36>\n> DX.xs = !old_dxs;;\n- : bool = false",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
## Printing counterexamples

By default, `dash` does not automatically print the counterexamples it finds. Instead, it prints a number `k`, e.g., `<dashed:k>`, indicating that `k` counterexamples have been computed and stored in the list `DX.xs`.  
[block:code]
{
  "codes": [
    {
      "code": "> dash _ (x,y) = x + y < 10;;\ndash _ = <dashed:100>",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
This behaviour is intentional: Dash is designed to compute lists of counterexamples, not single (counter-)examples like `verify`, `instance`, and `check`. Moreover, `dash` is designed to be fast, and printing large counterexamples can be computationally expensive. By reflecting the found counterexamples into the `DX.xs` list, `dash` places control of the display of counterexamples into the hands of the user.
[block:code]
{
  "codes": [
    {
      "code": "> DX.xs;;\n- : (int * int) list =\n[(2, 12); (3, 49); (4, 51); (5, 12); (5, 39); (5, 64); (6, 68); (8, 60);\n (10, 32); (11, 29); (12, 3); (12, 7); (12, 58); (14, 4); (14, 54); (15, 19);\n (16, 76); (17, 14); (18, 49); (18, 61); (19, 55); (21, 99); (23, 68);\n (25, 70); (25, 91); (27, 9); (28, 7); (29, 28); (30, 48); (31, 38);\n (31, 44); (33, 15); (33, 40); (36, 67); (37, 86); (38, 38); (38, 93);\n (39, 26); (39, 63); (40, 33); (41, 60); (43, 7); (43, 77); (43, 79);\n (45, 82); (46, 61); (47, 77); (47, 78); (47, 87); (48, 74); (50, 82);\n (52, 22); (52, 29); (52, 59); (54, 55); (54, 76); (56, 39); (56, 54);\n (57, 91); (58, 6); (60, 15); (60, 74); (60, 81); (61, 67); (62, 97);\n (63, 56); (64, 5); (64, 21); (64, 86); (65, 63); (66, 41); (66, 75);\n (66, 77); (67, 16); (72, 49); (72, 50); (73, 91); (74, 70); (75, 10);\n (75, 26); (77, 77); (78, 9); (78, 65); (78, 68); (79, 31); (80, 42);\n (81, 47); (86, 44); (87, 77); (88, 14); (88, 52); (88, 82); (89, 88);\n (92, 6); (93, 46); (95, 24); (95, 84); (97, 75); (97, 99); (99, 32)]",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
That said, `dash` can be configured to automatically print a single counterexample from each `dash` command that computes one. This is done by enabling the `dash_dx` printer option via the `:set_print` directive, i.e., `:set_print dash_dx`. When this option is enabled, the first counterexample (i.e., `List.hd DX.xs`) will be printed. This option can be disabled with `:unset_print dash_dx`.
[block:code]
{
  "codes": [
    {
      "code": "> :set_print dash_dx\n> dash _ (x,y) = x + y < 10;;\ndash _ = <dashed:100>\n\nCounterexample (List.hd DX.xs):\n\n- : int * int = (2, 12)\n\n> dash _ x = (step x).tick <> x.tick;;\ndash _ = <dashed:36>\n\nCounterexample (List.hd DX.xs):\n\n- : state =\n{order_type = Limit; qty = 1; price = Some 69.1502421389093769;\n top = Some 8.99170783937942; tick = 52}\n\n> :unset_print dash_dx\n> dash _ (x,y) = x + y < 10;;\ndash _ = <dashed:100>",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Note that the format of the printed counterexamples differs slightly from that of other commands such as `verify`, `instance` and `check`. The key differences are as follows:

* The counterexample is presented as tuple, not a record. This is consistent with how the values are stored in `DX.xs`.
* The type of the tuple is printed before the counterexample is displayed, using the printing format of OCaml toplevel evaluation results, e.g., `- : int * int = (2, 12)`. 

This display of counterexamples is also affected by the standard OCaml `#print_depth` and `#print_length` values. These can be changed by executing `#print_depth k` and `#print_length k`. The default Imandra printer values are `#print_depth 1000` and `#print_length 1000`. If a counterexample is printed and its display will exceed these bounds, ellipses `...` are printed in place of the offending value nodes.

See the documentation on [Printing](doc:printing-1) for how custom printers can be used to display `dash` counterexamples.
