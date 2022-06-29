```{.imandra .input}
type node = int;;
type node_with_edges = (node * node list)
type graph = node_with_edges list;;
type path = node list;;

#max_induct 1;;

let empty : graph = List.empty;;

let key_of (x : node_with_edges) = fst x;;

let edges_of (x : node_with_edges) = snd x;;

let all_nodes (g: graph) : node list =
    List.map (fun (x : node_with_edges) -> fst x) g;;

let graph_mem (x : node) (g : graph) = List.mem x (all_nodes g);;

let get_node_with_edges n g =
    List.find (fun x -> fst x = n) g;;
```

```{.imandra .input}
lemma graph_mem_all_nodes x g = 
    (graph_mem x g) [@trigger] ==> List.mem x (all_nodes g) [@@auto] [@@gen] [@@fc];;
```

```{.imandra .input}
#require "imandra-discover-bridge";;
open Imandra_discover_bridge.User_level;;
```

```{.imandra .input}
let rec neighbors (n : node) (g : graph) =
    match g with
    | [] -> []
    | x :: xs ->
        if n = fst x then snd x else
        neighbors n xs;;

lemma neighbors_gen n g =
    (neighbors n g) [@trigger] <> [] ==> graph_mem n g [@@gen] [@@auto];;

let rec no_duplicates l =
    match l with
    | [] -> true
    | x :: xs -> if List.mem x xs then false else no_duplicates xs;;

let rec subset l1 l2 =
    match l1 with
    | [] -> true
    | x :: xs -> if not (List.mem x l2) then false else subset xs l2;;
```

```{.imandra .input}
verify (fun n g ->
graph_mem (key_of n) g && subset (edges_of n) (all_nodes g) && is_graph g 
==> neighbors (key_of n) g = edges_of n);;
```

Subset lemmas

```{.imandra .input}
lemma subset_cons x y l1 = List.mem x l1 ==> List.mem x (y :: l1) [@@auto];;

lemma subset_sing x y l1 = subset x l1 ==> subset x (y :: l1) [@@fc] [@@auto];;

lemma subset_id x0 = subset x0 x0 [@@auto];;

lemma sing_mem x x1 x2 = List.mem x x1 && subset x1 x2 ==> List.mem x x2 [@@auto] [@@fc];;

lemma subset_cons_sing2 x l = subset l (x @ l) [@@induct structural x] [@@apply subset_id l];;

lemma subset_cons_sing3 x l = subset l (x :: l) [@@auto] [@@apply subset_cons_sing2 [x] l];;

lemma subset_trans l1 l2 l3 = subset l1 l2 && subset l2 l3 ==> subset l1 l3 [@@auto] [@@fc];;
```

```{.imandra .input}
let is_graph2 all_nodes (node,edges) =
    List.mem node all_nodes &&
    subset edges all_nodes &&
    no_duplicates edges;;
    
let is_graph (g : graph) =
    if g = [] then true else
    let all_nodes = all_nodes g in
    no_duplicates all_nodes &&
    List.for_all (is_graph2 all_nodes) g;;
    
verify (fun g1 g2 ->  is_graph (g1 :: g2) && List.for_all (is_graph2 (all_nodes (g1 :: g2))) g2  ==>
        List.for_all (is_graph2 (all_nodes g2)) g2);;

```

```{.imandra .input}
let rec is_path1 path_remaining g = 
    match path_remaining with
    | [] -> true
    | [x] -> if graph_mem x g then true else false
    | x :: xs ->
    (
        let next = List.hd xs in
        if not (graph_mem x g) then false else
        match neighbors x g with
        | [] -> false
        | neighbs -> if List.mem next neighbs then is_path1 xs g else false
    );;

let is_path (p : path) (g : graph) =
    if List.is_empty p then false else
    is_path1 p g

let rec last l =
    match l with
    | [] -> None
    | _ :: [x] -> Some x
    | x :: xs -> last xs;;

let path_from_to p a b g =
    is_path p g && List.hd p = a && last p = Some b;;

let all_graphs g1 g2 g3 = is_graph g1 && is_graph g2;;
let cons_graphs (x : node_with_edges) (g : graph) : graph = x :: g;;
let append_graphs (g1 : graph) (g2 : graph) = g1 @ g2;;

```

