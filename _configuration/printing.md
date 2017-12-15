---
title: "Printing"
excerpt: ""
permalink: /printing/
layout: pageSbar
colName: Configuration
---
Custom printers can be installed for any Imandra type. This is done using the `:install_printer` directive. A custom printer for a type `t` should have type ```Format.formatter -> t -> unit.``` These printers can be defined in `:program` mode.

### Installing a custom printer"

Let us start with a small example, beginning by defining a type in `:logic` mode.
{% highlight ocaml %}
# type order = Market of int | Limit of int * float;;
{% endhighlight %}
With the type defined, we can begin reasoning about it. For example, we may ask for a value of type `order` using `instance`:
{% highlight ocaml %}
# instance _ (x : order) = true;;
Instance:  { x = Market 0; }
{% endhighlight %}
Notice how the value `Market 0` is printed as part of a record. In fact, it is bound to a module `CX` and can be accessed by `CX.x`:

```
# CX.x;;
- : order = Market 0
```

Let us now define a custom type printer for `order` values. We'll do this in `:program` mode.
```
# :program
> let string_of_order x =
  let open Printf in
  match x with
  Market n    -> sprintf "M(%d)" n
  | Limit (n,p) -> sprintf "L(%d,%f)" n p;;
val string_of_order : order -> string = <fun>
> let print_order fmt x =
  Format.fprintf fmt "<order %s>" (string_of_order x);;
val print_order : Format.formatter -> order -> unit = <fun>
```

We install it:
```
> :install_printer print_order\nPrinter print_order installed.
```

And now `order` values obtained by evaluation will be printed using it:
```
> Market 10;;
- : order = <order M(10)>
```

This applies also to tuples, records and other compound types that build upon `order`:
```
> (Market 1, Limit (1, 3.0));;
- : order * order = (<order M(1)>, <order L(1,3.000000)>)
> type t = { x : order; y : order };;
type t = { x : order; y : order; }
> { x = Market 1; y = Limit (10, 25.0) };;
- : t = {x = <order M(1)>; y = <order L(10,25.000000)>}
```

Of course, we can further define our own custom printers for such compound types. These custom compound type printers will be given priority if they are installed:
```
> let print_t fmt (x : t) = 
let qty = function
  Market n     -> n
  | Limit (n, _) -> n
  in Format.fprintf fmt "<t:%d>" (qty x.x + qty x.y);;
> :install_printer print_t
Printer print_t installed.
> { x = Market 1; y = Limit (10, 25.0) };;
- : t = <t:11>
```

#### For CX-bound values

However, if we perform `instance` or `check` or `verify` commands that construct and print (counter-)examples, the custom printers will not by default be applied:

```
> :logic
# instance _ (x,y : order * order) = x <> y;;
Instance:
  { x = Market 0;
    y = Market 1; }
```

This is because, by default, values bound to the `CX` module are not "obtained by evaluation." Compare this output to the following, which is obtained by evaluation:

```
# (CX.x, CX.y);;
- : order * order = (<order M(0)>, <order M(1)>)
```

We can instruct Imandra to print all values bound to the `CX` module in this latter format, i.e., as a tuple (rather than a record) that is obtained by evaluation and thus has all custom printers applied. We do this through the `:set_print cx_custom` directive.

```
# :set_print cx_custom
```

Now, the result of `instance` and related commands will have our custom printers applied:

```
# instance _ (x,y : order * order) = x <> y;;
Instance:
- : order * order = (<order M(0)>, <order M(1)>)
```

#### For DX-bound values

We can cause the same printing behaviour to occur in `dash_mode` by enabling the `:set_print dash_dx` option. See [Dashing VGs](doc:dashing-vgs) for more on this option.

```
# :dash_mode on
> type order = Market of int | Limit of int * float;;
type order = Market of int | Limit of int * float
> let string_of_order x =
  let open Printf in
    match x with
    Market n    -> sprintf "M(%d)" n
    | Limit (n,p) -> sprintf "L(%d,%f)" n p;;
val string_of_order : order -> string = <fun>
> let print_order fmt x =
  Format.fprintf fmt "<order %s>" (string_of_order x);;
val print_order : Format.formatter -> order -> unit = <fun>
> :install_printer print_order
Printer print_order installed.
> dash _ (x,y) =
  match x,y with
  Market _, Limit _ -> false
  | _ -> true;;
dash _ = <dashed:29>
> :set_print dash_dx
> dash _ (x,y) =
  match x,y with
  Market _, Limit _ -> false
  | _ -> true;;
dash _ = <dashed:29>

Counterexample (List.hd DX.xs):
- : order * order = (<order M(0)>, <order L(61,66.821092)>)
```

#### Uninstalling printers

Custom printers may be uninstalled with the `:uninstall_printer` directive:
```
> :uninstall_printer print_order
Printer print_order uninstalled.
> dash _ (x,y) = 
  match x,y with
  Market _, Limit _ -> false
  | _ -> true;;
dash _ = <dashed:29>

Counterexample (List.hd DX.xs):
- : order * order = (Market 0, Limit (61, 66.8210921032085139))
```
#### Uniform behaviour

To recap, to obtain uniform behaviour in the (custom) printing of all (counter-)examples bound either to `CX` or `DX`, we must do the following:

* `:set_print cx_custom`
* `:set_print dash_dx`

With these options enabled, `dash`, `verify`, `instance` and `check` will all print out (counter-)examples when they're computed, and all (counter-)examples will be printed in a format that has all custom printers applied.
