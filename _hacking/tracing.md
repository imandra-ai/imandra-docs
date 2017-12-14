---
title: "Tracing"
excerpt: ""
colName: Hacking
permalink: /tracing/
layout: pageSbar
---
Imandra supports the standard tracing commands of OCaml: 
```#trace function-name```, ```#untrace function-name``` and ```#untrace_all```.

```
  .__      /\\ .__                           .___\n     _____  |__|    / / |__| _____ _____    ____    __| _/___________\n     \\__  \\ |  |   / /  |  |/     \\__   \\  /    \\  / __ |\\_  __ \\__  \\\n      / __ \\|  |  / /   |  |  Y Y  \\/ __ \\|   |  \\/ /_/ | |  | \\// __ \\_\n     (____  /__| / /    |__|__|_|  (____  /___|  /\\____ | |__|  (____  /\n          \\/     \\/              \\/     \\/     \\/      \\/            \\/
  
  ----------------------------------------------------------------------------
   Imandra Commander 0.8a89 - (c)Copyright Aesthetic Integration Ltd, 2014-16
  ----------------------------------------------------------------------------
  # let rec sum x =
    if x <= 0 then 0
    else x + sum (x-1)
  ;;
  val sum : int -> int = <fun>
  # 
  #trace sum;;
  sum is now traced.
  # sum 10;;
  sum <-- 10
  sum <-- 9
  sum <-- 8
  sum <-- 7
  sum <-- 6
  sum <-- 5
  sum <-- 4
  sum <-- 3
  sum <-- 2
  sum <-- 1
  sum <-- 0
  sum --> 0
  sum --> 1
  sum --> 3
  sum --> 6
  sum --> 10
  sum --> 15
  sum --> 21
  sum --> 28
  sum --> 36
  sum --> 45
  sum --> 55
  - : int = 55
  # #untrace sum;;
  sum is no longer traced.
  # sum 10;;
  - : int = 55
  ```