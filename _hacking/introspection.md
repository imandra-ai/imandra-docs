---
title: "Introspection"
excerpt: ""
colName: Hacking
permalink: /introspection/
layout: pageSbar
---
The directive ```:introspection on``` will enable introspection into the Imandra runtime. We currently support the introspection of type definitions.

When introspection is enabled, type definitions are reflected and saved into the ```Meta.type_defs``` list.

#### 1. Example

```
            .__      /\ .__                           .___            
     _____  |__|    / / |__| _____ _____    ____    __| _/___________   
     \__  \ |  |   / /  |  |/     \__   \  /    \  / __ |\_  __ \__  \  
      / __ \|  |  / /   |  |  Y Y  \/ __ \|   |  \/ /_/ | |  | \// __ \_
     (____  /__| / /    |__|__|_|  (____  /___|  /\____ | |__|  (____  /
          \/     \/              \/     \/     \/      \/            \/ 
----------------------------------------------------------------------------
 Imandra Commander 0.8a94 - (c)Copyright Aesthetic Integration Ltd, 2014-17
----------------------------------------------------------------------------
# :introspection on
# type t1 = A of int | B of int * int | C of t1;;
type t1 = A of int | B of int * int | C of t1
# type t2 = { x : int; y : t1 };;
type t2 = { x : int; y : t1; }
# type t3 = t2 option;;
type t3 = t2 option
# Meta.type_defs;;
- : Meta.type_def list ref =
  {contents =
    [{Meta.mod_path = "";
      loc = "//toplevel//";
      decl = Meta.Def_alias ("t3", "t2_option")};
    {Meta.mod_path = ""; loc = "//toplevel//";
      decl =
        Meta.Def_rec ("t2",
        [{Meta.field_name = "x"; field_ty = "int"};
        {Meta.field_name = "y"; field_ty = "t1"}])};
        {Meta.mod_path = ""; loc = "//toplevel//";
      decl =
        Meta.Def_adt ("t1",
          [{Meta.constr = "A"; c_args = ["int"]};
          {Meta.constr = "B"; c_args = ["int"; "int"]};
          {Meta.constr = \"C\"; c_args = ["t1"]}])}]}

```
To see the signature of the ```IMeta``` module, you can use the following trick:
```

# :shadow off
> module Meta = Meta;;
module Meta :
  sig
    type adt_row = Meta.adt_row = { constr : string; c_args : string list; }
    type rec_row =
      Meta.rec_row = {
        field_name : string;
        field_ty : string;
      }
      type type_decl =
        Meta.type_decl =
          Def_adt of string * adt_row list
          | Def_rec of string * rec_row list
          | Def_alias of string * string
          type type_def =
            Meta.type_def = {
              mod_path : string;
              loc : string;
              decl : type_decl;
            }
          val type_defs : type_def list ref
          val register_type_def : type_def -> unit
  end
```