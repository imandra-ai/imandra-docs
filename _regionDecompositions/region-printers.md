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
```
# :program
> module R = Reflect.Region;;
module R :
  sig
    type t =
      Reflect.Region.t = {
        name : string;
        depth : int;
        constraints : Reflect.Expr.t list;
        invariant : Reflect.Expr.t option;
      }
    val install_printer : name:string -> f:(t -> string) -> unit
  end
```

For region printers, the important part of the above signature is the record type `t`. A region printer will render a string for such a value. 

Note that both the `constraints` and `invariant` fields contain `Reflect.Expr.t` values. This is a datatype of Imandra logical expressions. A region printer will typically analyze these `Reflect.Expr.t` values and display them in a domain-relevant manner. 

Let us inspect the signature of `Reflect.Expr` below:
```
> module E = Reflect.Expr;;
module E :
  sig
    type name = string
    type t =
    Reflect.Expr.t =
      Fun of name * t list
      | Atom of name
      | Nil
      | True
      | False
      | And of t list
      | Or of t list
      | Not of t
      | Equal of t * t
      | Implies of t * t
      | If of t * t * t
      | Rec of name * (name * t) list
      | Rec_field of t * name
      | Target_fun of t list
      val pp : Format.formatter -> t -> unit
      val to_string : t -> string
  end
```

#### A simple example

Let us define a simple region printer, taking advantage of the `Reflect.Expr.to_string` function, which is a built-in default pretty-printer for `Reflect.Expr.t` values:
```
> let pp (x : Reflect.Region.t) =
let open Reflect in
  let open Reflect.Region in
  let open Printf in
  sprintf "---\\nname: %s\\nhyps:\\n[%s]\\ninv:\\n %s\\n---\\n%!"
    x.name
    (String.concat "," (List.map Expr.to_string x.constraints))
    (match x.invariant with
      Some i -> Expr.to_string i
      | None   -> "<none>")
  ;;
val pp : Reflect.Region.t -> string = <fun>
```

#### Installation

Region printers must be installed using the `Reflect.Region.install_printer` function.

- `Reflect.Region.install_printer : name:string -> f:(Reflect.Region.t -> string) -> unit`

For example, to we can install our `pp` region printer as follows:

```
> Reflect.Region.install_printer ~name:\"ex_pp\" ~f:pp;;
- : unit = ()
```

#### Invocation

Once the printer is installed, we may use it in `:decompose` and `:testgen` invocations via the `region_printer` parameter.

As an example, let us define a simple arithmetic function `f` and decompose it, printing the results using our `pp` region printer. Recall that we've installed `pp` with the name `ex_pp`.

First, we switch to `:logic` mode and define our `f`:

```
> :logic
# let f x =
  if x > 10 then 99
  else 100;;
val f : int -> int = <fun>
```

Now, we `:decompose` it and apply our region printer:
```
# :decompose f region_printer ex_pp
----------------------------------------------------------------------------
 Beginning principal region decomposition for f
----------------------------------------------------------------------------
- Isolated region #1 (2, depth=1): --------------------

---
name: 2
hyps:
  [>(x1, 10)]
  inv:
    Equal(99, F(x1))
---

- Isolated region #2 (1, depth=1): --------------------

---
name: 1
hyps:
  [<=(x1, 10)]
inv:
  Equal(100, F(x1))
---

----------------------------------------------------------------------------
Finished principal region decomposition for f
Stats: {rounds=2; regions=2; time=0.038sec}
----------------------------------------------------------------------------
```

#### A more sophisticated example using JSON

Imandra infrastructure often expects region decompositions to be printed in JSON. This JSON printing of regions is done by default when one enters `:web` mode and uses Imandra's default region printer. However, when a custom region printer is used, the type of string produced for the region is completely determined by the custom region printer itself. Thus, to work with other Imandra tools, it is likely you will need to write your region printers to output JSON.

Here is an example doing just that via the `Yojson` library. This widely used OCaml JSON library is included with Imandra, available for use out of the box. 

Note the required JSON fields for Imandra region descriptions:

- `name : String` -- The name of the region, e.g., `4.21.2`
- `vars : String List` -- A list of variables (with their associated types) used in the region constraints. This is currently ignored in Imandra web interfaces (e.g., Imandra Regions Explorer / interactive voronoi).
- `constraints : String List` -- A list of strings representing the region constraints.
- `invariant : String` -- A single string representing the region invariant.

```
(* A simple region printer that produces JSON. *)
let pp_json (x : Reflect.Region.t) =
  let open Reflect in
  let open Reflect.Region in
  let open Yojson.Basic in
  let cs = List.map (fun c -> `String (Expr.to_string c)) x.constraints in
  let i =
  match x.invariant with
    Some i -> `String (Expr.to_string i)
    | None   -> `String "<none>" in
    let j = `Assoc [ ("name", `String x.name)
    ; ("vars", `List [])
    ; ("constraints", `List cs)
    ; (\"invariant\", i) ]
    in
      (to_string j) ^ "\n\"\n;;
```

Once we've defined it, let's install it. We'll give it the name `ex_pp_json`:

```
> Reflect.Region.install_printer ~name:\"ex_pp_json\" ~f:pp_json;;
- : unit = ()
```

Finally, we may switch to `:logic` mode and apply it:

```
> :logic
# :decompose f region_printer ex_pp_json
----------------------------------------------------------------------------
  Beginning principal region decomposition for f
----------------------------------------------------------------------------
- Isolated region #1 (2, depth=1): --------------------

{"name": "2", "vars": [], "constraints": [>(x1, 10)], "invariant": "Equal(99, F(x1))"}

- Isolated region #2 (1, depth=1): --------------------
{ "name" : "1", "vars" : [], "constraints": ["<=(x1, 10)"], "invariant": "Equal(100, F(x1))"}

----------------------------------------------------------------------------
Finished principal region decomposition for f\nStats: {rounds=2; regions=2; time=0.018sec}
----------------------------------------------------------------------------

```