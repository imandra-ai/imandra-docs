---
title: "Environments"
excerpt: ""
layout: pageSbar
colName: Environments
permalink: /environments/
---
A state of an Imandra session is called an *environment*. An environment contains type and function definitions, configuration options, verification goals that have been proved, and all other contextual data that govern the evaluation of Imandra commands and directives. 

Intuitively, an environment is given by a history of *events*. This history describes how the initial *Ground Zero* environment was extended to arise at the current environment. Users typically work in the *live* environment, performing computations and extending the environment with new definitions and modifications of the Imandra configuration state. However, more fine-grained control over environments is available, including an environment stack, checkpointing and programmatic serialisation and restoration. 
[block:api-header]
{
  "title": "The Environment Stack"
}
[/block]
The most basic environment management is performed through the *environment stack.* 

By default, the environment stack is empty.

Environments can be *pushed* and *popped* on and off the stack through the `:push` and `:pop` directives.

At any time, a description of the environment stack (currently, just its size) can be displayed through the `:stack` directive.

Let's see an example:
[block:code]
{
  "codes": [
    {
      "code": "            .__      /\\ .__                           .___\n     _____  |__|    / / |__| _____ _____    ____    __| _/___________\n     \\__  \\ |  |   / /  |  |/     \\__   \\  /    \\  / __ |\\_  __ \\__  \\\n      / __ \\|  |  / /   |  |  Y Y  \\/ __ \\|   |  \\/ /_/ | |  | \\// __ \\_\n     (____  /__| / /    |__|__|_|  (____  /___|  /\\____ | |__|  (____  /\n          \\/     \\/              \\/     \\/     \\/      \\/            \\/\n----------------------------------------------------------------------------\n Imandra Commander 0.8a94 - (c)Copyright Aesthetic Integration Ltd, 2014-17\n----------------------------------------------------------------------------\n# :stack\nEnvironment stack is empty.\n# :h\nAll events in session:\n\n0.<<Ground Zero>>\n\n# :push\n# :stack\nEnvironment stack contains 1 element.\n# let f x = x + 1;;\nval f : int -> int = <fun>\n# :h\nAll events in session:\n\n0.<<Ground Zero>>\n1.     Fun: f\n\n# f 10;;\n- : int = 11\n# instance _ x = f x = 100;;\n\nInstance:\n\n  { x = 99; }\n\n# :pop\n# :h\nAll events in session:\n\n0.<<Ground Zero>>\n\n# f 10;;\nError: Unbound value f",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]

[block:api-header]
{
  "title": "Programmatic Stack Manipulation"
}
[/block]
An API for the environment stack is exposed through the `Reflect.Stack` module. This functionality is fully available in `:program` mode and can be applied (though not used in definitions) in `:logic` mode. 

The key functions are: 
 - `Reflect.Stack.size : unit -> int`,
 - `Reflect.Stack.push : unit -> unit`, and
 - `Reflect.Stack.pop : unit -> unit`.
[block:code]
{
  "codes": [
    {
      "code": "# Reflect.Stack.push ();;\n- : unit = ()\n# let f x = x + 1;;\nval f : int -> int = <fun>\n# theorem _ x = f x > x;;\nthm _ = <proved>\n# Reflect.Stack.size ();;\n- : int = 1\n# Reflect.Stack.pop ();;\n- : unit = ()\n# let f x = x + 2;;\nval f : int -> int = <fun>\n# theorem _ x = f x > x + 1;;\nthm _ = <proved>\n# :h\nAll events in session:\n\n0.<<Ground Zero>>\n1.     Fun: f\n\n# Reflect.Stack.size ();;\n- : int = 0",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
We can use these stack manipulation functions in our own `:program` mode functions. For example, here is a light-weight way to "safely" evaluate a sequence of IML events and then subsequently throw away the results. Note this `safe_eval` is not truly safe as no checking is done to ensure that the evaluated commands do not contain, e.g., `:push` or `:pop`: 
[block:code]
{
  "codes": [
    {
      "code": "> let safe_eval xs =\n   begin\n    Reflect.Stack.push ();\n    List.iter Reflect.eval xs;\n    Reflect.Stack.pop ()\n   end\n  ;;\nval safe_eval : string list -> unit = <fun>\n> :logic\n# safe_eval [\"let f x = x + 1;;\"; \"f 10;;\"; \"theorem f_gt x = f x > x;;\"];;\nval f : int -> int = <fun>\n- : int = 11\nthm f_gt = <proved>\n- : unit = ()\n# :h\nAll events in session:\n\n0.<<Ground Zero>>\n",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]

[block:api-header]
{
  "title": "Environment Checkpoints"
}
[/block]
The live environment may be serialised to disk through the use of the `:checkpoint` directive. A checkpoint must be given a name. By default, it is stored in an Imandra system directory which Imandra will automatically search whenever one attempts to restore the checkpoint.

The loading of checkpoints is designed to be a fast, ideally `O(1)` operation. We typically "compile" large Imandra models by loading them in a fresh session and checkpointing the session immediately after their loading is complete. While the initial compilation may take some time (30 sec is not uncommon for a FIX venue model), once the checkpoint has been saved, we may then start (potentially simultaneous) Imandra sessions and `:restore` the checkpoint in all of them very quickly (e.g., 0.1 sec).
[block:code]
{
  "codes": [
    {
      "code": "            .__      /\\ .__                           .___\n     _____  |__|    / / |__| _____ _____    ____    __| _/___________\n     \\__  \\ |  |   / /  |  |/     \\__   \\  /    \\  / __ |\\_  __ \\__  \\\n      / __ \\|  |  / /   |  |  Y Y  \\/ __ \\|   |  \\/ /_/ | |  | \\// __ \\_\n     (____  /__| / /    |__|__|_|  (____  /___|  /\\____ | |__|  (____  /\n          \\/     \\/              \\/     \\/     \\/      \\/            \\/\n----------------------------------------------------------------------------\n Imandra Commander 0.8a94 - (c)Copyright Aesthetic Integration Ltd, 2014-17\n----------------------------------------------------------------------------\n# type foo = A | B;;\ntype foo = A | B\n# let f = function\n    A -> 10\n  | B -> 20\n  ;;\nval f : foo -> int = <fun>\n# :checkpoint foo\n- Building checkpoint foo.\n- Checkpoint foo built.\n                                                                 \nTo restore this checkpoint from the toplevel, run\n   :restore foo\n\n- Linking checkpoint foo back into current session.\n- Link complete.                                                                 ",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Now that the checkpoint exists, we may use the `:restore` directive to restore it in a fresh session:
[block:code]
{
  "codes": [
    {
      "code": "            .__      /\\ .__                           .___\n     _____  |__|    / / |__| _____ _____    ____    __| _/___________\n     \\__  \\ |  |   / /  |  |/     \\__   \\  /    \\  / __ |\\_  __ \\__  \\\n      / __ \\|  |  / /   |  |  Y Y  \\/ __ \\|   |  \\/ /_/ | |  | \\// __ \\_\n     (____  /__| / /    |__|__|_|  (____  /___|  /\\____ | |__|  (____  /\n          \\/     \\/              \\/     \\/     \\/      \\/            \\/\n----------------------------------------------------------------------------\n Imandra Commander 0.8a94 - (c)Copyright Aesthetic Integration Ltd, 2014-17\n----------------------------------------------------------------------------\n# :restore foo\nCheckpoint foo restored.\n# :h\nAll events in session:\n\n0.<<Ground Zero>>\n1.    Type: foo\n2.     Fun: f\n\n# f A;;\n- : int = 10\n# instance _ x = f x = 20;;\n\nInstance:\n\n  { x = B; }\n",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
By default, `:checkpoint` will overwrite a checkpoint of the same name, if one exists. To block this overwriting, give `:checkpoint` an extra argument of `false`:
[block:code]
{
  "codes": [
    {
      "code": "# :checkpoint foo false\nError: Checkpoint foo already exists (overwrite=false).",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]

[block:api-header]
{
  "title": "Programmatic Checkpoint Manipulation"
}
[/block]
The checkpointing functions are available through the `Reflect` API. 

The key functions are:
- `Reflect.checkpoint : ?overwrite:bool -> string -> unit`
- `Reflect.restore : string -> unit`
[block:code]
{
  "codes": [
    {
      "code": "            .__      /\\ .__                           .___\n     _____  |__|    / / |__| _____ _____    ____    __| _/___________\n     \\__  \\ |  |   / /  |  |/     \\__   \\  /    \\  / __ |\\_  __ \\__  \\\n      / __ \\|  |  / /   |  |  Y Y  \\/ __ \\|   |  \\/ /_/ | |  | \\// __ \\_\n     (____  /__| / /    |__|__|_|  (____  /___|  /\\____ | |__|  (____  /\n          \\/     \\/              \\/     \\/     \\/      \\/            \\/\n----------------------------------------------------------------------------\n Imandra Commander 0.8a94 - (c)Copyright Aesthetic Integration Ltd, 2014-17\n----------------------------------------------------------------------------\n# Reflect.checkpoint;;\n- : ?overwrite:bool -> string -> unit = <fun>\n# Reflect.checkpoint \"foo\";;\n- Building checkpoint foo.\n- Checkpoint foo built.\n\nTo restore this checkpoint from the toplevel, run\n   :restore foo\n\n- Linking checkpoint foo back into current session.\n- Link complete.\n- : unit = ()\n# Reflect.checkpoint ~overwrite:false \"foo\";;\nException:\nVersion.Unsupported \"Checkpoint foo already exists (overwrite=false).\".\n# Reflect.restore \"foo\";;\nCheckpoint foo restored.\n- : unit = ()",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]


[block:api-header]
{
  "title": "Exporting and Importing Checkpoints"
}
[/block]
By default, checkpoints are created and stored in a system-wide Imandra directory. Facilities for exporting and importing checkpoints are provided through the `Reflect` API. Exported checkpoints are version-sensitive: they may only be imported by installations of the same version of Imandra that was used to create them.

The relevant functions are:

- `Reflect.export : string -> string -> unit`
- `Reflect.import : string -> unit`

`Reflect.export "foo.icp" "foo"` will export an existing checkpoint named `foo` into the file `foo.icp` in the current directory.

`Reflect.import "foo.icp"` will import the checkpoint `foo` from the file `foo.icp`. When a checkpoint is imported, it is installed in the system directory and is then made available to all Imandra instances in the same environment.

There are no restrictions on the export filenames. However, the name of the exported checkpoint (e.g., `foo`) is stable and not affected by the export filename.

Let us see an example:
[block:code]
{
  "codes": [
    {
      "code": "            .__      /\\ .__                           .___\n     _____  |__|    / / |__| _____ _____    ____    __| _/___________\n     \\__  \\ |  |   / /  |  |/     \\__   \\  /    \\  / __ |\\_  __ \\__  \\\n      / __ \\|  |  / /   |  |  Y Y  \\/ __ \\|   |  \\/ /_/ | |  | \\// __ \\_\n     (____  /__| / /    |__|__|_|  (____  /___|  /\\____ | |__|  (____  /\n          \\/     \\/              \\/     \\/     \\/      \\/            \\/\n----------------------------------------------------------------------------\n Imandra Commander 0.8a94 - (c)Copyright Aesthetic Integration Ltd, 2014-17\n----------------------------------------------------------------------------\n# let f x = x + 1;;\nval f : int -> int = <fun>\n# let g x = f x + 2;;\nval g : int -> int = <fun>\n# :checkpoint foo\n- Building checkpoint foo.\n- Checkpoint foo built.\n\nTo restore this checkpoint from the toplevel, run\n   :restore foo\n\n- Linking checkpoint foo back into current session.\n- Link complete.\n# Reflect.export \"example.icp\" \"foo\";;\n- : unit = ()",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
We can view the exported file in the current directory:
[block:code]
{
  "codes": [
    {
      "code": "$ ls -lh example.icp\n-rw-r--r--  1 grant  staff    34M Jun 20 18:15 example.icp",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
And we can then start a fresh session and import the checkpoint. Once it's imported, it is made available to all Imandra sessions running in the same environment, just the same as if it had been obtained through a `:checkpoint` directive. 
[block:code]
{
  "codes": [
    {
      "code": "            .__      /\\ .__                           .___\n     _____  |__|    / / |__| _____ _____    ____    __| _/___________\n     \\__  \\ |  |   / /  |  |/     \\__   \\  /    \\  / __ |\\_  __ \\__  \\\n      / __ \\|  |  / /   |  |  Y Y  \\/ __ \\|   |  \\/ /_/ | |  | \\// __ \\_\n     (____  /__| / /    |__|__|_|  (____  /___|  /\\____ | |__|  (____  /\n          \\/     \\/              \\/     \\/     \\/      \\/            \\/\n----------------------------------------------------------------------------\n Imandra Commander 0.8a94 - (c)Copyright Aesthetic Integration Ltd, 2014-17\n----------------------------------------------------------------------------\n# Reflect.import \"example.icp\";;\nArchive contains checkpoint foo.\nImporting foo.exe\nImporting foo.exe.dx86cl64\nImporting foo.ims\nCheckpoint foo imported, ready to be restored.\n- : unit = ()",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Thus, we may then restore it, either through `:restore` or `Reflect.restore`:
[block:code]
{
  "codes": [
    {
      "code": "# Reflect.restore \"foo\";;\nCheckpoint foo restored.\n- : unit = ()\n# :h\nAll events in session:\n\n0.<<Ground Zero>>\n1.     Fun: f\n2.     Fun: g\n\n# instance _ x = g x = 10;;\n\nInstance:\n\n  { x = 7; }\n\n# g CX.x;;\n- : int = 10",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
