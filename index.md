---
title: "A brief introduction"
excerpt: ""
layout: page
---
## Welcome to the online Imandra documentation!

Imandra is both a programming language and a reasoning engine with which you can analyse and verify properties of your programs.

As a programming language, Imandra is a subset of the functional language OCaml.
We call this subset of OCaml "IML" or "ImandraML" (for "Imandra Modelling Language").

With Imandra, you write your code and verification goals in the same language, and pursue programming and reasoning together.

Before starting to use Imandra, it may be helpful to familiarise yourself with the basics of OCaml.
There are many great resources and books for doing so.
Here's a good place to start:
[block:embed]
{
"html": false,
"url": "http://ocaml.org/learn/",
"title": "Learn - OCaml",
"favicon": "http://ocaml.org/img/favicon32x32.ico",
"image": "http://ocaml.org/img/real-world-ocaml.jpg"
}
[/block]

[block:api-header]
{
"type": "basic",
"title": "First steps"
}
[/block]
As a first example, let's define a simple arithmetic function and analyse it with Imandra:
[block:code]
{
"codes": [
{
"code": "let f (x) = x + 1;;",
"language": "scala",
"name": "Imandra"
}
]
}
[/block]
When we submit this function definition to Imandra, it responds with a message telling us the function's type:
[block:code]
{
"codes": [
{
"code": "# let f x = x + 1;;\nval f : int -> int = <fun>",
"language": "scala",
"name": "Imandra"
}
]
}
[/block]
This means that our function ```f``` maps integers to integers.

We can compute with this function:
[block:code]
{
"codes": [
{
"code": "# f 0;;\n- : int = 1\n# f 10;;\n- : int = 11\n# f 20;;\n- : int = 21\n# f 99;;\n- : int = 100",
"language": "text",
"name": "Imandra"
}
]
}
[/block]
And we can also ask Imandra questions about this function. For example, is there any instance of this function in which its result will be ```1000```?
[block:code]
{
"codes": [
{
"code": "# instance _ x =\n   f x = 1000;;\n\nInstance:\n\n  { x = 999; }",
"language": "scala",
"name": "Imandra"
}
]
}
[/block]
Imandra tells us that yes, this can happen, when ```x = 999```. Whenever Imandra finds an instance like this, it will reflect the values of the variables in the instance into a module (i.e., a name space) called ```CX```. So, we can compute directly with this found value by using, in this case, ```CX.x```:
[block:code]
{
"codes": [
{
"code": "# CX.x;;\n- : int = 999\n# f (CX.x);;\n- : int = 1000",
"language": "scala",
"name": "Imandra"
}
]
}
[/block]
Finally, we may also want to prove theorems about this function. Here's a simple one:
[block:code]
{
"codes": [
{
"code": "# theorem _ x =\n   f x > x;;\nthm _ = <proved>",
"language": "scala",
"name": "Imandra"
}
]
}
[/block]
In Imandra, all variables in logical formulas are implicitly universally quantified. So, we've just proven the mathematical statement "for all integers ```x```, it is always the case that ```f(x) > x```."

Let's now see what happens if we try to prove something that's false:
[block:code]
{
"codes": [
{
"code": "# theorem _ x = f x = f (x+1);;\n[x] _: proof attempt failed.",
"language": "scala",
"name": "Imandra"
}
]
}
[/block]
Imandra tells us that its proof attempt failed. When Imandra proves (or tries to prove) a theorem, it typically works by reducing a statement to a sequence of subgoals that are easier to prove. When it fails to complete a proof, we can ask Imandra to show us the subgoals it computed for our problem:
[block:code]
{
"codes": [
{
"code": "# :s\n1 subgoal:\n\n x : int\n|--------------------------------------------------------------------------\n false",
"language": "scala",
"name": "Imandra"
}
]
}
[/block]
In this case, we see that Imandra reduced our original conjecture to a clearly false subgoal. In a subgoal, the constraints above the bar are the hypotheses, and the statement below the bar is the conclusion. Thus, this subgoal is "for all integers ```x```, false is true," which is clearly false. No wonder Imandra's proof attempt failed!

Let's ask Imandra to compute a counterexample for us. We do this with the ```check``` command:
[block:code]
{
"codes": [
{
"code": "# check _ x = f x = f (x+1);;\n\nCounterexample:\n\n  { x = 0; }",
"language": "scala",
"name": "Imandra"
}
]
}
[/block]
So, clearly the universally quantified conjecture is false. But we might wonder if there exists any integers ```x``` such that ```f(x) = f(x+1)```. We can use the ```instance``` command again to see:
[block:code]
{
"codes": [
{
"code": "# instance _ x = f x = f(x+1);;\nNo such instance exists.",
"language": "scala",
"name": "Imandra"
}
]
}
[/block]
Thus, every integer is a counterexample to this conjecture.

Subgoals can also help us to understand "why" something isn't true. For example, if we try to prove the following false goal:
[block:code]
{
"codes": [
{
"code": "No such instance exists.\n# theorem _ (x,y) =\n   f(x) = f(y);;\n[x] _: proof attempt failed.",
"language": "scala",
"name": "Imandra"
}
]
}
[/block]
And inspect the subgoals:
[block:code]
{
"codes": [
{
"code": "# :s\n1 subgoal:\n\n x : int\n y : int\n|--------------------------------------------------------------------------\n x = y\n",
"language": "scala",
"name": "Imandra"
}
]
}
[/block]
We see immediately why the goal is false. For it to be true, it would have to be the case that all integers ```x``` and ```y``` are equal to each other. But of course this is not the case.

This concludes our first example. Happy proving!

