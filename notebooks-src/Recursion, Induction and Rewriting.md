---
title: "Recursion, Induction and Rewriting"
description: "In this notebook, we're going to use Imandra to prove some interesting properties of functional programs. We'll learn a bit about induction, lemmas and rewrite rules along the way."
kernel: imandra
slug: 'recursion-induction-and-rewriting'
key-phrases:
  - recursion
  - induction
  - rewriting
  - rewrite rules
difficulty: advanced
expected-error-report: { "errors": 3, "exceptions": 0 }
---

# Recursion, Induction and Rewriting

In this notebook, we're going to use Imandra to prove some interesting properties of functional programs. We'll learn a bit about _induction_, _lemmas_ and _rewrite rules_ along the way.

Let's start by defining our own `append` function on lists. It should take two lists as input, and compute the result of appending (concatenating) the elements of the first list with those of the second list.

_Note: Imandra contains a `List` module with predefined functions like `List.append` (i.e., `(@)`), `List.rev`, etc. However, we define our own versions of these functions by hand in this notebook so that all definitions and proofs are illustrated from scratch._

```{.imandra .input}
let rec append x y =
 match x with
  | [] -> y
  | x :: xs -> x :: append xs y
```

Let's compute a bit with this function to understand how it works.

```{.imandra .input}
append [1;2;3] [4;5;6]
```

```{.imandra .input}
append [] [4;5;6]
```

```{.imandra .input}
append [1;2;3] []
```

We can ask Imandra some questions about `append`. For example, do there exist lists `x` and `y` such that `append x y = [1;2;3;4;5;6;7;8]`?

```{.imandra .input}
verify (fun x y -> append x y <> [1;2;3;4;5;6;7;8])
```

Ah, of course! What if we make the problem a little harder -- perhaps we want `x` and `y` to be the same length:

```{.imandra .input}
verify (fun x y -> List.length x = List.length y ==> append x y <> [1;2;3;4;5;6;7;8])
```

Nice! Remember that counterexamples are always reflected into the runtime in a module called `CX`. So, we can compute with this counterexample and see that it indeed refutes our conjecture:

```{.imandra .input}
append CX.x CX.y
```

Let's now investigate a more interesting conjecture: That `append` is _associative_.

That is,

 `(forall (x,y,z) : 'a list. append x (append y z) = append (append x y) z)`.

 Is this property true? Let's ask Imandra.

```{.imandra .input}
verify (fun x y z -> append x (append y z) = append (append x y) z)
```

Imandra tells us that there are no counterexamples to this conjecture up to our current recursion unrolling bound (`100`).

This gives us some confidence that this conjecture is true. Let's now ask Imandra to prove it for all possible cases by induction.

```{.imandra .input}
verify (fun x y z -> append x (append y z) = append (append x y) z) [@@induct]
```

Beautiful! So, we see Imandra proved our goal by induction on `x`, using a structural induction principle derived from the `'a list` datatype. We now know the property holds for all possible inputs (of which there are infinitely many!).

By the way, we can always view Imandra's current session configuration with the `#config` directive:

```{.imandra .input}
#config
```

# Lemmas and Rules

