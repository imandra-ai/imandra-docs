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

```python
def i_sort( lst ):
  for i in range( 1, len(lst)):
  tmp = lst[i]
  k = i
  while k > 0 and tmp < lst[k - 1]:
    lst[k] = lst[k - 1]
    k -= 1
    lst[k] = tmp
```

Notice the nested iteration, i.e., the while-loop nested inside of the outer for-loop.

Mathematically, this suggests that we use two recursive functions to give a functional definition of this algorithm.

Let's implement this in Imandra.

First, we'll define the ```insert``` function: 
```
# let rec insert (a,lst) =
  match lst with
  []      -> [a]
  | x :: xs ->
    if a < x then a :: x :: xs else x :: insert(a, xs);;

val insert : 'a * 'a list -> 'a list = <fun>,
```

Next, we'll define the ```sorting``` function: 
```
# let rec i_sort lst =
  match lst with
  []      -> []
  | x :: xs -> insert(x, i_sort xs);;

val i_sort : 'a list -> 'a list = <fun>
```
Note that both definitions were accepted (and thus proved to be terminating) by Imandra. 

Note also the type of ```i_sort``` computed by Imandra. This type ```'a list -> 'a list``` tells us that ```i_sort``` is a polymorphic function: It will accept as input a list of any type of values (all values in the list having type ```'a``` where ```'a``` is arbitrary), and will compute as output a list of the same type.
(This is possible as the comparison function ```<``` used in the definition of ```insert``` is itself polymorphic.)

With these functions admitted, we can now compute with them:

```
# i_sort [7; 3; 890; 100];;

- : int list = [3; 7; 100; 890]
```

Excellent. But is the code actually correct? Are there ever any corner cases where it can fail to produce a sorted list as output?

We can ask Imandra.

First, we define a specification of what it means for a list to be sorted:

```
# let rec is_sorted (x) =
  match x with
  | a :: b :: xs -> (a <= b) && is_sorted (b::xs)
  | _ -> true;;

val is_sorted : 'a list -> bool = <fun>
```

Take some time to think about this definition.

Now, we can ask Imandra to verify a correctness theorem:
```
# verify i_sort_spec x =
  is_sorted (i_sort x);;

thm i_sort_spec = <proved>
```

Success! And very quickly:
```
# :t\nLast timed event: 0.395 sec.
```

But now let's think more about our spec. Is our spec really expressing what we want it to?

Not completely! Why? Consider the following function:

```
# let i_sort_bad (x) = [];;

val i_sort_bad : 'a -> 'b list = <fun>
```

This function also satisfies our spec:
```
# verify i_sort_bad_spec x =
  is_sorted (i_sort_bad x);;

thm i_sort_bad_spec = <proved>
```
We must also consider the property that the output is a permutation of its input. 

Defining and proving this property of ```i_sort``` is a great Imandra exercise!
