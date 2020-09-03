---
title: "Sudoku"
description: "Crossing the River Safely: a Puzzle"
kernel: imandra
slug: sudoku
difficulty: intermediate
---

# Sudoku

In this notebook we're going to use Imandra to reason about the [classic kind of puzzle](https://en.wikipedia.org/wiki/Sudoku) that you can find everywhere.

(*note*: this example was adapted from code from [Koen Claessen](https://github.com/koengit/) and [Dan Rosén](https://github.com/danr))

We're going to define what a sudoku puzzle is, and how to _check_ if a given sudoku is a solution.
From that we can get Imandra to find solutions for us, without actually writing a sudoku solver.

## Helpers

We're going to define a sudoku as a 9×9 grid.

### Numbers

However, for now, the _bounded model checker_ that comes along with Imandra doesn't handle numbers. We do not need much here besides length, so a unary notation (classic [Peano arithmetic](https://en.wikipedia.org/wiki/Peano_axioms)) will do.

```{.imandra .input}
type nat = Z | S of nat;;

(* readability matters, so we write a pretty-printer for nats *)
let rec int_of_nat = function Z -> 0i | S n -> Caml.Int.(1i + int_of_nat n) [@@program]
let pp_nat out n = Format.fprintf out "%d" (int_of_nat n) [@@program];;
#install_printer pp_nat;;
```

```{.imandra .input}
let rec length = function
  | [] -> Z
  | _ :: tl -> S (length tl)

let n3 = S (S (S Z));;
let n6 = S (S (S n3));;
let n9 = S (S (S n6));;
```

### Rows, columns, blocks

Sudokus have some constraints that work on rows, and some that work on columns.
Using a `transpose` function we can always work on rows.

```{.imandra .input}
(** helper for {!transpose} *)
let rec transpose3 = function
  | [] -> []
  | [] :: tl -> transpose3 tl
  | (_::t) :: tl -> t :: transpose3 tl

let rec get_heads = function
  | [] -> []
  | [] :: tl -> get_heads tl
  | (h :: _) :: tl -> h :: get_heads tl
;;

(** We need a custom termination function here *)
let measure_transpose = function
| [] -> 0
| x :: _ -> List.length x
;;

(** Transpose rows and columns in a list of lists *)
let rec transpose l =
  match l with
  | [] -> []
  | [] :: _ -> []
  | (x1 :: xs) :: xss ->
    (x1 :: get_heads xss) :: transpose (xs :: transpose3 xss)
[@@measure Ordinal.of_int (measure_transpose l)]
;;
```

Now we also need to extract 3×3 blocks for the additional constraint that none of them contains a duplicate.

This require a few helpers on lists and options, nothing too complicated.

```{.imandra .input}
let rec take (x:nat) l : _ list =
  match x with
  | Z -> []
  | S x' ->
    match l with
    | [] -> []
    | y :: tl -> y :: take x' tl

let rec drop x y =
  match x with
  | Z -> y
  | S x' ->
    match y with
    | [] -> []
    | _ :: y' -> drop x' y'

let rec elem x y =  match y with [] -> false | z :: ys -> x=z || elem x ys ;;

(** Is the list [l] composed of unique elements (without duplicates)? *)
let rec unique x : bool =
  match x with
  | [] -> true
  | y :: xs -> not (elem y xs) && unique xs
;;

(** Keep the elements that are [Some _], drop the others *)
let rec keep_some_list l =
  match l with
  | [] -> []
  | y :: tail ->
    let tail = keep_some_list tail in
    match y with None -> tail | Some x -> x :: tail
;;

(** A block is valid if it doesn't contain duplicates *)
let block_satisfies_constraints x = unique (keep_some_list x) ;;

let rec blocks_3_34 = function
  | [] -> []
  | y :: z -> drop n6 y :: blocks_3_34 z
;;

let rec blocks_3_33 = function
  | [] -> []
  | y :: z -> take n3 (drop n3 y) :: blocks_3_33 z
;;

let rec blocks_3_32 = function
  | [] -> []
  | y :: z -> take n3 y :: blocks_3_32 z
;;

(*

let rec group3 = function
  | xs1 :: xs2 :: xs3 :: xss ->
    (xs1 @ xs2 @ xs3) :: (group3 xss)
  | _ -> []
  ;;
*)

let rec group3 = function
  | [] -> []
  | xs1 :: y ->
    match y with
    | [] -> []
    | xs2 :: z ->
      match z with
      | [] -> []
      | xs3 :: xss -> (xs1 @ xs2 @ xs3) :: (group3 xss)
;;

let blocks_3_3 l =
  group3 (blocks_3_32 l) @
    group3 (blocks_3_33 l) @
      group3 (blocks_3_34 l)
;;
```

## The Sudoku type

We're ready to define the sudoku as a list of lists of (possibly empty) cells.

First, cells are just an enumeration of 9 distinct cases:

```{.imandra .input}
type cell = C1 | C2 | C3 | C4 | C5 | C6 | C7 | C8 | C9 ;;

(* let us also write a nice printer for cells. We will put
   it to good use later. *)
let doc_of_cell c =
  Document.s (match c with C1->"1"|C2->"2"|C3->"3"|C4->"4"|C5->"5"|C6->"6"|C7->"7"|C8->"8"|C9->"9") [@@program];;

#install_doc doc_of_cell;;
```

And the sudoku itself:

```{.imandra .input}
type sudoku = { rows: cell option list list } ;;

(* now install a nice printer for sudoku grids *)
let doc_of_sudoku (s:sudoku) : Document.t =
  let module D = Document in
  let d_of_c = function None -> D.s "·" | Some c -> doc_of_cell c in
  D.tbl_of d_of_c s.rows [@@program]
  ;;

#install_doc doc_of_sudoku;;
```

We're going to solve the following instance (still from Dan Rosén and Koen Claessen's code).
The custom printer we installed earlier shows the grid in a readable way.

```{.imandra .input}
let the_problem : sudoku =
  {rows=
    [ [ (Some C8) ; None ; None ; None ; None ; None ; None ; None ; None ];
    [ None ; None ; (Some C3) ; (Some C6) ; None ; None ; None ; None ; None ];
    [ None ; (Some C7) ; None ; None ; (Some C9) ; None ; (Some C2) ; None ; None ];
    [ None ; (Some C5) ; None ; None ; None ; (Some C7) ; None ; None ; None ];
    [ None ; None ; None ; None ; (Some C4) ; (Some C5) ; (Some C7) ; None ; None ];
    [ None ; None ; None ; (Some C1) ; None ; None ; None ; (Some C3) ; None ];
    [ None ; None ; (Some C1) ; None ; None ; None ; None ; (Some C6) ; (Some C8); ];
    [ None ; None ; (Some C8) ; (Some C5) ; None ; None ; None ; (Some C1) ; None ];
    [ None ; (Some C9) ; None ; None ; None ; None ; (Some C4) ; None ; None ];
  ]}
;;
```

```{.imandra .input}
(** All the relevant blocks: rows, columns, and 3×3 sub-squares *)
let blocks (x:sudoku) =
  x.rows @ transpose x.rows @ blocks_3_3 x.rows

(** Are all constraints satisfied? *)
let satisfies_constraints (x:sudoku) = List.for_all block_satisfies_constraints (blocks x);;

(** is a sudoku entirely defined (all cells are filled)? *)
let is_solved (x:sudoku) =
  List.for_all (List.for_all Option.is_some) x.rows;;

(** Is [x] of the correct shape, i.e. a 9×9 grid? *)
let is_valid_sudoku (x:sudoku) =
  length x.rows = n9 &&
  List.for_all (fun col -> length col = n9) x.rows
;;
```

We have a template (the initial problem) and we want to solve it.
It means the sudoku we're looking for must be:

- solved (all cells are `Some _` rather than `None`)
- a solution of the template (i.e. cells defined in the template must match)

```{.imandra .input}
(** Combine lists together *)
let rec zip l1 l2 = match l1, l2 with
  | [], _ | _, [] -> []
  | x1::tl1, x2 :: tl2 -> (x1,x2) :: zip tl1 tl2

let rec match_cols y =
  match y with
  | [] -> true
  | z :: x2 ->
    match z with
    | None,_ | _, None -> match_cols x2
    | (Some n1,Some n2) -> n1=n2 && match_cols x2
;;

let rec match_rows x =
  match x with
  | [] -> true
  | (row1,row2) :: z -> match_cols (zip row1 row2) && match_rows z
;;

(** is [x] a solution of [y]? We check that each cell in each rows,
    if defined in [y], has the same value in [x] *)
let is_solution_of (x:sudoku) (y:sudoku) : bool =
  is_solved x &&
  satisfies_constraints x &&
  match_rows (zip x.rows y.rows)

```

## The Satisfaction of Subrepticiously Solving Sudokus using Satisfiability

We can now, finally, ask Imandra to find a sudoku that satisfies all the constraints defined before!

**NOTE**: we have to use `[@@blast]` because this problem is prone to combinatorial explosion and is too hard for Imandra's default unrolling algorithm.

```{.imandra .input}
instance (fun (s:sudoku) -> is_valid_sudoku s && is_solution_of s the_problem) [@@blast] ;;
```

Let us look at the initial sudoku and its solution side to side:

```{.imandra .input}
Imandra.display (Document.tbl [[doc_of_sudoku the_problem; Document.s "-->"; doc_of_sudoku CX.s]]) ;;
```

We can manipulate `CX.s` easily, directly in OCaml:

```{.imandra .input}
let transpose_sudoku (s:sudoku) : sudoku = {rows = transpose s.rows};;

transpose_sudoku CX.s;;
```
