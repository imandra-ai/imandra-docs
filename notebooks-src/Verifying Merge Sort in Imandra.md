---
title: "Verifying Merge Sort in Imandra"
description: "Merge sort is a widely used efficient general purpose sorting algorithm, and a prototypical divide and conquer algorithm. It forms the basis of standard library sorting functions in languages like OCaml, Java and Python. Let's verify it with Imandra!"
kernel: imandra
slug: verifying-merge-sort
---

# Verifying Merge Sort in Imandra

Merge sort is a widely used efficient general purpose sorting algorithm invented by [John von Neumann](https://en.wikipedia.org/wiki/John_von_Neumann) in 1945. It is a prototypical *divide and conquer* algorithm and forms the basis of standard library sorting functions in languages like OCaml, Java and Python.

Let's verify it in Imandra!

<img src="https://upload.wikimedia.org/wikipedia/commons/c/c5/Merge_sort_animation2.gif">

## The main idea

The main idea of merge sort is as follows:
 - Divide the input list into sublists
 - Sort the sublists
 - Merge the sorted sublists to obtain a sorted version of the original list

## Merging two lists

We'll start by defining a function to `merge` two lists in a "sorted" way. Note that our termination proof involves *both* arguments `l` and `m`, using a lexicographic product (via the `[@@adm l,m]` admission annotation).

```{.imandra .input}
let rec merge (l : int list) (m : int list) =
 match l, m with
  | [], _ -> m
  | _, [] -> l
  | a :: ls, b :: ms ->
    if a < b then
     a :: (merge ls m)
    else
     b :: (merge l ms)
[@@adm l, m]
```

Let's experiment a bit with `merge`.

```{.imandra .input}
merge [1;2;3] [4;5;6]
```

```{.imandra .input}
merge [1;4;5] [2;3;4]
```

```{.imandra .input}
merge [1;5;2] [2;3]
```

Observe that `merge` will merge *sorted* lists in a manner that respects their sortedness. But, if the lists given to `merge` aren't sorted, the output of `merge` need not be sorted.

# Dividing into sublists

In merge sort, we need to *divide* a list into sublists. We'll do this in a simple way using the function `odds` which computes "every other" element of a list. We'll then be able to split a list `x` into sublists by taking `odds x` and `odds (List.tl x)`.

```{.imandra .input}
let rec odds l =
 match l with
  | []  -> []
  | [x] -> [x]
  | x :: y :: rst -> x :: odds rst
```

Let's compute a bit with `odds` to better understand how it works.

```{.imandra .input}
odds [1;2;3;4;5;6]
```

```{.imandra .input}
odds (List.tl [1;2;3;4;5;6])
```

# Defining Merge Sort

We can now put the pieces together and define our main `merge_sort` function, as follows:

```{.imandra .input}
let rec merge_sort l =
 match l with
  | []  -> []
  | [_] -> l
  | _ :: ls -> merge (merge_sort (odds l)) (merge_sort (odds ls))
```

To admit `merge_sort` into Imandra, we must prove it terminating. We can do this with a custom measure function which we'll call `merge_sort_measure`. We'll prove a lemma about `odds` (by functional induction) to make it clear why the measure is decreasing in every recursive call. We'll install the lemma as a `forward_chaining` rule, which is a good strategy for making it effective during termination analysis.

```{.imandra .input}
let merge_sort_measure x =
 Ordinal.of_int (List.length x)
```

```{.imandra .input}
theorem odds_len_1 x =
 x <> [] && List.tl x <> []
 ==>
 (List.length (odds x) [@trigger]) < List.length x
[@@induct functional odds] [@@forward_chaining]
```

Now we're ready to define `merge_sort`. Imandra is able prove it terminating using our custom measure (and lemma!).

```{.imandra .input}
let rec merge_sort l =
 match l with
  | []  -> []
  | [_] -> l
  | _ :: ls -> merge (merge_sort (odds l)) (merge_sort (odds ls))
[@@measure merge_sort_measure l]
```

Let's experiment a bit with `merge_sort` to gain confidence we've defined it correctly.

```{.imandra .input}
merge_sort [1;2;3]
```

```{.imandra .input}
merge_sort [9;100;6;2;34;19;3;4;7;6]
```

This looks pretty good! Let's now use Imandra to *prove* it correct.

# Proving Merge Sort correct

What does it mean for a sorting algorithm to be correct? There are two main components:

- The result is *sorted*
- The result has *the same elements* as the original

Let's start by defining what it means for a list to be *sorted*.

```{.imandra .input}
let rec is_sorted (x : int list) =
 match x with
  | []  -> true
  | [_] -> true
  | x :: x' :: xs -> x <= x' && is_sorted (x' :: xs)
```

As usual, let's experiment a bit with this definition.

```{.imandra .input}
is_sorted [1;2;3;4;5]
```

```{.imandra .input}
is_sorted [1;4;2]
```

```{.imandra .input}
is_sorted [1]
```

```{.imandra .input}
instance (fun x -> List.length x >= 5 && is_sorted x)
```

```{.imandra .input}
instance (fun x -> List.length x >= 5 && is_sorted x && is_sorted (List.rev x))
```

## Proving Merge Sort sorts

Now that we've defined our `is_sorted` predicate, we're ready to state one of our main verification goals: that `merge_sort` sorts!

We can write this this way:

```ocaml
theorem merge_sort_sorts x =
 is_sorted (merge_sort x)
```


Before we try to prove this for all possible cases by induction, let's ask Imandra to verify that this property holds up to our current recursion unrolling bound (`100`).

```{.imandra .input}
verify (fun x -> is_sorted (merge_sort x))
```

Excellent. This gives us quite some confidence that this result is true. Let's now try to prove it by induction. We'll want to use an induction principle suggested by the definition of `merge_sort`. Let's use our usual strategy of `#max_induct 1`, so we can analyse Imandra's output to help us find needed lemmata.

Note, we could prove this theorem directly without any lemmas by using `#max_induct 3`, but it's good practice to use `#max_induct 1` and have Imandra help us develop useful collections of lemmas.

```{.imandra .input}
#max_induct 1
```

```{.imandra .input}
theorem merge_sort_sorts x =
 is_sorted (merge_sort x)
[@@induct functional merge_sort]
```

Analysing the output of this proof attempt, we notice the following components of our `Checkpoint`:

```ocaml
 H1. is_sorted gen_1
 H2. is_sorted gen_2
|---------------------------------------------------------------------------
 is_sorted (merge gen_2 gen_1)
```


Ah, of course! We need to prove a lemma that `merge` respects the sortedness of its inputs.

Let's do this by functional induction following the definition of `merge` and install it as a `rewrite` rule. 
We'll allow nested induction (`#max_induct 2`), but it's a good exercise to do this proof without it (deriving an additional lemma!).

```{.imandra .input}
#max_induct 2;;

theorem merge_sorts x y =
 is_sorted x && is_sorted y
 ==>
 is_sorted (merge x y)
[@@induct functional merge]
[@@rewrite]
```

Excellent! Now that we have that key lemma proved and available as a rewrite rule, let's return to our original goal:

```{.imandra .input}
theorem merge_sort_sorts x =
 is_sorted (merge_sort x)
[@@induct functional merge_sort]
```

Beautiful! So now we've proved half of our specification: `merge_sort` sorts!

# Merge Sort contains the right elements

Let's now turn to the second half of our correctness criterion: That `merge_sort x` contains "the same" elements as `x`.

What does this mean, and why does it matter?

## An incorrect sorting function

Consider the sorting function `bad_sort` defined as `bad_sort x = []`.

Clearly, we could prove `theorem bad_sort_sorts x = is_sorted (bad_sort x)`, even though we'd never want to use `bad_sort` as a sorting function in practice.

That is, computing a sorted list is only one piece of the puzzle. We must also verify that `merge_sort x` contains exactly the same elements as `x`, including their [multiplicity](https://en.wikipedia.org/wiki/Multiplicity_(mathematics)).

## Multiset equivalence

How can we express this concept? We'll use the notion of a [multiset](https://en.wikipedia.org/wiki/Multiset) and count the number of occurrences of each element of `x`, and make sure these are respected by `merge_sort`.

We'll begin by defining a function `num_occurs x y` which counts the number of times an element `x` appears in the list `y`.

```{.imandra .input}
let rec num_occurs x y =
 match y with
  | [] -> 0
  | hd :: tl when hd = x ->
    1 + num_occurs x tl
  | _ :: tl ->
    num_occurs x tl
```

Anticipating the need to reason about the interplay of `num_occurs` and `merge`, let's prove the following nice lemmas characterising their relationship (applying the `max_induct 1` strategy to find these lemmas as above is a great exercise).

```{.imandra .input}
theorem num_occur_merge a x y =
 num_occurs a (merge x y) = num_occurs a x + num_occurs a y
[@@induct functional merge]
[@@rewrite]
```

```{.imandra .input}
theorem num_occurs_arith (x : int list) (a : int) =
  x <> [] && List.tl x <> []
  ==>
  num_occurs a (odds (List.tl x))
  =
  num_occurs a x - num_occurs a (odds x)
  [@@induct functional num_occurs]
  [@@rewrite]
```

Finally, let's put the pieces together and prove our main remaining theorem.

And now, our second main theorem at last:

```{.imandra .input}
theorem merge_sort_elements a (x : int list) =
 num_occurs a x = num_occurs a (merge_sort x)
[@@induct functional merge_sort]
```

So now we're sure `merge_sort` really is a proper sorting function.

# Merge Sort is Correct!

To recap, we've proved:

```ocaml
theorem merge_sort_sorts x =
 is_sorted (merge_sort x)
```


and

```ocaml
theorem merge_sort_elements a (x : int list) =
 num_occurs a x = num_occurs a (merge_sort x)
```


Beautiful! Happy proving (and sorting)!
