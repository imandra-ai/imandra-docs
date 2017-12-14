---
title: "In more detail"
excerpt: ""
colName: The Basics
permalink: /theBasics/
layout: pageSbar
---
In this section we'll get up to speed on writing and experimenting with Imandra code.

#### Executing IML code

Use ```;;``` to indicate that you've finished entering each statement:
```
# 1+1;;
- : int = 2
```

#### Comments

IML comments are delimited by ```(*``` and ```*)```, like this:
```
(* This is a single-line comment. *)
(* This is a
 * multi-line
 * comment.
 *)
```

The commenting convention is very similar to original C (```\* ... \*```). There is currently no single-line comment syntax (like ```# ...``` in Perl or ```// ...``` in C99/C++/Java).

IML counts nested ```(* ... *)``` blocks, and this allows you to comment out regions of code very easily:
```
(* This code is broken, we comment it out ...

(* Primality test. *)
let is_prime n =
(* note to self: ask about this on the mailing lists *) XXX;;

*)
```

#### Defining functions

Functions are defined with the ```let``` command. In Imandra, multi-argument functions must be given a tuple of arguments. This is normal for, e.g., C, Python and Java programmers, but may be strange at first from functional programmers used to writing curried higher-order functions. 

When we define a function, Imandra responds telling us the type for the function:

```
# let k(x,y,z) =
if x > y then y else z + 1;;
val k : int * int * int -> int = <fun>
```
In this case, we see that ```k``` maps a triple of integers to an integer.

Because Imandra is both a programming language and a mathematical logic, we must be careful about our definitions, to ensure that they do not introduce inconsistencies into the logic. Luckily, as users, we do not have to worry about this: Imandra checks our definitions to ensure that they do not introduce inconsistency. This does mean however that Imandra will stop us from doing certain things.

For example, once we've defined a function, we cannot redefine it in the same Imandra session (without explicitly enabling redefinition): 
```
# let k(x,y,z) = x + 1;;
Error: Name "k" is already in use.
Use :redef (with caution) to redefine named values.
```
Why is this restriction on redefinition important? Well, if we define a function, we can then prove theorems about it and other functions that depend on it. But if we then later redefine that function, those theorems we've proved (and are now available to Imandra's reasoning engine) may now be false. Thus, redefinition can lead to inconsistency. It's a useful tool to have while developing a formal model interactively, allowing you to experiment and fix mistakes in your designs. But, once your definitions are set, you should never enable redefinition during verification of your system.

To enable redefinition, use ```:redef on```:

```
# let f(x) = x+1;;
val f : int -> int = <fun>
# let f(x) = x+2;;
Error: Name "f" is already in use.
Use :redef (with caution) to redefine named values.
# :redef on
# let f(x) = x+2;;
val f : int -> int = <fun>
# f(3);;
- : int = 5
```

To define recursive functions, we use ```let rec``` instead of ```let```:
```
# let rec sum(x) =
if x <= 0 then 0
else x + sum(x-1);;
val sum : int -> int = <fun>
```

When we define recursive functions, Imandra must be able to prove that they terminate for all of their inputs. Why? Again, this connects to logical consistency. Consider what would happen if Imandra allowed us to define the following non-terminating function:

```
# let rec f(x) = f(x) + 1;;
val f : 'a -> int = <fun>
Error: Function f rejected by definitional principle.
```

Thankfully, Imandra will not allow this function to be defined. If it had, we could derive a falsehood by the following chain of reasoning: ```f(0) = f(0) + 1```, so subtracting ```f(0)``` from both sides, we see ```0=1```. That terminating recursive functions do not introduce inconsistency is a deep result of mathematical logic. This is part of Imandra's "definitional principle." The definitional principle guarantees that all functions (and types) admitted in Imandra extend Imandra's logical theory in a consistent way (in technical terms, "every definitional extension of Imandra is a conservative extension.")

In some cases, you may need to tell Imandra why a recursive function is terminating, by specifying a "termination measure." We'll go over this in due course.

#### Defining types

Like OCaml, F# and Haskell, Imandra is a statically-typed language with type inference. Much of the power of the type system extends from the use of *algebraic datatypes* and *exhaustive pattern-matching*.

