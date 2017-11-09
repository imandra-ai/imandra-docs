---
title: "Printing"
excerpt: ""
permalink: /printing/
layout: pageSbar
colName: Configuration
---
Custom printers can be installed for any Imandra type. This is done using the `:install_printer` directive. A custom printer for a type `t` should have type ```Format.formatter -> t -> unit.``` These printers can be defined in `:program` mode.
[block:api-header]
{
  "title": "Installing a custom printer"
}
[/block]
Let us start with a small example, beginning by defining a type in `:logic` mode.
[block:code]
{
  "codes": [
    {
      "code": "# type order = Market of int | Limit of int * float;;",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
With the type defined, we can begin reasoning about it. For example, we may ask for a value of type `order` using `instance`:
[block:code]
{
  "codes": [
    {
      "code": "# instance _ (x : order) = true;;\n\nInstance:\n\n  { x = Market 0; }",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Notice how the value `Market 0` is printed as part of a record. In fact, it is bound to a module `CX` and can be accessed by `CX.x`:
[block:code]
{
  "codes": [
    {
      "code": "# CX.x;;\n- : order = Market 0",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Let us now define a custom type printer for `order` values. We'll do this in `:program` mode.
[block:code]
{
  "codes": [
    {
      "code": "# :program\n> let string_of_order x =\n   let open Printf in\n    match x with\n     Market n    -> sprintf \"M(%d)\" n\n   | Limit (n,p) -> sprintf \"L(%d,%f)\" n p;;\nval string_of_order : order -> string = <fun>\n> let print_order fmt x =\n  Format.fprintf fmt \"<order %s>\" (string_of_order x);;\nval print_order : Format.formatter -> order -> unit = <fun>",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
We install it:
[block:code]
{
  "codes": [
    {
      "code": "> :install_printer print_order\nPrinter print_order installed.",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
And now `order` values obtained by evaluation will be printed using it:
[block:code]
{
  "codes": [
    {
      "code": "> Market 10;;\n- : order = <order M(10)>",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
This applies also to tuples, records and other compound types that build upon `order`:
[block:code]
{
  "codes": [
    {
      "code": "> (Market 1, Limit (1, 3.0));;\n- : order * order = (<order M(1)>, <order L(1,3.000000)>)\n> type t = { x : order; y : order };;\ntype t = { x : order; y : order; }\n> { x = Market 1; y = Limit (10, 25.0) };;\n- : t = {x = <order M(1)>; y = <order L(10,25.000000)>}",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Of course, we can further define our own custom printers for such compound types. These custom compound type printers will be given priority if they are installed:
[block:code]
{
  "codes": [
    {
      "code": "> let print_t fmt (x : t) = \n   let qty = function\n      Market n     -> n\n    | Limit (n, _) -> n \n  in Format.fprintf fmt \"<t:%d>\" (qty x.x + qty x.y);;\n> :install_printer print_t\nPrinter print_t installed.\n> { x = Market 1; y = Limit (10, 25.0) };;\n- : t = <t:11>",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]

[block:api-header]
{
  "title": "For CX-bound values"
}
[/block]
However, if we perform `instance` or `check` or `verify` commands that construct and print (counter-)examples, the custom printers will not by default be applied:
[block:code]
{
  "codes": [
    {
      "code": "> :logic\n# instance _ (x,y : order * order) = x <> y;;\n\nInstance:\n\n  { x = Market 0;\n    y = Market 1; }",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
This is because, by default, values bound to the `CX` module are not "obtained by evaluation." Compare this output to the following, which is obtained by evaluation:
[block:code]
{
  "codes": [
    {
      "code": "# (CX.x, CX.y);;\n- : order * order = (<order M(0)>, <order M(1)>)",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
We can instruct Imandra to print all values bound to the `CX` module in this latter format, i.e., as a tuple (rather than a record) that is obtained by evaluation and thus has all custom printers applied. We do this through the `:set_print cx_custom` directive.
[block:code]
{
  "codes": [
    {
      "code": "# :set_print cx_custom",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Now, the result of `instance` and related commands will have our custom printers applied:
[block:code]
{
  "codes": [
    {
      "code": "# instance _ (x,y : order * order) = x <> y;;\n\nInstance:\n- : order * order = (<order M(0)>, <order M(1)>)",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]

[block:api-header]
{
  "title": "For DX-bound values"
}
[/block]
We can cause the same printing behaviour to occur in `dash_mode` by enabling the `:set_print dash_dx` option. See [Dashing VGs](doc:dashing-vgs) for more on this option.
[block:code]
{
  "codes": [
    {
      "code": "# :dash_mode on\n> type order = Market of int | Limit of int * float;;\ntype order = Market of int | Limit of int * float\n> let string_of_order x =\n   let open Printf in\n    match x with\n     Market n    -> sprintf \"M(%d)\" n\n   | Limit (n,p) -> sprintf \"L(%d,%f)\" n p;;\nval string_of_order : order -> string = <fun>\n> let print_order fmt x =\n  Format.fprintf fmt \"<order %s>\" (string_of_order x);;\nval print_order : Format.formatter -> order -> unit = <fun>\n> :install_printer print_order\nPrinter print_order installed.\n> dash _ (x,y) =\n   match x,y with\n    Market _, Limit _ -> false\n   | _ -> true;;\ndash _ = <dashed:29>\n> :set_print dash_dx\n> dash _ (x,y) =\n   match x,y with\n    Market _, Limit _ -> false\n   | _ -> true;;\ndash _ = <dashed:29>\n\nCounterexample (List.hd DX.xs):\n\n- : order * order = (<order M(0)>, <order L(61,66.821092)>)",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]

[block:api-header]
{
  "title": "Uninstalling printers"
}
[/block]
Custom printers may be uninstalled with the `:uninstall_printer` directive:
[block:code]
{
  "codes": [
    {
      "code": "> :uninstall_printer print_order\nPrinter print_order uninstalled.\n> dash _ (x,y) = \n   match x,y with\n    Market _, Limit _ -> false\n   | _ -> true;;\ndash _ = <dashed:29>\n\nCounterexample (List.hd DX.xs):\n\n- : order * order = (Market 0, Limit (61, 66.8210921032085139))   ",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]

[block:api-header]
{
  "title": "Uniform behaviour"
}
[/block]
To recap, to obtain uniform behaviour in the (custom) printing of all (counter-)examples bound either to `CX` or `DX`, we must do the following:

* `:set_print cx_custom`
* `:set_print dash_dx`

With these options enabled, `dash`, `verify`, `instance` and `check` will all print out (counter-)examples when they're computed, and all (counter-)examples will be printed in a format that has all custom printers applied.
