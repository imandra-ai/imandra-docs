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
lemma list_cons_mem x l = 
    List.mem x (x :: l) [@@auto];;
```

```{.imandra .input}
lemma graph_mem_all_nodes x g = 
    (graph_mem x g) [@trigger] ==> List.mem x (all_nodes g) [@@auto] [@@gen] [@@fc];;
```

```{.imandra .input}

let rec neighbors (n : node) (g : graph) =
    match g with
    | [] -> []
    | x :: xs ->
        if n = fst x then snd x else
        neighbors n xs;; 

(*     
let rec neighbors (n : node) (g : graph) =
    match g with
    | [] -> None
    | x :: xs ->
        if n = fst x then Some (snd x) else
        neighbors n xs;;
*)
(*
lemma neighbors_gen n g =
    (neighbors n g) [@trigger] <> [] ==> graph_mem n g [@@gen] [@@fc] [@@auto];;
*)

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
lemma graph_mem_some x g =
    (graph_mem x g) [@trigger] ==> Option.is_some (get_node_with_edges x g) [@@auto] [@@fc];;
```

Subset lemmas

```{.imandra .input}
lemma subset_cons x y l1 = List.mem x l1 ==> List.mem x (y :: l1) [@@auto];;

lemma subset_sing x y l1 = subset x l1 ==> subset x (y :: l1) [@@fc] [@@auto];;

lemma subset_id x0 = subset x0 x0 [@@auto];;

lemma sing_mem x x1 x2 = (List.mem x x1 && subset x1 x2) [@trigger] ==> List.mem x x2 [@@auto] [@@fc];;

lemma subset_cons_sing2 x l = subset l (x @ l) [@@induct structural x] [@@apply subset_id l];;

lemma subset_cons_sing3 x l = subset l (x :: l) [@@auto] [@@apply subset_cons_sing2 [x] l];;
(*
lemma subset_trans l1 l2 l3 = subset l1 l2 && subset l2 l3 ==> subset l1 l3 [@@auto] [@@fc];;
*)
```

```{.imandra .input}
(*
let is_graph2 g x =
    List.mem (key_of x) (all_nodes g) &&
    subset (edges_of x) (all_nodes g) &&
    no_duplicates (edges_of x);;
*)
(*
let is_graph (g : graph) =
    if g = [] then true else
    let all_nodes = all_nodes g in
    no_duplicates all_nodes &&
    List.for_all (is_graph2 g) g;;
*)

let is_graph2 g x =
    let nbs = neighbors x g in
    graph_mem x g &&
    subset nbs (all_nodes g) &&
    no_duplicates nbs;;
    
let is_graph (g : graph) =
    if g = [] then true else
    let all_nodes = all_nodes g in
    no_duplicates all_nodes &&
    List.for_all (is_graph2 g) all_nodes;;
```

```{.imandra .input}
verify (fun x g -> 
    is_graph g &&
    List.mem x g ==>
    neighbors (key_of x) g = edges_of x);;
```

```{.imandra .input}
lemma forall p x l =
    List.for_all p l && List.mem x l ==> p x [@@auto] [@@fc];;
```

```{.imandra .input}
lemma for_all_lemma g x =
    (List.for_all (is_graph2 g) (all_nodes g) &&
     graph_mem x g) [@trigger] ==> is_graph2 g x [@@auto] [@@simp] [@@fc];;
```

```{.imandra .input}
lemma isgraph2_neighbors_fc x g =
    (is_graph g && graph_mem x g) [@trigger] ==>
    subset (neighbors x g) (all_nodes g) [@@auto] [@@fc];;
```

```{.imandra .input}
verify ~upto:200 (fun x y g ->
    is_graph g &&
    List.mem x g &&
    List.mem y (edges_of x) ==> graph_mem y g
);;
```

```{.imandra .input}
verify ~upto:500 (fun x y g ->
    is_graph g &&
    List.mem y (neighbors x g) ==> graph_mem y g);;
```

```{.imandra .input}
lemma neighbor_mem_graph x y g =
    is_graph g &&
    graph_mem x g &&
    List.mem y (neighbors x g) ==> graph_mem y g 
    [@@auto] 
    [@@apply isgraph2_neighbors_fc x g] 
    [@@apply sing_mem y (neighbors x g) (List.map key_of g)] 
    [@@fc];;
