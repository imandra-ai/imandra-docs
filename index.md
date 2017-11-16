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

[![OCaml](https://ocaml.org/img/real-world-ocaml.jpg)](http://ocaml.org/learn)

### First steps


As a first example, let's define a simple arithmetic function and analyse it with Imandra:
{% highlight ocaml %}
#let f (x) = x + 1;;
{% endhighlight %}
When we submit this function definition to Imandra, it responds with a message telling us the function's type:
{% highlight ocaml %}
# let f x = x + 1;;
val f : int -> int = <fun>
{% endhighlight %}
This means that our function ```f``` maps integers to integers.

We can compute with this function:
{% highlight ocaml %}
# f 0;;
- : int = 1
# f 10;;
- : int = 11
# f 20;;
- : int = 21
# f 99;;
- : int = 100
{% endhighlight %}
And we can also ask Imandra questions about this function. For example, is there any instance of this function in which its result will be ```1000```?
{% highlight ocaml %}
# instance _ x =
   f x = 1000;;
Instance:
  { x = 999; }
{% endhighlight %}
Imandra tells us that yes, this can happen, when ```x = 999```. Whenever Imandra finds an instance like this, it will reflect the values of the variables in the instance into a module (i.e., a name space) called ```CX```. So, we can compute directly with this found value by using, in this case, ```CX.x```:
{% highlight ocaml %}
# CX.x;;
- : int = 999
# f (CX.x);;
- : int = 1000
{% endhighlight %}
Finally, we may also want to prove theorems about this function. Here's a simple one:
{% highlight ocaml %}
# theorem _ x =
   f x > x;;
thm _ = <proved>
{% endhighlight %}
In Imandra, all variables in logical formulas are implicitly universally quantified. So, we've just proven the mathematical statement "for all integers ```x```, it is always the case that ```f(x) > x```."

Let's now see what happens if we try to prove something that's false:
{% highlight ocaml %}
# theorem _ x = f x = f (x+1);;
[x] _: proof attempt failed.
{% endhighlight %}
Imandra tells us that its proof attempt failed. When Imandra proves (or tries to prove) a theorem, it typically works by reducing a statement to a sequence of subgoals that are easier to prove. When it fails to complete a proof, we can ask Imandra to show us the subgoals it computed for our problem:
{% highlight ocaml %}
# :s
1 subgoal:
 x : int
 |--------------------------------------------------------------------------
 false
{% endhighlight %}
In this case, we see that Imandra reduced our original conjecture to a clearly false subgoal. In a subgoal, the constraints above the bar are the hypotheses, and the statement below the bar is the conclusion. Thus, this subgoal is "for all integers ```x```, false is true," which is clearly false. No wonder Imandra's proof attempt failed!

Let's ask Imandra to compute a counterexample for us. We do this with the ```check``` command:
{% highlight ocaml %}
# check _ x = f x = f (x+1);;

Counterexample:
  { x = 0; }
{% endhighlight %}
So, clearly the universally quantified conjecture is false. But we might wonder if there exists any integers ```x``` such that ```f(x) = f(x+1)```. We can use the ```instance``` command again to see:
{% highlight ocaml %}
# instance _ x = f x = f(x+1);;
No such instance exists.
{% endhighlight %}
Thus, every integer is a counterexample to this conjecture.

Subgoals can also help us to understand "why" something isn't true. For example, if we try to prove the following false goal:
{% highlight ocaml %}
No such instance exists.
# theorem _ (x,y) =
   f(x) = f(y);;
   [x] _: proof attempt failed.
{% endhighlight %}
And inspect the subgoals:
{% highlight ocaml %}
# :s
1 subgoal:
 x : int
 y : int
|--------------------------------------------------------------------------
 x = y
{% endhighlight %}
We see immediately why the goal is false. For it to be true, it would have to be the case that all integers ```x``` and ```y``` are equal to each other. But of course this is not the case.

This concludes our first example. Happy proving!

