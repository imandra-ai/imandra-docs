---
title: "Plugins"
description: "Use code-generation plugins"
kernel: imandra
slug: installation
---

# Plugins


Some programming tasks are tedious and distracting, such as writing pretty-printers or (de)serializers for one's types. Imandra provides a *plugin* mechanism to make your life easier using automatic code generation

```{.imandra .input}
[@@@ocaml.warning "-3"];;
Imandra.add_plugin_pp ();;
Imandra.add_plugin_yojson ();;
```

```{.imandra .input}
type t = {
    x: int;
    y: string;
}
```

Note that when we define `t`, some functions were automatically defined along. Let's try them.

```{.imandra .input}
let some_t = {x=42; y="howdy"};;

to_yojson_t some_t;;

Format.printf "some_t = %a@." pp_t some_t;;
```

These functions are program-mode only, though. Plugins can define logic-mode functions, but for most use cases it's not necessary, and program-mode code generation is easier.

```{.imandra .input}
#h;;
```

We can also load plugins in the middle of a development, and it will automatically apply to pre-existing definitions.

It is cleaner to load plugins first, but nevertheless, this is a possibility.

For example, we can ask Imandra to produce random generators for all types, automatically:

```{.imandra .input}
Imandra.add_plugin_rand ();;
```

```{.imandra .input}
rand_t;;

let rand_st = Random.State.make [| 4i |] [@@program];;

(* generate a list of at most 5 instances of [t] *)
let l = gen_rand_l ~st:rand_st ~n:5i rand_t [@@program];;
```
