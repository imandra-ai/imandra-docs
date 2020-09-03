---
title: "Verifying a Ripple Carry Adder"
description: "In this notebook, we'll verify a simple hardware design in Imandra, that of a full (arbitrary width) ripple-carry adder. We'll express this simple piece of hardware at the gate level. The theorem we'll prove expresses that our (arbitrary width) adder circuit is correct for all possible bit sequences."
kernel: imandra
slug: ripple-carry-adder
difficulty: advanced
---

# Verifying a Ripple-Carry Adder in Imandra

<img src="https://upload.wikimedia.org/wikipedia/commons/5/57/Fulladder.gif">

In this notebook, we'll verify a simple hardware design in Imandra, that of a full (arbitrary width) *ripple-carry adder*.

We'll express this simple piece of hardware at the *gate* level.

The correctness theorem we'll prove is as follows:

```ocaml
theorem full_ripple_carry_adder_correct a b cin =
  List.length a = List.length b ==>
  int_of_bits (ripple_carry_adder a b cin) =
  int_of_bits a + int_of_bits b + int_of_bit cin
```


This theorem expresses that our (arbitrary width) adder circuit is correct for all possible bit sequences.

# Building the circuit in Imandra

We begin by defining `xor` and our basic building blocks `adder_sum` and `adder_carry_out`.

```{.imandra .input}
let xor (x : bool) (y : bool) : bool = x <> y
```

We now define the basic sum and carry circuits for our adder.

<table border="0">
    <tr><td><img src="https://upload.wikimedia.org/wikipedia/commons/thumb/4/48/1-bit_full-adder.svg/215px-1-bit_full-adder.svg.png"></td><td>&nbsp;</td><td><img src="https://upload.wikimedia.org/wikipedia/commons/thumb/6/69/Full-adder_logic_diagram.svg/400px-Full-adder_logic_diagram.svg.png"></td></tr>
</table>

We'll define two functions: `adder_sum` and `adder_carry_out`. Notice these are purely logical (_"combinational"_), i.e., they're defined using combinations of logic gates like `xor`, `and` (`&&`), and `or` (`||`) operating on `bool` values.

```{.imandra .input}
let adder_sum a b cin =
  xor (xor a b) cin
```

```{.imandra .input}
let adder_carry_out a b cin =
  ((xor a b) && cin) || (a && b)
```

To help us understand and document how it works, we can use Imandra's `Document` machinery to produce a truth-table for our one-bit full adder circuit:

```{.imandra .input}
let args = CCList.cartesian_product [[true; false]; [true; false]; [true; false]] in
let pb b = Document.s (string_of_bool b) in
Imandra.display @@
 Document.(tbl ~headers:["a";"b";"cin";"sum";"cout"] @@
  List.map (function [a;b;cin] ->
   [pb a; pb b; pb cin; pb (adder_sum a b cin); pb (adder_carry_out a b cin)]
   | _ -> [])
   args)
```

We can now define our ripple-carry adder, for arbitrary length bitvector inputs.

```{.imandra .input}
let rec ripple_carry_adder (a : bool list) (b : bool list) (cin : bool) : bool list =
  match a, b with
  | a1 :: a', b1 :: b' ->
    adder_sum a1 b1 cin ::
    ripple_carry_adder a' b' (adder_carry_out a1 b1 cin)
  | _ -> if cin then [cin] else []
```

Let's now compute with our adder to get a feel for it.

```{.imandra .input}
let zero = []
let one = [true]
let two = [false; true]
```

```{.imandra .input}
ripple_carry_adder zero zero false
```

```{.imandra .input}
ripple_carry_adder one one false
```

```{.imandra .input}
instance (fun a b -> ripple_carry_adder a b false = [false; false; false; true])
```

# Relating bit sequences to natural numbers

Let's now define some functions to relate our bit sequences to natural numbers. These will be useful both in our computations and in our expression of our correctness criteria for the circut.

