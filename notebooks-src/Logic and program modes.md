---
title: "Logic and program modes"
description: "An overview of logic and program modes in Imandra"
kernel: imandra
slug: logic-and-program-modes
key-phrases:
  - logic mode
  - program mode
expected-error-report: { "errors": 3, "exceptions": 0 }
---

# Logic and Program modes

Imandra has two modes: *logic mode* and *program mode*. When we launch Imandra Terminal (or an Imandra Jupyter Notebook session), we start off in logic mode.

In the terminal, we can identify that Imandra is in logic mode by the pound sign prompt (`#`).

In a notebook, we can inspect Imandra's current mode using the `#config` directive.

```{.imandra .input}
#config 1
```

While in logic mode, we have access to Imandra's reasoning tools, such as `verify` and `theorem`.

```{.imandra .input}
let succ n = n + 1
```

```{.imandra .input}
verify (fun n -> succ n > n)
```

A future notebook will summarize the various reasoning tools, and explain when to use which one.

In logic mode, all definitions -- types, values and functions -- are entered into the logic. We can see all previous events in logic mode by inspecting the `#history` (aliased to `#h`).

```{.imandra .input}
#h;;
```

```{.imandra .input}
#h succ
```

While in logic mode, we are restricted to a purely functional subset of OCaml, and our recursive functions must terminate.

If we try to define a non-terminating function, for example, Imandra will reject it.

```{.imandra .input}
let rec bad_repeat x = x :: bad_repeat x
```

```{.imandra .input}
#show bad_repeat
```

For more complex recursive functions, we may need to convince Imandra that the function terminates, for example by defining a "measure". See the notebook [Proving Program Termination with Imandra](Proving%20Program%20Termination%20with%20Imandra.md) for more details.

Our logic-mode definitions are allowed to call other definitions only if those other definitions have been admitted into the logic.

```{.imandra .input}
let say_hi () = print_endline "Hello!"
```

In order to define such a side-effecting function, we switch to *program mode*. We do this using the `#program` directive.

```{.imandra .input}
#program;;

#config 1;;
```

In the terminal, we can identify that Imandra is in program mode by the angle bracket prompt (`>`).

Now that we are in program mode, we have the full power of OCaml at our fingertips!

```{.imandra .input}
let say_hi () = print_endline "Hello!"
```

```{.imandra .input}
say_hi ()
```

When we switch back to logic mode (using the `#logic` directive), we can still refer to our program-mode definitions at the top level.

```{.imandra .input}
#logic;;

say_hi ()
```

But we are forbidden from using them in our logic-mode definitions.

```{.imandra .input}
let say_hi_from_logic_mode () = say_hi ()
```

Often, we want to define a type in logic mode and then a related function in program mode, for example a pretty-printer. For this case we can use the `[@@program]` annotation to define a one-off program-mode function while in logic mode.

```{.imandra .input}
type person = { name : string; favorite_color : string };;

let print_person (person : person) : string =
  Printf.sprintf "%s prefers %s things" person.name person.favorite_color
[@@program];;

print_person { name = "Matt"; favorite_color = "green" };;
```

Sometimes we also need to use program-mode functions in order to generate logic-mode values, this can be done using the `[@@reflect]` annotation:

```{.imandra .input}
let one = Z.of_string "1" [@@reflect]
```

This can be useful for several reasons, one of the most common ones is reading logic-mode values from files. Imandra also offers the lower-level facility `Imandra.port` to port program-mode values into logic-mode locals:

```{.imandra .input}
let x = print_endline "debug"; 1 [@@program];;
Imandra.port "y" "x";;
y;;
```

That concludes our overview of Imandra's logic and program modes!
