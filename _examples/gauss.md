---
title: "Gauss"
excerpt: ""
colName: Examples
permalink: /gauss/
layout: pageSbar
---
Let's use Imandra to reason about a simple recursive function.

Given an input integer ```n```, this function sums up the integers from ```0``` to ```n```.

First, we enable "rational division," which causes Imandra's reasoning engine to treat division between integers as exact rational division:
```
# :rational_div on
```

Whenever we define a recursive function, Imandra must be able to prove that the function is terminating (also called being "total").

```
# let rec sum(n) =
  if n <= 0 then 0 else n + sum (n-1);;
val sum : int -> int = <fun>
```

This particular function was easy for Imandra to prove totality, but it is worth taking a look at the ```:skipterm``` directive and "termination measures" in case you have a problematic function.

Now that this function is defined, we can compute with it:
```
# sum 3;;
- : int = 6
# sum 10;;
- : int = 55
# sum 99;;
- : int = 4950
# sum 100;;
- : int = 5050
```

Now, we ask Imandra to verify a key property of the summation function:
```
# verify gauss (n) =
  n >= 0
    ==>
  sum n = (n * (n+1)) / 2;;

thm gauss = <proved>
```

But what if we had tried to verify something that was false? 
Notice below that we make a mistake, replacing ```(n+1)``` with ```(n-1)```:

```
# verify gauss_bad (n) =
  n >= 0
  ==>
  sum n = (n * (n-1)) / 2;;

Counterexample:

{ n = 1; }
```