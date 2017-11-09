---
title: "Insertion sort"
excerpt: ""
colName: Examples
permalink: /insertionSort/
layout: pageSbar
---
Let's use Imandra to verify an implementation of *insertion sort*. 
[block:api-header]
{
  "type": "basic",
  "title": "1. Define the function"
}
[/block]
You may be familiar with languages like Python. Here's a Python implementation of the algorithm:
[block:code]
{
  "codes": [
    {
      "code": "def i_sort( lst ):\n for i in range( 1, len( lst ) ):\n   tmp = lst[i]\n   k = i\n   while k > 0 and tmp < lst[k - 1]:\n       lst[k] = lst[k - 1]\n       k -= 1\n   lst[k] = tmp",
      "language": "python",
      "name": null
    }
  ]
}
[/block]
Notice the nested iteration, i.e., the while-loop nested inside of the outer for-loop.

Mathematically, this suggests that we use two recursive functions to give a functional definition of this algorithm.

Let's implement this in Imandra.

First, we'll define the ```insert``` function: 
[block:code]
{
  "codes": [
    {
      "code": "# let rec insert (a,lst) =\n   match lst with\n      []      -> [a]\n    | x :: xs ->\n      if a < x then a :: x :: xs else x :: insert(a, xs);;        \nval insert : 'a * 'a list -> 'a list = <fun>",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Next, we'll define the ```sorting``` function: 
[block:code]
{
  "codes": [
    {
      "code": "# let rec i_sort lst =\n   match lst with\n     []      -> []\n   | x :: xs -> insert(x, i_sort xs);;\nval i_sort : 'a list -> 'a list = <fun>",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Note that both definitions were accepted (and thus proved to be terminating) by Imandra. 

Note also the type of ```i_sort``` computed by Imandra. This type ```'a list -> 'a list``` tells us that ```i_sort``` is a polymorphic function: It will accept as input a list of any type of values (all values in the list having type ```'a``` where ```'a``` is arbitrary), and will compute as output a list of the same type.
(This is possible as the comparison function ```<```used in the definition of ```insert``` is itself polymorphic.)

With these functions admitted, we can now compute with them:
[block:code]
{
  "codes": [
    {
      "code": "# i_sort [7; 3; 890; 100];;\n- : int list = [3; 7; 100; 890]",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Excellent. But is the code actually correct? Are there ever any corner cases where it can fail to produce a sorted list as output?

We can ask Imandra.

First, we define a specification of what it means for a list to be sorted:
[block:code]
{
  "codes": [
    {
      "code": "# let rec is_sorted (x) =\n  match x with\n  | a :: b :: xs ->\n     (a <= b) && is_sorted (b::xs)\n  | _ -> true;;        \nval is_sorted : 'a list -> bool = <fun>",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Take some time to think about this definition.

Now, we can ask Imandra to verify a correctness theorem:
[block:code]
{
  "codes": [
    {
      "code": "# verify i_sort_spec x =\n   is_sorted (i_sort x);;\nthm i_sort_spec = <proved>",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Success! And very quickly:
[block:code]
{
  "codes": [
    {
      "code": "# :t\nLast timed event: 0.395 sec.",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
But now let's think more about our spec. Is our spec really expressing what we want it to?

Not completely! Why? Consider the following function:
[block:code]
{
  "codes": [
    {
      "code": "# let i_sort_bad (x) = [];;\nval i_sort_bad : 'a -> 'b list = <fun>",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
This function also satisfies our spec:
[block:code]
{
  "codes": [
    {
      "code": "# verify i_sort_bad_spec x =\n   is_sorted (i_sort_bad x);;  \nthm i_sort_bad_spec = <proved>",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
We must also consider the property that the output is a permutation of its input. 

Defining and proving this property of ```i_sort``` is a great Imandra exercise!
