---
title: "Exchange Implied Trading"
description: "Modelling implied trading within an exchange - implied trading refers to ability to connect liquidity on strategy and outright order books"
kernel: imandra
slug: exchange-implied-trading
key-phrases:
  - financial exchanges
---

In this notebook, we'll look into modelling implied trading within an exchange. Implied trading refers to ability to connect liquidity on strategy and outright order books (e.g. Euronext).


## 1 Type definitions and printers

### 1.1 Model type definitions

Our first goal is to setup the various type definitions that we'll use later on.

```{.imandra .input}
type side = BUY | SELL

type outright_id = OUT1 | OUT2 | OUT3
type strategy_id = STRAT1 | STRAT2
type month = Mar | Jun | Sep | Dec

(* Map an outright with an expiry *)
let contract_expiry = function
  | OUT1 -> Mar
  | OUT2 -> Jun
  | OUT3 -> Sep

(* Convert month to an integer *)
let month_to_int = function
  | Mar -> 3
  | Jun -> 6
  | Sep -> 9
  | Dec -> 12
;;

(* Return true of m1 is nearer (or equal) to m2 *)
let month_comp (m1 : month) (m2 : month) =
  (month_to_int m1) < (month_to_int  m2)
;;

type instrument =
  | Strategy of strategy_id
  | Outright of outright_id
    
(* Level information *)
type level_info = {
  li_qty : int
  ; li_price : int
}

(* best bid and ask information *)
type best_bid_ask = {
  bid_info : level_info option
  ; ask_info : level_info option
}

(* Best bid/ask for all of the books *)
type books_info = {
  book1 : best_bid_ask
  ; book2 : best_bid_ask
  ; book3 : best_bid_ask
}

(* Order type *)
type order = {
  o_qty : int
  ; o_price : int
  ; o_time : int
  ; o_id : int
  ; o_side : side
  ; o_client_id : int
  ; o_inst : instrument
  ; o_is_implied : bool
}

(* Helper function to make order creation simpler *)
let make si qty price id inst clientid isimp time =
  {o_qty = qty ; o_price = price; o_id = id; o_side = si; 
   o_client_id = clientid; o_inst = inst; o_is_implied = isimp;
   o_time = time }


(* outright order book *)
type book = {
  b_buys : order list
  ; b_sells : order list
}

let empty_book = { b_buys = []; b_sells = [] }
    
(* Individual leg *)
type leg = {
  leg_sec_idx : outright_id
  ; leg_mult : int
}

(* Strategy is composed of legs *)
type strategy = {
  time_created : int
  ; leg1 : leg
  ; leg2 : leg
  ; leg3 : leg
}

(* Helper function to make strategy creation smaller *)
let make_strat tcreated m1 m2 m3 = {
  time_created = tcreated
  ; leg1 = { leg_sec_idx = OUT1; leg_mult = m1 }
  ; leg2 = { leg_sec_idx = OUT2; leg_mult = m2 }
  ; leg3 = { leg_sec_idx = OUT3; leg_mult = m3 } 
}

type implied_strat_ord = {
  max_strat : int option
  ; strat_price : int option
}

(* New order message *)
type new_ord_msg = {
  no_client_id : int
  ; no_inst_type : instrument
  ; no_qty : int
  ; no_side : side
  ; no_price : int
}

(* cancel order ID *)
type cancel_ord_msg = {
  co_client_id : int
  ; co_order_id : int
  ; co_instrument : instrument
  ; co_side : side
}

(* Inbound messages type *)
type inbound_msg = 
  | NewOrder of new_ord_msg
  | CancelOrder of cancel_ord_msg
  | ImpliedUncross

(* Helper function for creating new order messages *)
let make_no_msg cid inst qty sd p =
 NewOrder {
  no_client_id = cid
  ; no_inst_type = inst
  ; no_qty = qty
  ; no_side = sd
  ; no_price = p
 }

(* ack message *)
type ack_msg = {
  ack_client_id : int
  ; ack_order_id : int
  ; ack_inst_type : instrument
  ; ack_qty : int
  ; ack_side : side
  ; ack_price : int
}

(* fill information *)
type fill = {
  fill_client_id : int
  ; fill_qty : int
  ; fill_price : int
  ; fill_order_id : int
  ; fill_order_done : bool
}

(* uncross result *)
type uncross_res = {
  uncrossed_book : book
  ; uncrossed_fills : fill list
  ; uncrossed_qty : int
}

(* outbound message type *)
type outbound_msg = 
  | Ack of ack_msg
  | Fill of fill
  | UncrossResult of uncross_res
;;

(* The entire market - strategy definitions, order books, messages, etc. s*)
type market = {

  (* current time*)
  curr_time : int

  (* used for order ID counter *)
  ; last_ord_id : int

  (* two strategy definitions *)
  ; strat1    : strategy
  ; strat2    : strategy

  (* outright books *)
  ; out_book1 : book
  ; out_book2 : book
  ; out_book3 : book

  (* strategy books *)
  ; s_book1   : book
  ; s_book2   : book

  (* inbound and outbound message queues *)
  ; inbound_msgs  : inbound_msg list
  ; outbound_msgs : outbound_msg list

}

```

