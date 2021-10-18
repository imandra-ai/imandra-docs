---
title: "Analysing the UBS ATS Dark Pool"
description: "In this notebook, we model the order priority logic of the UBS ATS dark pool as described in UBS's June 1st 2015 Form ATS submission to the SEC and analyse it using Imandra. We observe that as described, the order priority logic suffers from a fundamental flaw: the order ranking function is not transitive."
kernel: imandra
slug: ubs-case-study
key-phrases:
  - custom document printers
  - counterexample
difficulty: intermediate
---

# Imandra encoding of UBS dark pool (Form ATS)

In this notebook, we model the order priority logic of the UBS ATS dark pool as described in UBS's [June 1st 2015 Form ATS submission to the SEC](https://storage.googleapis.com/imandra-notebook-assets/Form-ATS-June15.pdf) and analyse it using Imandra.

We observe that as described, the order priority logic suffers from a fundamental flaw: the order ranking function is not _transitive_.

This type of subtle issue in matching logic strongly motivates the use of formal, [machine reasonable](https://medium.com/imandra/machine-reasonable-apis-and-regulations-20f29e1bd4cf) disclosures.

Some relevant references:
 - [Bloomberg - Intel's Pentium Bug Fix Is Proposed as Solution for Dark Pools](https://www.bloomberg.com/news/articles/2016-03-04/intel-s-pentium-bug-fix-is-proposed-as-solution-for-dark-pools)
 - our 2017 Lecture Notes in AI paper [Formal Verification of Financial Algorithms](https://link.springer.com/chapter/10.1007/978-3-319-63046-5_3)
 - our 2016 [SEC Reg ATS-N comment letter](https://www.sec.gov/comments/s7-23-15/s72315-24.pdf) proposing the _Precise Specification Standard_ for disclosure of financial algorithms
 - our 2018 [Machine Reasonable APIs and Regulations](https://medium.com/imandra/machine-reasonable-apis-and-regulations-20f29e1bd4cf) Medium post

## UBS Future of Finance Challenge - First Place Winner

<img src="https://storage.googleapis.com/imandra-notebook-assets/winningubsfinals2015_jpg-large.jpg" width=500>

This analysis was part of Aesthetic Integration's entry in the 2015 UBS Future of Finance Challenge, for which we won first place (out of 620 companies from 52 countries!). This analysis is based purely on publicly available documents, and is based on our interpretation of the English prose written in the Form ATS.

<img src="https://storage.googleapis.com/imandra-notebook-assets/ubs-form-ats-first-page.png" width=500>

# An Imandra Formal Model of UBS ATS Order Priority Logic

We begin our model by defining a record type corresponding to the current NBB/O and relevant market data signals.

```{.imandra .input}
type mkt_data = {
  nbb : real;
  nbo : real;
  l_up : real;
  l_down : real;
}
```

Let us now introduce some useful functions on `mkt_data`.

```{.imandra .input}
type mkt_cond = MKT_NORMAL | MKT_CROSSED | MKT_LOCKED

let which_mkt mkt =
  if mkt.nbo = mkt.nbb then MKT_LOCKED
  else if mkt.nbo <. mkt.nbb then MKT_CROSSED
  else MKT_NORMAL

let mid_point mkt = (mkt.nbb +. mkt.nbo) /. 2.0
```

Because our model is executable, we can compute with various `mkt_data` values:

```{.imandra .input}
{nbb=42.11; nbo=42.10; l_up=3. ; l_down= 2.5}
```

```{.imandra .input}
which_mkt {nbb=42.11; nbo=42.10; l_up=3. ; l_down= 2.5}
```

## Aside: Custom Document Printers

Imandra has a powerful structured _document_ system for making custom views and interfaces for your algorithm analysis tasks.

To make our Imandra notebooks and analysis toolchains user-friendly, we can define and install our own custom Imandra _document printer_ that will render our market data type in a table in our notebook.

For example, we can define a simple table-based document printer for our `mkt_data` type as follows.

We use the `[@@program]` attribute on our pretty-printer definition, to tell Imandra to only define this function in `#program` mode (not in `#logic` mode, i.e., not within our formal logic). Arbitrary OCaml functions can be defined in `#program` mode, the basis for much custom Imandra interfaces and proof automation:

```{.imandra .input}
#program;;
#require "tyxml";;

let html elt =
  let module H = Tyxml.Html in
  Document.html (Document.Unsafe_.html_of_string @@ CCFormat.sprintf "%a" (H.pp_elt ()) elt);;

let html_of_mkt_data (m : mkt_data) =
  let module H = Tyxml.Html in
  H.table
  [ H.tr [ H.td [H.txt "nbb"]; H.td [H.txt (Real.to_string_approx m.nbb)] ]
  ; H.tr [ H.td [H.txt "nbo"]; H.td [H.txt (Real.to_string_approx m.nbo)] ]
  ; H.tr [ H.td [H.txt "l_up"]; H.td [H.txt (Real.to_string_approx m.l_up)] ]
  ; H.tr [ H.td [H.txt "l_down"]; H.td [H.txt (Real.to_string_approx m.l_down)] ]
  ];;

let doc_of_mkt_data m =
  let module D = Document in
  let module H = Tyxml.Html in
  D.indent "mkt_data" @@ (html (html_of_mkt_data m))
[@@program]

#install_doc doc_of_mkt_data;;

#logic;;
```

If we view the same `mkt_data` value as above, we'll now see it rendered with our custom pretty-printer:

```{.imandra .input}
{nbb=42.11; nbo=42.10; l_up=3. ; l_down= 2.5}
```

# Time, Price and Static Data

We now define some types and functions for representing `time`, `price` and `static_data`. We use `int` for `time` and `real` for `price`, as it is sufficient for this analysis, but custom types (e.g., `decs` with price bands) can be easily defined.

```{.imandra .input}
type time = int
```

```{.imandra .input}
type price = real
```

```{.imandra .input}
type static_data = { round_lot : int;
                     tick_size : float }
```

# Order types

We now define the order types supported by the dark pool.

## Section 2 of the Form ATS defines the order types as follows:

Order Types:

- Pegged Orders (both Resident and IOC TimeInForce).
      Pegging can be to the near, midpoint, or far
      side of the NBBO. Pegged Orders may have a limit price.
- Limit Orders (both Resident and IOC TimeInForce)
- Market Orders (both Resident and IOC TimeInForce)

Conditional Indication Types:

- Pegged Conditional Indications (Resident T)
- Limit Conditional Indications (Resident TimeInForce only)

```{.imandra .input}
type order_side = BUY | SELL | SELL_SHORT

type order_peg = NEAR | MID | FAR | NO_PEG

type order_type =
    MARKET
  | LIMIT
  | PEGGED
  | PEGGED_CI
  | LIMIT_CI
  | FIRM_UP_PEGGED
  | FIRM_UP_LIMIT
```

Source Categories are defined in the Form ATS as follows:

- Source Category 1: Retail orders routed by broker - dealer clients of the UBS Retail Market Making business.
- Source Category 2: Certain orders received from UBS algorithms, where the underlying client is an institutional client of UBS.
- Source Category 3: Orders received from Order Originators that are determined by UBS to exhibit lowto - neutral reversion.
- Source Category 4: All other orders not originating from Source Categories 1, 2 or 3.

```{.imandra .input}
type order_attr = RESIDENT | IOC

type category = C_ONE | C_TWO | C_THREE | C_FOUR
```

# Capacity, Eligibilities and Crossing Restrictions

```{.imandra .input}
type capacity = Principal | Agency

(* ID of the order source *)

type order_source = int

(* UBS's ID in the model *)

let ubs_id = 12

(* Category crossing constraints *)

type category_elig = {
  c_one_elig : bool;
  c_two_elig : bool;
  c_three_elig : bool;
  c_four_elig : bool;
}

let default_cat_elig = {
  c_one_elig = true;
  c_two_elig = true;
  c_three_elig = true;
  c_four_elig = true;
}

(* Type for crossing restrictions *)

type cross_restrict = {
  cr_self_cross : bool;
  cr_ubs_principal : bool;
  cr_round_lot_only : bool;
  cr_no_locked_nbbo : bool;
  cr_pegged_mid_point_mode : int;

  (* From the examples, we understand that: 0 - no constraint 1 - mid      *)
  (* constraint 2 - limit constraint                                       *)

  cr_enable_conditionals : bool;
  cr_min_qty : bool;
  cr_cat_elig : category_elig;
}

let default_cross_restrict = {
  cr_self_cross = false;
  cr_ubs_principal = false;
  cr_round_lot_only = false;
  cr_no_locked_nbbo = false;
  cr_pegged_mid_point_mode = 0;
  cr_enable_conditionals = false;
  cr_min_qty = false;
  cr_cat_elig = default_cat_elig;
}
```

# Orders

We now define the type `order`, representing all data associated with a given order.

```{.imandra .input}
(* Note: there's both the quantity of the order and the current filled quantity. *)

type order =
    { id : int;                        (* Order ID *)
      peg : order_peg;                 (* Near, Mid, Far or NoPeg *)
      client_id : int;                 (* Client ID *)
      order_type : order_type;         (* Market, Limit or Pegged order + Conditional Indications *)
      qty : int;                       (* Original quantity of the order (updated after cancel/replace) *)
      min_qty : int;                   (* Minimum acceptible quantity to trade *)
      leaves_qty : int;                (* Remaining quantity of the order *)
      price : price;                   (* Limit price (Not used if the order *)
      time : time;                     (* time of order entry (reset on update)) *)
      src : order_source;              (* ID of the order source *)
      order_attr : order_attr;         (* Resident or Immediate Or Cancel (IOC) *)
      capacity : capacity;             (* Principal or agency *)
      category : category;             (* Client category *)
      cross_restrict : cross_restrict; (* Crossing restrictions *)
      locate_found : bool;             (* A sell-short order without a locate would be rejected *)
      expiry_time : int;               (* When will the order expire? *)
    }

```

# Determining how much and at what price two orders may trade

```{.imandra .input}
(** Uses two orders' timestamps to determin the older price of the two *)
let older_price (o1, o2) =
  if o1.time > o2.time then o2.price else o1.price

type fill_price =
  | Known of price
  | Unknown
  | TOP of price

(* Functions for categorisations  *)

let cat_priority (o1, o2) =
  if o1.category = C_ONE then false
  else if o1.category = C_TWO &&
            (o2.category = C_THREE || o2.category = C_FOUR)
  then false
  else if o1.category = C_THREE && (o2.category = C_FOUR) then false
  else true

let eff_min_qty (o) = min o.min_qty o.leaves_qty

let effective_size (o, should_round, round_lot) =
  if should_round = true then
    ( if round_lot > 0 then ( (o.leaves_qty / round_lot) * round_lot )
      else o.leaves_qty )
  else
    o.leaves_qty

(* The pricing functions *)

let lessAggressive (side, lim_price, far_price) =
  if lim_price <. 0.0 then far_price else
    (if side = BUY then Real.min lim_price far_price
     else Real.max lim_price far_price)

(** This function is used to calculate the priority price *)
let priority_price (side, o, mkt) =
  let calc_pegged_price =
    ( match o.peg with
      | FAR -> lessAggressive(side, o.price,
                              (if side = BUY then mkt.nbo else mkt.nbb))
      | MID -> lessAggressive(side, o.price, (mid_point mkt))
      | NEAR -> lessAggressive(side, o.price,
                               (if side = BUY then mkt.nbb else mkt.nbo))
      | NO_PEG -> o.price )
  in
  let calc_nbbo_capped_limit =
    ( if side = BUY then lessAggressive (BUY, o.price, mkt.nbo)
      else lessAggressive (SELL, o.price, mkt.nbb ) )
  in
  match o.order_type with
  | LIMIT -> calc_nbbo_capped_limit
  | MARKET -> if side = BUY then mkt.nbo else mkt.nbb
  | PEGGED -> calc_pegged_price
  | PEGGED_CI -> calc_pegged_price
  | LIMIT_CI -> calc_nbbo_capped_limit
  | FIRM_UP_PEGGED -> calc_pegged_price
  | FIRM_UP_LIMIT -> calc_nbbo_capped_limit

(** This is used to calculate the actual price at which the order would trade   *)
let exec_price (side, o, mkt) =
  priority_price (side, o, mkt)
```

# Crossing Restrictions

The UBS ATS allows all Order Originators to use the following optional
crossing restrictions, on a per - order or configured basis:

- No Self Cross: To prevent crossing against 'own orders' (orders sent with the same client ID).
- No UBS Principal: To prevent crossing against UBS BD Principal Orders, or UBS affiliate Principal orders.
- Round Lot Only: To prevent crossing in other than round lot orders.
- No Locked: To prevent crossing on a pegged order when the NBBO is locked. (Bid = Offer)
- PeggedMidPointMode: To prevent a Mid - point Pegged Order from being executed
    at its limit price if (i) in the case of a buy order, its limit price is less
    than the mid - point of the spread between the NBB and NBO and (ii) in the
    case of a sell order, its limit price is greater than the mid - point of the
    spread between the NBB and NBO. In the event this restriction is not
    elected, a Mid - Point Pegged Order with a specified limit price may be executed
    at the limit price even if the price is not equal to the mid - point of the
    spread between the NBB and the NBBO.
- Enable Conditionals: To enable a Resident Order to interact with Conditional Indicators.
- Minimum Quantity: Orders may be routed to the UBS ATS with a minimum quantity
    value specified. UBS ATS will only cross where at least this number of shares
    is available from a single eligible contra side order.

```{.imandra .input}
(* Note that these are order-level constraints. There are members of this  *)
(* structure, like cr_min_qty and cr_round_lot_only that are used in       *)
(* calculating the effective minimum price.                                *)

let get_cat_eligibility (cat_elig, c) =
  match c with
  | C_ONE -> cat_elig.c_one_elig
  | C_TWO -> cat_elig.c_two_elig
  | C_THREE -> cat_elig.c_three_elig
  | C_FOUR -> cat_elig.c_four_elig

let can_orders_cross (o1, o2) =
  let o1_cr = o1.cross_restrict in
  let o2_cr = o2.cross_restrict in
  if (o1_cr.cr_self_cross || o2_cr.cr_self_cross) && (o1.client_id = o2.client_id)
  then false
  else if (o1_cr.cr_ubs_principal || o2_cr.cr_ubs_principal) &&
            (o1.client_id = ubs_id || o2.client_id = ubs_id) then false
  else if (o1_cr.cr_enable_conditionals || o2_cr.cr_enable_conditionals) &&
            (o1.order_type = LIMIT_CI || o1.order_type = PEGGED_CI) then false
  else true
```

# Order Book

The Order Book is used to match buy orders against sell orders.

```{.imandra .input}
type order_book = {
  buys  : order list;
  sells : order list;
}

let empty_book = { buys = []; sells = [] }

type fill = { order_buy : order;
              order_sell : order;
              fill_qty : int;
              fill_price : fill_price;
              fill_time : time;
            }
```

## Ranking functions for orders

From Section 4.1 of UBS's June, 2015 Form ATS:

```
Eligible Resident Orders and IOC Orders are given priority
based first on price and second on the time of their receipt by the UBS ATS.
Eligibility is determined based on the crossing restrictions associated with
the orders on both sides of the potential cross.

Invites are sent to the Order Originators of Conditional Indications on a
priority based first on price, second on the quantity and third on the time of
receipt by UBS ATS. For orders with the same price and time, priority is given
to Resident and IOC Orders over Conditional Indications.

All marketable limit orders (i.e., buy orders with limit prices at or above the
NBO or sell orders with limit prices at or below the NBB) will be treated as
though they are at equivalent prices for priority purposes. As such, they will
be handled based strictly on time priority, as if they were market orders. If a
marketable limit order becomes non - marketable before execution, it will be treated
as a limit order and will receive price / time priority, with time based upon the
original time of receipt of the order by the UBS ATS.
```


Let us formalise this logic below.

```{.imandra .input}
let non_ci (ot) = not(ot = PEGGED_CI || ot = LIMIT_CI);;

let order_higher_ranked (side, o1, o2, mkt) =
  let ot1 = o1.order_type in
  let ot2 = o2.order_type in

  let p_price1 = priority_price (side, o1, mkt) in
  let p_price2 = priority_price (side, o2, mkt) in

  let wins_price = (
    if side = BUY then
      ( if p_price1 >. p_price2 then 1
        else if p_price1 = p_price2 then 0
        else -1)
    else
      ( if p_price1 <. p_price2 then 1
        else if p_price1 = p_price2 then 0
        else -1) ) in

  let wins_time = (
    if o1.time < o2.time then 1
    else if o1.time = o2.time then 0
    else -1
  ) in

  (* Note that the CI priority is price, quantity and then time *)
  if wins_price = 1 then true
  else if wins_price = -1 then false
  else (
    (* Same price level - first check to see whether we're comparing two   *)
    (* CI orders here                                                      *)
    if not (non_ci (ot1)) && not (non_ci (ot2)) then
      o1.leaves_qty > o2.leaves_qty
    else ( if wins_time = 1 then true
           else if wins_time = -1 then false
           else (
             if non_ci(ot1) then true
             else if (not(non_ci(ot1)) && non_ci(ot2)) then false
             else
               o1.leaves_qty > o2.leaves_qty)
         )
  )
```

The property we're interested in is whether this ranking predicate is transitive (a necessary condition for being a proper ordering relation that can be used for sorting, e.g., orders in the book):

```{.imandra .input}
let rank_transitivity side o1 o2 o3 mkt =
    order_higher_ranked(side,o1,o2,mkt) &&
    order_higher_ranked(side,o2,o3,mkt)
    ==>
    order_higher_ranked(side,o1,o3,mkt)
```

Now we can check whether this property of being transitive holds:

```{.imandra .input}
verify (fun side o1 o2 o3 mkt -> rank_transitivity side o1 o2 o3 mkt)
```

We just showed that the ranking function is **not** transitive! As always, the components of the counterexample are automatically reflected into a module called `CX` and can be computed with, just as any other value in our runtime:

```{.imandra .input}
CX.o1
```

Let's verify this counterexample to transitivity by computation!

```{.imandra .input}
order_higher_ranked CX.(side, o1, o2, mkt)
```

```{.imandra .input}
order_higher_ranked CX.(side, o2, o3, mkt)
```

```{.imandra .input}
order_higher_ranked CX.(side, o1, o3, mkt)
```

Let us add some additional constraints to help make our counterexample "pretty":

```{.imandra .input}
let pretty mkt o1 o2 o3 =
    o1.leaves_qty <= o1.qty &&
    o2.leaves_qty <= o2.qty &&
    o3.leaves_qty <= o3.qty &&
    o1.time >= 0 &&
    o2.time >= 0 &&
    o3.time >= 0 &&
    o1.price >. 0.0 &&
    o2.price >. 0.0 &&
    o3.price >. 0.0 &&
    o1.qty > 0 &&
    o2.qty > 0 &&
    o3.qty > 0 &&
    o1.leaves_qty >= 0 &&
    o2.leaves_qty >= 0 &&
    o3.leaves_qty >= 0 &&
    mkt.l_down >. 0.0 &&
    mkt.nbb >. mkt.l_down &&
    mkt.nbo >. mkt.nbb &&
    mkt.l_up >. mkt.nbo
```

```{.imandra .input}
verify (fun side o1 o2 o3 mkt -> pretty mkt o1 o2 o3 ==> rank_transitivity side o1 o2 o3 mkt)
```

# Extending the model with Document printers

Let's define a few more custom document printers to make these (complex!) counterexamples easier to understand.

```{.imandra .input}
(* We can generate string printers for our types automatically using the pp plugin *)
Imandra.add_plugin_pp ();;

let doc_of_order o =
  let module D = Document in
  let module H = Tyxml.Html in
  D.indent "order" @@ html (H.table
      [ H.tr [ H.td [ H.txt "id"]; H.td [ H.txt (Z.to_string o.id)]]
      ; H.tr [ H.td [ H.txt "peg"]; H.td [ H.txt ( CCFormat.to_string pp_order_peg o.peg)]]
      ; H.tr [ H.td [ H.txt "client_id"]; H.td [ H.txt (Z.to_string o.client_id)]]
      ; H.tr [ H.td [ H.txt "order_type"]; H.td [ H.txt ( CCFormat.to_string pp_order_type o.order_type)]]
      ; H.tr [ H.td [ H.txt "qty"]; H.td [ H.txt (Z.to_string o.qty)]]
      ; H.tr [ H.td [ H.txt "min_qty"]; H.td [ H.txt (Z.to_string o.min_qty)]]
      ; H.tr [ H.td [ H.txt "leaves_qty"]; H.td [ H.txt (Z.to_string o.leaves_qty)]]
      ; H.tr [ H.td [ H.txt "price"]; H.td [ H.txt ( Real.to_string_approx o.price)]]
      ; H.tr [ H.td [ H.txt "time"]; H.td [ H.txt ( CCFormat.to_string pp_time o.time)]]
      ; H.tr [ H.td [ H.txt "src"]; H.td [ H.txt ( CCFormat.to_string pp_order_source o.src)]]
      ; H.tr [ H.td [ H.txt "order_attr"]; H.td [ H.txt ( CCFormat.to_string pp_order_attr o.order_attr)]]
      ; H.tr [ H.td [ H.txt "capacity"]; H.td [ H.txt ( CCFormat.to_string pp_capacity o.capacity)]]
      ; H.tr [ H.td [ H.txt "category"]; H.td [ H.txt ( CCFormat.to_string pp_category o.category)]]
      ; H.tr [ H.td [ H.txt "locate_found"]; H.td [ H.txt (CCFormat.sprintf "%B" o.locate_found)]]
      ; H.tr [ H.td [ H.txt "expiry_time"]; H.td [ H.txt (Z.to_string o.expiry_time)]]
      ])
[@@program];;

#install_doc doc_of_order;;

let doc_of_side side = Document.s @@ CCFormat.to_string pp_order_side side
[@@program];;

#install_doc doc_of_side;;

let pp_rank (side, o1, o2, o3, mkt) =
  Document.(tbl ~headers:["side";"order1";"order2";"order3";"mkt"]
    @@ [[doc_of_side side; doc_of_order o1; doc_of_order o2; doc_of_order o3; doc_of_mkt_data mkt]])
 [@@program];;

#install_doc pp_rank
```

Now, let's view our latest counterexample again:

```{.imandra .input}
CX.(side, o1, o2, o3, mkt)
```
