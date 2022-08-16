---
title: "Solving the countdown maths game."
description: "How to use an evaluator in imandra to solve the countdown maths problem."
kernel: imandra
slug: countdown
key-phrases:
  - OCaml
  - proof
  - instance
difficulty: easy
---

# Stating the problem

The famous decideable but combinatorially tricky countdown mathematics problem is one which is very simply stated for example in prolog:

```
my_delete([H|T],H,T).
my_delete([H|T],H2,[H|T2]) :-
	my_delete(T,H2,T2).


calculate(Nums,Total,[]) :- member(Total,Nums).

calculate(Nums,Total,[Op|T2]) :- 
	my_delete(Nums,H1,Rest1),
	my_delete(Rest1,H2,Rest),
	operation(H1,H2,Op,Numpair),
	calculate([Numpair|Rest],Total,T2).


operation(Num1,Num2,plus(Num1,Num2,Out),Out) :- Out is Num1 + Num2.
operation(Num1,Num2,times(Num1,Num2,Out),Out) :- \+ Num1 is 1,\+ Num2 is 1, Out is Num1 * Num2.
operation(Num1,Num2,minus(Num1,Num2,Out),Out) :- Out is Num1 - Num2,\+ Out < 1.
operation(Num1,Num2,divides(Num1,Num2,Out),Out) :- \+ Num2 = 0,\+ Num2 = 1,Out is Num1/Num2,0 is Num1 mod Num2.
```


We can write this in imandra and reason about the functions:

```{.imandra .input}
module R = struct

  type t = int

  let (+) x y = x + y

  let (-) x y = x - y

  let rec ( * ) x y =
    if x = 0 then (
      0
    ) else if x < 0 then (
      0 - ((0 - x) * y)
    ) else (
      y + ((x-1) * y)
    )
  [@@measure Ordinal.of_int (if x < 0 then (1-x) else x)]

  let rec div_psd x y =
    if y <= 0 then (
      0
    ) else (
      if x < y then (
        0
      ) else (
        1 + (div_psd (x-y) y)
      )
    )

  (* Note: This is only equal to our standard Z.ediv (/) for psd args. *)
  let (/) x y =
    if (x >= 0) then (
      if (y >= 0) then (
        div_psd x y
      ) else (
        0 - (div_psd x (0-y))
      )
    ) else if (y >= 0) then (
        0 - (div_psd (0-x) y)
      ) else (
      0 - div_psd (0-x) (0-y)
    )

  let total_div x y =
    if y = 0 then (
      0
    ) else (
      x/y
    )

  let rec mod_psd x y =
    if y <= 0 then (
      0
    ) else (
      if x < y then (
        x
      ) else (
        mod_psd (x-y) y
      )
    )

  (* Note: This is only equal to our standard mod for psd args. *)
  let (mod) x y =
    if (x >= 0) then (
      if (y >= 0) then (
        mod_psd x y
      ) else (
        0 - (mod_psd x (0-y))
      )
    ) else if (y >= 0) then (
      0 - (mod_psd (0-x) y)
    ) else (
      0 - mod_psd (0-x) (0-y)
    )

end

open R

type op =
  | Plus
  | Times
  | Divides
  | Minus;;

type op_choice = {
    op:op
  ; one:int 
  ; two:int
};;

let rec choose_and_rest (num:int) (nums:int list) (rest:int list): bool = 
  match nums with 
  | [] -> false
  | n::r when n=num && r = rest -> true 
  | n::r -> choose_and_rest num r (n::rest);;

let rec rest (a:int) (l:int list) : int list = 
  match l with 
  | [] -> []
  | h::t when h = a -> t 
  | h::t -> h::(rest a t);;

let calc op =
   match op.op with 
  | Plus -> op.one + op.two 
  | Minus -> op.one - op.two 
  | Times -> op.one * op.two 
  | Divides -> op.one / op.two
;;

let valid_choice op nums = 
  List.mem op.one nums && List.mem op.two nums &&
  match op.op with 
  | Divides ->  op.one <> 0 && op.one <> 1 && op.two <> 1 && op.two <> 0 && op.one mod op.two = 0
  | Minus -> op.one > op.two
  | _ -> true
;;

let choose (nums:int list) (op:op_choice) (resta:int list) (restb:int list) (ans:int) : bool = 
  valid_choice op nums && 
  choose_and_rest op.one nums resta &&
  choose_and_rest op.two resta restb && 
  calc op = ans 
;;

let rec apply_choices (choices:op_choice list) (nums:int list) (target:int) : bool = 
  List.length choices < List.length nums && 
  match choices with 
  | [] -> false
  | op::t -> 
      valid_choice op nums &&
      let resta = rest op.one nums in 
      let restb = rest op.two resta in
      (choose nums op resta restb target && List.is_empty t) ||
      apply_choices t ((calc op)::restb) target
;;
```