### 1.2 Custom type printers
One of Imandra's powerful features is the ability to combine logic (pure subset of OCaml) and program (all of OCaml) modes. In the following cell, we will create and install a custom type printer (HTML) for an order book. So that next time a value of this type is computed within a cell, this printer would be used instead of the generic one.

```{.imandra .input}
(* Here's an example of a custom printer that we can install for arbitrary data types. *)

#program;;
#require "tyxml";;
let html_of_order (o : order) =
  let module H = Tyxml.Html in
  H.div
  ~a:(if o.o_is_implied then [H.a_style "color: red"] else [])
  [ H.div 
    ~a:[H.a_style "font-size: 1.4em"]
    [H.txt (Format.asprintf "%s (%s)" (Z.to_string o.o_price) (Z.to_string o.o_qty))]
  ; H.div (if o.o_is_implied then [H.txt "Implied"] else [])
  ]
  
let doc_of_order (o:order) =
  let module H = Tyxml.Html in
  Document.html (H.div [html_of_order o]);;
  
#install_doc doc_of_order

let html_of_book ?(title="") (b: book) =
  let module H = Tyxml.Html in
  let rec build_rows acc buys sells =
      match buys, sells with
      | b :: bs, s :: ss -> build_rows (acc @ [H.tr [H.td [html_of_order b]; H.td [html_of_order s]]]) bs ss
      | b :: bs, [] -> build_rows (acc @ [H.tr [H.td [html_of_order b]; H.td [H.txt "-"]]]) bs []
      | [], s :: ss -> build_rows (acc @ [H.tr [H.td [H.txt "-"]; H.td [html_of_order s]]]) [] ss
      | [], [] -> acc
  in
  H.div 
  ~a:[H.a_style "margin-right:1em; display: flex; flex-direction: column; align-items: center; justify-content: flex-start"]
  [ H.div ~a:[H.a_style "font-weight: bold"] [H.txt title]
  ; H.table
    ~thead:(H.thead [H.tr [H.th [H.txt "Buys"]; H.th [H.txt "Sells"]]])
    (build_rows [] b.b_buys b.b_sells)]
  
let doc_of_book (b:book) =
  let module H = Tyxml.Html in
  Document.html (H.div [html_of_book ~title:"M1 Mar21" b]);;
  
#install_doc doc_of_book;;

let html_of_market (m: market) =
  let module H = Tyxml.Html in
  H.div 
  [ H.div ~a:[H.a_style "display: flex"]
    [ html_of_book ~title:"Strategy 1" m.s_book1 
    ; html_of_book ~title:"Strategy 2" m.s_book2
    ]
  ; H.div ~a:[H.a_style "margin-top: 1em; display: flex"]
    [ html_of_book ~title:"Book 1" m.out_book1 
    ; html_of_book ~title:"Book 2" m.out_book2
    ; html_of_book ~title:"Book 3" m.out_book3
    ]]
    
let doc_of_market (m : market) =
  let module H = Tyxml.Html in
  Document.html (html_of_market m);;
  
#install_doc doc_of_market;;

#logic;;
```

### 1.3 Custom type printer example

```{.imandra .input}
let leg = { leg_sec_idx = OUT1; leg_mult = 1 } in

let strat = { time_created = 0; leg1 = leg; leg2 = leg; leg3 = leg } in

let b1 = {
  b_buys = [ 
    (make BUY 100 54 1 (Outright OUT1) 1 true 1)
    ;(make BUY 100 54 2 (Outright OUT1) 1 false 1)
  ]
  ; b_sells = [
    (make SELL 100 54 3 (Outright OUT1) 1 false 1)
    ;(make SELL 100 54 4 (Outright OUT1) 1 false 1)
  ] } in

  { curr_time = 1
  ; last_ord_id = 1
  ; strat1 = strat
  ; strat2 = strat
  ; out_book1 = b1
  ; out_book2 = b1
  ; out_book3 = b1
  ; s_book1 = b1
  ; s_book2 = b1
  ; inbound_msgs = []
  ; outbound_msgs = []
  }
```

## 2. Outright uncrossing logic

### 2.1 Order book operatons (inserting, cancelling orders)

```{.imandra .input}
(* Convert fills into outbound messages *)
let rec create_fill_msgs (f : fill list) =
  match f with 
  | [] -> []
  | x::xs -> (Fill x) :: create_fill_msgs xs

(* TODO: recode this with higher-order functions *)
let rec cancel_ord_side (orders : order list) (c : cancel_ord_msg) =
  match orders with
  | [] -> []
  | x::xs ->
    begin
      if (x.o_client_id = c.co_client_id) && (x.o_id = c.co_order_id) then xs
      else x :: (cancel_ord_side xs c)
    end

(* Helper to cancel orders *)
let cancel_ord_book (co : cancel_ord_msg) (b : book) =
  match co.co_side with 
  | BUY -> { b with b_buys = (cancel_ord_side b.b_buys co) }
  | SELL -> { b with b_sells = (cancel_ord_side b.b_sells co) }

(* function used insert individual orders *)
let rec insert_order_side (orders : order list) (o : order) =
  match orders with
  | [] -> [ o ]
  | x::xs ->
    begin
      if o.o_side = BUY then
        (if o.o_price > x.o_price then o :: orders else x :: (insert_order_side xs o))
      else
        (if o.o_price < x.o_price then o :: orders else x :: (insert_order_side xs o))
    end

(* insert order into the book *)
let insert_order (o : order) (b : book) = 
  if o.o_side = BUY then
    { b with b_buys = (insert_order_side b.b_buys o) }
  else
    { b with b_sells = (insert_order_side b.b_sells o) }

(* The fills are adjusted to a single fill price during the uncross *)
let rec adjust_fill_prices (fills : fill list) ( f_price : int ) =
  match fills with 
  | [] -> []
  | x::xs -> { x with fill_price = f_price } :: ( adjust_fill_prices xs f_price )
;;

```

