---
title: "Imandra Python API library"
description: "Imandra Python API library"
kernel: imandra
slug: python-api
---

# Imandra Python API client library

[Imandra](https://www.imandra.ai) is a cloud-native automated reasoning engine for analysis of algorithms and data.  

This notebook illustrates the use of `imandra` python library for interacting with cloud-hosted  Imandra Core instances. 

For more details on developing Imandra models, you may also want to see the [main Imandra docs site](https://docs.imandra.ai/imandra-docs/), and consider setting up Imandra Core locally by following the installation instructions there.

## Authentication

This is the first step to start using Imandra via APIs. Our cloud environment requires a user account, which you may setup like this:

```
$ ./my/venv/bin/imandra-cli auth login
```

and follow the prompts to authenticate. This will create the relevant credentials in `~/.imandra` (or `%APPDATA%\imandra` on Windows).

You should now be able to invoke CLI commands that require authentication, and construct an `auth` object from python code:

```
    import imandra.auth
    auth = imandra.auth.Auth()
```

This auth object can then be passed to library functions which make requests to Imandra's web APIs.


# Starting an Imandra session

The `imandra.session` class provides an easy-to-use interface for requesting and managing an instance of Imandra Core within our cloud environment. It has built-in use of `auth` class described above. The `imandra.session` can be used as a context manager in Python:


```
import imandra
```


```
with imandra.session() as s:
    verify_result = s.verify("fun x -> x * x = 0 ")
print("\n", verify_result)
```

```
Instance created:
- url: https://core-europe-west1.imandra.ai/imandra-http-api/http/31b7acb6-ed86-4204-bd6f-75a9c05d9909
- token: 8805d2e6-8fc7-49d1-a5b5-26d639755bb8
Instance killed

 Refuted, with counterexample:
let x : int = (Z.of_nativeint (-1n))
```

When used as a context manager it initiates a pod specifically for the time within the `with` context. Once the operations within the `with` block are completed, the pod is automatically terminated and its resources are recycled.

This could be limiting, especially within the Jupyter notebook environment. Alternatively one can instantiate the `imandra.session` class directly.In this case, the session remains persistent across the Jupyter cells. However, it is crucial not to forget to free the pod resources once the execution is completed by calling the `session.close()` method at the final section of the notebook.


```
session = imandra.session()
```

```
Instance created:
- url: https://core-europe-west1.imandra.ai/imandra-http-api/http/84d5880f-0bae-4f57-be09-101ee25a4c11
- token: 8680adcd-6af4-4963-8f34-477736dd2568
```

## Running OCaml/ImandraML code

The `eval` method of the `session` instance serves as the bridge between your Python environment and the Imandra REPL. By invoking this method, you can evaluate code within the Imandra environment.

```
session.eval('let f x = if x > 42 then 0 else 2 * x + 1')
```

```
EvalResponse(success=True, stdout='', stderr='')
```

Any errors (syntax, typecheking, e.t.c.) in the evaulated code will ber reported and the evaluation fails:

```
result = session.eval('let x = "test" + 0')
print(result.error)
```

```
Error:
  Type error (typecore):
    File "<user input>", line 1, characters 8-14:
    Error: This expression has type string
           but an expression was expected of type Z.t
  At <user input>:1,8--14
  1 | let x = "test" + 0
              ^^^^^^
```      


The REPL environment stays persistent as long as the session remains unclosed - any declared variables or functions are staying in the context. 
Here we define a function `g` that uses `f` defined above.


```
session.eval('let g x = if x > 5 then f (x + 3) else 3 * x')
```

```
EvalResponse(success=True, stdout='', stderr='')
```


The `session.get_history()` method allows you to retrieve what functions and theorems have been defined in the current session context.


```
print(session.get_history())
```

```
## All events in session
0. Fun: f
1. Fun: g
```

The `session.reset()` method resets the Imandra REPL internal state, wiping all the previous variables and functions.


```
session.reset()
print(session.get_history())
```

```
No events in session
```

## Proving statements and getting counterexamples 

The `session.verify(src)` method takes a function representing a goal and attempts to prove it.


```
result = session.verify('fun x -> x + 1 > x')
print(result)
```

```
Proved
```

If the proof attempt fails, Imandra will try to synthesize a concrete counterexample illustrating the failure


```
result = session.verify('fun n -> succ n <> 100')
print(result)
```

```
Refuted, with counterexample:
let n : int = (Z.of_nativeint (99n))
```

## Finding instances

A `session.instance(src)` takes a function representing a goal and attempts to synthesize an instance (i.e., a concrete value) that satisfies it.


```
result = session.instance('fun x y -> x < 0 && x + y = 4')
print(result)
```

```
Instance found:
let x : int = (Z.of_nativeint (-1n))
let y : int = (Z.of_nativeint (5n))
```

If the constraints are found to be unsatisfiable, the result is not


```
result = session.instance('fun x -> x * x < 0')
print(result)
```

```
Unsatisfiable
```

It the recursion depth needed to find an instance exceeds the unrolling, Imandra could only check this property up to that bound.


```
session.eval("let rec fib x = if x <= 0 then 1 else fib (x - 1)")
result = session.instance("fun x -> x < 101 ==> fib x <> 1")
print(result)
```

```
Unknown: Verified up to bound 100
```

This goal is in fact a property that is better suited for verification by induction. We might try adding the `auto` hint to the above goal to invoke the Imandra's inductive waterfall and prove it.


```
result = session.instance("fun x -> x < 101 ==> fib x <> 1", hints={"method": {"type": "auto"}})
print(result)
```

```
Instance found:
let x : int = (Z.of_nativeint (0n))
```

## Region decomposition

The term Region Decomposition refers to a (geometrically inspired) "slicing" of an algorithm’s state-space into distinct regions where the behavior of the algorithm is invariant, i.e., where it behaves "the same." Each "slice" or region of the state-space describes a family of inputs and the output of the algorithm upon them, both of which may be symbolic and represent (potentially infinitely) many concrete instances.

The `session.decompose(...)` method allows you to run perform the Region Decomposition given the function name:


```
session.eval("let f x = if x > 0 then if x * x < 0 then x else x + 1 else x")
decomposition = session.decompose("f")

for n, region in enumerate(decomposition.regions):
    print("-"*10 + " Region", n, "-"*10 + "\nConstraints")
    for c in region.constraints_pp:
        print("  ", c)
    print("Invariant:", "\n  ", region.invariant_pp) 
```

```
---------- Region 0 ----------
Constraints
   (x * x) >= 0
   x > 0
Invariant: 
   x + 1
---------- Region 1 ----------
Constraints
   x <= 0
Invariant: 
   x
```

# Closing the Imandra session

Always ensure to close the session after use.


```
session.close()
```

```
Instance killed
```
