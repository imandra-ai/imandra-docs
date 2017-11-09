---
title: "Induction and Termination"
excerpt: ""
layout: pageSbar
permalink: /selectiveInduction/
colName: Examples
---
Proofs by induction are based upon an *induction principle.*

With induction, we *deduce* a universal property ``Forall x. P(x)`` by assuming the property P holds for some ``smaller'' values, and then combining the results.

Perhaps this reminds you of something: With recursion, we *compute* a value F(x) of a function by first computing F with respect to some ``smaller`` values, and then combining the results.

Indeed, recursion and induction are intimately related.

In Imandra, if we wish to prove a property about a recursive function, we will usually do this by induction. There are many subtleties, e.g., exactly which induction principle should be used, whether or not the formula being proved should be generalised, etc. 

Let us approach these subjects with concrete examples.
[block:api-header]
{
  "type": "basic",
  "title": "1. Deleting an element preserves sorting"
}
[/block]
Note the use of the custom termination measure below. This gives us a simpler induction principle than the default, which allows us to prove our goal sorted_stable. (Will write more soon!).
[block:code]
{
  "codes": [
    {
      "code": "let rec is_sorted (xs) =\n  match xs with\n  | x :: y :: rest ->\n      x <= y && is_sorted (List.tl xs)\n  | _ -> true\n;;\n\n(* @meta[measure : delete_at]\n    let measure_delete_at (i, xs) = List.length xs\n   @end\n*)\n\nlet rec delete_at (i,xs) =\n  if i < 0 then xs else\n  match xs with\n  | x :: rest ->\n      if i = 0 then\n        rest\n      else\n        x :: delete_at(i-1,rest)\n  | [] -> []\n;;\n\ntheorem[rw] sorted_stable (i,xs) =\n is_sorted xs ==> is_sorted(delete_at(i,xs))\n;;",
      "language": "scala",
      "name": "Imandra"
    }
  ]
}
[/block]