### 2.2 Book uncross


```{.imandra .input}

(* Measure for proving termination of `uncross_book` below *)
let book_measure b =
  Ordinal.of_int (List.length b.b_buys + List.length b.b_sells)

let rec uncross_book (b : book) (fills : fill list) (filled_qty : int) = 
  match b.b_buys, b.b_sells with
  | [], [] | _, [] | [], _ ->
    (* we need to check whether there have been fills before, 
      if so we need to adjust fill prices before getting out *)
    begin
      match fills with
      | [] -> { uncrossed_book = b; uncrossed_fills = fills; uncrossed_qty = filled_qty }
      | x::xs ->
        let fills' = x :: (adjust_fill_prices xs x.fill_price) in
      { uncrossed_book = b; uncrossed_fills = fills'; uncrossed_qty = filled_qty }
    end
  | buy::bs, sell::ss ->
    if buy.o_price >= sell.o_price then
      begin
        (* compute the fill qty and price *)
        let fill_qty = if buy.o_qty < sell.o_qty then buy.o_qty else sell.o_qty in
        let fill_price = (buy.o_price + sell.o_price) / 2 in

        (* update the orders that traded *)
        let buy' = { buy with o_qty = buy.o_qty - fill_qty } in
        let sell' = { sell with o_qty = sell.o_qty - fill_qty } in

        (* create the fills *)
        let fill1 = { 
          fill_client_id = buy.o_client_id
          ; fill_qty = fill_qty
          ; fill_price = fill_price
          ; fill_order_id = buy.o_id
          ; fill_order_done = true } in
        
        let fill2 = {
          fill_client_id = sell.o_client_id
          ; fill_qty = fill_qty
          ; fill_price = fill_price
          ; fill_order_id = sell.o_id
          ; fill_order_done = true } in

        (* now update the books and fills *)
        let new_buys = if buy'.o_qty = 0 then bs else buy'::bs in
        let new_sells = if sell'.o_qty = 0 then ss else sell'::ss in
        let b' = {
          b_buys = new_buys
          ; b_sells = new_sells } in

        (* We should not be generating fills for implied orders - there's
          a different mechanism for that *)
        let fills' = if not buy.o_is_implied then
          fill1 :: fills else fills in
        let fills' = if not sell.o_is_implied then
          fill2 :: fills' else fills' in

        (* recursively go to the next level *)
        uncross_book b' fills' (filled_qty + fill_qty)
      end
      
    else
      (* nothing to do here *)
      { uncrossed_book = b; uncrossed_fills = fills; uncrossed_qty = filled_qty }
[@@measure book_measure b]
;;
```

We now have a function that does something real - `uncross_book (b : book) (fills : fill list) (filled_qty : int)`. Let's experiment how it works with some concrete values.

```{.imandra .input}
let book1 = {
  b_buys = [
    (make BUY 100 55 1 (Outright OUT1) 1 false 1)
    ; (make BUY 100 50 2 (Outright OUT1) 1 false 1)
    ]
 ; b_sells = [
    (make BUY 100 54 3 (Outright OUT1) 1 false 1)
    ; (make BUY 100 54 4 (Outright OUT1) 1 false 1)
  ]
} in

uncross_book book1 [] 0
```

### 2.3 A few verification goals
Let's try to verify some verification goals.

