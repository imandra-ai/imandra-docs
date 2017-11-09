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
[block:api-header]
{
  "type": "basic",
  "title": "Transitivity"
}
[/block]
As a simple example, consider three numbers a, b and c. 

If ```a > b``` and ```b > c```, then it must be true that ```a > c```. This is a fundamental property of the "greater than" function. This property is called *transitivity*. We say that ```>``` is *transitive*. 

When we use a sorting algorithm to sort a list of items with respect to some comparison function, it's important that the comparison be transitive.

Similarly, the way that orders are sorted within an order book must also be transitive. Otherwise, the sorting algorithm may easily rank orders incorrectly, and ensuring regulations like "best execution" becomes hopeless. Flaws like this are very difficult to catch by analysing a venue's post-trade data alone. For example, in modern dark pools, there can be many valid (and legal) reasons why two orders that agree in price will not trade with one another. 

Fundamentally, this is an issue of the matching logic that must be analysed and eliminated.
[block:api-header]
{
  "type": "basic",
  "title": "Loading the example in Imandra Cloud"
}
[/block]
The Examples folder of your Imandra installation should have the full version of the code we're referencing, under ```Transitivity```. So, we will just provide the most relevant fragment here. 

Below we define the function ```order_higher_ranked``` that is used by the sorting algorithm to ensure that the book is always order with respect to priority. 
[block:code]
{
  "codes": [
    {
      "code": "let order_higher_ranked (side, o1, o2, mkt) =\n  let ot1 = o1.order_type in\n  let ot2 = o2.order_type in\n  let p_price1 = priority_price (side, o1, mkt) in\n  let p_price2 = priority_price (side, o2, mkt) in\n  let wins_price = (\n    if side = BUY then\n      ( if p_price1 > p_price2 then 1\n        else if p_price1 = p_price2 then 0\n        else -1)\n    else\n      ( if p_price1 < p_price2 then 1\n        else if p_price1 = p_price2 then 0\n        else -1) ) in\n  let wins_time = (\n    if o1.time < o2.time then 1\n    else if o1.time = o2.time then 0\n    else -1\n  ) in\n  (* Note that the CI priority is price, quantity and then time *)\n  if wins_price = 1 then true\n  else if wins_price = -1 then false\n  else (\n    (* Same price level - first check to see whether we're comparing two   *)\n    (* CI orders here                                                      *)\n    if not (non_ci (ot1)) && not (non_ci (ot2)) then\n      o1.leaves_qty > o2.leaves_qty\n    else ( if wins_time = 1 then true\n           else if wins_time = -1 then false\n           else (\n             if non_ci(ot1) then true\n             else if (not(non_ci(ot1)) && non_ci(ot2)) then false\n             else\n               o1.leaves_qty > o2.leaves_qty)\n         )\n  );;",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
Armed with the definition of the ranking function, we're now ready to look for a transitivity counterexample. We will use the check command to start the direct search for it. The code is listed below. Note the constraints that the verification goal lists for the orders and market data. 
[block:code]
{
  "codes": [
    {
      "code": "check _ (side, o1, o2, o3, mkt) =\n  (order_higher_ranked(side,o1,o2,mkt) &&\n   order_higher_ranked(side,o2,o3,mkt) &&\n       o1.leaves_qty <= o1.qty &&\n       o2.leaves_qty <= o2.qty &&\n       o3.leaves_qty <= o3.qty &&\n       o1.time >= 0 &&\n       o2.time >= 0 &&\n       o3.time >= 0 &&\n       o1.price > 0.0 &&\n       o2.price > 0.0 &&\n       o3.price > 0.0 &&\n       o1.qty > 0 &&\n       o2.qty > 0 &&\n       o3.qty > 0 &&\n       o1.leaves_qty >= 0 &&\n       o2.leaves_qty >= 0 &&\n       o3.leaves_qty >= 0 &&\n       mkt.nbb > 0.0 &&\n       mkt.nbo > 0.0)\n  ==>\n  (order_higher_ranked(side,o1,o3,mkt));;",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
When we run this, Imandra computes the following counterexample:
[block:code]
{
  "codes": [
    {
      "code": "Counterexample:\n  { side = SELL;\n    o1 = { id = 4;\n           peg = FAR;\n           client_id = 5;\n           order_type = PEGGED;\n           qty = 2289;\n           min_qty = 6;\n           leaves_qty = 1052;\n           price = 3.0;\n           time = 7720;\n           src = 7;\n           order_attr = RESIDENT;\n           capacity = Principal;\n           category = C_ONE;\n           cross_restrict = { cr_self_cross = false;\n                              cr_ubs_principal = false;\n                              cr_round_lot_only = false;\n                              cr_no_locked_nbbo = false;\n                              cr_pegged_mid_point_mode = 3;\n                              cr_enable_conditionals = false;\n                              cr_min_qty = false;\n                              cr_cat_elig = { c_one_elig = false;\n                                              c_two_elig = false;\n                                              c_three_elig = false;\n                                              c_four_elig = false; }; };\n           locate_found = false;\n           expiry_time = 8; };\n \n    o2 = { id = 10;\n           peg = FAR;\n           client_id = 11;\n           order_type = PEGGED_CI;\n           qty = 2438;\n           min_qty = 12;\n           leaves_qty = 1052;\n           price = 3.0;\n           time = 7721;\n           src = 13;\n           order_attr = RESIDENT;\n           capacity = Principal;\n           category = C_ONE;\n           cross_restrict = { cr_self_cross = false;\n                              cr_ubs_principal = false;\n                              cr_round_lot_only = false;\n                              cr_no_locked_nbbo = false;\n                              cr_pegged_mid_point_mode = 9;\n                              cr_enable_conditionals = false;\n                              cr_min_qty = false;\n                              cr_cat_elig = { c_one_elig = false;\n                                              c_two_elig = false;\n                                              c_three_elig = false;\n                                              c_four_elig = false; }; };\n \n           locate_found = false;\n           expiry_time = 14; };\n \n    o3 = { id = 18;\n           peg = NEAR;\n           client_id = 19;\n           order_type = PEGGED_CI;\n           qty = 8856;\n           min_qty = 20;\n           leaves_qty = 1051;\n           price = 3.0;\n           time = 7719;\n           src = 21;\n           order_attr = RESIDENT;\n           capacity = Principal;\n           category = C_ONE;\n           cross_restrict = { cr_self_cross = false;\n                              cr_ubs_principal = false;\n                              cr_round_lot_only = false;\n                              cr_no_locked_nbbo = false;\n                              cr_pegged_mid_point_mode = 17;\n                              cr_enable_conditionals = false;\n                              cr_min_qty = false;\n                              cr_cat_elig = { c_one_elig = false;\n                                              c_two_elig = false;\n                                              c_three_elig = false;\n                                              c_four_elig = false; }; };\n           locate_found = false;\n           expiry_time = 22; };\n \n    mkt = { nbb = 1.0;\n            nbo = 2.0;\n            l_up = 4.0;\n            l_down = 5.0; }; }",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