Let's use it to find a solution to a simple problem:

```{.imandra .input}
instance (fun cs -> apply_choices cs [2;3;4;5] 17);; 
```

We can use trace to see the operations performed here:

```{.imandra .input}
#trace apply_choice;;
apply_choices CX.cs [2;3;4;5] 17;;
```

Also we can verify some properties - for example that reversing the numbers chosen has no effect on the result:

```{.imandra .input}
#untrace apply_choice;;
verify (fun x y nums target -> apply_choices x nums target ==> apply_choices x (List.rev nums) target);; 
```

or that if you find a set of operations which find a solution, adding any new operations does not affect this result:

```{.imandra .input}
verify (fun x y nums target -> apply_choices x nums target ==> apply_choices (x@y) nums target);; 
```

or we can prove that if you subtract one from each of the answers this does not maintain the result:

```{.imandra .input}
verify (fun x y nums target -> apply_choices x nums target ==> apply_choices x (List.map (fun x -> x-1)  nums) target);; 
```

It is possible also to use imandra in a more substantial way, to solve the same problem using an evaluator:

```{.imandra .input}
#program;;
type op =
  | Plus
  | Times
  | Divides
  | Minus;;

type op_choice = {
    op:op
  ; one:int 
  ; two:int
};;

let rec rest (a:int) (l:int list) : int list = 
  match l with 
  | [] -> []
  | h::t when h = a -> t 
  | h::t -> h::(rest a t)
;;

let calc op =
   match op.op with 
  | Plus -> op.one + op.two 
  | Minus -> op.one - op.two 
  | Times -> op.one * op.two 
  | Divides -> op.one / op.two
;;

let apply_choice (op:op_choice) (nums:int list) : int list = 
  let resta = rest op.one nums in 
  let restb = rest op.two resta in 
  calc op::restb

let valid_choice op num1 num2 = 
  match op with 
  | Divides ->  num1 <> 0 && num2 <> 1 && num1 <> 1 && num2 <> 0 && num1 mod num2 = 0
  | Minus -> num1 > num2
  | _ -> true
;;

let rec get_possible_pairs nums = match nums with 
  | [] -> [] 
  | [_] -> []
  | h1::t -> 
      (List.map  (fun x -> (h1,x,rest x t)) t)@
      (let res = get_possible_pairs t in List.map (fun (c1,c2,r) -> (c1,c2,h1::r)) res)
;;
    
let rec eval (nums:int list) (target:int) (choices:op_choice list) = 
      if List.mem target nums then Ok choices else 
      if List.length nums=1 then Error 0 else
      let possible_operations = 
        List.fold_left (fun acc (one,two,rest) -> 
          let res =List.filter (
            fun op -> valid_choice op one two
          ) [Plus;Minus;Times;Divides] in 
          let res_rev = List.filter (
            fun op -> valid_choice op two one
          ) [Plus;Minus;Times;Divides] in 
          (List.map (fun op -> 
            {op;one;two}     
            ) (res@res_rev))@acc )       
           [] (get_possible_pairs nums) in 
        let all_evals = List.map (fun c -> 
          c,apply_choice c nums) possible_operations in 
       match List.filter_map (fun (c,nums) -> match eval nums target choices with 
       Ok ans -> Some (c::ans) | _ -> None) all_evals with
       | [] -> Error 0 
       | ans :: _ -> Ok ans
;;
```

which we can then use to solve the infamous problem of obtaining 952 from 25, 50, 75, 100, 3 and 6:

```
 eval [25;50;75;100;3;6] 952 [];; 
```

