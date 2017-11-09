---
title: "Tracing"
excerpt: ""
colName: Hacking
permalink: /tracing/
layout: pageSbar
---
Imandra supports the standard tracing commands of OCaml: 
```#trace function-name```, ```#untrace function-name``` and ```#untrace_all```.
[block:code]
{
  "codes": [
    {
      "code": "            .__      /\\ .__                           .___\n     _____  |__|    / / |__| _____ _____    ____    __| _/___________\n     \\__  \\ |  |   / /  |  |/     \\__   \\  /    \\  / __ |\\_  __ \\__  \\\n      / __ \\|  |  / /   |  |  Y Y  \\/ __ \\|   |  \\/ /_/ | |  | \\// __ \\_\n     (____  /__| / /    |__|__|_|  (____  /___|  /\\____ | |__|  (____  /\n          \\/     \\/              \\/     \\/     \\/      \\/            \\/\n----------------------------------------------------------------------------\n Imandra Commander 0.8a89 - (c)Copyright Aesthetic Integration Ltd, 2014-16\n----------------------------------------------------------------------------\n# let rec sum x =\n   if x <= 0 then 0\n   else x + sum (x-1)\n  ;;\nval sum : int -> int = <fun>\n# #trace sum;;\nsum is now traced.\n# sum 10;;\nsum <-- 10\nsum <-- 9\nsum <-- 8\nsum <-- 7\nsum <-- 6\nsum <-- 5\nsum <-- 4\nsum <-- 3\nsum <-- 2\nsum <-- 1\nsum <-- 0\nsum --> 0\nsum --> 1\nsum --> 3\nsum --> 6\nsum --> 10\nsum --> 15\nsum --> 21\nsum --> 28\nsum --> 36\nsum --> 45\nsum --> 55\n- : int = 55\n# #untrace sum;;\nsum is no longer traced.\n# sum 10;;\n- : int = 55",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
