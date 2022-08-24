---
title: "Decomposing a Simple car intersection model"
description: "In this notebook, we'll implement a simple model of a road interseciton with a car approaching, we'll then use Imandra's Principal Region Decomposition to explore its state space and define custom printers in order to explore the behavior of the car approaching the intersection using english prose."
kernel: imandra
slug: simple-stoplight-model
difficulty: beginner
---

# The stoplight model

In this notebook we want to explore a simple model of a car approaching an intersection. The model is not supposed to be representative of a real world simulation, but rather a first stage high level abstraction of one such.

We start by defining datatypes representing the state of the stoplight in the intersection:

```{.imandra .input}

(* Street light color *)
type color = Green | Yellow | Red ;;

(* State representation of an intersection. *)
type light_state = {
    blinking : bool;
    current_time : int;
    (* Transition every X seconds *)
    blink_time : int;
    (* Transition period *)
    light_change_time : int;
    (* Intersection light *)
    light_state : color;
  };;

```

Next we define a transition function for the stoplight:

```{.imandra .input}

(* Update the light *)
let light_step (l : light_state) =
  let l = { l with current_time = l.current_time + 1 } in
  if l.current_time > l.light_change_time then
    begin
      let l = { l with blinking = false } in
      match l.light_state with
      | Green -> { l with light_state = Yellow }
      | Yellow -> { l with light_state = Red }
      | Red -> { l with light_state = Green }
    end
  else if l.current_time > l.blink_time then
    begin match l.light_state with
    | Green | Yellow -> { l with blinking = true }
    | Red -> l
    end
  else
    l
;;
```

We do the same for the state of the car approaching said stoplight:

```{.imandra .input}

(* Driving state *)
type driving_state = Accelerating | Steady | Braking;;

(* Current car state *)
type car_state = {
    car_drive_state : driving_state;
    car_speed : int; (* Speed of the car meters/time *)
    car_distance : int; (* Distance to the intersection *)
    (* Define some parameters. We'll condition our model
  on these later. *)
    car_accel_speed : int;
    car_max_speed : int;
    car_min_speed : int;
  };;

(* Our simple car controller - takes the current state of the car
and the streetlight and adjusts the speed. *)
let car_controller (c, l : car_state * light_state) =
  (* Let's define possible commands here. *)
  let steady = { c with car_drive_state = Steady } in
  let brake = { c with car_drive_state = Braking } in
  let accelerate = { c with car_drive_state = Accelerating } in
  (* Now we're going to update the speed based on the current light *)
  match l.light_state with
  | Green -> steady (* If it's green, let's just do what we do. *)
  | Red -> brake
  | Yellow ->
     if not l.blinking && c.car_distance > 10 then
       accelerate
     else
       brake
;;
```

We can now define our intersection as a struct containing both the car and the stoplight state, and we can then define a `one_step` function over the state of the intersection, by first updating the state of the stoplight and then letting the car react to this new state of the world:

```{.imandra .input}

type intersection = {
    c : car_state;
    l : light_state;
  };;

(* Our car state transition here *)
let car_step (i : intersection) =
  let c = i.c in
  (* Update distance given the current speed *)
  let c = { c with car_distance = c.car_distance + c.car_speed } in
  let c = match c.car_drive_state with
    | Accelerating ->
       let new_speed = c.car_speed + c.car_accel_speed in
       if new_speed > c.car_max_speed then { c with car_speed = c.car_max_speed }
       else { c with car_speed = new_speed }
    | Steady -> c
    | Braking ->
       let new_speed = c.car_speed - c.car_accel_speed in
       if new_speed < 0 then { c with car_speed = 0 }
       else { c with car_speed = new_speed } in
  (* We have our current distance, speed and acceleration. *)
  let c' = car_controller (c, i.l) in
  { i with c = c'}
;;

(* State transitions of our core values... *)
let one_step (i : intersection) =
  let l' = light_step (i.l) in
  car_step ({i with l = l'});;

let valid_car_state (i: intersection) =
  (* let's make sure the car is going in a good speed *)
  i.c.car_speed = 20 &&
    i.c.car_accel_speed = 10 &&
      i.c.car_max_speed = 100 &&
        i.c.car_min_speed = 0;;

```

