---
title: "Synthesising Game Solvers in Imandra"
description: "In this Iml notebook we demonstrate how it is possible to use imandra to quickly synthesise winning strategies for simple games."
kernel: imandra
slug: solver-synthesis
key-phrases:
  - OCaml
  - proof
  - instance
---
# Synthesising a Game Solver in Imandra

In this notebook we introduce a simple game called "Les Bâtonnets Géants", and show how imandra can be exploited to synthesise a strategy which always wins. The game itself consists of 16 pegs, and opponents take turns in taking 1,2 or 3 pegs from the end. The loser is the player with 1 remaining peg a their turn. 
![Imandrabot](https://storage.googleapis.com/imandra-notebook-assets/batonnets.jpg)

## Game specific rules

Let us first set up a very simple representation of this game consisting of a state which is either in play with n pieces or ended with a winner:
```{.imandra .input}
type choice = int
;;

type player = 
  | Imandra
  | Opponent 
;;

type state = 
  | Inplay of int
  | Terminal of player
;;

let create_initial_state n = 
  Inplay n;;

let final_state n = 
  n=1
;;

let remove_pins num_pins state = 
 match state with 
 | Terminal p -> Terminal p 
 | Inplay n -> if n-num_pins >= 1 then Inplay (n - num_pins) else Inplay n
;;
```
Now let us also set up simple functions which describe a "move" in the game, given by the function `step`, and two functions which find all the valid choices for a given state, and determine if a move is valid for a given state.
```{.imandra .input}
let step choice state = 
  if choice <=0 || choice >3 then state else remove_pins choice state
;;

let find_all_available_choices state = 
 match state with 
 | Inplay n -> 
  if n>3 then [1;2;3] else if n>2 then [2;1] else if n>1 then [1]
 else []
 | Terminal _ -> [];;

let is_valid_choice choice state =
  choice <=3 && choice >=1 && match state with 
  | Inplay s -> s > choice 
  | Terminal _ -> false;;
```
Above are the specific functions we need for this game. In what follows a generalised architecture for solving adversarial games is given - this could be viewed as similar to a Functor structure in OCaml where the specific functions given for game of Batonnets Géants are those given above. 

## General solver synthesis functions

We introduce first a function called `one_step` which assumes the player of the game is `Imandra`. The function takes a list of possible states as well as a map between states and choices. For each list of states the choice is played, resulting in a new list of states. If any of these states are in a final state they become "annealed" to the `Terminal` variant of state declaring `Imandra` as the winner. For any non-terminal states, every possible opponent play is calcuated using the function `find_all_available_choices` to calculate all the next possible states.
```{.imandra .input}
let one_step (choice_map: (state*choice) list) (states:state list): state list = 
  let new_states = 
    List.fold_left (fun acc el -> 
        match List.find (fun (x,_) -> x=el) choice_map with 
        | None -> el::acc
        | Some (_,choice) -> 
          let a = step choice el in if List.mem a acc then acc else
            (step choice el)::acc) [] states in
  let annealed_states = List.map (fun x -> 
      match x with 
      | Inplay l -> 
        if final_state l then Terminal Imandra else Inplay l 
      | Terminal p -> Terminal p
    ) new_states in 
  List.fold_left (fun acc el -> 
      match el with 
      | Terminal p -> (Terminal p)::acc
      | Inplay l -> 
        let next_states = List.fold_left (fun acc el -> 
            (step el (Inplay l))::acc
          ) [] (find_all_available_choices (Inplay l)) in 
        List.fold_left (fun acc el -> if List.mem el acc then acc else el::acc) acc next_states
    ) [] annealed_states
;;
```
## Using Imandra to synthesise a solver

We now introduce a function which takes an initial state and a set of steps and returns true if every resulting list of states is a winning state for Imandra.  
```{.imandra .input}
let init_state = create_initial_state 16;;

let instance_function init_state steps =   
  let states,validity_cond = List.fold_left (fun acc el -> 
      match acc with 
      | first,second -> 
        (one_step el first,
         second && (
           let fsts = List.map fst el in 
           fsts=first && 
           List.for_all (
             fun (s,c) -> 
               match List.find (fun (x,_) -> x = s) el with 
               | None -> false 
               | Some (s,c) -> is_valid_choice c s 
           ) el
         )
        )) ([init_state],true) steps in 
  validity_cond &&
  List.for_all (fun x ->
      match x with 
      | Terminal Imandra -> true 
      | _ -> false) states;;
```
Now we can exploit Imandra's technology to find a solution for the game - in this case using `[@@blast]` to find the solution:
```{.imandra .input}
instance (fun steps -> 
    instance_function init_state steps) [@@blast];;
```

## Playing against Imandra

Now this is a strategy for the game, we can write a simple game player to play against. 
```{.imandra .input}
[@@@program]
let rec gather_inputs max = 
    let user_input = read_line () in
    if user_input = "" then gather_inputs max else
      let n = String.to_nat user_input in
      match n with 
      | None -> gather_inputs max 
      | Some n -> 
      if n <=0 || n >max then gather_inputs max else 
      n;;
      

let winner_message p =
  match p with Imandra -> "imandra wins " | Opponent -> "you win";;

let print_state state = 
  let rec print_state_aux l = 
    if l <=0 then "\n"
    else "|"^(print_state_aux (l-1)) in
  match state with 
  | Terminal p -> 
    winner_message p
  | Inplay l -> 
    print_state_aux l;;

let print_choice choice = 
  String.of_int choice;;

let rec play_against_imandra state solver  = 
  match state with 
  | Terminal p -> 
    print_endline (winner_message p)
  | Inplay l -> 
    if final_state l then 
      print_endline (winner_message Imandra)
    else
      begin
        match solver with 
        | [] -> ()
        | h::t -> 
          begin
            match List.find (fun (x,_) -> x = state) h with 
            | None -> print_endline "Solver error"; ()
            | Some (_,choice) -> 
              begin 
                let next_state = step choice state in 
                print_endline ("Imandra plays: "^ (print_choice choice)^"\n");
                print_endline (print_state next_state);
                if (match next_state with |Inplay l -> final_state l | _ -> false)then
                  print_endline "Imandra wins\n"else
                  print_endline "Enter your choices";
                let user_choice = gather_inputs (match next_state with Terminal _ -> 0 | Inplay n -> n-1 ) in
                if is_valid_choice user_choice next_state
                then 
                  let next_state = step user_choice next_state in 
                  print_endline ("You played: "^ (print_choice user_choice)^"\n");
                  print_endline (print_state next_state);
                  if (match next_state with |Inplay l -> final_state l | _ -> false)then
                    print_endline "You win\n"else
                    play_against_imandra next_state t
                else 
                  print_endline "invalid choices - replaying...";
                play_against_imandra state solver 
              end
          end
      end
;;
```
By invoking the following code in program mode it is possible to play against imandra, but never win:
```
let play () = 
  print_endline (print_state init_state);
  play_against_imandra init_state CX.steps
;;

play ();;
```
An example trace is:
```
  play ();;
||||||||||||||||

Imandra plays: [3]

|||||||||||||

Enter your choices
1
You played: [1]

||||||||||||

Imandra plays: [3]

|||||||||

Enter your choices
2
You played: [2]

|||||||

Imandra plays: [2]

|||||

Enter your choices
1
You played: [1]

||||

Imandra plays: [3]

|

Imandra wins
```