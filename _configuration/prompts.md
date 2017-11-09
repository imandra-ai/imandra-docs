---
title: "Prompts"
excerpt: ""
permalink: /prompts/
layout: pageSbar
colName: Configuration
---
[block:api-header]
{
  "title": "Introduction"
}
[/block]
The Imandra top-level prompt may be configured via the `Reflect` API.

By default, it is either `# ` or `> `, depending whether one is in `:logic` or `:program` mode.
[block:code]
{
  "codes": [
    {
      "code": "            .__      /\\ .__                           .___\n     _____  |__|    / / |__| _____ _____    ____    __| _/___________\n     \\__  \\ |  |   / /  |  |/     \\__   \\  /    \\  / __ |\\_  __ \\__  \\\n      / __ \\|  |  / /   |  |  Y Y  \\/ __ \\|   |  \\/ /_/ | |  | \\// __ \\_\n     (____  /__| / /    |__|__|_|  (____  /___|  /\\____ | |__|  (____  /\n          \\/     \\/              \\/     \\/     \\/      \\/            \\/\n----------------------------------------------------------------------------\n Imandra Commander 0.8a94 - (c)Copyright Aesthetic Integration Ltd, 2014-17\n----------------------------------------------------------------------------\n# 1 + 2;;\n- : int = 3\n# :program\n> 2 + 3;;\n- : int = 5\n> :logic\n# 3 + 4;;\n- : int = 7",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]

[block:api-header]
{
  "title": "API"
}
[/block]
The relevant functions are:
 - `Reflect.Prompt.set_logic_prompt : string -> unit` 
 - `Reflect.Prompt.set_program_prompt : string -> unit`
[block:api-header]
{
  "title": "Example"
}
[/block]

[block:code]
{
  "codes": [
    {
      "code": "# Reflect.Prompt.set_logic_prompt\n   \">>> BEGIN IMANDRA PROMPT (LOGIC MODE)\n  #\n  <<< END IMANDRA PROMPT\n  \";;\n- : unit = ()\n>>> BEGIN IMANDRA PROMPT (LOGIC MODE)\n#\n<<< END IMANDRA PROMPT\nlet f x = x + 1;;\nval f : int -> int = <fun>\n>>> BEGIN IMANDRA PROMPT (LOGIC MODE)\n#\n<<< END IMANDRA PROMPT\n:program\n> Reflect.Prompt.set_program_prompt\n   \">>> BEGIN IMANDRA PROMPT (PROGRAM MODE)\n  >\n  <<< END IMANDRA PROMPT\n  \";;\n- : unit = ()\n>>> BEGIN IMANDRA PROMPT (PROGRAM MODE)\n>\n<<< END IMANDRA PROMPT\n1;;\n- : int = 1\n>>> BEGIN IMANDRA PROMPT (PROGRAM MODE)\n>\n<<< END IMANDRA PROMPT\n:logic\n>>> BEGIN IMANDRA PROMPT (LOGIC MODE)\n#\n<<< END IMANDRA PROMPT\ninstance _ x = f x = 10;;\n\nInstance:\n\n  { x = 9; }\n\n>>> BEGIN IMANDRA PROMPT (LOGIC MODE)\n#\n<<< END IMANDRA PROMPT\n",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