When we use the `verify` command, we give it a closed formula (e.g., a lambda term such as `(fun x y z -> foo x y z)` and ask Imandra to prove that the goal always evaluates to `true`. Notice that the `verify` command does not give the verification goal a _name_.

Once we've proved a goal, we often want to record it as a `theorem`. This is both to document our verification progress and to make it possible for our proved goal to be used as a _lemma_ in subsequent verification efforts.

This can be done by the `theorem` command.

For example, we could name our result `assoc_append` and install it as a theorem as follows:

```ocaml
theorem assoc_append x y z = append x (append y z) = append (append x y) z) [@@induct]
```


By default, a `theorem` is not installed as a _rule_ that will be used automatically in subsequent verification efforts. To install the `theorem` as a rule, we can use the `[@@rewrite]` or `[@@forward_chaining]` attributes.

Let's focus in this notebook on the use of theorems as _rewrite rules_.

## Rewrite Rules

A rewrite rule is a theorem of the form `(H1 && ... && Hk ==> LHS = RHS)`. It instructs Imandra's simplifier to replace terms it matches with the `LHS` with the suitably instantiated `RHS`, provided that the corresponding instantiations of the hypotheses `H1, ..., Hk` can be proved.

It is also allowed for the conclusion of the rule to be a boolean term, e.g., `(H1 && ... && Hk ==> foo)` is interpreted with an `RHS` of `true`, i.e., `(H1 && ... && Hk ==> foo = true)`.

Good rewrite rules can have a powerful normalising effect on formulas. We usually want to orient them so that the `RHS` is a _better_ (i.e., _simpler_ or _more canonical_) term than the `LHS`.

Let us see the use of rewrite rules through a prove about the function `reverse`.

## Reverse

Let's define a function to reverse a list. Note how it uses our `append` function we defined above:

```{.imandra .input}
let rec reverse x =
 match x with
  | [] -> []
  | x :: xs -> append (reverse xs) [x]
```

Let's compute with `reverse` to help gain confidence we defined it correctly.

```{.imandra .input}
reverse [1;2;3;4;5]
```

Let's ask Imandra, are there any lists that are their own reverse?

```{.imandra .input}
instance (fun x -> reverse x = x)
```

Ah! Of course, the empty list is its own reverse. What about longer lists, such as those of length 5?

Note that here we use the keyword `instance`, which tries to find values that _satisfy_ the given property, instead of trying to prove the property.

```{.imandra .input}
instance (fun x -> List.length x >= 5 && reverse x = x)
```

Ah! Of course, palindromes! This counterexample is also interesting because, in addition to giving us a concrete value `CX.x`, this counterexample also involves the synthesis of an algebraic datatype. This is because our goal was _polymorphic_. If we want, for example, an `int list` counterexample, we can simply annotate our goal with types:

```{.imandra .input}
instance (fun (x : int list) -> List.length x >= 5 && reverse x = x)
```

Excellent! And we can of course compute with our counterexample:

```{.imandra .input}
reverse CX.x
```

```{.imandra .input}
reverse CX.x = CX.x
```

# Reverse of Reverse is the Identity

Now that we've defined our `reverse` function and experimented a bit with it, let's try to prove an interesting theorem. Let's prove that

 `(forall x, (reverse (reverse x)) = x)`.

 That is, if we take an arbitrary list `x` and we reverse it twice, we always get our original `x` back unscathed.

 As usual, let's start by asking Imandra to `verify` this via bounded checking (a.k.a. _recursive unrolling_).

```{.imandra .input}
verify (fun x -> reverse (reverse x) = x)
```

Imandra tells us that there are no counterexamples up to our current unrolling bound (`100`).

So, our conjecture seems like a good candidate for proof by induction.

```{.imandra .input}
verify (fun x -> reverse (reverse x) = x) [@@induct]
```

Success!

Imandra proves this fact automatically, and its inductive proof actually involves a nested subinduction.

Imandra has powerful techniques for automating complex inductions, involving simplification, destructor elimination, generalisation and more. But it's often the case that nested inductions actually suggest _lemmas_ that could be of general use.

To illustrate this, let's take a look at one of the interesting subgoals in our proof:

```ocaml
reverse (append gen_1 (x1 :: [])) = x1 :: (reverse gen_1)
```


This looks like a very nice fact. Instead of Imandra having to derive this fact as a subinduction, let's prove it as a `theorem` itself and install it as a rewrite rule. Then we will be able to apply it later and shorten our subsequent proofs.

```{.imandra .input}
theorem rev_app_single x y = reverse (append x [y]) = y :: (reverse x) [@@induct] [@@rewrite]
```

Now, if we were to try to prove our original `reverse (reverse x)` goal again, we'd get a shorter proof that makes use of our new lemma:

```{.imandra .input}
verify (fun x -> reverse (reverse x) = x) [@@induct]
```

Excellent!

## Reverse Append

Now, let's try to prove another interesting conjecture about our functions `append` and `reverse`:

 `reverse (append x y) = append (reverse y) (reverse x)`

 Actually, first let's pretend we made a mistake in formulating this conjecture, and accidentally swapped the `x` and `y` on the RHS (Right Hand Side) of the equality. Let's constrain the types of lists involved to make the counterexample especially easy to read:

```{.imandra .input}
verify (fun (x : int list) y -> reverse (append x y) = append (reverse x) (reverse y))
```

Ah! Let's do it right this time:

```{.imandra .input}
verify (fun (x : int list) y -> reverse (append x y) = append (reverse y) (reverse x))
```

Our conjecture has passed through to depth 100 recursive unrolling, so we feel pretty confident it is true. Let's try to prove it by induction:

```{.imandra .input}
verify (fun x y -> reverse (append x y) = append (reverse y) (reverse x)) [@@induct]
```

Success! And in a proof with _three_ inductions! If we inspect the proof, we'll see that those subsequent inductions actually suggest some very useful lemmas.

In fact, this phenomenon of goals proved by subinductions suggesting useful lemmas happens so often, that we commonly like to work with a very low `#max_induct` value. Let's attempt the same proof as above, but instruct Imandra to only perform inductions of depth 1 (i.e., no subinductions allowed):

```{.imandra .input}
#max_induct 1
```

```{.imandra .input}
verify (fun x y -> reverse (append x y) = append (reverse y) (reverse x)) [@@induct]
```

We see above that Imandra is unable to prove our theorem with `#max_induct` set to `1`. However, by inspecting the subgoal Imandra was working on before it hit its `#max_induct` limit (nicely presented to us as a `Checkpoint` at the end of the proof attempt), we can find a useful lemma we should prove!

In particular, note this checkpoint:

`gen_1 = append gen_1 []`

This, oriented as `append gen_1 [] = gen_1` is a great rule. Note that it really does require induction, as `append` recurses on its first argument, not its second.

Let's ask Imandra to prove this as a `theorem` and to install it as a rewrite rule:

```{.imandra .input}
theorem append_nil x = append x [] = x [@@induct] [@@rewrite]
```

Success! Now, let's return to our main goal and see if we progress any further (still with `#max_induct 1`) now that we have `append_nil` available as a rewrite rule:

```{.imandra .input}
verify (fun x y -> reverse (append x y) = append (reverse y) (reverse x)) [@@induct]
```

Yes! If we inspect Imandra's aborted proof, we see that our rewrite rule `append_nil` was applied exactly where we wanted it, and we now see another interesting subgoal which looks quite familiar:

```ocaml
append (append gen_1 gen_2) (x1 :: []) = append gen_1 (append gen_2 (x1 :: []))
```


That is, Imandra has derived, as a subgoal to be proved, an instance of the associativity of `append`!

If we set our `#max_induct` to `2`, then Imandra would finish this proof automatically.

But, this fact about append seems very useful and of general purpose, so let's prove it as a rewrite rule and make it available to our subsequent proof efforts.

```{.imandra .input}
theorem assoc_append x y z = append x (append y z) = append (append x y) z [@@induct] [@@rewrite]
```

Success! Now, let's go back to our original goal and see if we can prove it with the help of our proved rules (still with `max_induct 1`):

```{.imandra .input}
verify (fun x y -> reverse (append x y) = append (reverse y) (reverse x)) [@@induct]
```

Success! And our rewrite rules were used exactly where we'd hoped.

Happy proving!