```

```{.imandra .input}
#require "imandra-discover-bridge";;


    let funlist = ["true";"neighbors";"no_duplicates";"graph_mem";"List.mem"]
    
    let condition x y g = is_graph g && List.mem y (neighbors x g)
    
    let dresult = Imandra_discover_bridge.User_level.discover 
        ~imandra_instances:5i
        ~rewrite_terms:false
        ~condition:"condition"
        ~rewrite_schemas:false
         db funlist [@@program]

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
        if List.mem next (neighbors x g) then is_path1 xs g else 
        false
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

```{.imandra .input}
lemma adm_lemma5 g x stack acc = count_non_members1 g stack (acc+1) = count_non_members1 g (x :: stack) acc ==>
                                 List.mem x stack [@@auto] [@@fc];;
```

This is the important function we needed all of the lemmas for

```{.imandra .input}
lemma neighbors_gen n g =
    (neighbors n g) [@trigger] <> [] ==> graph_mem n g [@@gen] [@@auto];;
```

```{.imandra .input}
let rec find_next_step (nbs : node list) (stack : path) (b : node) (g : graph) =
    if List.mem b nbs then Some (List.rev (b :: stack)) else
    match nbs with
    | [] -> None
    | x :: xs ->
        if List.mem x stack then find_next_step xs stack b g else
        let temp = find_next_step (neighbors x g) (x :: stack) b g in
        match temp with
        | None -> find_next_step xs stack b g
        | Some _ -> temp
        [@@measure find_next_step_measure g stack nbs] [@@auto];;
        
let find_path a b g = 
    find_next_step (neighbors a g) [a] b g;;
```

```{.imandra .input}
lemma find_next_step_nonempty nbs p b g x = 
    (find_next_step nbs p b g = Some x) [@trigger] ==> x <> [] [@@auto] [@@fc];;
```

```{.imandra .input}
verify (fun nbs stack a b g x ->
    is_graph g &&
    nbs = neighbors a g &&
    stack = [a] &&
    find_next_step nbs stack b g = Some x ==>
    graph_mem a g
);;
```

```{.imandra .input}
lemma fns_start_mem nbs stack a b g x =
    is_graph g &&
    nbs = neighbors a g &&
    stack = [a] &&
    find_next_step nbs stack b g = Some x ==>
    graph_mem a g [@@auto] [@@fc];;
```

```{.imandra .input}
verify ~upto:200 (fun nbs stack a b g x ->
    is_graph g &&
    nbs = neighbors a g &&
    stack = [a] &&
    find_next_step nbs stack b g = Some x ==>
    graph_mem b g);;
```

```{.imandra .input}
lemma fns_end_mem nbs stack a b g x =
    is_graph g &&
    nbs = neighbors a g &&
    stack = [a] &&
    find_next_step nbs stack b g = Some x ==>
    graph_mem b g [@@induct functional find_next_step] [@@fc];;
```

```{.imandra .input}
verify ~upto:200 (fun nbs stack a b g x ->
    is_graph g &&
    nbs = neighbors a g &&
    stack = [a] &&
    find_next_step nbs stack b g = Some x ==>
    List.for_all (fun el -> List.mem el (all_nodes g)) x);;
```

```{.imandra .input}
lemma fns_mem nbs stack a b g x = 
    is_graph g &&
    nbs = neighbors a g &&
    graph_mem a g &&
    stack = [a] &&
    find_next_step nbs stack b g = Some x ==>
    List.for_all (fun el -> graph_mem el g) x 
    [@@induct functional find_next_step] 
    [@@disable graph_mem] 
    [@@fc];;
```

```{.imandra .input}
verify (fun nbs stack a b g x y z ->
    nbs = neighbors a g &&
    stack = [a] &&
    find_next_step nbs stack b g = Some (x :: (y :: z))
    ==> List.mem y (neighbors x g));;
```

```{.imandra .input}
lemma find_next_step_nbs nbs stack a b g x y z = 
    nbs = neighbors a g &&
    stack = [a] &&
    find_next_step nbs stack b g = Some (x :: (y :: z))
    ==> List.mem y (neighbors x g) [@@induct functional find_next_step];;
```

```{.imandra .input}
lemma find_path_is_path a b g x = 
    find_path a b g = Some x ==> is_path x g [@@induct structural x];;
```

```{.imandra .input}

```
