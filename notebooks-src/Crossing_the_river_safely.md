---
title: "Crossing the River Safely"
description: "River example notebooks"
kernel: imandra
slug: crossing-river-safely
---

# Crossing the River Safely

For the sake of brain scrambling, we're going to solve this [ancient puzzle](https://en.wikipedia.org/wiki/Fox,_goose_and_bag_of_beans_puzzle) using Imandra ([again!](https://medium.com/imandra/the-wolf-goat-and-cabbage-exchange-97e7f3ff8d5a)). As most polyvalent farmers will tell you, going to the market with your pet wolf, tastiest goat, and freshest cabbage is sometimes difficult as they tend to have appetite for one another. The good news is that there is a way to cross this river safely anyway.

First we should define the problem by tallying our goods and looking around.

```{.imandra .input}
type location =
  | Boat
  | LeftCoast
  | RightCoast
  | Eaten

type boat =
  | Left
  | Right

type good = Cabbage | Goat | Wolf
```

This problem is delicate and will require multiple steps to be solved. Each step should take us from a `state` to another `state` (where, hopefully, no cabbage nor goat was hurt).

```{.imandra .input}
type state = {
  cabbage : location;
  goat : location;
  wolf : location;
  boat : boat;
}
```

We can define a few helpers:

```{.imandra .input}
let get_location (s:state) (g:good) = match g with
  | Cabbage -> s.cabbage
  | Goat -> s.goat
  | Wolf -> s.wolf

let set_location (s:state) (g:good) (l:location) = match g with
  | Cabbage -> { s with cabbage = l}
  | Goat    -> { s with goat    = l}
  | Wolf    -> { s with wolf    = l}

let boat_empty (s:state) =
  (s.cabbage <> Boat) &&
  (s.goat    <> Boat) &&
  (s.wolf    <> Boat)
  
```

Now, transition from a state to the next one is done via *actions*:

```{.imandra .input}
type action =
  | Pick of good
  | Drop of good
  | CrossRiver

let process_action (s:state) (m:action) : state =
  match m with
  | CrossRiver -> { s with boat = match s.boat with Left -> Right | Right -> Left }
  | Pick x -> begin
    if not @@ boat_empty s then s else
    match get_location s x, s.boat with
    |  LeftCoast ,  Left -> set_location s x Boat
    | RightCoast , Right -> set_location s x Boat
    | _ -> s
  end
  | Drop x -> begin
    match get_location s x, s.boat with
    | Boat ,  Left -> set_location s x LeftCoast
    | Boat , Right -> set_location s x RightCoast
    | _ -> s
  end
;;

let process_eating s =
  match s.boat, s.cabbage, s.goat, s.wolf with
  | Right, LeftCoast, LeftCoast, _    -> Some { s with cabbage = Eaten }
  | Right, _ , LeftCoast, LeftCoast   -> Some { s with goat = Eaten }
  |  Left, RightCoast, RightCoast, _  -> Some { s with cabbage = Eaten }
  |  Left, _ , RightCoast, RightCoast -> Some { s with goat = Eaten }
  | _  -> None

(* is… it a bad state? *)
let anything_eaten s =
  s.cabbage = Eaten || s.goat = Eaten

let one_step s a =
  if anything_eaten s then s
  else
    match process_eating s with
    | Some s -> s
    | None ->
      process_action s a

(* process many actions. Note that we have to specify that [acts] is
   the argument that proves termination *)
let rec many_steps s acts =
  match acts with
  | [] -> s
  | a :: acts ->
    let s' = one_step s a in
    many_steps s' acts
[@@adm 1n]


let solved s =
  s.cabbage = RightCoast
  && s.goat = RightCoast
  && s.wolf = RightCoast
  && s.boat = Right
;;
```

```{.imandra .input}
(* initial state, on the west bank of Anduin with empty pockets and fuzzy side-kicks *)
let init_state = {
  cabbage = LeftCoast;
  goat = LeftCoast;
  wolf = LeftCoast;
  boat = Left;
}
```

We are now ready to ask for a solution! Because we're looking for a given solution rather than a universal proof, `instance` is the most natural.

```{.imandra .input}
#timeout 10_000;;

instance (fun l -> solved @@ many_steps init_state l) ;;
```

That seems to take a bit of time, because this problem is not that easy for Imandra's unrolling algorithm. Let's try `[@@blast]` to see if we can get a result faster:

```{.imandra .input}
instance (fun l -> solved @@ many_steps init_state l)
[@@blast] ;;
```

It only took a fraction of second! 🎉

Now we have a clear plan for crossing the river. How to sell the goat and cabbage is left as an exercise to the reader.
