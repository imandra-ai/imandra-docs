---
title: "Imandra Diaries #0"
description: "Imandra Diaries #0"
kernel: imandra
slug: imandra-diaries-0
---

# Imandra Diaries #0

Let’s try to verify a property of list concatenation: concatenating a list `lst` with itself returns `lst` itself if and only if `lst` is the empty list.

This seems quite an obvious property, but proving it formally is not trivial, thankfully, Imandra can help us prove this without too much effort.

Let’s first encode this property as a computable Boolean function:

```{.imandra .input}
let append_self_property_1 lst =
  if lst @ lst = lst then
    lst = []
  else
    lst <> []
```

An equivalent definition, formulated in a more “logical” style, looks like:

```{.imandra .input}
let append_self_property_2 lst =
  lst @ lst = lst <==> lst = []
```

We can quickly verify that the two functions are indeed equivalent using Imandra:

```{.imandra .input}
verify (fun x -> append_self_property_1 x = append_self_property_2 x);;
```

Ok, we’ve seen that the two definitions are equivalent, let’s focus now on attempting to prove the property (we’ll use the second definition but either would work just the same), before attempting to prove that this function holds (returns true) for all the possible lists given as input, let’s do a soft check by computing with a couple of trivial base cases:

```{.imandra .input}
append_self_property_2 [];;
append_self_property_2 [1];;
```

After executing a couple of unit tests this gives us a tiny bit of confidence that the `append_self_property` might indeed be encoding a true property, let’s bring Imandra’s theorem proving capabilities into play and let’s attempt to formally prove this.

```{.imandra .input}
verify (fun lst -> append_self_property_2 lst);;
```

Imandra has tried to prove this property using a form of bounded model checking, which seems to not be enough to completely prove this particular property, but it has given us even more confidence that we’re on the right track with this property.

You might now be wondering what makes `append_self_property` unsuited for Imandra’s bounded model checking, and the reason is simple: `List.append` is a recursive function and as such, it requires more advanced techniques for verifying generic properties about itself. Luckily for us, Imandra has support for very complex inductive proofs. Let’s attempt to use that.

```{.imandra .input}
#max_induct 1;;

verify (fun lst -> append_self_property_2 lst) [@@induct];;
```

Hmm, Imandra wasn’t able to completely prove this theorem using induction and the default set of lemmas and theorems at its disposal, but it made very good progress towards a complete proof and it gave us some good hints on what it needs some help with.

We can see that it proved `Subgoal 1.2` which is the half of our property that express `lst @ lst = lst <== lst = []`,  but it failed along the way trying to prove `Subgoal 1.1`, which is the remaining half of our property, expressing: `lst @ lst = lst ==> lst = []`

Looking at the checkpoint Imandra stopped at, we can see it was trying to prove a goal with of the form `x@(y::x)=x ==> ..`, clearly the premise can never be satisfied, so if we can make Imandra realise that that hypothesis is false, it will be able to prove the subgoal given that `false ==> x` is a tautology:

```{.imandra .input}
verify (fun x -> false ==> x);;
```

Let's attempt to prove the negation of that hypthesis (we'll reach for induction directly):
```{.imandra .input}
verify (fun x y -> not (x@(y::x)=x)) [@@induct];;
```

Hmm.. that didn't work like we hoped it would, looking at the penultimate subgoal Imandra produced before giving up, we can see that Imandra was trying to prove a more "specific" version of our original theorem, with just an extra level of consing, so trying to prove this subgoal would likely only lead us to try to prove more and more specialised versions of it.

Let's step back a bit and look at this lemma we're trying to prove: if we give it a bit of thought we can see that `(y::x)` is not really useful, and is just expressing an implicit property of it not being an empty list. So let's replace `(y::x)` with a generic non empty list `z` and let's try again:

```{.imandra .input}
verify (fun x z -> z <> [] ==> not (x@z=x)) [@@induct];;
```

Awesome, it looks like Imandra was able to prove this more general version of our original subgoal, let's now turn this into a rewrite rule so that Imandra will be able to use this equivalence while trying to prove `append_self_property_2`:

```{.imandra .input}
lemma append_nonempty_not_identity x z =
  z <> [] ==> not (x@z=x)
[@@auto] [@@rw]
```

Now that we've registered this lemma as a rewrite rule, let's attept to prove our original theorem:

```{.imandra .input}
verify (fun lst -> append_self_property_2 lst) [@@induct];;
```

Yes! That lemma was all Imandra needed to know in order to prove our theorem.

Now let's step back even further and let's look at our original theorem. We can quickly realize that  `append_nonempty_not_identity` is itself in fact an instance of a more general property: concatenating a list `x` with a list `y` will result in `x` itself if and only if `y` is the empty list.

In IML this property looks like:
```{.imandra .input}
let append_self_id lst1 lst2 =
  (lst1@lst2=lst1) <==> (lst2=[])
```

Let's try to prove this via induction:
```{.imandra .input}
verify (fun lst1 lst2 -> append_self_id lst1 lst2) [@@induct];;
```

Wow, that was a much simpler proof than that of our specialised instance, let's make it a theorem and register it as a rewrite rule

```{.imandra .input}
theorem append_self_id lst1 lst2 =
  (lst1@lst2=lst1) <==> (lst2=[])
[@@induct]
[@@rw]
```

If we try to verify `append_self_property_2` now we'll see we don't even need to use induction, the above rewrite rule is enough for Imandra to simplify the entire goal to `true`:

```{.imandra .input}
verify (fun lst -> append_self_property_2 lst) [@@simp];;
```

This exercise taught us a number of important things:

1- There's more than one way to prove a property!

2- When using induction, often times trying to prove the most general version of a goal possible will result in much easier proofs

3- When we get stuck on a proof, inspecting the checkpoints Imandra suggests us and the Subgoals it gave up on, can lead to useful lemmas that will lead to completing the proof