Little lemmas

```{.imandra .input}
lemma gcons x y g = graph_mem x g ==> graph_mem x (cons_graphs y g) [@@auto];;

lemma mem_false x = not (List.mem x []) [@@rw] [@@auto];;

```

Termination measure for finding next step

```{.imandra .input}
let rec count_non_members1 all_nodes stack acc =
  match all_nodes with
  | [] -> acc
  | x :: xs -> match List.mem x stack with
               | true -> count_non_members1 xs stack acc
               | false -> count_non_members1 xs stack (acc+1);;

let count_non_members g stack =
  let all_nodes = all_nodes g in
  count_non_members1 all_nodes stack 0;;
  
  
let find_next_step_measure g stack rmder =
  Ordinal.pair
      (Ordinal.of_int ((count_non_members1 (all_nodes g) stack 0) + 1))
      (Ordinal.of_int (List.length rmder));;

```

A whole bunch of lemmas for `find_next_step`

```{.imandra .input}
lemma count_non_id stack acc = count_non_members1 [] stack acc = acc [@@auto] [@@elim];;

lemma count_non_zero nodes acc = count_non_members1 nodes [] acc = acc + List.length nodes [@@auto] [@@rw];;

lemma count_non_zero_bound_upper nodes stack acc = (count_non_members1 nodes stack acc) [@trigger] <= acc + List.length nodes [@@auto] [@@gen] [@@rw] [@@fc];;

lemma count_non_zero_bound_unit_upper nodes x acc = count_non_members1 nodes [x] acc <= acc + List.length nodes [@@auto] [@@rw];;

lemma count_non_zero_bound_unit_upper2 nodes x acc = count_non_members1 nodes [x] acc <= 1 + acc + List.length nodes [@@auto] [@@rw];;

lemma count_non_dec1_non nodes x acc =
      count_non_members1 nodes [x] acc <=
      count_non_members1 nodes [] acc [@@induct structural nodes] [@@rw];;

lemma count_non_members1_dec g x stack acc = (count_non_members1 g (x :: stack) acc) [@trigger] <= acc + List.length g [@@auto] [@@rw] [@@fc];;

lemma count_non_add g stack acc = count_non_members1 g stack (acc+1) = (count_non_members1 g stack acc) + 1 [@@auto] [@@rw];;

(* But if this holds as a hypothesis, then it means that they must be equal. *)
lemma count_non_members_key1 g stack acc x = (count_non_members1 g stack acc <=
                                            count_non_members1 g (x :: stack) acc) ==>
                                            (count_non_members1 g (x :: stack) acc) [@trigger] = count_non_members1 g stack acc [@@induct functional count_non_members1] [@@rw] [@@fc];;

(* Generalization of the previous, with different accumulators! *)
lemma count_non_members_key2 g stack acc1 acc2 x = (count_non_members1 g stack acc1 <=
                                            count_non_members1 g (x :: stack) acc1) ==>
                                            (count_non_members1 g (x :: stack) acc2) = count_non_members1 g stack acc2 [@@induct functional count_non_members1] [@@fc];;

lemma count_non_lemma1 all stack acc = (count_non_members1 all stack acc) [@trigger] >= acc [@@rw] [@@auto] [@@fc] [@@gen];;

lemma adm_lemma0 gen_1 stack nbs1 = count_non_members1 gen_1 stack 1 <=
    count_non_members1 gen_1 (nbs1 :: stack) 1 ==>
    ((count_non_members1 gen_1 (nbs1 :: stack) 1 = count_non_members1 gen_1 stack 1) [@trigger] ||
    stack <> []) [@@auto] [@@rewrite] [@@fc];;

lemma adm_lemma1 gen_2 stack gen_1 = count_non_members1 gen_2 stack 1 <= count_non_members1 gen_2 gen_1 0 ==>
                                     (count_non_members1 gen_2 gen_1 0 = count_non_members1 gen_2 stack 1) [@trigger] ||
                                     stack <> [] [@@auto] [@@rw] [@@fc];;

lemma adm_lemma2_1 g stack x acc = count_non_members1 g stack acc <= count_non_members1 g (x :: stack) acc ==>
                                   (count_non_members1 g (x :: stack) acc) [@trigger] = count_non_members1 g stack acc [@@auto] [@@rw] [@@fc];;

lemma adm_lemma3_helper g stack x acc1 acc2 = count_non_members1 g stack acc1 <= count_non_members1 g (x :: stack) acc1 ==>
                                              count_non_members1 g stack acc2 <= count_non_members1 g (x :: stack) acc2
                                              [@@auto] [@@fc];;

lemma adm_lemma3_1 g1 g2 x stack acc = List.mem x g2 && count_non_members1 (g1 :: g2) stack acc <= count_non_members1 (g1 :: g2) (x :: stack) acc ==> List.mem x stack [@@auto] [@@fc];;
lemma adm_lemma3_2 g x stack acc = List.mem x g && count_non_members1 g stack acc <= count_non_members1 g (x :: stack) acc ==> List.mem x stack [@@induct functional count_non_members1] [@@fc];;

lemma adm_lemma4 g x stack acc = count_non_members1 g stack (acc+1) <= count_non_members1 g (x :: stack) acc ==>
                                 List.mem x stack [@@auto] [@@fc];;
```

