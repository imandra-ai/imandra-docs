---
title: "Reflection"
description: "Reflection"
kernel: imandra
slug: reflection
---
# Reflection

Imandra is able to _reflect_ its normal expressions into a special datatype from the prelude, called `Reflect.Term.t`. A `Reflect.Term.t` is a logic-mode (recursive) type that can be reasoned about, the same way lists, trees, records or any other logic-mode types can be.


```{.imandra .input}
let arith_term = [%quote 1 + 1];;

(* note: [%q x] is short for [%quote x] *)

let arith_term2 = [%q 2];;
```

These two terms are distinct, because they are distinct ASTs.


```{.imandra .input}
verify (arith_term <> arith_term2);;
```

The data type `Reflect.Term.t` closely mirrors Imandra's internal AST. It looks like this:


```{.imandra .input}
#show Reflect.Term.t
```


```{.imandra .input}
(* let's have some helpers, it's a bit subtle to get the Uid of "+" *)
let ast_plus = [%quote (+)];;
let ast_one = Reflect.Term.(Const (Const_z 1));;

verify (arith_term = Reflect.Term.(Apply (ast_plus, [ast_one; ast_one])))
```


## Building new terms manually

As demonstrated above, it is possible to build new terms with `Reflect.Term.Apply` and other constructors. However, applying functions is made difficult by the existence of `Reflect.Uid.t`s (a reflection of Imandra's internal unique IDs) that are impossible to guess.

To remediate that, `[%uid f]` can be used to obtain the `Reflect.Uid.t` for a function `f` in scope:


```{.imandra .input}
let uid_plus = [%uid (+)];;

let arith_term_manual = Reflect.Term.(Apply (Ident uid_plus, [[%q 1]; [%q 1]]));;

verify (arith_term = arith_term_manual);;
```


## Unquote

Now, it is possible to _unquote_ values or other subterms inside a quoted expression. This way, quoted expressions can be parametrized. Here is a function that produces the AST `x + y + 0`:


```{.imandra .input}
let mk_plus_0 x y : Reflect.Term.t =
    [%quote [%u x] + [%u y] + 0];;
```


The expression `[%u x]` (short for `[%unquote x]`) _pulls_ `x` from the outside scope and injects it, as an integer, into the reflected term (of type `Reflect.Term.t`).

It is important to remark that this function takes _integers_, not ASTs. It is type-safe, you cannot produce
a ill-typed expression this way!


```{.imandra .input}
mk_plus_0 10 50;;

(* this doesn't typecheck:
mk_plus_0 true "hello";;
*)
```

The actual AST produced by `[%quote …]` is significantly more verbose (click on "definition" below). Again note that `x` and `y` have type `Int.t`.


```{.imandra .input}
#h mk_plus_0;;
```

Instead of `[%unquote x]`, which injects a well-typed value inside the AST, we can use `[%uu x]` or `[%unquote_splice x]` to inject an already reflected term. This doesn't guarantee type-safety anymore, so one should be careful not to create ill-typed ASTs.


```{.imandra .input}
(* ternary conjunction of arbitrary terms *)
let mk_and3 x y z : Reflect.Term.t =
    [%quote [%uu x] && [%uu y] && [%uu z]];;
```


```{.imandra .input}
mk_and3 [%q true] [%q false] [%q true];;

(* ill-typed!! Do not do that! *)
mk_and3 [%q 1] [%q None] [%q ("hello", "world")];;
```


## Quotations in patterns

It is possible to use `[%q …]` in pattern position, as well as `[%q? p]` where `p` is a valid Imandra pattern. This is useful to build functions that operate on `Reflect.Term.t`:


```{.imandra .input}
(* build the negation of the reflected term "t", but with some simplifications *)
let mk_not = function
  | [%q (not [%uu t])] -> t
  | [%q true] -> [%q false]
  | [%q false] -> [%q true]
  | t -> [%q [%uu t]]
  ;;

#h mk_not;;
```


```{.imandra .input}
mk_not [%q true];;
mk_not [%q false];;
mk_not [%q not true];;
mk_not [%q not (not (not false))];;

```
