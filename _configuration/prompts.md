---
title: "Prompts"
excerpt: ""
permalink: /prompts/
layout: pageSbar
colName: Configuration
---

#### Introduction
The Imandra top-level prompt may be configured via the `Reflect` API.

By default, it is either `# ` or `> `, depending whether one is in `:logic` or `:program` mode.

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
# 1 + 2;;
- : int = 3
# :program
> 2 + 3;;
- : int = 5
> :logic
# 3 + 4;;
- : int = 7
```

#### API

The relevant functions are:
 - `Reflect.Prompt.set_logic_prompt : string -> unit` 
 - `Reflect.Prompt.set_program_prompt : string -> unit`

#### Example

```
# Reflect.Prompt.set_logic_prompt
>>> BEGIN IMANDRA PROMPT (LOGIC MODE)
#
<<< END IMANDRA PROMPT\n  \";;
- : unit = ()
>>> BEGIN IMANDRA PROMPT (LOGIC MODE)
#
<<< END IMANDRA PROMPT
let f x = x + 1;;
val f : int -> int = <fun>
>>> BEGIN IMANDRA PROMPT (LOGIC MODE)
#
<<< END IMANDRA PROMPT
:program
> Reflect.Prompt.set_program_prompt
>>> BEGIN IMANDRA PROMPT (PROGRAM MODE)
>
<<< END IMANDRA PROMPT
";;
- : unit = ()
>>> BEGIN IMANDRA PROMPT (PROGRAM MODE)
>
<<< END IMANDRA PROMPT
1;;
- : int = 1
>>> BEGIN IMANDRA PROMPT (PROGRAM MODE)
>
<<< END IMANDRA PROMPT
:logic
>>> BEGIN IMANDRA PROMPT (LOGIC MODE)
#
<<< END IMANDRA PROMPT
instance _ x = f x = 10;;

Instance:

{ x = 9; }

>>> BEGIN IMANDRA PROMPT (LOGIC MODE)
#
<<< END IMANDRA PROMPT
```