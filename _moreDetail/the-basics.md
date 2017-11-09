---
title: "In more detail"
excerpt: ""
colName: The Basics
permalink: /theBasics/
layout: pageSbar
---
In this section we'll get up to speed on writing and experimenting with Imandra code.
[block:api-header]
{
  "type": "basic",
  "title": "Executing IML code"
}
[/block]
Use ```;;``` to indicate that you've finished entering each statement:
[block:code]
{
  "codes": [
    {
      "code": "# 1+1;;\n- : int = 2",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]

[block:api-header]
{
  "type": "basic",
  "title": "Comments"
}
[/block]
IML comments are delimited by ```(*``` and ```*)```, like this:
[block:code]
{
  "codes": [
    {
      "code": "\n(* This is a single-line comment. *)\n \n(* This is a\n * multi-line\n * comment.\n *)",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
The commenting convention is very similar to original C (```\* ... \*```). There is currently no single-line comment syntax (like ```# ...``` in Perl or ```// ...``` in C99/C++/Java).

IML counts nested ```(* ... *)``` blocks, and this allows you to comment out regions of code very easily:
[block:code]
{
  "codes": [
    {
      "code": "(* This code is broken, we comment it out ...\n \n(* Primality test. *)\nlet is_prime n =\n  (* note to self: ask about this on the mailing lists *) XXX;;\n \n*)",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]

[block:api-header]
{
  "type": "basic",
  "title": "Defining functions"
}
[/block]
Functions are defined with the ```let``` command. In Imandra, multi-argument functions must be given a tuple of arguments. This is normal for, e.g., C, Python and Java programmers, but may be strange at first from functional programmers used to writing curried higher-order functions. 

When we define a function, Imandra responds telling us the type for the function:
[block:code]
{
  "codes": [
    {
      "code": "# let k(x,y,z) =\n   if x > y then y else z + 1;;\nval k : int * int * int -> int = <fun>",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
In this case, we see that ```k``` maps a triple of integers to an integer.

Because Imandra is both a programming language and a mathematical logic, we must be careful about our definitions, to ensure that they do not introduce inconsistencies into the logic. Luckily, as users, we do not have to worry about this: Imandra checks our definitions to ensure that they do not introduce inconsistency. This does mean however that Imandra will stop us from doing certain things.

For example, once we've defined a function, we cannot redefine it in the same Imandra session (without explicitly enabling redefinition): 
[block:code]
{
  "codes": [
    {
      "code": "# let k(x,y,z) = x + 1;;\nError: Name \"k\" is already in use.\nUse :redef (with caution) to redefine named values.",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
Why is this restriction on redefinition important? Well, if we define a function, we can then prove theorems about it and other functions that depend on it. But if we then later redefine that function, those theorems we've proved (and are now available to Imandra's reasoning engine) may now be false. Thus, redefinition can lead to inconsistency. It's a useful tool to have while developing a formal model interactively, allowing you to experiment and fix mistakes in your designs. But, once your definitions are set, you should never enable redefinition during verification of your system.

To enable redefinition, use ```:redef on```:
[block:code]
{
  "codes": [
    {
      "code": "# let f(x) = x+1;;\nval f : int -> int = <fun>\n# let f(x) = x+2;;\nError: Name \"f\" is already in use.\nUse :redef (with caution) to redefine named values.\n# :redef on\n# let f(x) = x+2;;\nval f : int -> int = <fun>\n# f(3);;\n- : int = 5",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
To define recursive functions, we use ```let rec``` instead of ```let```:
[block:code]
{
  "codes": [
    {
      "code": "# let rec sum(x) =\n   if x <= 0 then 0\n   else x + sum(x-1);;\nval sum : int -> int = <fun>",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
When we define recursive functions, Imandra must be able to prove that they terminate for all of their inputs. Why? Again, this connects to logical consistency. Consider what would happen if Imandra allowed us to define the following non-terminating function:
[block:code]
{
  "codes": [
    {
      "code": "# let rec f(x) = f(x) + 1;;\nval f : 'a -> int = <fun>\nError: Function f rejected by definitional principle.",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
Thankfully, Imandra will not allow this function to be defined. If it had, we could derive a falsehood by the following chain of reasoning: ```f(0) = f(0) + 1```, so subtracting ```f(0)``` from both sides, we see ```0=1```. That terminating recursive functions do not introduce inconsistency is a deep result of mathematical logic. This is part of Imandra's "definitional principle." The definitional principle guarantees that all functions (and types) admitted in Imandra extend Imandra's logical theory in a consistent way (in technical terms, "every definitional extension of Imandra is a conservative extension.")

In some cases, you may need to tell Imandra why a recursive function is terminating, by specifying a "termination measure." We'll go over this in due course.
[block:api-header]
{
  "type": "basic",
  "title": "Defining types"
}
[/block]
Like OCaml, F# and Haskell, Imandra is a statically-typed language with type inference. Much of the power of the type system extends from the use of *algebraic datatypes* and *exhaustive pattern-matching*.

In languages like C, we're used to enumerated types. These are the simplest form of algebraic datatypes:
[block:code]
{
  "codes": [
    {
      "code": "# type color = Red | Green | Blue;;  \ntype color = Red | Green | Blue",
      "language": "text",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
Notice that when we define a type in Imandra, it then prints the type definition back to us.

We call ```Red```, ```Green``` and ```Blue``` the "constructors" for the type ```color```. There is no way to be a value of type ```color``` other than being either ```Red```, ```Green``` or ```Blue```.

In fact, we can ask Imandra to prove this for us, by asking it to compute an instance of type ```color``` that is neither ```Red``` nor ```Green``` nor ```Blue```:
[block:code]
{
  "codes": [
    {
      "code": "# instance _ (x : color) = \n   not(x = Red || x = Green || x = Blue);;\nNo such instance exists.",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
With algebraic datatypes (ADTs), we can define functions using pattern-matching:
[block:code]
{
  "codes": [
    {
      "code": "# let num_of_color x =\n   match x with\n     Red   -> 0\n   | Green -> 1\n   | Blue  -> 2\n  ;;\nval num_of_color : color -> int = <fun>",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
In Imandra, pattern-matching must be exhaustive. For example, if we tried to define the above function but forgot the case for ```Green```, we'd see the following error:
[block:code]
{
  "codes": [
    {
      "code": "# let num_of_color_oops x =\n   match x with\n    Red -> 0\n  | Blue -> 2\n  ;;\nWarning 8: this pattern-matching is not exhaustive.\nHere is an example of a value that is not matched:\nGreen\nError: Pattern-matching must be exhaustive.",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
As part of its static typing, Imandra can always tell us whether or not our patterns are exhaustive.

We can use values of algebraic datatypes in searches for instances and counterexamples in the same way as any other value:
[block:code]
{
  "codes": [
    {
      "code": "# instance _ x =\n   num_of_color x <> 2;;\n\nInstance:\n\n  { x = Green; }",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
Is ```Green``` the only such instance? Let's ask:
[block:code]
{
  "codes": [
    {
      "code": "# instance _ x =\n   num_of_color x <> 2 && x <> Green;;\n\nInstance:\n\n  { x = Red; }",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
Algebraic datatypes allow us to do much more than simple enumeration types. Crucially, every constructor in an ADT may itself take parameters:
[block:code]
{
  "codes": [
    {
      "code": "# type cash = GBP of int | USD of int | Euro of int;;\ntype cash = GBP of int | USD of int | Euro of int",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
Some values of type ```cash```:
[block:code]
{
  "codes": [
    {
      "code": "# GBP 10;;\n- : cash = GBP 10\n# USD 100;;\n- : cash = USD 100\n# Euro 50;;\n- : cash = Euro 50",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
What happens if we try to add them together?
[block:code]
{
  "codes": [
    {
      "code": "# (Euro 100) + (USD 10);;\n   ^^^^^^^^\nError: This expression has type cash but an expression was expected of type\n         int",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
We get a type error. The function ```+``` is defined on integers only. Note that this error has nothing to do with which constructors for cash we use. For example, if we try to add two ```USD``` values together, we'll get the error just the same:
[block:code]
{
  "codes": [
    {
      "code": "# (USD 100) + (USD 50);;\n   ^^^^^^^\nError: This expression has type cash but an expression was expected of type\n         int",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
Let's define our own addition function for the type cash:
[block:code]
{
  "codes": [
    {
      "code": "# let add (x,y) =\n   match x,y with\n     USD n, USD m   -> Some (USD (n+m))\n   | GBP n, GBP m   -> Some (GBP (n+m))\n   | Euro n, Euro m -> Some (Euro (n+m))\n   | _ -> None;;\nval add : cash * cash -> cash option = <fun>",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
There are a few things to notice here. First, we see the use of variables in pattern matching, i.e., the uses of ```n``` and ```m``` in the patterns for each constructor. This allows us to "destruct" values of an ADT and compute with its constituent parts.

Second, think about what happens if we try to add ```GBP``` and ```USD``` values together. We don't want that to be allowed. One approach we're used to from other languages is to raise an exception. In Imandra, however, we do not have exceptions. Instead, we use a special type called the ```option``` type to help us structure possible failures. This allows our handling of exceptional cases to take place fully within the type-system, guaranteeing that we never fail to handle an exceptional case or failure.

With an option type, we have two constructors: ```Some``` and ```None```. For any type ```t```, there's an option type called ```t option``` such that the parameter of the ```Some``` constructor has type ```t```. 

Let's see what happens when we use this function:
[block:code]
{
  "codes": [
    {
      "code": "# add(USD 5, USD 10);;\n- : cash option = Some (USD 15)\n# add(GBP 25, GBP 50);;\n- : cash option = Some (GBP 75)\n# add(USD 5, GBP 10);;\n- : cash option = None",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
Let's verify something about this function. For instance, we may want to ensure that if we call the function with arguments of the same currency, then we'll never get ```None``` as a result. 

To express this, we just need to define the concept ```same_currency```:
[block:code]
{
  "codes": [
    {
      "code": "# let same_currency (x,y) =\n   match x,y with\n    USD _, USD _ -> true\n   | GBP _, GBP _ -> true\n   | Euro _, Euro _ -> true        \n   | _ -> false\n  ;;\nval same_currency : cash * cash -> bool = <fun>",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
And now we can ask Imandra to prove our theorem:
[block:code]
{
  "codes": [
    {
      "code": "# theorem _ (x,y) =\n   same_currency(x,y)  ==>  add(x,y) <> None;;\nthm _ = <proved>",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
ADTs can also be recursive:
[block:code]
{
  "codes": [
    {
      "code": "# type foo = A of int | B of foo * foo;;\ntype foo = A of int | B of foo * foo",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
Let's compute with some values of this type:
[block:code]
{
  "codes": [
    {
      "code": "# A 100;;\n- : foo = A 100\n# B (B (A 10, B (A 5, A 123)), A 999);;\n- : foo = B (B (A 10, B (A 5, A 123)), A 999)\n# B (A 123, A 456);;\n- : foo = B (A 123, A 456)",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
Let's use Imandra to do some deeper investigations:
[block:code]
{
  "codes": [
    {
      "code": "# verify _ (x,a,b) =\n   x <> B (A (a+1), B (A a, A (a+2)));;  \n\nWarning: This conjecture contains free type variables.\n We shall concretise them to ints for counterexample search.\n You can control this by annotating the conjecture with types.\n\nCounterexample:\n\n  { x = B (A 1, B (A 0, A 2));\n    a = 0;\n    b = 0; }",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
Notice our use of the ```verify``` command. This command first tries to prove the given conjecture, and if that fails, it then searches for counterexamples. If a counterexample is found, its values are reflected into the CX module:
[block:code]
{
  "codes": [
    {
      "code": "# CX.x;;\n- : foo = B (A 1, B (A 0, A 2))\n# CX.a;;\n- : int = 0\n# CX.b;;\n- : int = 0",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
Notice that warning "This conjecture contains ...": Because the conjecture contains free type variables, these types must be `concretized' before a search for counterexamples can commence.

Why does this happen in this example? Because the ```b``` variable isn't actually used! However, we can have type variables for more interesting reasons as well.

By default, type variables are concretized to be integers during counterexample search.
However, we can override this with explicit type annotations:
[block:code]
{
  "codes": [
    {
      "code": "# verify _ (x,a,b : _ * _ * foo list) =\n  x <> B (A (a+1), B (A a, A (a+2)));;  \n\nCounterexample:\n\n  { x = B (A 1, B (A 0, A 2));\n    a = 0;\n    b = []; }",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
Note that we could achieve the same result by using the ```instance``` command instead. We just have to negate our formula:
[block:code]
{
  "codes": [
    {
      "code": "# instance _ (x,a,b : _ * _ * foo list) =\n  x = B (A (a+1), B (A a, A (a+2)));;  \n\nInstance:\n\n  { x = B (A 1, B (A 0, A 2));\n    a = 0;\n    b = []; }",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
Now, let's do something a bit more interesting:
[block:code]
{
  "codes": [
    {
      "code": "# verify _ (x,a,b : _ * _ * foo list) =\n    not(x = B (A (a+1), B (A a, A (a+2)))\n        && (List.length b > 2)\n        && (List.hd b = A (2*a + 1)));;\n\nNo counterexample found up to bound 1. Use :unroll to increase bound.",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
Imandra tells us that no counterexamples were found up to recursion unrolling bound 1. This is not surprising, as we have a constraint requiring the length of a list is greater than 2.

So, let's set the unrolling bound to 3 and try again:
[block:code]
{
  "codes": [
    {
      "code": "# :unroll 3\nunroll set to 3.\n# verify _ (x,a,b : _ * _ * foo list) =\n    not(x = B (A (a+1), B (A a, A (a+2)))\n        && (List.length b > 2)\n        && (List.hd b = A (2*a + 1)));;      \n\nCounterexample:\n\n  { x = B (A 1797, B (A 1796, A 1798));\n    a = 1796;\n    b = [A 3593;\n         A 19;\n         A 20]; }",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
Again, we can compute with our counterexample:
[block:code]
{
  "codes": [
    {
      "code": "# CX.x;;\n- : foo = B (A 1797, B (A 1796, A 1798))\n# CX.a;;\n- : int = 1796\n# CX.b;;\n- : foo list = [A 3593; A 19; A 20]\n# List.length CX.b;;\n- : int = 3\n# List.hd CX.b;;\n- : foo = A 3593\n# 2*CX.a + 1;;\n- : int = 3593",
      "language": "scala",
      "name": "Imandra Command Line"
    }
  ]
}
[/block]
