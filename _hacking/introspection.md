---
title: "Introspection"
excerpt: ""
colName: Hacking
permalink: /introspection/
layout: pageSbar
---
The directive ```:introspection on``` will enable introspection into the Imandra runtime. We currently support the introspection of type definitions.

When introspection is enabled, type definitions are reflected and saved into the ```Meta.type_defs``` list.
[block:api-header]
{
  "type": "basic",
  "title": "1. Example"
}
[/block]

[block:code]
{
  "codes": [
    {
      "code": "            .__      /\\ .__                           .___\n     _____  |__|    / / |__| _____ _____    ____    __| _/___________\n     \\__  \\ |  |   / /  |  |/     \\__   \\  /    \\  / __ |\\_  __ \\__  \\\n      / __ \\|  |  / /   |  |  Y Y  \\/ __ \\|   |  \\/ /_/ | |  | \\// __ \\_\n     (____  /__| / /    |__|__|_|  (____  /___|  /\\____ | |__|  (____  /\n          \\/     \\/              \\/     \\/     \\/      \\/            \\/\n----------------------------------------------------------------------------\n Imandra Commander 0.8a89 - (c)Copyright Aesthetic Integration Ltd, 2014-16\n----------------------------------------------------------------------------\n# :introspection on\n# type t1 = A of int | B of int * int | C of t1;;\ntype t1 = A of int | B of int * int | C of t1\n# type t2 = { x : int; y : t1 };;\ntype t2 = { x : int; y : t1; }\n# type t3 = t2 option;;\ntype t3 = t2 option\n# Meta.type_defs;;\n- : Meta.type_def list ref =\n{contents =\n  [{Meta.mod_path = \"\"; loc = \"//toplevel//\";\n    decl = Meta.Def_alias (\"t3\", \"t2_option\")};\n   {Meta.mod_path = \"\"; loc = \"//toplevel//\";\n    decl =\n     Meta.Def_rec (\"t2\",\n      [{Meta.field_name = \"x\"; field_ty = \"int\"};\n       {Meta.field_name = \"y\"; field_ty = \"t1\"}])};\n   {Meta.mod_path = \"\"; loc = \"//toplevel//\";\n    decl =\n     Meta.Def_adt (\"t1\",\n      [{Meta.constr = \"A\"; c_args = [\"int\"]};\n       {Meta.constr = \"B\"; c_args = [\"int\"; \"int\"]};\n       {Meta.constr = \"C\"; c_args = [\"t1\"]}])}]}",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
To see the signature of the ```IMeta``` module, you can use the following trick:
[block:code]
{
  "codes": [
    {
      "code": "# :shadow off\n> module Meta = Meta;;\nmodule Meta :\n  sig\n    type adt_row = Meta.adt_row = { constr : string; c_args : string list; }\n    type rec_row =\n      Meta.rec_row = {\n      field_name : string;\n      field_ty : string;\n    }\n    type type_decl =\n      Meta.type_decl =\n        Def_adt of string * adt_row list\n      | Def_rec of string * rec_row list\n      | Def_alias of string * string\n    type type_def =\n      Meta.type_def = {\n      mod_path : string;\n      loc : string;\n      decl : type_decl;\n    }\n    val type_defs : type_def list ref\n    val register_type_def : type_def -> unit\n  end",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
