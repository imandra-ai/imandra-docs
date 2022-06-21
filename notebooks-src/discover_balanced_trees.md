# Using Imandra Discover

Imandra Discover is a tool for theory exploration and producing conjectures.  Sometimes, it is not entirely clear what lemmas are necessary for a proof to succeed, or what the properties of a program are.  Discover intends to help with this problem, giving the user potential properties to be proved and themselves used as lemmas.

## Balanced Binary Trees

In this example, we will define a type of binary trees, and a function that creates a balanced binary tree of a given number of nodes.  Balanced binary trees are trees where the subtrees to the left and right of the root have either the same number of nodes, or differ by one.  We will then demonstrate how to use Discover for the discovery of properties of these functions.  

# Demonstration

First, we need to `#require` the Discover Bridge.  This allows Discover to interface with Imandra.

```{.imandra .input}
#require "imandra-discover-bridge";;
```

This function loads some other things necessary for Discover to run, including the Imandra `rand_gen` plugin.

```{.imandra .input}
Imandra_discover_bridge.Top.init ();;
```

It is common to restrict induction used by Imandra using `#max_induct`.

```{.imandra .input}
#max_induct 1;;
```

This is our type of binary trees.  The content of the binary trees is immaterial.  

Keep in mind that Discover instantiates polymorphic types with `int`.  This means that if this was a polymorphic binary tree whose values were of `'a`, Discover would replace the type variable `'a` with `int`.  If Discover gives you unexpected output or seems to lack things that it should have, take a look at the signature used by Discover.  You can specify the types of your functions to prevent this.

```{.imandra .input}
type bt = | Empty 
          | Branch of 
            {value : int;
             left : bt;
             right : bt;};;
```

Let's define some functions that we will use in the construction of balanced binary trees.

```{.imandra .input}
let lhs_split n = n/2;;
let rhs_split n = n - lhs_split n;;
```

What are some properties that hold of these functions?  We should ask Discover to suggest some things.  We invoke Discover with the events database `db` and pass it a list of the string function names we would like Discover to investigate.

```{.imandra .input}
discover db ~iterations:2i ["+";"lhs_split";"rhs_split"];;
```

Discover finishes after running for a few seconds and gives us some conjectures we could try to prove.  One of them states that the sum of the `lhs_split` and `rhs_split` of some `x0` is equal to `x0`.  Great, we can ask Imandra to prove it for us.

```{.imandra .input}
lemma discover__2 x0 = ((lhs_split x0) + (rhs_split x0)) = x0 [@@rewrite]  [@@auto];;
```

Now, we will make a function that should return a balanced binary tree with `n` nodes, given `n`.

```{.imandra .input}
let rec cbal n =
  if n < 0 then Empty else
  match n with
  | 0 -> Empty
  | 1 -> Branch {value=1; left = Empty; right = Empty}
  | _ -> let left_split = lhs_split (n-1) in
         let right_split = rhs_split (n-1) in
         let left = cbal left_split in
         let right = cbal right_split in
         Branch {value=1; left; right};;
```

This is simply the size of the tree.

```{.imandra .input}
let rec nodes tree =
  match tree with
  | Empty -> 0
  | Branch {left; right; _} -> 1 + (nodes left) + (nodes right);;
```

In our function `cbal`, we always return `Empty` if `n < 0`.  This suggests that we will want to have a predicate capturing the interesting case where the input to `cbal` is nonnegative, and a predicate for the zero or negative case.

```{.imandra .input}
let nonnegative x = x >= 0;;
let leq_zero x = x <= 0;;
```

Now that we have the functions `nodes` and `cbal`, we should ask Discover to find some properties that may hold.  Since `cbal` is only really interesting if the input is nonnegative, we invoke Discover with the labeled argument `~condition` set to the string literal `"nonnegative"`.  This string argument lets Discover know to always instantiate a fixed variable with values satisfying the predicate we just defined.  We specify `nodes` and `cbal` for investigation.

```{.imandra .input}
discover db ~condition:"nonnegative" ["nodes";"cbal"];;
```

Great, Discover suggests that the balanced binary trees produced by `cbal` have the correct number of nodes!  It's often helpful to tweak the lemmas suggested by Discover.  In this case we'll replace the predicate condition with its body. Let's have Imandra prove it.

```{.imandra .input}
lemma discover__0 x0 = x0 >= 0 ==> (nodes (cbal x0)) = x0   [@@auto];;
```

What about the zero or negative case?

```{.imandra .input}
discover db ~condition:"leq_zero" ["nodes";"cbal";"Empty"];;
```

Discover suggests exactly what `cbal` does in the less than or equal to zero case, so we can have Imandra prove this as well.

```{.imandra .input}
lemma discover__0_neg x0 = x0 <= 0 ==> (cbal x0) = Empty [@@auto];;
```

We were interested in verifying that the trees produced by `cbal` are actually balanced, so here is a predicate capturing that idea.

```{.imandra .input}
let is_balanced tree =
  match tree with
  | Empty -> true
  | Branch {left; right; _} ->
    let lnodes = nodes left in
    let rnodes = nodes right in
    rnodes = lnodes || rnodes - lnodes = 1;;
```

Now we can ask Discover to find a relationship between `is_balanced`, `cbal`, and `true`.  We include `true` so that Discover can suggest predicates as equations.  Similarly, you can include `false` to find things that don't hold.

```{.imandra .input}
discover db ["is_balanced";"cbal";"true"];;
```

Discover suggests that every tree produced by `cbal` is balanced.  We can prove this too!

```{.imandra .input}
lemma discover_cbal_balanced_0 x0 = x0 >= 0 ==> (is_balanced (cbal x0)) [@@auto];;
```

In this demonstration we used Discover to suggest conjectures and lemmas used in the verification of some properties of balanced binary trees.  We also showed examples of using conditions with Discover and some basic pointers on its use.
