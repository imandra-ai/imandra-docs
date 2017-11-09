---
title: "Region Printers"
excerpt: ""
layout: pageSbar
permalink: /customRegionPrinters/
colName: Region Printers
---
Custom region printers may be defined in `:program` mode using the `Reflect` API.

A region printer is a function that maps a `Reflect.Region.t` value to a `string`.

Let us first see the definition of the datatype `Reflect.Region.t`. We'll use the `module X = Foo` trick which causes Imandra to display the signature of the module `Foo`:
[block:code]
{
  "codes": [
    {
      "code": "# :program\n> module R = Reflect.Region;;\nmodule R :\n  sig\n    type t =\n      Reflect.Region.t = {\n      name : string;\n      depth : int;\n      constraints : Reflect.Expr.t list;\n      invariant : Reflect.Expr.t option;\n    }\n    val install_printer : name:string -> f:(t -> string) -> unit\n  end",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
For region printers, the important part of the above signature is the record type `t`. A region printer will render a string for such a value. 

Note that both the `constraints` and `invariant` fields contain `Reflect.Expr.t` values. This is a datatype of Imandra logical expressions. A region printer will typically analyze these `Reflect.Expr.t` values and display them in a domain-relevant manner. 

Let us inspect the signature of `Reflect.Expr` below:
[block:code]
{
  "codes": [
    {
      "code": "> module E = Reflect.Expr;;\nmodule E :\n  sig\n    type name = string\n    type t =\n      Reflect.Expr.t =\n        Fun of name * t list\n      | Atom of name\n      | Nil\n      | True\n      | False\n      | And of t list\n      | Or of t list\n      | Not of t\n      | Equal of t * t\n      | Implies of t * t\n      | If of t * t * t\n      | Rec of name * (name * t) list\n      | Rec_field of t * name\n      | Target_fun of t list\n    val pp : Format.formatter -> t -> unit\n    val to_string : t -> string\n  end",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]

[block:api-header]
{
  "title": "A simple example"
}
[/block]
Let us define a simple region printer, taking advantage of the `Reflect.Expr.to_string` function, which is a built-in default pretty-printer for `Reflect.Expr.t` values:
[block:code]
{
  "codes": [
    {
      "code": "> let pp (x : Reflect.Region.t) =\n   let open Reflect in\n   let open Reflect.Region in\n   let open Printf in\n   sprintf \"---\\nname: %s\\nhyps:\\n[%s]\\ninv:\\n %s\\n---\\n%!\"\n     x.name\n     (String.concat \",\\n \" (List.map Expr.to_string x.constraints))\n     (match x.invariant with\n        Some i -> Expr.to_string i\n      | None   -> \"<none>\")\n;;\nval pp : Reflect.Region.t -> string = <fun>",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]

[block:api-header]
{
  "title": "Installation"
}
[/block]
Region printers must be installed using the `Reflect.Region.install_printer` function.

- `Reflect.Region.install_printer : name:string -> f:(Reflect.Region.t -> string) -> unit`

For example, to we can install our `pp` region printer as follows:
[block:code]
{
  "codes": [
    {
      "code": "> Reflect.Region.install_printer ~name:\"ex_pp\" ~f:pp;;\n- : unit = ()",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]

[block:api-header]
{
  "title": "Invocation"
}
[/block]
Once the printer is installed, we may use it in `:decompose` and `:testgen` invocations via the `region_printer` parameter.

As an example, let us define a simple arithmetic function `f` and decompose it, printing the results using our `pp` region printer. Recall that we've installed `pp` with the name `ex_pp`.

First, we switch to `:logic` mode and define our `f`:
[block:code]
{
  "codes": [
    {
      "code": "> :logic\n# let f x =\n  if x > 10 then 99\n  else 100\n;;\nval f : int -> int = <fun>",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Now, we `:decompose` it and apply our region printer:
[block:code]
{
  "codes": [
    {
      "code": "# :decompose f region_printer ex_pp\n----------------------------------------------------------------------------\nBeginning principal region decomposition for f\n----------------------------------------------------------------------------\n- Isolated region #1 (2, depth=1): --------------------\n\n---\nname: 2\nhyps:\n[>(x1, 10)]\ninv:\n Equal(99, F(x1))\n---\n\n- Isolated region #2 (1, depth=1): --------------------\n\n---\nname: 1\nhyps:\n[<=(x1, 10)]\ninv:\n Equal(100, F(x1))\n---\n\n----------------------------------------------------------------------------\nFinished principal region decomposition for f\nStats: {rounds=2; regions=2; time=0.038sec}\n----------------------------------------------------------------------------",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]

[block:api-header]
{
  "title": "A more sophisticated example using JSON"
}
[/block]
Imandra infrastructure often expects region decompositions to be printed in JSON. This JSON printing of regions is done by default when one enters `:web` mode and uses Imandra's default region printer. However, when a custom region printer is used, the type of string produced for the region is completely determined by the custom region printer itself. Thus, to work with other Imandra tools, it is likely you will need to write your region printers to output JSON.

Here is an example doing just that via the `Yojson` library. This widely used OCaml JSON library is included with Imandra, available for use out of the box. 

Note the required JSON fields for Imandra region descriptions:

- `name : String` -- The name of the region, e.g., `4.21.2`
- `vars : String List` -- A list of variables (with their associated types) used in the region constraints. This is currently ignored in Imandra web interfaces (e.g., Imandra Regions Explorer / interactive voronoi).
- `constraints : String List` -- A list of strings representing the region constraints.
- `invariant : String` -- A single string representing the region invariant.
[block:code]
{
  "codes": [
    {
      "code": "(* A simple region printer that produces JSON. *)\n\nlet pp_json (x : Reflect.Region.t) =\n  let open Reflect in\n  let open Reflect.Region in\n  let open Yojson.Basic in\n  let cs = List.map (fun c -> `String (Expr.to_string c)) x.constraints in\n  let i =\n    match x.invariant with\n      Some i -> `String (Expr.to_string i)\n    | None   -> `String \"<none>\" in\n  let j = `Assoc [ (\"name\", `String x.name)\n                 ; (\"vars\", `List [])\n                 ; (\"constraints\", `List cs)\n                 ; (\"invariant\", i) ]\n  in\n  (to_string j) ^ \"\\n\"\n;;",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Once we've defined it, let's install it. We'll give it the name `ex_pp_json`:
[block:code]
{
  "codes": [
    {
      "code": "> Reflect.Region.install_printer ~name:\"ex_pp_json\" ~f:pp_json;;\n- : unit = ()",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Finally, we may switch to `:logic` mode and apply it:
[block:code]
{
  "codes": [
    {
      "code": "> :logic\n# :decompose f region_printer ex_pp_json\n----------------------------------------------------------------------------\nBeginning principal region decomposition for f\n----------------------------------------------------------------------------\n- Isolated region #1 (2, depth=1): --------------------\n\n{\"name\":\"2\",\"vars\":[],\"constraints\":[\">(x1, 10)\"],\"invariant\":\"Equal(99, F(x1))\"}\n\n- Isolated region #2 (1, depth=1): --------------------\n\n{\"name\":\"1\",\"vars\":[],\"constraints\":[\"<=(x1, 10)\"],\"invariant\":\"Equal(100, F(x1))\"}\n\n----------------------------------------------------------------------------\nFinished principal region decomposition for f\nStats: {rounds=2; regions=2; time=0.018sec}\n----------------------------------------------------------------------------",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
