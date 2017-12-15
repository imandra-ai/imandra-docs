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

# :stack
Environment stack is empty.
# :h
All events in session:
  0.<<Ground Zero>>
# :push
# :stack
Environment stack contains 1 element.
# let f x = x + 1;;
val f : int -> int = <fun>
# :h
All events in session:
  0.<<Ground Zero>>
  1.     Fun: f

# f 10;;
- : int = 11
# instance _ x = f x = 100;;

Instance:
  { x = 99; }

# :pop
# :h
All events in session:
  0.<<Ground Zero>>
# f 10;;
Error: Unbound value f

```

#### Programmatic Stack Manipulation

An API for the environment stack is exposed through the `Reflect.Stack` module. This functionality is fully available in `:program` mode and can be applied (though not used in definitions) in `:logic` mode. 

The key functions are: 
 - `Reflect.Stack.size : unit -> int`,
 - `Reflect.Stack.push : unit -> unit`, and
 - `Reflect.Stack.pop : unit -> unit`.

```
# Reflect.Stack.push ();;
- : unit = ()
# let f x = x + 1;;
val f : int -> int = <fun>
# theorem _ x = f x > x;;
thm _ = <proved>
# Reflect.Stack.size ();;
- : int = 1
# Reflect.Stack.pop ();;
- : unit = ()
# let f x = x + 2;;
val f : int -> int = <fun>
# theorem _ x = f x > x + 1;;
thm _ = <proved>
# :h
All events in session:

0.<<Ground Zero>>
1.     Fun: f
# Reflect.Stack.size ();;
- : int = 0"

```

We can use these stack manipulation functions in our own `:program` mode functions. For example, here is a light-weight way to "safely" evaluate a sequence of IML events and then subsequently throw away the results. Note this `safe_eval` is not truly safe as no checking is done to ensure that the evaluated commands do not contain, e.g., `:push` or `:pop`: 
```
> let safe_eval xs =
  begin
    Reflect.Stack.push ();
    List.iter Reflect.eval xs;
    Reflect.Stack.pop ()
  end
  ;;
  val safe_eval : string list -> unit = <fun>
> :logic
# safe_eval [\"let f x = x + 1;;\"; \"f 10;;\"; \"theorem f_gt x = f x > x;;\"];;

val f : int -> int = <fun>
- : int = 11
thm f_gt = <proved>
- : unit = ()
# :h
All events in session:
0.<<Ground Zero>>

```

#### Environment Checkpoints

The live environment may be serialised to disk through the use of the `:checkpoint` directive. A checkpoint must be given a name. By default, it is stored in an Imandra system directory which Imandra will automatically search whenever one attempts to restore the checkpoint.

The loading of checkpoints is designed to be a fast, ideally `O(1)` operation. We typically "compile" large Imandra models by loading them in a fresh session and checkpointing the session immediately after their loading is complete. While the initial compilation may take some time (30 sec is not uncommon for a FIX venue model), once the checkpoint has been saved, we may then start (potentially simultaneous) Imandra sessions and `:restore` the checkpoint in all of them very quickly (e.g., 0.1 sec).

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
# type foo = A | B;;
type foo = A | B
# let f = function
  A -> 10
  | B -> 20
;;
val f : foo -> int = <fun>
# :checkpoint foo
- Building checkpoint foo.
- Checkpoint foo built.

To restore this checkpoint from the toplevel, run
:restore foo
- Linking checkpoint foo back into current session.
- Link complete.
```

Now that the checkpoint exists, we may use the `:restore` directive to restore it in a fresh session:

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
# :restore foo
Checkpoint foo restored.
# :h
All events in session:

0.<<Ground Zero>>
1.  Type: foo
2.  Fun: f

# f A;;
- : int = 10
# instance _ x = f x = 20;;

Instance:

  { x = B; }

```
By default, `:checkpoint` will overwrite a checkpoint of the same name, if one exists. To block this overwriting, give `:checkpoint` an extra argument of `false`:

```
# :checkpoint foo false
Error: Checkpoint foo already exists (overwrite=false).
```

#### Programmatic Checkpoint Manipulation

The checkpointing functions are available through the `Reflect` API. 

The key functions are:
- `Reflect.checkpoint : ?overwrite:bool -> string -> unit`
- `Reflect.restore : string -> unit`

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
# Reflect.checkpoint;;
- : ?overwrite:bool -> string -> unit = <fun>
# Reflect.checkpoint "foo";;
- Building checkpoint foo.
- Checkpoint foo built.

To restore this checkpoint from the toplevel, run
  :restore foo

- Linking checkpoint foo back into current session.
- Link complete.
- : unit = ()
# Reflect.checkpoint ~overwrite:false "foo\;;
Exception:
  Version.Unsupported "Checkpoint foo already exists (overwrite=false).".

# Reflect.restore "foo";;
Checkpoint foo restored.
- : unit = ()

```

#### Exporting and Importing Checkpoints

By default, checkpoints are created and stored in a system-wide Imandra directory. Facilities for exporting and importing checkpoints are provided through the `Reflect` API. Exported checkpoints are version-sensitive: they may only be imported by installations of the same version of Imandra that was used to create them.

The relevant functions are:

- `Reflect.export : string -> string -> unit`
- `Reflect.import : string -> unit`

`Reflect.export "foo.icp" "foo"` will export an existing checkpoint named `foo` into the file `foo.icp` in the current directory.

`Reflect.import "foo.icp"` will import the checkpoint `foo` from the file `foo.icp`. When a checkpoint is imported, it is installed in the system directory and is then made available to all Imandra instances in the same environment.

There are no restrictions on the export filenames. However, the name of the exported checkpoint (e.g., `foo`) is stable and not affected by the export filename.

Let us see an example:

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
# let f x = x + 1;;
val f : int -> int = <fun>
# let g x = f x + 2;;
val g : int -> int = <fun>
# :checkpoint foo
- Building checkpoint foo.
- Checkpoint foo built.

To restore this checkpoint from the toplevel, run
:restore foo

- Linking checkpoint foo back into current session.
- Link complete.
# Reflect.export \"example.icp\" \"foo\";;
- : unit = ()
```

We can view the exported file in the current directory:
```shell
$ ls -lh example.icp
-rw-r--r--  1 grant  staff    34M Jun 20 18:15 example.icp
```

And we can then start a fresh session and import the checkpoint. Once it's imported, it is made available to all Imandra sessions running in the same environment, just the same as if it had been obtained through a `:checkpoint` directive. 

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
 # Reflect.import "example.icp";;
 Archive contains checkpoint foo.
 Importing foo.exe
 Importing foo.exe.dx86cl64
 Importing foo.ims
 Checkpoint foo imported, ready to be restored.
 - : unit = ()
```

Thus, we may then restore it, either through `:restore` or `Reflect.restore`:
```
# Reflect.restore "foo";;
Checkpoint foo restored.
- : unit = ()
# :h
All events in session:
0.<<Ground Zero>>
1.     Fun: f
2.     Fun: g
# instance _ x = g x = 10;;

Instance:

{ x = 7; }
# g CX.x;;

- : int = 10
```