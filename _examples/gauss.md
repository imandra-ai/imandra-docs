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
[block:code]
{
  "codes": [
    {
      "code": "# :rational_div on",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Whenever we define a recursive function, Imandra must be able to prove that the function is terminating (also called being "total").
[block:code]
{
  "codes": [
    {
      "code": "# let rec sum(n) =\n   if n <= 0 then 0 else n + sum (n-1);;  \nval sum : int -> int = <fun>",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
This particular function was easy for Imandra to prove totality, but it is worth taking a look at the ```:skipterm``` directive and "termination measures" in case you have a problematic function.

Now that this function is defined, we can compute with it:
[block:code]
{
  "codes": [
    {
      "code": "# sum 3;;\n- : int = 6\n# sum 10;;\n- : int = 55\n# sum 99;;\n- : int = 4950\n# sum 100;;",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Now, we ask Imandra to verify a key property of the summation function:
[block:code]
{
  "codes": [
    {
      "code": "# verify gauss (n) =\n   n >= 0\n     ==>\n   sum n = (n * (n+1)) / 2;;      \nthm gauss = <proved>",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
But what if we had tried to verify something that was false? 
Notice below that we make a mistake, replacing ```(n+1)``` with ```(n-1)```:
[block:code]
{
  "codes": [
    {
      "code": "# verify gauss_bad (n) =\n   n >= 0\n     ==>\n   sum n = (n * (n-1)) / 2;;\n\nCounterexample:\n\n  { n = 1; }",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
