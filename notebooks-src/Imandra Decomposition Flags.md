---
title: "Region Decomposition"
description: "In this notebook we’re going to describe Imandra's Region Decomposition, with concrete examples."
kernel: imandra
slug: decomposition-flags
key-phrases:
  - decompose
  - side-condition
  - target function
  - uninterpreted function
  - state space enumeration
  - region of behaviour
---

# Region Decomposition

The term Region Decomposition refers to a ([geometrically inspired](https://en.wikipedia.org/wiki/Cylindrical_algebraic_decomposition)) "slicing" of an algorithm’s state-space into distinct regions where the behavior of the algorithm is invariant, i.e., where it behaves "the same."

Each "slice" or region of the state-space describes a family of inputs and the output of the algorithm upon them, both of which may be symbolic and represent (potentially infinitely) many concrete instances.

The entrypoint to decomposition is the `Decompose.top` function, here's a quick basic example of how it can be used:

```{.imandra .input}
let f x =
  if x > 0 then
    1
  else
    -1
;;

Decompose.top "f"
```

Imandra decomposed the function "f" into 2 regions: the first region tells us that whenever the input argument `x` is less than or equal to 0, then the value returned by the function will be `-1`, the second region tells us that whenever `x` is positive, the output will be 1.

When using Region Decomposition from a REPL instead of from the jupyter notebook, we recommend installing the vornoi printer (producing the above diagram) via `#install_printer Imandra_voronoi.Voronoi.print;;`

In the rest of this article we'll go over various important flags and arguments accepted by Imandra's `Decompose.top` entrypoint into its Principal Region Decomposition machinery. As much as possible, we'll use concrete examples to clarify their behaviour.

- [Assuming](#Assuming)
- [Compound](#Compound)
- [Reduce symmetry](#Reduce-symmetry)
- [Ctx asm simp](#Ctx_asm_simp)
- [Max ctx simp](#Max_ctx_simp)
- [Basis](#Basis)
- [Interpret basis](#Interpret-basis)
- [Aggressive rec](#Aggressive-Recursion)

# Assuming

The `~assuming` flag is used to add extra axioms as a side-condition to the decomposition of target function. This usually has the effect that regions that don't satisfy the side-condition will be pruned away (although it is not always the case when in presence of non-interpreted functions, see [aggressive_rec](#Aggressive-Recursion) for a mitigation) but it can also cause constraints to be pruned away or new regions to be discovered when used in combination with [ctx_asm_simp](#Ctx_asm_simp).

The side-condition function must be a boolean predicate accepting the same arguments as the target function.

Let's see how it works:

```{.imandra .input}
let f x y =
  if x > 0 then
    if x > y then
      Some (x - y)
    else
      Some (y - x)
  else
    None

let g x (y : int) = x > 0
```

Let's assume we only care to decompose feasible paths of `f` when `g` holds (i.e. when `x > 0`):

```{.imandra .input}
Decompose.top ~assuming:"g" "f"
```

As we can see, the call to `Decompose.top` pruned away the region where `g` didn't hold.

# Compound
The `~compound` flag instructs Imandra whether or not to expand compound logical statements in conditionals, such as conjunctions and disjunctions, into their constituent parts. With `~compound:true`, the decomposition may in general be possible with fewer regions than otherwise, but region constraints and invariants may involve `&&` and `||`. This flag doesn't cause any constraints to be removed.

By default, `~compound:false` is used.

Let's see how `~compound` works in practice on a target function with a compound conditional:

```{.imandra .input}
let f x y =
  if x > 10 || y < 20 then
    1
  else
    2
```

If we decompose `f` with `~compound:false`, we'll get 3 different regions:

```{.imandra .input}
Decompose.top ~compound:false "f"
```

Though all regions are disjoint, we can see that two regions have the same invariant and could be logically collapsed into just one region with a disjunctive constraint. (Hint: click on a region in the Voronoi diagram to see the region's constraints and invariant.) This is where `~compound:true` helps us:

```{.imandra .input}
Decompose.top ~compound:true "f"
```

Note that `~compound:true` doesn't simply operate on literal `&&`'s and `||`'s in code, but is more general, taking the boolean meaning of nested `if` statements into account.

# Reduce symmetry

The flag `~reduce_symmetry` is like `~compound` in the sense that it is used to reduce the number of regions output by a decomposition, but through very different means.

This flag is only meaningful when used in combination with side-conditions (`assuming`), and behaves like a no-op when no-side conditions are present.

When side-conditions are present and `reduce_symmetry` is true, Imandra uses the information it has been given by the `assuming` function to find and merge _symmetric_ regions. At a high level, symmetric regions are regions that share some control flow paths which, modulo the assumptions, can be seen to behave identically and thus can be merged.

This flag can cause constraints to be eliminated, so it should be used only when decomposing as means of finding possible behavioural regions rather than as a way to get at all the possible execution paths of a function.

Let's see how this works in practice:

```{.imandra .input}
let f x y =
  if x + y = 10 then
    1
  else if x > y then
    1
  else
    2
```

For this particular example (with no compound conditionals), the setting of `~compound` is immaterial, so for the sake of demonstrating the behaviour of `~reduce_symmetry:true`, we'll decompose with the default `~compound:false` setting. Note that in general, with more complex target and side-condition functions than the ones we use here as examples, it is not in general true that `~compound:true` subsumes `~reduce_symmetry:true`.

If we try to decompose `f`, we see that we get 3 different regions, as expected, corresponding to the three different branches.

```{.imandra .input}
Decompose.top "f"
```

Let's now try to insert a side condition `g` that simply states that `x` is always bigger than `y`:

```{.imandra .input}
let g (x:int) y = x > y;;

Decompose.top ~assuming:"g" "f"
```

We've now excluded the third region, as we've asserted that it is never the case that `x<=y`.

However if we look carefully, we'll notice that both remaining regions have invariants that don't depend on the region constraints, thus if we're doing a decomposition just to analyze all the possible states our `f` can be in and not to get a concrete listing of all the possible paths through `f`, we'd like for this decomposition to collapse both regions into one.

In other words, we'd like imandra to understand that for our purposes, `f` could have been written instead like:

```{.imandra .input}
let f' x y =
  if x <= y then
    2
  else
    1
```

This is where `~reduce_symmetry:true` helps us:

```{.imandra .input}
Decompose.top ~assuming:"g" ~reduce_symmetry:true "f"
```

As you can see, not only did `~reduce_symmetry:true` collapse both regions into one, but it also figured out that there are actually no constraints to be held true for this regions's invariant to hold, since all possible values of `x` and `y` will cause `f x y` to evaluate to `1`, as we've restricted the functions' domain in the side-condition.

For the curious, this is one of the big differencies between `~reduce_symmetry:true` and `~compound:true` in this case, as `~compound:true` would've merged the two regions and had the constraints in a logical disjunction, but wouldn't have figured out that it could just as well remove the constraints altogether as they always hold true from the side-condition:

```{.imandra .input}
Decompose.top ~assuming:"g" ~compound:true "f"
```

# Ctx_asm_simp

`~ctx_asm_simp` is yet another flag that deals with trying to reduce the number of regions and improve performance. It instructs Imandra whether or not to take the side-conditions into accound when doing a pre-processing step of contextually simplifying the target function. When no side condition is present this is equivalent to a no-op.

When set to `true`, this can help Imandra simplify some more state space away and make decomposition faster and produce less regions, however it is also possible that this will cause Imandra to spend a lot more time doing simplification and might even cause more regions to be produced, so careful consideration is needed before enabling this.

Let's see how this flag works in practice:

```{.imandra .input}
let f x (y:int) =
  if y > 0 then
    if x > y  then
      1
    else
      2
  else
    if x < 0 then
      3
    else
      2
```

If we decompose `f` we get all 4 regions, as expeted:

```{.imandra .input}
Decompose.top "f"
```

If we then introduce a side-condition `g` making the first and third branches unreachable:

```{.imandra .input}
let g x y =
  x + y = 1;;

Decompose.top ~assuming:"g" "f";;
```

The 2 unreachable branches are correctly filtered out by the side-condition. However we notice that both feasabile paths have the same invariant and we would like to collapse them into a single region.

Let's see how `~ctx_asm_simp:true` helps us here:

```{.imandra .input}
Decompose.top ~compound:false ~ctx_asm_simp:true ~assuming:"g" "f"
```

By letting Imandra use the side-condition while doing simplification, it can then realize there is just one possible behaviour for `f` given the side-condition `g`, and collapse the two regions.


# Max_ctx_simp

`~max_ctx_simp` is a numeric value (defaults to `100`) which tells Imandra how "deep" to simplify conditional statements into separate regions. A higher number will mean that Imandra will spend more time trying to "simplify" the target function, which can lead to faster or better decomposition, but a value too high might also make Imandra work too hard trying to simplify a target function that would be more easily decomposed with a less deep simplification.

In practice you'll very rarely need to tweak this flag.


# Basis

`~basis` is an optional list of functions that we want Imandra to leave _opaque_ (i.e., _disabled_ or _uninterpreted_). There are two main reasons for wanting to do this:

- Abstraction fence: Function symbols in the `basis` will give a logical vernacular for describing regions and invariants. This is very similar to the use of `disabled` function symbols in Imandra theorem proving.

   A typical example: Consider a "date/time comparison" function `Datetime.(<=)` which is used in an IML model. If this comparison function is complex with many branches (comparing year, month, day, hour, minute, etc.), these constraints may pollute your decomposition with a huge number of regions ultimately describing "every possible way" one can have, e.g., `Datetime.(x <= y)` and this may obscure the meaning of the various regions. Instead, if we add `Datetime.(<=)` to the basis, then its definition will not be expanded and it can appear atomically in constraints and invariants. There are also ways to make use of Imandra rewrite rules and other lemmas, so that various exposed properties of the `basis` functions are respected (and contribute to simplification) during decomposition, culimatining in the use of `interpret_basis` (described below).


- Performance/region space: When the interpretation of a function is too expensive (many branches, lots of complex nonlinear arithmetic), we may want to tell imandra to avoid interpreting it

Note that putting certain functions in `~basis` may actually cause a higher number of regions to be computed and much more deeply nested branches to be analyzed, thus also causing performance issues and having the exactly opposite effect than what desired, so be very careful and thoughtful about putting functions in `~basis`. There are also correctness issues that can arise, see [~interpret-basis](#interpret-basis)

Let's see how this flag works in practice:

```{.imandra .input}
type my_num = Real of real | Int of int | NaN

let add x y =
  match x, y with
  | Real f1, Real f2 -> Real (f1 +. f2)
  | Int i1, Int i2 -> Int (i1 + i2)
  | _, _ -> NaN

let is_pos x =
  match x with
  | Real f -> f >. 0.0
  | Int i -> i > 0
  | NaN -> false

let f x y =
  if is_pos (add x y) then
    1
  else
    2
```

Let's try to decompose `f` without anything in basis:

```{.imandra .input}
Decompose.top "f"
```

As we can see decomposition for our `f` explodes because of the branching in `is_pos` and `add`, we can imagine the number of regions getting much larger as we support summation between `Float` and `Int` for example.

Let's see how `~basis` helps us here:

```{.imandra .input}
Decompose.top ~basis:["add";"is_pos"] "f"
```

By putting `add` and `is_pos` in `~basis`, we now only get the 2 "logical" regions of behaviour instead of a listing of all the possible code paths.

# Interpret basis

`~interpret_basis` is a flag which tells Imandra whether or not to take the interpretation of the functions in `~basis` into account when `lifting` and when extracting sample values via the `Mex` module. It only has effect when `~basis` is not empty.

Note that `~interpret_basis` *cannot* be used with recursive functions in `basis`.

This flag has a strong effect on correctness when used in decompositions that have side-conditions that use functions in `~basis` in branching points, as in the absence of side-conditions, setting this flag to `false` may cause unreachable regions to be output. Setting `~interpret_basis:false` may have significant performance benefits, but could also cause a degradation in performance in certain cases; for those reasons we suggest to always set `~interpret_basis:true` unless careful thought is given and the possible issues have been explored and are understood.

Let's see how this flag works in practice:

```{.imandra .input}
let gt (x : int) (y : int) = x > y;;

let f x y =
  if gt x y then
    if gt y x then
      1 (* this is unreachable! *)
    else
      2
  else
    3
```

If we try to simply decompose `f`, we get 2 regions:

```{.imandra .input}
Decompose.top "f"
```

Imandra has correctly figured out that the region with invariant `F=1` is not admissible, since it's never the case that `x>y && y>x`.

However, if we decide we need `gt` to be a `basis` function (for one of the reasions we've described earlier), Imandra doesn't have any visibility into what `gt` does and thus loses the ability to understand that if `gt x y` then `not (gt y x)`, and we see that the unreachable region is output anyway:

```{.imandra .input}
Decompose.top ~basis:["gt"] "f"
```

If however, we set `~interpret_basis:true`, Imandra will have visibility into `gt` at "region feasibility checks" even though it will keep it atomic in the constraints, and thus will be able to prove that `gt x y ==> not (gt y x)` which is sufficient to exclude that region:

```{.imandra .input}
Decompose.top ~interpret_basis:true ~basis:["gt"] "f"
```

# Aggressive Recursion

Sometimes, even `~interpret_basis:true` won't be enough, and regions with falsifiable constraints will still be returned.
This can be the case for a number of cases where it is not possible to provide an interpretation for a function, for example in the case of a recursive function that cannot be fully unrolled.

In those cases, `~aggressive_rec:true` can help us by applying the full unrolling and simplification machinery used for theorem proving and verification to each region before returning it, this means that we can install theorems as rewrite rules or forward-chaining rules to aid in this process:

```{.imandra .input}
let rec f x = if x <= 0 then 23 else f (x - 1)

let g x = if f x = 23 then 1 else 2
```

It's quite clear that the only live region of `g` is the one that returns `1`, but if we try to decompose it we see that Imandra doesn't realize that:

```{.imandra .input}
Decompose.top "g";;
```

Let's prove that `f x` does indeed always return 23 and register the theorem as a rewrite rule:

```{.imandra .input}
theorem _ x = f x = 23 [@@induct functional f] [@@rw]
```

That was easy. We can now decompose `g` using `~aggressive_rec:true` and we obtain just one region, as Imandra is able to apply our rewrite rule during simplification:

```{.imandra .input}
Decompose.top "g" ~aggressive_rec:true
```