Let's verify that our model ensures that the car will always brake when approaching a red light:

```{.imandra .input}
verify
  (fun i ->
     let i = one_step i in
     valid_car_state i &&
     i.l.light_state = Red
     ==> i.c.car_drive_state = Braking)
;;
```

Let's now use Imandra's Principal Region Decomposition to enumerate all the possible distinct regions of behavior of the intersection:

```{.imandra .input}
#program;;
let d = Modular_decomp.top ~prune:true ~assuming:"valid_car_state" "one_step";;
```

Imandra has computed all the regions of behavior, let's now implement a custom printer using the `Imandra-tools` library to explore the behavior of the car in plain english:

```{.imandra .input}
open Imandra_tools;;

module Custom = struct
  open Region_pp_intf

  type ty = string

  type c =
    (* todo: collapse? *)
    | DriveState of driving_state
    | WithinMaxSpeed of bool
    | GoingForwards
    | GoingBackwards
    | CurrentSpeedEnough of bool
    (* todo: collapse? *)
    | LightState of color
    | LightBlinking of bool
    | TimeToBlink
    | TimeToChangeLight

  let compare _ _ _ = UnComparable

  let map _ = id

  let driving_state_string = function
    | Accelerating -> "accelerating"
    | Steady -> "steady"
    | Braking -> "braking"

  let light_state_string = function
    | Green -> "green"
    | Yellow -> "yellow"
    | Red -> "red"

  let print p ~focus out = function
    | DriveState d -> Format.fprintf out "Car is %s" (driving_state_string d)
    | WithinMaxSpeed b -> Format.fprintf out "Car is %s max speed limits" (if b then "within" else "exceeding")
    | GoingForwards -> Format.fprintf out "Car is moving forwards"
    | GoingBackwards -> Format.fprintf out "Car is moving backwards"
    | LightState l -> Format.fprintf out "Light is %s" (light_state_string l)
    | LightBlinking b -> Format.fprintf out "Light is%s blinking" (if b then "" else "n't")
    | TimeToBlink -> Format.fprintf out "Time to blink"
    | TimeToChangeLight -> Format.fprintf out "Time to change light"
    | CurrentSpeedEnough b -> Format.fprintf out "Car's current speed is%s enough to make it in time"
                                             (if b then "" else "n't")
end

module TY = Region_pp.String_conv

module PPrinter = Region_pp.Make (TY) (Custom)

module Refiner = struct

  open PPrinter
  open Region_pp_intf
  exception Ignore

  let bool_types = (TY.translate_imandra_type (Type.bool ()))

  let refine_invariant (intersection_s : (string * node) list) : node list =
    let open Custom in
    match CCOption.map view (List.assoc "c" intersection_s), CCOption.map view (List.assoc "l" intersection_s) with
    | Some Struct ("car_state", car_state_s), Some Struct ("light_state", light_state_s) ->
       begin
         match List.assoc "car_drive_state" car_state_s,
               List.assoc "car_speed" car_state_s,
               List.assoc "blinking" light_state_s,
               List.assoc "light_state" light_state_s
         with
         | Some {view = (Obj (state, []));ty=obj_ty}, Some ({ty = speed_ty;_} as speed), Some ({ty = blinking_ty;_} as blinking), Some ({ty = light_state_ty;_} as light_state) ->
            let speed : node = mk ~ty:bool_type (Eq (mk ~ty:speed_ty (Var "car_speed"), speed)) in
            let blinking : node = mk ~ty:bool_type (Eq (mk ~ty:blinking_ty (Var "blinking"), blinking)) in
            let light_state : node = mk ~ty:bool_type (Eq (mk ~ty:light_state_ty (Var "light_state"), light_state)) in
            begin match state with
            | "Accelerating" -> [mk ~ty:obj_ty (Custom (DriveState Accelerating)); speed; blinking; light_state]
            | "Steady" -> [mk ~ty:obj_ty (Custom (DriveState Steady)); speed; blinking; light_state]
            | "Braking" -> [mk ~ty:obj_ty (Custom (DriveState Braking)); speed; blinking; light_state]
            | _ -> raise Ignore
            end
         | _ -> raise Ignore
       end
    | _, _ -> raise Ignore

  let walk (x : node) : node =
    let open Custom in
    let r_x = match view x with
   | FieldOf (Record, "current_time", {view = FieldOf (Record, "l", {view = Var "i";_});_}) ->
      Ok (Var "Current time")
     | FieldOf (Record, l, {view = FieldOf (Record, "l", {view = Var "i";_});_}) ->
      Ok (Var l)
    | FieldOf (Record, c, {view = FieldOf (Record, "c", {view = Var "i";_});_}) ->
      Ok (Var c)
   | Is (x, _, {view = Var "car_drive_state";_}) ->
       begin match x with
       | "Accelerating" -> Ok  (Custom (DriveState Accelerating))
       | "Steady" -> Ok (Custom (DriveState Steady))
       | "Braking" -> Ok (Custom (DriveState Braking))
       | _ -> Error Ignore
       end

    | Eq ({view = Var "light_state";ty}, {view = Obj (x, []);_}) ->
       Ok (Is (x, [], mk ~ty (Var "light_state")))

    | Is (x, _, {view = Var "light_state";_}) ->
       begin match x with
       | "Green" -> Ok (Custom (LightState Green))
       | "Yellow" -> Ok (Custom (LightState Yellow))
       | "Red" -> Ok (Custom (LightState Red))
       | _ -> Error Ignore
       end

    | Minus ({view = Var "light_change_time";_}, {view = Int 1;_}) ->
       Ok (Custom TimeToChangeLight)

    | Minus ({view = Var "blink_time";_}, {view = Int 1;_}) ->
       Ok (Custom TimeToBlink)

   | Var "blinking" ->
       Ok (Custom (LightBlinking true))

    | Not ({view = Custom (LightBlinking true);_}) ->
       Ok (Custom (LightBlinking false))

    | Geq ({view = Var "car_max_speed";_}, {view = Plus ({view = Var "car_speed";_}, {view = Var "car_accel_speed";_});_})
      -> Ok (Custom (WithinMaxSpeed true))

   | Gt ({view = Plus ({view = Var "car_speed";_}, {view = Var "car_accel_speed";_});_}, {view = Var "car_max_speed";_})
      -> Ok (Custom (WithinMaxSpeed false))

    | Geq ({view = Minus ({view = Var "car_speed";_}, {view = Var "car_accel_speed";_});_}, {view = Int 0;_})
      -> Ok (Custom GoingForwards)

    | Gt ({view = Int 0;_}, {view = Minus ({view = Var "car_speed";_}, {view = Var "car_accel_speed";_});_})
      -> Ok (Custom GoingBackwards)

    (* 10 is currently hard coded in the model *)
    | Geq ({view = Int 10;_}, {view = Plus ({view = Var "car_distance";_}, {view = Var "car_speed";_});_})
      -> Ok (Custom (CurrentSpeedEnough false))

    | Gt ({view = Plus ({view = Var "car_distance";_}, {view = Var "car_speed";_});_}, {view = Int 10;_})
      -> Ok (Custom (CurrentSpeedEnough true))
    | x -> Ok x
    in match r_x with
    | Ok node_view -> mk ~ty:x.ty node_view
    | Error e -> raise e

  let rec refine (node : node) =
    try
      match view node with
      | Eq ({view = Var "F";_}, {view = Struct ("intersection", intersection);_})
        -> refine_invariant intersection |> List.flat_map refine
      | _ ->
         [XF.walk_fix walk node]
    with Ignore ->
      []
end;;

let pp_cs ?inv cs =
 cs
 |> PPrinter.pp ~refine:Refiner.refine ?inv
 |> List.map (CCFormat.to_string (PPrinter.Printer.print ()))

let regions_doc d =
 Jupyter_imandra.Decompose_render.regions_doc ~pp_cs d;;

#install_doc regions_doc;;
```

```{.imandra .input}
d;;
```
