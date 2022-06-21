```{.imandra .input}
type node = string;;
type graph = (node * node list) list;;
type path = node list;;
```

```{.imandra .input}
let empty : graph = List.empty;;
```

```{.imandra .input}
#show List;;
```

```{.imandra .input}
let rec all_nodes_ (g : graph) acc = 
    match g with
    | [] -> acc
    | x :: xs -> 
        all_nodes_ xs (fst x :: (snd x @ acc));;
```

```{.imandra .input}
let all_nodes g = all_nodes_ g [];;
```

```{.imandra .input}
let graph_mem x g = List.mem x (all_nodes g);;
```

```{.imandra .input}
let rec neighbors (n : node) (g : graph) =
    match g with
    | [] -> []
    | x :: xs ->
        if n = fst x then snd x else
        neighbors n xs;; 
```

```{.imandra .input}
let is_path (p : path) (g : graph) =
    if List.is_empty p then false else
    let rec aux path_remaining g =
        match path_remaining with
        | [] -> true
        | x :: xs ->
        (
            if not (graph_mem x g) then false else
            match neighbors x g with
            | [] -> false
            | neighbs -> if List.mem x neighbs then aux xs g else false
        ) in
    aux p g;;
```

```{.imandra .input}
#show Option;;
```

```{.imandra .input}
let rec last l =
    match l with
    | [] -> None
    | _ :: [x] -> Some x
    | x :: xs -> last xs;;
```

```{.imandra .input}
let path_from_to p a b g =
    is_path p g && List.hd p = a && last p = Some b;;
```