In languages like C, we're used to enumerated types. These are the simplest form of algebraic datatypes:
```
# type color = Red | Green | Blue;;
type color = Red | Green | Blue
```

Notice that when we define a type in Imandra, it then prints the type definition back to us.

We call ```Red```, ```Green``` and ```Blue``` the "constructors" for the type ```color```. There is no way to be a value of type ```color``` other than being either ```Red```, ```Green``` or ```Blue```.

In fact, we can ask Imandra to prove this for us, by asking it to compute an instance of type ```color``` that is neither ```Red``` nor ```Green``` nor ```Blue```:

```
# instance _ (x : color) =
  not(x = Red || x = Green || x = Blue);;

No such instance exists.
```

With algebraic datatypes (ADTs), we can define functions using pattern-matching:
```
# let num_of_color x =
match x with
  Red   -> 0
  | Green -> 1
  | Blue  -> 2
  ;;
val num_of_color : color -> int = <fun>
```

In Imandra, pattern-matching must be exhaustive. For example, if we tried to define the above function but forgot the case for ```Green```, we'd see the following error:

```
# let num_of_color_oops x =
  match x with
  Red -> 0
  | Blue -> 2
;;
Warning 8: this pattern-matching is not exhaustive.
Here is an example of a value that is not matched:
  Green
Error: Pattern-matching must be exhaustive.
```

As part of its static typing, Imandra can always tell us whether or not our patterns are exhaustive.

We can use values of algebraic datatypes in searches for instances and counterexamples in the same way as any other value:

```
# instance _ x =
num_of_color x <> 2;;
Instance:

{ x = Green; }
```

Is ```Green``` the only such instance? Let's ask:
```
# instance _ x =
  num_of_color x <> 2 && x <> Green;;
Instance:
  { x = Red; }
```

Algebraic datatypes allow us to do much more than simple enumeration types. Crucially, every constructor in an ADT may itself take parameters:

```
# type cash = GBP of int | USD of int | Euro of int;;
type cash = GBP of int | USD of int | Euro of int
```

Some values of type ```cash```:

```
# GBP 10;;
- : cash = GBP 10
# USD 100;;
- : cash = USD 100
# Euro 50;;
- : cash = Euro 50
```

What happens if we try to add them together?

```
# (Euro 100) + (USD 10);;
  ^^^^^^^^
Error: This expression has type cash but an expression was expected of type
  int
```

We get a type error. The function ```+``` is defined on integers only. Note that this error has nothing to do with which constructors for cash we use. For example, if we try to add two ```USD``` values together, we'll get the error just the same:
```
# (USD 100) + (USD 50);;
  ^^^^^^^
Error: This expression has type cash but an expression was expected of type
  int
```

Let's define our own addition function for the type cash:

```
# let add (x,y) =
  match x,y with
    USD n, USD m   -> Some (USD (n+m))
    | GBP n, GBP m   -> Some (GBP (n+m))
    | Euro n, Euro m -> Some (Euro (n+m))
    | _ -> None;;
val add : cash * cash -> cash option = <fun>
```

There are a few things to notice here. First, we see the use of variables in pattern matching, i.e., the uses of ```n``` and ```m``` in the patterns for each constructor. This allows us to "destruct" values of an ADT and compute with its constituent parts.

Second, think about what happens if we try to add ```GBP``` and ```USD``` values together. We don't want that to be allowed. One approach we're used to from other languages is to raise an exception. In Imandra, however, we do not have exceptions. Instead, we use a special type called the ```option``` type to help us structure possible failures. This allows our handling of exceptional cases to take place fully within the type-system, guaranteeing that we never fail to handle an exceptional case or failure.

With an option type, we have two constructors: ```Some``` and ```None```. For any type ```t```, there's an option type called ```t option``` such that the parameter of the ```Some``` constructor has type ```t```. 

Let's see what happens when we use this function:

```
# add(USD 5, USD 10);;
- : cash option = Some (USD 15)
# add(GBP 25, GBP 50);;
- : cash option = Some (GBP 75)
# add(USD 5, GBP 10);;
- : cash option = None
```

