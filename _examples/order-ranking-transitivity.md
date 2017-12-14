---
title: "Order ranking transitivity"
excerpt: ""
colName: Examples
permalink: /orderRankingTransitivity/
layout: pageSbar
---
This example is based on our white paper titled 'Case Study: 2015 SEC fine against UBS ATS'. 

As part of the case study, we took the publicly available Form ATS (dated June 1st, 2015) and encoded it as an Imandra venue model. Our goal was to demonstrate how UBS could could have automatically picked up the issues raised by the SEC with Imandra. 

In particular, the report demonstrates verification goals targeting 'sub-penny' pricing and crossing restrictions. In the course of creating the model and verified those goals, we realised that under one interpretation of their Form ATS, their model's ranking function violates transitivity. 

Let us analyse!

#### Transitivity

As a simple example, consider three numbers a, b and c. 

If ```a > b``` and ```b > c```, then it must be true that ```a > c```. This is a fundamental property of the "greater than" function. This property is called *transitivity*. We say that ```>``` is *transitive*. 

When we use a sorting algorithm to sort a list of items with respect to some comparison function, it's important that the comparison be transitive.

Similarly, the way that orders are sorted within an order book must also be transitive. Otherwise, the sorting algorithm may easily rank orders incorrectly, and ensuring regulations like "best execution" becomes hopeless. Flaws like this are very difficult to catch by analysing a venue's post-trade data alone. For example, in modern dark pools, there can be many valid (and legal) reasons why two orders that agree in price will not trade with one another. 

Fundamentally, this is an issue of the matching logic that must be analysed and eliminated.

#### Loading the example in Imandra Cloud

The Examples folder of your Imandra installation should have the full version of the code we're referencing, under ```Transitivity```. So, we will just provide the most relevant fragment here. 

Below we define the function ```order_higher_ranked``` that is used by the sorting algorithm to ensure that the book is always order with respect to priority. 

```ocaml
let order_higher_ranked (side, o1, o2, mkt) =
  let ot1 = o1.order_type in
  let ot2 = o2.order_type in
  let p_price1 = priority_price (side, o1, mkt) in
  let p_price2 = priority_price (side, o2, mkt) in
  
  let wins_price =
    begin
      if side = BUY then
        begin
          if p_price1 > p_price2 then 1
            else if p_price1 = p_price2 then 0
            else -1
        end
      else
        begin
          if p_price1 < p_price2 then 1
          else if p_price1 = p_price2 then 0
          else -1
        end
    end in

  let wins_time = 
    begin
      if o1.time < o2.time then 1
      else if o1.time = o2.time then 0
      else -1
    end in
      (* Note that the CI priority is price, quantity and then time *)
      if wins_price = 1 then true
      else if wins_price = -1 then false
      else
        begin
          (* Same price level - first check to see whether we're comparing two   *)
          (* CI orders here                                                      *)
          if not (non_ci (ot1)) && not (non_ci (ot2)) then
            o1.leaves_qty > o2.leaves_qty
          else
            begin
              if wins_time = 1 then true
              else if wins_time = -1 then false
              else (
                if non_ci(ot1) then true
                else if (not(non_ci(ot1)) && non_ci(ot2)) then false
                else o1.leaves_qty > o2.leaves_qty)
            end
        end
;;
```

Armed with the definition of the ranking function, we're now ready to look for a transitivity counterexample. We will use the check command to start the direct search for it. The code is listed below. Note the constraints that the verification goal lists for the orders and market data. 

```
check _ (side, o1, o2, o3, mkt) =
  
  (order_higher_ranked(side,o1,o2,mkt) &&
    order_higher_ranked(side,o2,o3,mkt) &&
    o1.leaves_qty <= o1.qty &&
    o2.leaves_qty <= o2.qty &&
    o3.leaves_qty <= o3.qty &&
    o1.time >= 0 &&
    o2.time >= 0 &&
    o3.time >= 0 &&
    o1.price > 0.0 &&
    o2.price > 0.0 &&
    o3.price > 0.0 &&
    o1.qty > 0 &&
    o2.qty > 0 &&
    o3.qty > 0 &&
    o1.leaves_qty >= 0 &&
    o2.leaves_qty >= 0 &&
    o3.leaves_qty >= 0 &&
    mkt.nbb > 0.0 &&
    mkt.nbo > 0.0)
  ==>
    order_higher_ranked(side, o1, o3, mkt);;

```

When we run this, Imandra computes the following counterexample:
```
Counterexample:
{ 
  side = SELL;
  o1 = {
    id = 4;
    peg = FAR;
    client_id = 5;
    order_type = PEGGED;
    qty = 2289;
    min_qty = 6;
    leaves_qty = 1052;
    price = 3.0;
    time = 7720;
    src = 7;
    order_attr = RESIDENT;
    capacity = Principal;
    category = C_ONE;
    cross_restrict = {
      cr_self_cross = false;
      cr_ubs_principal = false;
      cr_round_lot_only = false;
      cr_no_locked_nbbo = false;
      cr_pegged_mid_point_mode = 3;
      cr_enable_conditionals = false;
      cr_min_qty = false;
      cr_cat_elig = {
        c_one_elig = false;
        c_two_elig = false;
        c_three_elig = false;
        c_four_elig = false;
      }; 
    }; 
    locate_found = false;
    expiry_time = 8; 
  };
  
  o2 = {
    id = 10;
    peg = FAR;
    client_id = 11;
    order_type = PEGGED_CI;
    qty = 2438;
    min_qty = 12;
    leaves_qty = 1052;
    price = 3.0;
    time = 7721;
    src = 13;
    order_attr = RESIDENT;
    capacity = Principal;
    category = C_ONE;
    cross_restrict = {
      cr_self_cross = false;
      cr_ubs_principal = false;
      cr_round_lot_only = false;
      cr_no_locked_nbbo = false;
      cr_pegged_mid_point_mode = 9;
      cr_enable_conditionals = false;
      cr_min_qty = false;
      cr_cat_elig = {
        c_one_elig = false;
        c_two_elig = false;
        c_three_elig = false;
        c_four_elig = false;
      };
    };
    locate_found = false;
    expiry_time = 14; 
  };
  
  o3 = {
    id = 18;
    peg = NEAR;
    client_id = 19;
    order_type = PEGGED_CI;
    qty = 8856;
    min_qty = 20;
    leaves_qty = 1051;
    price = 3.0;
    time = 7719;
    src = 21;
    order_attr = RESIDENT;
    capacity = Principal;
    category = C_ONE;
    cross_restrict = {
      cr_self_cross = false;
      cr_ubs_principal = false;
      cr_round_lot_only = false;
      cr_no_locked_nbbo = false;
      cr_pegged_mid_point_mode = 17;
      cr_enable_conditionals = false;
      cr_min_qty = false;
      cr_cat_elig = { 
        c_one_elig = false;
        c_two_elig = false;
        c_three_elig = false;
        c_four_elig = false; 
      }; 
    };
    locate_found = false;
    expiry_time = 22; 
  };
  
  mkt = {
    nbb = 1.0;
    nbo = 2.0;
    l_up = 4.0;
    l_down = 5.0; 
  }; 
}
```
