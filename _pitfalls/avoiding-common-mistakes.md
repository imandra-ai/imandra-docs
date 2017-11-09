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
[block:code]
{
  "codes": [
    {
      "code": "f : (t1 * ... * tn) -> t",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
For example, if you try to write a higher-order function like ```add : int -> int -> int``` below, Imandra will give you an error:
[block:code]
{
  "codes": [
    {
      "code": "# let add x y = x + y;;\nval add : int -> int -> int = <fun>\nError: Defined values must be first-order (no currying, no output tuples).\nBut, add : int -> int -> int violates this restriction.",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Instead, you should write the function using a tuple of arguments:
[block:code]
{
  "codes": [
    {
      "code": "# let add (x,y) = x + y;;\nval add : int * int -> int = <fun>",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
### Writing functions which output tuples

Unlike OCaml, IML functions cannot return tuple values.
Instead of output tuples, you should use a record type, perhaps custom defined for the usage.
This use of records rather than tuples makes your code easier to read and maintain.

For example, the following will give an error:
[block:code]
{
  "codes": [
    {
      "code": "# let k x = (x, x + 1);;\nval k : int -> int * int = <fun>\nError: Defined values must be first-order (no currying, no output tuples).\nBut, k : int -> int * int violates this restriction.",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Instead, you should use a record type:
[block:code]
{
  "codes": [
    {
      "code": "# type my_rec = { v1 : int; v2 : int };;\ntype my_rec = { v1 : int; v2 : int; }\n# let k x = { v1 = x; v2 = x + 1 };;\nval k : int -> my_rec = <fun>",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]

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
[block:code]
{
  "codes": [
    {
      "code": "# let k = 123;\n  let f (x, y) = x > y;;\n\nCharacters 34-35:\n  let f (x, y) = x > y;;\n                       ^\nError: Parse error: \"in\" expected after [binding] (in [expr])",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
OCaml programmers may be used to omitting ```;;``` between definitions:
[block:code]
{
  "codes": [
    {
      "code": "# let k = 123\n  let f (x,y) = x > y\n;;\nval k : int = 123\nval f : 'a * 'a -> bool = <fun>\n\nError: Compound command - Did you forget to terminate a command with ';;'?",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
The correct Imandra version is:
[block:code]
{
  "codes": [
    {
      "code": "# let k = 123;;\n# let f (x, y) = x > y;;",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
