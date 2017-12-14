---
title: "Avoiding Common Mistakes"
excerpt: ""
colName: Pitfalls
permalink: /pitfalls/
layout: pageSbar
---
## Things to avoid

Imandra supports a (growing) strict subset of OCaml.
In this section, we record some common issues programmers face when beginning to use Imandra.

### Writing higher-order functions

Unlike OCaml, Imandra doesn't support higher-order functions.

This means that your functions should always accept tuples of arguments, and should never return a function value.

That is, the type of the functions you define will always be of this form (with ```t``` containing neither ```*``` nor ```->```):

```
f : (t1 * ... * tn) -> t
```

For example, if you try to write a higher-order function like ```add : int -> int -> int``` below, Imandra will give you an error:
```
# let add x y = x + y;;
val add : int -> int -> int = <fun>
Error: Defined values must be first-order (no currying, no output tuples).
But, add : int -> int -> int violates this restriction.

```

Instead, you should write the function using a tuple of arguments:

```
# let add (x,y) = x + y;;
val add : int * int -> int = <fun>
```

### Writing functions which output tuples

Unlike OCaml, IML functions cannot return tuple values.
Instead of output tuples, you should use a record type, perhaps custom defined for the usage.
This use of records rather than tuples makes your code easier to read and maintain.

For example, the following will give an error:

```
# let k x = (x, x + 1);;
val k : int -> int * int = <fun>
Error: Defined values must be first-order (no currying, no output tuples).
But, k : int -> int * int violates this restriction.
```

Instead, you should use a record type:

```
# type my_rec = { v1 : int; v2 : int };;
type my_rec = { v1 : int; v2 : int; }
# let k x = { v1 = x; v2 = x + 1 };;
val k : int -> my_rec = <fun>
```

[block:callout]
{
  "type": "info",
  "title": "Important!",
  "body": "You cannot use accessible global variables (logical constants) inside pattern matching."
}
[/block]
### Omitting double semi-colons

In Imandra, you must end each definitional event (type, function or theorem definition) with a double semicolon (```;;```).

Programmers used to procedural languages often use a single semicolon (```;```):
```
# let k = 123;
let f (x, y) = x > y;;

Characters 34-35:
  let f (x, y) = x > y;;
Error: Parse error: "in" expected after [binding] (in [expr])
```

OCaml programmers may be used to omitting ```;;``` between definitions:
```
# let k = 123
let f (x,y) = x > y\n;;
val k : int = 123
val f : 'a * 'a -> bool = <fun>

Error: Compound command - Did you forget to terminate a command with ';;'?
```

The correct Imandra version is:
```
# let k = 123;;
# let f (x, y) = x > y;;
```