```{.imandra .input}
let int_of_bit (a : bool) : Z.t =
 if a then 1 else 0

let rec int_of_bits (a : bool list) : Z.t =
  match a with
   | [] -> 0
   | a :: a' -> int_of_bit a + 2 * (int_of_bits a')
```

Let's experiment with these a bit, to ensure we understand their endianness (among other things).

```{.imandra .input}
int_of_bits [true; false]
```

```{.imandra .input}
int_of_bits [false; true]
```

```{.imandra .input}
int_of_bits [true; true; true; true;]
```

We can of course use Imandra to obtain some interesting examples by querying for interesting inputs to our functions via `instance`:

```{.imandra .input}
instance (fun a -> int_of_bits a = 256)
```

```{.imandra .input}
int_of_bits (ripple_carry_adder CX.a CX.a false)
```

# Verifying our circuit: The adder is correct for all possible inputs

Let's now prove our main theorem, namely that `ripple_carry_adder` is correct.

We'll prove this theorem by induction following the recursive definition of `ripple_carry_adder`.

```{.imandra .input}
theorem full_ripple_carry_adder_correct a b cin =
  List.length a = List.length b ==>
  int_of_bits (ripple_carry_adder a b cin) =
  int_of_bits a + int_of_bits b + int_of_bit cin
[@@induct functional ripple_carry_adder]
```

Excellent!

Note that we were able to prove this main theorem without introducing any auxiliary lemmas.

Nevertheless, it's almost always useful to prove local lemmas about our functions.

For example, the following is a very useful property to know about our single-step adder, `adder_sum`. We'll introduce it as a `rewrite` rule so that we may use it for an alternative proof of our main theorem.

```{.imandra .input}
theorem single_adder_circuit_correct a b cin =
  int_of_bit (adder_sum a b cin)
    = int_of_bit a + int_of_bit b + int_of_bit cin - (2 * (int_of_bit (adder_carry_out a b cin)))
[@@rewrite]
```

Notice the above `Warnings`, in particular about `int_of_bit` and `adder_sum`. These are printed because we've specified Imandra to install this theorem as a `rewrite` rule, and the LHS (left-hand-side) of the rule contains non-recursive functions which will, unless they are disabled, be expanded before rewriting can be applied.

Can you see an alternative proof of our main theorem which makes use of this rule? We just need to follow the advice of the warning!

```{.imandra .input}
theorem full_ripple_carry_adder_correct a b cin =
  List.length a = List.length b ==>
  int_of_bits (ripple_carry_adder a b cin) =
  int_of_bits a + int_of_bits b + int_of_bit cin
[@@induct functional ripple_carry_adder]
[@@disable adder_sum, int_of_bit]
```

If we inspect the proof, we'll find that our rewrite rule `single_adder_circuit_correct` was used to close our key subgoal under our induction. Beautiful!

# Examining a flawed circuit with Imandra

Now that we've verified our adder, let's imagine we'd instead designed a flawed version of our circut and use Imandra to analyse it.

Can you spot the error?

```{.imandra .input}
let bad_adder_sum a b cin =
  not ((xor a b) || cin)
```

```{.imandra .input}
let bad_adder_carry_out a b cin =
  ((xor a b) && cin) || (a && b)
```

```{.imandra .input}
verify (fun a b cin ->
 int_of_bit (bad_adder_sum a b cin)
    = int_of_bit a + int_of_bit b + int_of_bit cin - (2 * (int_of_bit (bad_adder_carry_out a b cin))))
```

```{.imandra .input}
let rec bad_ripple_carry_adder (a : bool list) (b : bool list) (cin : bool) : bool list =
  match a, b with
  | a1 :: a', b1 :: b' ->
    bad_adder_sum a1 b1 cin ::
    bad_ripple_carry_adder a' b' (bad_adder_carry_out a1 b1 cin)
  | _ -> if cin then [cin] else []
```

```{.imandra .input}
instance (fun a b -> int_of_bits (bad_ripple_carry_adder a b false) <> int_of_bits a + int_of_bits b)
```

Happy verifying!