Let's verify something about this function. For instance, we may want to ensure that if we call the function with arguments of the same currency, then we'll never get ```None``` as a result. 

To express this, we just need to define the concept ```same_currency```:

```
# let same_currency (x,y) =
  match x,y with
  USD _, USD _ -> true
  | GBP _, GBP _ -> true
  | Euro _, Euro _ -> true
  | _ -> false
;;
val same_currency : cash * cash -> bool = <fun>
```

And now we can ask Imandra to prove our theorem:

```
# theorem _ (x,y) =
  same_currency(x,y) ==> add(x,y) <> None;;
thm _ = <proved>
```

ADTs can also be recursive:

```
# type foo = A of int | B of foo * foo;;
type foo = A of int | B of foo * foo
```

Let's compute with some values of this type:

```
# A 100;;
- : foo = A 100
# B (B (A 10, B (A 5, A 123)), A 999);;
- : foo = B (B (A 10, B (A 5, A 123)), A 999)
# B (A 123, A 456);;
- : foo = B (A 123, A 456)
```

Let's use Imandra to do some deeper investigations:
```
# verify _ (x,a,b) =
  x <> B (A (a+1), B (A a, A (a+2)));;

Warning: This conjecture contains free type variables.
We shall concretise them to ints for counterexample search.
You can control this by annotating the conjecture with types.

Counterexample:
  
  { x = B (A 1, B (A 0, A 2));
    a = 0;
    b = 0; }
```

Notice our use of the ```verify``` command. This command first tries to prove the given conjecture, and if that fails, it then searches for counterexamples. If a counterexample is found, its values are reflected into the CX module:
```
# CX.x;;
- : foo = B (A 1, B (A 0, A 2))
# CX.a;;
- : int = 0
# CX.b;;
- : int = 0
```

Notice that warning "This conjecture contains ...": Because the conjecture contains free type variables, these types must be `concretized' before a search for counterexamples can commence.

Why does this happen in this example? Because the ```b``` variable isn't actually used! However, we can have type variables for more interesting reasons as well.

By default, type variables are concretized to be integers during counterexample search.
However, we can override this with explicit type annotations:

```
# verify _ (x,a,b : _ * _ * foo list) =
  x <> B (A (a+1), B (A a, A (a+2)));;

Counterexample:
  { x = B (A 1, B (A 0, A 2));
    a = 0;
    b = []; }
```

Note that we could achieve the same result by using the ```instance``` command instead. We just have to negate our formula:
```
# instance _ (x,a,b : _ * _ * foo list) =
  x = B (A (a+1), B (A a, A (a+2)));;

Instance:
  { x = B (A 1, B (A 0, A 2));
    a = 0;
    b = []; }
```

Now, let's do something a bit more interesting:

```
# verify _ (x,a,b : _ * _ * foo list) =
  not(x = B (A (a+1), B (A a, A (a+2)))
    && (List.length b > 2)
    && (List.hd b = A (2*a + 1)));;

No counterexample found up to bound 1. Use :unroll to increase bound.

```

Imandra tells us that no counterexamples were found up to recursion unrolling bound 1. This is not surprising, as we have a constraint requiring the length of a list is greater than 2.

So, let's set the unrolling bound to 3 and try again:
```

# :unroll 3
unroll set to 3.
# verify _ (x,a,b : _ * _ * foo list) =
  not(x = B (A (a+1), B (A a, A (a+2)))
  && (List.length b > 2)
  && (List.hd b = A (2*a + 1)));;
  
Counterexample:
  { x = B (A 1797, B (A 1796, A 1798));
    a = 1796;
    b = [A 3593;
          A 19;
          A 20]; }
```

Again, we can compute with our counterexample:

```
# CX.x;;
- : foo = B (A 1797, B (A 1796, A 1798))
# CX.a;;
- : int = 1796
# CX.b;;
- : foo list = [A 3593; A 19; A 20]
# List.length CX.b;;
- : int = 3
# List.hd CX.b;;
- : foo = A 3593
# 2*CX.a + 1;;
- : int = 3593
```