This is the important function we needed all of the lemmas for

```{.imandra .input}
let rec find_next_step (nbs : node list) (stack : path) (b : node) (g : graph) =
    if not (is_graph g) then None else
    if not (subset nbs (all_nodes g)) then None else
    if List.mem b nbs then Some (b :: stack) else
    match nbs with
    | [] -> None
    | x :: xs ->
        if List.mem x stack then find_next_step xs stack b g else
        let temp = find_next_step (neighbors x g) (x :: stack) b g in
        match temp with
        | None -> find_next_step xs stack b g
        | Some _ -> temp
        [@@measure find_next_step_measure g stack nbs] [@@auto];;
```

```{.imandra .input}
let rec find_next_step2 (nbs : (node_with_edges) list) 
                        (stack : node_with_edges list) 
                        (b : node_with_edges) 
                        (g : graph) =
    if List.mem b nbs then Some (b :: stack) else
    match nbs with
    | [] -> None
    | x :: xs ->
        if List.mem x stack then find_next_step2 xs stack b g else
        let neighboring_pairs = L in
        let temp = find_next_step2 (neighbors x g) (x :: stack) b g in
        match temp with
        | None -> find_next_step2 xs stack b g
        | Some _ -> temp
        [@@measure find_next_step_measure g stack nbs] [@@auto];;
```

```{.imandra .input}
lemma fns_empty_list nbs stack b = subset nbs (all_nodes []) ==> 
    find_next_step nbs stack b [] = None [@@auto] [@@rw];;
```

```{.imandra .input}
let find_path a b g =
    if not (graph_mem a g) then None else
    if not (graph_mem b g) then None else
    if a = b then Some [a] else
    find_next_step (neighbors a g) [a] b g;;
```

Now that we have the `find_path` function, we'd like to verify that it behaves correctly.  This first lemma ensures that we are getting the correct single path when finding a path from an element to itself.

```{.imandra .input}
lemma find_next_start nbs stack b g x = 
    (find_next_step nbs stack b g = Some x) ==> 
    List.hd x = b [@@auto];;
```

```{.imandra .input}
let res = find_next_step [1] [0; 5] 1 [(1,[])];;
verify ( fun nbs stack b g x y z -> 
    subset nbs (all_nodes g) &&
    (find_next_step nbs stack b g = Some (x :: (y :: z))) ==> 
    List.mem x (neighbors y g));;
```

```{.imandra .input}
lemma find_next_mem nbs stack b g x y z = 
    (find_next_step nbs stack b g = Some (x :: (y :: z))) ==> 
    List.mem x (neighbors y g) [@@auto];;
```

```{.imandra .input}
lemma find_path_start a b g x y = 
    (find_path a b g = Some (x :: y)) [@trigger] ==> x = b [@@auto] [@@fc] [@@gen];;
```

```{.imandra .input}
lemma singleton_path_is_path a g =
    graph_mem a g && is_graph g ==>
        match find_path a a g with
        | Some x when x = [a] -> is_path x g
        | _ -> false [@@auto] [@@fc];;
```