The first one will make sure that for an order book that is sorted (so the best bid/ask orders will be the first ones in their respective lists. Note: this is not based on the 'imbalance' of the order book, this is simply taking the midpointt of the most aggressive orders.

```{.imandra .input}
(* Returns true if the orders are sorted with respect to price *)
let rec side_price_sorted (si : side) (orders : order list) =
  match orders with
  | [] -> true
  | x::[] -> true
  | x::y::xs ->
    if si = BUY then
      begin
        if y.o_price > x.o_price && x.o_price > 0 then false else (side_price_sorted si (y::xs))
      end
    else
      begin
        if y.o_price < x.o_price && y.o_price > 0 then false else (side_price_sorted si (y::xs))
      end
;;

(* Let's make sure all the fills have this price *)
let rec fills_good_price (fills : fill list) (p : int) = 
  match fills with
  | [] -> true
  | x::xs -> (x.fill_price = p) && (fills_good_price xs p)
;;

(** Let's to verify some properties *)
let fill_price_midpoint (b : book) =

  let buys_sorted = side_price_sorted BUY b.b_buys in
  let sells_sorted = side_price_sorted SELL b.b_sells in

  let result_good = 
    begin
      match b.b_buys, b.b_sells with
      | [], _ -> true
      | _, [] -> true
      | x::xs, y::ys ->
        let unc_res = uncross_book b [] 0 in
        if x.o_price >= y.o_price then
          let midprice = (x.o_price + y.o_price) / 2 in
          (List.length unc_res.uncrossed_fills) > 0 && (fills_good_price unc_res.uncrossed_fills midprice)
        else
          true
    end in

  (* This is the 'punchline'... if the sides are price-sorted, then the fills will be the first midpoint *)
  (buys_sorted && sells_sorted) ==> result_good
;;


verify fill_price_midpoint
```

Our second verification goal will look to make sure that no quantities are lost during uncrossing. Note that no fills are generated for implied orders (there's a different mechanism for that), so when we look at the book we will only consider outright orders. Note that `o_qty` represents the residual order quantity - for this demo, we do not differentiate between original, filled and residual order quantity. When order is created, the `qty` is set to that number and is decreased when filled.

```{.imandra .input}
(* All no quantities get lost during uncross *)
let no_lost_qtys (b : book) = 
  
  let rec qtys_pos_nonimp = function
    | [] -> true
    | x::xs -> x.o_qty >= 0 && not x.o_is_implied && (qtys_pos_nonimp xs) in

  let rec sum_qtys = function
    | [] -> 0
    | x::xs -> x.o_qty + (sum_qtys xs) in

  let rec sum_fill_qtys = function
    | [] -> 0
    | x::xs -> x.fill_qty + (sum_fill_qtys xs) in

  let unc_res = uncross_book b [] 0 in
  
  (* We need to make sure the book is non-negative *)
  let book_nonneg_nonimp = (qtys_pos_nonimp b.b_buys) && (qtys_pos_nonimp b.b_sells) in

  (* Let's sum up all of the quantities of orders before the uncross *)
  let count_before = (sum_qtys b.b_buys) + (sum_qtys b.b_sells) in
  
  (* And after *)
  let count_after = (sum_qtys unc_res.uncrossed_book.b_buys) + 
                    (sum_qtys unc_res.uncrossed_book.b_sells) +
                    (sum_fill_qtys unc_res.uncrossed_fills) in

  book_nonneg_nonimp ==> (count_before = count_after)
;;

verify ~upto:15 no_lost_qtys
```

### 2.4 Test generation

First, we will decompose the function and then generate test cases for it.

```{.imandra .input}
(* This is a 'side_condition' function that tells decomposition that we're only interested in cases where the 
initial fills are empty *)
let cond (b : book) (fills : fill list) (filled_qty : int) =
 fills = [] && filled_qty = 0
;;

let d = Modular_decomp.top ~assuming:"cond" "uncross_book" ~prune:true [@@program];;
```

```{.imandra .input}
(* Now let's try to generate some test cases *)

(* This will auto-generate model extractor *)
Extract.eval ~signature:(Event.DB.fun_id_of_str "uncross_book") ();;

#remove_doc doc_of_book;;
Modular_decomp.get_regions d |> CCList.map (fun r -> r |> Modular_decomp.get_model |> Mex.of_model);;
#install_printer doc_of_book;;
```

## 3 Implied trading

### 3.1 Strategy ranking

When generating implied orders for strategies, there's a criteria used to rank strategies - this section encodes the comparison function.

```{.imandra .input}
(* Calculate somehow how big the ratio is *)
let leg_ratio (s : strategy) = 
  let abs x = if x < 0 then -x else x in
  (abs s.leg1.leg_mult) + (abs s.leg2.leg_mult) + (abs s.leg3.leg_mult)
;;

(* Nearest time to expiry *)
let nearest_time_to_exp (s : strategy) =
  let exp = 
    if (month_to_int (contract_expiry s.leg1.leg_sec_idx)) < (month_to_int (contract_expiry s.leg2.leg_sec_idx)) then
      contract_expiry s.leg1.leg_sec_idx
    else
      contract_expiry s.leg2.leg_sec_idx in
  
  if (month_to_int exp) < (month_to_int (contract_expiry s.leg2.leg_sec_idx)) then
    exp
  else
    contract_expiry s.leg2.leg_sec_idx
;;

(* Return true if s1 should implied uncross before s2 *)
let priority_strat (s1 : strategy) (s2 : strategy) =
  (*
    1. time to expiry of the nearest leg
    2. strategy types (strategies with the greater leg ratio executed first)
    3. strategy creation times *)
  if (month_to_int (nearest_time_to_exp s1)) < (month_to_int (nearest_time_to_exp s2)) then
    true
  else 
    if (leg_ratio s1) > (leg_ratio s2) then
      true
    else
      s1.time_created <= s2.time_created
```

```{.imandra .input}
let transitivity s1 s2 s3 =
 ((priority_strat s1 s2) && (priority_strat s2 s3)) ==> (priority_strat s1 s3)
 
verify transitivity
```

*Ooops! It seems that our ranking criteria is not transitive. Let's check the results (note that the counter examples are now reflected into the run time in the CX module)*

```{.imandra .input}
priority_strat CX.s1 CX.s2
```

```{.imandra .input}
priority_strat CX.s2 CX.s3
```

```{.imandra .input}
priority_strat CX.s1 CX.s3
```

### 3.2 Implied strategy price calculation

```{.imandra .input}
(* return the sum of volume at the highest level *)
let rec get_level_sums (orders : order list) (li : level_info option) =
  match orders with 
  | [] -> li
  | x::xs ->
    begin
      match li with
      | None -> get_level_sums xs (Some {li_qty = x.o_qty; li_price = x.o_price})
      | Some l ->
        if (l.li_price = x.o_price) then
          get_level_sums xs (Some {l with li_qty = l.li_qty + x.o_qty})
        else
          li
    end

(* Return best bid/ask levels *)
let get_book_tops (b : book) = 
  let bid_info = get_level_sums b.b_buys None in
  let ask_info = get_level_sums b.b_sells None in
  { bid_info; ask_info }
;;

(* Get the maximum number of strategy units here *)
(* Note that the units may have different signs, so we 
 need to make sure that we have enough *)
let calc_implied_strat_order (sid : strategy_id) (s : strategy) (books : books_info) (si : side) (time : int) =
  let abs x = if x < 0 then -x else x in

  let adjust (mult : int) =
    if si = BUY then mult else -mult in

  (* *)
  let calc_max_out_mult (mult : int) (book : best_bid_ask)  =
    if mult = 0 then
      None
    else
      begin
       if (adjust mult) > 0 then
        match books.book1.bid_info with
           | Some x -> Some (x.li_qty / (abs mult))
           | None -> None
       else
           match book.ask_info with
           | Some x -> Some (x.li_qty / (abs mult))
           | None -> None
      end in

  let mult1 = calc_max_out_mult s.leg1.leg_mult books.book1 in
  let mult2 = calc_max_out_mult s.leg2.leg_mult books.book2 in
  let mult3 = calc_max_out_mult s.leg3.leg_mult books.book3 in

  (* Compute the quantity *)
  let max_strat = 
    begin 
       match mult1 with 
       | None -> 0
       | Some x -> x
    end in
  let max_strat = 
    begin
       match mult2 with
       | None -> max_strat
       | Some x -> if x < max_strat then x else max_strat
    end in
  let max_strat = 
    begin
     match mult3 with
     | None -> max_strat
     | Some x -> if x < max_strat then x else max_strat
    end in

  (* Now compute the price *)
  let strat_price = 
    begin 
       match mult1 with 
       | None -> 0
       | Some x -> 
         begin
            if (adjust s.leg1.leg_mult) > 0 then
                match books.book1.bid_info with
                | Some x -> x.li_price * (adjust s.leg1.leg_mult)
                | None -> 0
            else
                match books.book1.ask_info with
                | Some x -> x.li_price * (adjust s.leg1.leg_mult)
                | None -> 0
         end
    end in
  let strat_price = 
    begin 
       match mult2 with 
       | None -> strat_price
       | Some x -> 
         begin
            if (adjust s.leg2.leg_mult) > 0 then
                match books.book2.bid_info with
                | Some x -> x.li_price * (adjust s.leg2.leg_mult) + strat_price
                | None -> strat_price
            else
                match books.book2.ask_info with
                | Some x -> x.li_price * (adjust s.leg2.leg_mult) + strat_price
                | None -> strat_price
         end
    end in
  let strat_price = 
    begin 
       match mult3 with 
       | None -> strat_price
       | Some x -> 
         begin
            if (adjust s.leg3.leg_mult) > 0 then
                match books.book3.bid_info with
                | Some x -> x.li_price * (adjust s.leg3.leg_mult) + strat_price
                | None -> strat_price
            else
                match books.book3.ask_info with
                | Some x -> x.li_price * (adjust s.leg3.leg_mult) + strat_price
                | None -> strat_price
         end
    end in

  (* Now form the new implied order here... *)
  {
   o_qty = max_strat
   ; o_price = strat_price
   ; o_id = -1
   ; o_time = time
   ; o_side = si
   ; o_client_id = -1
   ; o_inst = Strategy sid
   ; o_is_implied = true }
;;
```

Let's now try to experiment with this.

```{.imandra .input}
let strat1 = {
  time_created = 1;
  leg1    = { leg_sec_idx = OUT1; leg_mult = 1 }
  ; leg2  = { leg_sec_idx = OUT2; leg_mult = 0 }
  ; leg3  = { leg_sec_idx = OUT3; leg_mult = 0 }
};;

let books = {
    book1 = { bid_info = None ; ask_info = Some { li_qty = 100 ; li_price = 450 }}
  ; book2 = { bid_info = Some { li_qty = 125 ; li_price = 100 }; ask_info = Some { li_qty = 100 ; li_price = 350 }}
  ; book3 = { bid_info = None ; ask_info = Some { li_qty = 100 ; li_price = 425 }} 
};;

(* This should just replicate the OUT1 security on the SELL side *)
calc_implied_strat_order STRAT1 strat1 books SELL 1
```

```{.imandra .input}
(* Now let's try the same on the BUY side - there should not be any available orders as the bid is empty *)
calc_implied_strat_order STRAT1 strat1 books BUY 1
```

```{.imandra .input}
(* let's try to mix up the legs now *)

let strat2 = {
 strat1 with
 leg2 = {leg_sec_idx = OUT2; leg_mult = -1}
};;

(* This will not result in any orders because there's no BUY *)
calc_implied_strat_order STRAT1 strat2 books BUY 1
```

```{.imandra .input}
calc_implied_strat_order STRAT2 strat2 books SELL 1
```

```{.imandra .input}
let strat = {
  time_created = 1;
  leg1    = { leg_sec_idx = OUT1; leg_mult = 1 }
  ; leg2  = { leg_sec_idx = OUT2; leg_mult = -2 }
  ; leg3  = { leg_sec_idx = OUT3; leg_mult = 0 }
};;

let books = {
    book1 = { bid_info = Some { li_qty = 500; li_price = 50 } ; ask_info = Some { li_qty = 750 ; li_price = 50 }}
  ; book2 = { bid_info = Some { li_qty = 200 ; li_price = 60 }; ask_info = Some { li_qty = 500 ; li_price = 70 }}
  ; book3 = { bid_info = None ; ask_info = None } 
};;

calc_implied_strat_order STRAT1 strat books BUY 1
```

### 3.3 Implied uncrossing operations

```{.imandra .input}

(* removes implied orders from a book *)
let remove_imp_orders (b : book) =
  let rec remove_imp_orders_side (orders : order list) = 
    match orders with
    | [] -> []
    | x::xs -> 
        if x.o_is_implied then 
          (remove_imp_orders_side xs)
        else
          x::(remove_imp_orders_side xs) in
    
  { b_buys = (remove_imp_orders_side b.b_buys)
  ; b_sells = (remove_imp_orders_side b.b_sells)
  }

(* Allocate implied fills to the book and return fills *)
let allocate_implied_fills (b : book) (qty : int) (price : int) (time : int) = 
  if qty = 0 then {
    uncrossed_book = b
    ; uncrossed_fills = []
    ; uncrossed_qty = 0
  } else 
  begin
    (* Insert new order into the book and uncross it *)
    let new_order = {
      o_qty = if qty < 0 then (-qty) else qty
      ; o_price = price
      ; o_id = -1
      ; o_time = time
      ; o_side = if qty < 0 then SELL else BUY
      ; o_client_id = -1
      ; o_inst = Outright OUT1
      ; o_is_implied = true
    } in 
    
    (* create new order that we will trade *)
    let b' = insert_order new_order b in

    (* finally we will uncross the book and return results *)
    (uncross_book b' [] 0)
  end

(* Calculate the price at which implied orders should trade in the outright books *)
let calc_implied_trade_price (mult : int) (bidask : best_bid_ask) =
  if mult > 0 then
   begin
    match bidask.ask_info with
      | None -> 0
      | Some x -> x.li_price
    end
  else
    begin
        match bidask.bid_info with
          | None -> 0
          | Some x -> x.li_price
    end
;;

```

### 3.4 Implied uncrossing (for single side)

```{.imandra .input}
(* The actual cycle *)
let implied_uncross_side (sd : side) (s_id : strategy_id) (s : strategy) (m : market) =

  (* 0. get the top of the book s*)
  let book1 = get_book_tops m.out_book1 in
  let book2 = get_book_tops m.out_book2 in
  let book3 = get_book_tops m.out_book3 in 

  let books_tops = { book1; book2; book3 } in

  (* 1. calculate the implied orders that are available right now... *)
  let imp_order = calc_implied_strat_order s_id s books_tops sd m.curr_time in

  (* Need to increase the order ID first *)
  let new_ord_id = m.last_ord_id + 1 in

  (* 2. insert them into the order book *)
  let strat_book =
    begin
      match s_id with
      | STRAT1 -> insert_order { imp_order with o_id = new_ord_id } m.s_book1
      | STRAT2 -> insert_order { imp_order with o_id = new_ord_id } m.s_book2
    end in

  (* 3. perform the uncross - get the fills, etc... *)
  let unc_result = uncross_book strat_book [] 0 in

  let fq = unc_result.uncrossed_qty in

  if fq = 0 then
    (* Since we didn't trade anything, let's just return the original market state *)
    m
  else
  
  let adjust (mult : int) =
    let mult = -mult in
    if sd = BUY then mult else -mult in
  
  let adj_mul1 = adjust s.leg1.leg_mult in
  let adj_mul2 = adjust s.leg2.leg_mult in
  let adj_mul3 = adjust s.leg3.leg_mult in
  
  (* calculate the prices at which outright orders will trade *)
  let price1 = calc_implied_trade_price adj_mul1 book1 in
  let price2 = calc_implied_trade_price adj_mul2 book2 in
  let price3 = calc_implied_trade_price adj_mul3 book3 in

  (* 4. allocate fills to the outright orders *)
  let out_book1_res = allocate_implied_fills m.out_book1 (fq * adj_mul1) price1 m.curr_time in
  let out_book2_res = allocate_implied_fills m.out_book2 (fq * adj_mul2) price2 m.curr_time in
  let out_book3_res = allocate_implied_fills m.out_book3 (fq * adj_mul3) price3 m.curr_time in

  (* 5. remove the implied orders - notice that the uncrossed result contains a new book
    with partial fills *)
  let m = match s_id with
  | STRAT1 -> { m with s_book1 = remove_imp_orders unc_result.uncrossed_book }
  | STRAT2 -> { m with s_book2 = remove_imp_orders unc_result.uncrossed_book } in

  (* 6. let's now gather all of the fills and turn them into outbound messages *)
  let new_fill_msgs = create_fill_msgs (unc_result.uncrossed_fills @ out_book1_res.uncrossed_fills
    @ out_book2_res.uncrossed_fills @ out_book3_res.uncrossed_fills) in

  { m with 
    outbound_msgs = new_fill_msgs @ m.outbound_msgs
    ; out_book1 = out_book1_res.uncrossed_book
    ; out_book2 = out_book2_res.uncrossed_book
    ; out_book3 = out_book3_res.uncrossed_book
    ; last_ord_id = new_ord_id }
;;

```

Let's now experiment with some concrete examples.

```{.imandra .input}
#program;;
(* #remove_doc doc_of_market;; *)
#logic;;

let strat = {
  time_created = 1;
  leg1    = { leg_sec_idx = OUT1; leg_mult = 1 }
  ; leg2  = { leg_sec_idx = OUT2; leg_mult = -2 }
  ; leg3  = { leg_sec_idx = OUT3; leg_mult = 0 }
};;

let books = {
    book1 = { bid_info = Some { li_qty = 500; li_price = 50 } ; ask_info = Some { li_qty = 750 ; li_price = 50 }}
  ; book2 = { bid_info = Some { li_qty = 200 ; li_price = 60 }; ask_info = Some { li_qty = 500 ; li_price = 70 }}
  ; book3 = { bid_info = None ; ask_info = None } 
};;

let m = {
  curr_time = 1
  
  ; last_ord_id = 0

  (* first strategy is 2*x1 - x2 + x3 *)
  ; strat1 = (make_strat 1 2 (-1) 1)
  (* second strategy is just the 3rd outright security *)
  ; strat2 = (make_strat 2 0 1 0)

  (* outright books *)
  ; out_book1 = { 
    b_buys = [ (make BUY 500 50 1 (Outright OUT1) 1 false 1) ]
    ; b_sells = [ (make SELL 750 55 2 (Outright OUT1) 1 false 1) ] 
  }

  ; out_book2 = {
    b_buys = [ (make BUY 200 60 3 (Outright OUT1) 1 false 1) ]
    ; b_sells = [ (make SELL 500 70 4 (Outright OUT1) 1 false 1) ] 
  }

  ; out_book3 = { 
    b_buys = [ ]
    ; b_sells = [] 
  }

  (* Strategy books *)
  ; s_book1 = { 
    b_buys = [ 
    ]
    ; b_sells = [
      (make SELL 100 (-100) 5 (Strategy STRAT1) 1 false 1)
    ] 
  }
  ; s_book2 = empty_book

  (* Inbound and outbound message queues *)
  ; inbound_msgs = [] 
  ; outbound_msgs = []
} in

let m' = implied_uncross_side BUY STRAT1 strat m in

(*calc_implied_strat_order STRAT1 m.strat1 books BUY 1 *)
m'.outbound_msgs

```

### 3.5 Implied uncrossing decomposition

```{.imandra .input}
(* Let's try to decompose the logic of 'implied_uncross_side' - we will put 
   several functions in the basis to focus on the critical aspects of the logic *)
let d = Modular_decomp.top "implied_uncross_side" 
        ~basis:["get_book_tops"; "allocate_implied_fills"; "insert_order";
        "create_fill_msgs"; "calc_implied_strat_order"] ~prune:true [@@program];;
    
```

### 3.6 Full book implied uncross

```{.imandra .input}
(* The implied uncross algorithm *)
let implied_uncross_books (s : strategy_id) (m : market) =
  if s = STRAT1 then
    begin
      let m = implied_uncross_side BUY s m.strat1 m in
      implied_uncross_side SELL s m.strat1 m
    end
  else 
    begin
      let m = implied_uncross_side BUY s m.strat2 m in
      implied_uncross_side SELL s m.strat2 m
    end

```

## 4. Global state transition functions functions
### 4.1 Insert order

```{.imandra .input}
(* Perform operation to create and insert a new order *)
let run_new_order (m : market) (no : new_ord_msg) =
  let new_o_id = m.last_ord_id + 1 in
  let o = {
    o_id = new_o_id
    ; o_qty = no.no_qty
    ; o_price = no.no_price
    ; o_time = m.curr_time
    ; o_side = no.no_side
    ; o_client_id = no.no_client_id
    ; o_inst = no.no_inst_type
    ; o_is_implied = false (* these are always outright *)
  } in

  let m' = 
    match no.no_inst_type with 
    | Strategy STRAT1 -> { m with s_book1 = (insert_order o m.s_book1) }
    | Strategy STRAT2 -> { m with s_book2 = (insert_order o m.s_book2) }
    | Outright OUT1   -> { m with out_book1 = (insert_order o m.out_book1) }
    | Outright OUT2   -> { m with out_book2 = (insert_order o m.out_book2) }
    | Outright OUT3   -> { m with out_book3 = (insert_order o m.out_book3) }

  in { m' with last_ord_id = new_o_id }

```

### 4.2 Cancel order

```{.imandra .input}
(* Cancel an order *)
let run_cancel_order (m : market) (co : cancel_ord_msg) = 
  match co.co_instrument with
  | Strategy STRAT1 -> {m with s_book1 = (cancel_ord_book co m.s_book1)}
  | Strategy STRAT2 -> {m with s_book2 = (cancel_ord_book co m.s_book2)}
  | Outright OUT1 -> {m with out_book1 = (cancel_ord_book co m.out_book1)}
  | Outright OUT2 -> {m with out_book2 = (cancel_ord_book co m.out_book2)}
  | Outright OUT3 -> {m with out_book3 = (cancel_ord_book co m.out_book3)}

```

### 4.3 Run implied uncross

```{.imandra .input}
(* Perform opreation to execute new fill *)
let run_implied_uncross (m : market) = 

  (* Do the typical uncross between the strategies *)
  let sbook1_res = uncross_book m.s_book1 [] 0 in
  let sbook2_res = uncross_book m.s_book2 [] 0 in 

  (*  outright books  *)
  let obook1_res = uncross_book m.out_book1 [] 0 in
  let obook2_res = uncross_book m.out_book2 [] 0 in
  let obook3_res = uncross_book m.out_book3 [] 0 in
  
  (* Now let's update the entire market state *)
  let m' = {
    m with
      s_book1 = sbook1_res.uncrossed_book
      ; s_book2 = sbook2_res.uncrossed_book

      ; out_book1 = obook1_res.uncrossed_book
      ; out_book2 = obook2_res.uncrossed_book
      ; out_book3 = obook3_res.uncrossed_book

      ; outbound_msgs = 
          create_fill_msgs (
            sbook1_res.uncrossed_fills @
            sbook2_res.uncrossed_fills @
            obook1_res.uncrossed_fills @
            obook2_res.uncrossed_fills @ 
            obook3_res.uncrossed_fills )
  } in

  (* Now we should be done with uncrossing the books the old way,
    let's now create implied orders here. 
    Notice that we're using the priority function to determine which 
    strategy order book runs first... *)
  if priority_strat m'.strat1 m'.strat2 then
    let m' = implied_uncross_books STRAT1 m' in
    (implied_uncross_books STRAT2 m')
  else
    let m' = implied_uncross_books STRAT2 m' in
    (implied_uncross_books STRAT1 m')

;;
```

```{.imandra .input}
(* Now is a time for a full market uncross. *)

let m2 = {
  curr_time = 1
  
  ; last_ord_id = 0
  
  (* In a larger model, we can *)
  (* first strategy is 2*x1 - x2 + x3 *)
  ; strat1 = (make_strat 1 2 (-1) 1)
  (* second strategy is just the 3rd outright security *)
  ; strat2 = (make_strat 2 0 1 0)

  (* outright books *)
  ; out_book1 = { 
    b_buys = [ (make BUY 500 50 1 (Outright OUT1) 1 false 1) ]
    ; b_sells = [ (make SELL 750 55 2 (Outright OUT1) 1 false 1) ] 
  }

  ; out_book2 = {
    b_buys = [ (make BUY 200 60 3 (Outright OUT1) 1 false 1) ]
    ; b_sells = [ (make SELL 500 70 4 (Outright OUT1) 1 false 1) ] 
  }
  ; out_book3 = empty_book

  (* Strategy books *)
  ; s_book1 = empty_book
  ; s_book2 = empty_book

  (* Inbound and outbound message queues *)
  ; inbound_msgs = [] 
  ; outbound_msgs = []
}
```

### 4.4 Main transition function
This is where we put it all together. Note that this is a 'shortened' version of the full model - in a complete model we would allow new strategies to be created, more intricate state transitions (e.g. auctions) and much more.

```{.imandra .input}
(* The main state transition loop of the exchange state *)
let step (m : market) (msg : inbound_msg) = 
 begin
  match msg with
  | NewOrder no -> run_new_order m no
  | CancelOrder co -> run_cancel_order m co
  | ImpliedUncross -> run_implied_uncross m
 end
;;

let rec run (m: market) (msgs : inbound_msg list) =
 match msgs with
 | [] -> []
 | x::xs -> let m' = step m x in
   m' :: (run m' xs)
;;

```

## 5.  Complete examples

Now let's have a complete example that shows how to insert and then trade outright and strategy orders

```{.imandra .input}
let m4 = {

  curr_time = 1
  
  ; last_ord_id = 0
  
  (* first strategy is 2*x1 - x2 + x3 *)
  ; strat1 = (make_strat 1 2 (-1) 1)
  (* second strategy is just the 3rd outright security *)
  ; strat2 = (make_strat 2 0 0 1)

  (* outright books *)
  ; out_book1 = empty_book
  ; out_book2 = empty_book
  ; out_book3 = empty_book

  (* Strategy books *)
  ; s_book1 = empty_book
  ; s_book2 = empty_book

  (* Inbound and outbound message queues *)
  ; inbound_msgs = []
  ; outbound_msgs = []
} in

(* Helper function signature is: 'cid inst qty sd p'*)
let new_ord1_msg = make_no_msg 1 (Outright OUT1) 100 SELL 75 in
let new_ord2_msg = make_no_msg 2 (Outright OUT1) 75 BUY 80 in
let new_ord3_msg = make_no_msg 3 (Outright OUT1) 125 SELL 50 in

run m4 [new_ord1_msg; new_ord2_msg; new_ord3_msg];;

```

```{.imandra .input}

```