```{.imandra .input}
lemma path_found_implies_mem a b g x =
    is_graph g && (find_path a b g = Some x) [@trigger] ==>
    graph_mem a g && graph_mem b g [@@auto] [@@gen] [@@fc];;
```

```{.imandra .input}
verify ~upto:50 (fun a b g ->
    let res = find_path a b g in
    match res with
    | Some x -> is_path x g
    | _ -> true);;
```

```{.imandra .input}
lemma find_path_is_path_lemma0 a b g =
    graph_mem a g && is_graph g ==>
    let res = find_path a b g in
    match res with
    | Some [x] -> a = b
    | _ -> true [@@auto] [@@fc] [@@disable find_path] [@@disable is_graph];;
```

```{.imandra .input}
let is_legit_node n g =
  let key = key_of n in
  let edges = edges_of n in
  graph_mem key g && no_duplicates edges && List.for_all (fun x -> graph_mem x g) edges;;

verify (fun g1 g2 ->
    is_graph g2 && edges_of g1 = [] ==>
    is_graph (g1 :: g2));;
```

```{.imandra .input}
lemma is_graph_cons_not_mem g1 g2 = 
    (is_graph (g1 :: g2)) [@trigger] ==> not (graph_mem (key_of g1) g2) [@@auto] [@@fc];;
```

```{.imandra .input}
lemma find_next_step_nonempty nbs stack b g =
    (find_next_step nbs stack b g = Some []) = false [@@auto] [@@rw];;
```

```{.imandra .input}
lemma find_next_step_nonempty_true nbs stack b g =
    (find_next_step nbs stack b g) [@trigger] <> Some [] [@@auto] [@@gen] [@@fc];;
```

```{.imandra .input}
lemma find_next_step_nonempty_gen nbs stack b g x =
    ((find_next_step nbs stack b g) = Some x) [@trigger] ==> x <> [] [@@auto] [@@gen] [@@fc];;
```

```{.imandra .input}
lemma path_nonempty a b g x =
    (find_path a b g = Some x) [@trigger] ==> x <> [] [@@auto] [@@gen] [@@fc];;
```

```{.imandra .input}
lemma fns_onestep_fc g1 g2 b x =
    is_graph (g1 :: g2) && graph_mem b g2 &&
    find_next_step (edges_of g1) [key_of g1] b (g1 :: g2) = Some x ==>
    is_path x (g1 :: g2) [@@auto];;
```

```{.imandra .input}
verify (fun g1 g2 -> List.for_all (is_graph2 (all_nodes (g1 :: g2))) g2 ==> 
                     List.for_all (is_graph2 (all_nodes g2)) g2);;
```

```{.imandra .input}
#max_induct 1;;
lemma path_lem_start a b p nbs g x y =
    is_graph g ==> 
    ((find_next_step nbs p b g) = Some (x :: y)) [@trigger] ==>
    x = List.hd p [@@auto] [@@fc] [@@gen];;
```

```{.imandra .input}
lemma path_lem a b g x y z = 
    (find_next_step (neighbors a g) [a] b g = Some (x :: (y :: z))) [@trigger] ==>
    List.mem y (neighbors x g) [@@auto] [@@gen] [@@fc];;
```

```{.imandra .input}
verify (fun a b g path x y z ->
 (find_next_step (neighbors a g) [a] b g = Some (x :: (y :: z))) [@trigger] ==>
 List.mem y (neighbors x g));;
```

```{.imandra .input}
lemma fns_onestep2_fc g a b x =
    is_graph g &&
    find_next_step (neighbors a g) [a] b g = Some x ==>
    is_path x g [@@auto];;
```

```{.imandra .input}
#max_induct 1;;
lemma find_path_is_path a b g =
    graph_mem a g && is_graph g ==>
    let res = find_path a b g in
    match res with
    | Some x -> is_path x g 
    | _ -> true [@@induct structural g] [@@disable is_graph] [@@disable graph_mem] [@@disable neighbors]
        [@@disable no_duplicates] [@@disable all_nodes] [@@disable find_path];;
```
