---
title: "Creating and Verifying a ROS Node"
description: "In this notebook we look at verifying a Robotic Operating System (ROS) node."
kernel: imandra
slug: verifying-an-ros-node
key-phrases:
  - ROS
  - counterexample
difficulty: intermediate
---

# Creating and Verifying a ROS Node

![Imandrabot](https://storage.googleapis.com/imandra-notebook-assets/ros/kostya_ros_medium_1.png)

*At AI, we've been working on an IML (Imandra Modelling Language) interface to ROS, allowing one to develop ROS nodes and use Imandra to verify their properties. In this notebook, we will go through creation and verification of a Robotic Operating System (ROS) node in Imandra. We will make a robot control node that controls the motion of a simple 2-wheeler bot:*

![Imandrabot](https://storage.googleapis.com/imandra-notebook-assets/ros/Imandrabot.png)

We'll create a controller that uses the laser scanner to avoid obstacles and drive around the scene. The Imandra ML code can be compiled in OCaml and plugged into the ROS system - the behaviour of the bot can be observed in the Gazebo simulator.

Then we'll illustrate how to use Imandra to formally verify various statements about the model and how to find bugs and corner cases by exploring the Imandra-generated counterexamples for false conjectures.

# 1. ROS message OCaml types

For our Imandra-ROS project we’ve processed all the standard ROS messages with our code generation tool creating a collection of strongly-typed IML/OCaml bindings for them. But, in order to keep this notebook self-contained we'll define the necessary messaging modules here.

First, we'll need to declare the message type that will control our robot. This is typically done with a `Twist` message from the `geometry_msgs` standard ROS package. We want to mimic ROS messaging nomenclauture as close as possible, so we'll create an OCaml/Imadra `module` with the same name as the package and will place the necessary type/message declaraions inside:

```{.imandra .input}
module Geometry_msgs = struct
  type vector3 =
    { vector3_x : int
    ; vector3_y : int
    ; vector3_z : int
    }
  type twist =
    { twist_linear  : vector3
    ; twist_angular : vector3
    }
end
```

You might have noticed that we've replaced floating point values for vector coordinates with integers. In this context, it is more straight-forward for Imandra to reason about integers, so we assume that there is a common factor of 100,000 multiplying all the incoming floating point values and divides all the outgoing integers. (That effectively makes our unit of measurement of length to be 10 micrometres).

Let's move on and declare the incoming messages:
 - `LaserScan` sensor input message from the `sensor_msgs` ROS package
 - and the `Clock` message from the `Rosgraph_msg` ROS package

We define the wrapping modules for both messages and declare their datatypes:

```{.imandra .input}
module Sensor_msgs = struct
  type laserScan =
    { laserScan_range_min : int
    ; laserScan_range_max : int
    ; laserScan_ranges : int list
    }
end
module Rosgraph_msgs = struct
  type time =
    { seconds     : int
    ; nanoseconds : int
    }
  type clock = { clock : time }
end
```

Robotics OS middleware will communicate with our node via messages of these three types. The code that we'll write for of our node will represent the formal mathematical model of the controller algorithm - we can use Imandra to reason and verify various statements about the code. Since IML is valid OCaml, we'll leverage its compiler to create an executable from the verified IML code.

# 2. Creating a simple ROS Node model

We want to create some simple but non-trivial robot controller that makes our bot drive around avoiding the obstacles. The bot is going to drive forward until one of the laser scanner ranges becomes too low, meaning that we've gotten too close to some obstacle - in that case, we want the bot to stop and turn until the scanner tells us that the road ahead is clear. To make the model a bit more complicated, we'd like to implement the ability to choose the turning direction depending on the laser scanner ranges.

One might try to make a "naive" controller that doesn't have any memory about its previous states and observations - such a bot reacts to the currently observed scanner values and decides its actions based solely on that information. Such an approach will quickly lead to the bot being "stuck" in infinite oscillatory loops. E.g. here is a bot that decides which side to turn depending on the first value in the `ranges` array:

![Imandrabot](https://storage.googleapis.com/imandra-notebook-assets/ros/Stuck.gif)

To avoid this kind of oscillations we need the model to have some memory of its previous states. The idea is to introduce two modes of model's operation: driving forward and turning in one place. The bot is in the "driving" mode by default, but it can transition to the turning mode if it gets dangerously close to surrounding objects.

The turning direction is calculated using the direction of the minimum of the distances that the scanner returns. While the robot is turning in one place, it stores the minimal range that the scanner has detected at that location. If at some point the scanner detects a range that is lower than the stored one - the turning direction gets recalculated, and the minimal range gets updated.

## 2.1 State datatype

Working with Imandra we’ve adopted a standard way to construct formal models of message-driven systems. At the top of the model we have a single OCaml datatype that holds all the data needed to describe the system at a given moment, including incoming and outgoing messages. We call this record type `state`. Together with this `state` type we define a `one_step` transition `state -> state` function, which performs a single logically isolated step of the simulation and returns the new `state` after the transition.

As an example, consider an IML/OCaml type declaration for a simple ROS node that is able to accept `rosgraph_msgs/Clock` and `sensor_msgs/LaserScan` standard ROS messages. We also want the state to store three values:
 - the current mode of the bot -- whether we are driving forward or turning in a preferred direction
 - the latest minimal value of the ranges that the laser sensor returns
 - the preferred side for the robot to turn -- either clockwise (`CW`) or counter-clockwise (`CCW`)

Finally, we want the node to be able to send `geometry_msgs/Twist` ROS message depending on the stored `min_range` data:

```{.imandra .input}
type incoming_msg =
  | Clock  of Rosgraph_msgs.clock
  | Sensor of Sensor_msgs.laserScan

type outgoing_msg =
  | Twist of Geometry_msgs.twist

type direction = CW | CCW

type mode = Driving | Turning

type state =
  { mode : mode
  ; min_range : int option
  ; direction : direction option
  ; incoming  : incoming_msg option
  ; outgoing  : outgoing_msg option
  }
```

## 2.2 State transition `one_step` function

To implement our node, we'll need a function that scans through a list of values and returns the minimum value and its index. We'll make a generic function `foldi` that does an indexed version of the `List.fold_right`:

```{.imandra .input}
let rec foldi ~base ?(i=0) f l =
  match l with
  | [] -> base
  | x :: tail -> f i x ( foldi f ~base ~i:(i+1) tail )
```

When accepting this function, Imandra constructs its "termination proof" - that means that Imandra managed to prove that recursive calls in this function will not end up in an infinite loop. Imandra proves such things using inductive reasoning and is able to prove further statements about other properties of such functions.

```{.imandra .input}
let get_min_range max lst =
  List.fold_right ~base:max
    (fun x a -> if x < a then x else a) lst
```

On an incoming `Clock` tick we are simply sending out a `Twist` message which tells the robot to either move forward or turn, depending on the mode that it is currently in. We encode it by introducing the `make_twist_message` helper function and the `process_clock_message : state -> state` function.

```{.imandra .input}
let make_twist_message v omega=
  let open Geometry_msgs in
  let mkvector x y z =  { vector3_x = x; vector3_y = y; vector3_z = z   } in
  Twist { twist_linear  = mkvector v 0 0 ; twist_angular = mkvector 0 0 omega }

let process_clock_message state =
  match state.mode with
  | Driving -> { state with outgoing = Some (make_twist_message 10000 0) }
  | Turning -> begin
  match state.direction with
    | None
    | Some ( CW ) -> { state with outgoing = Some (make_twist_message 0   10000) }
    | Some (CCW ) -> { state with outgoing = Some (make_twist_message 0 (-10000))}
  end
```

On incoming `Scan` message, we want to find the minimum of the received ranges and the index of that minimum in the list. Depending on the index, we decide in which direction to turn. To implement this, we create another helper function and the `process_sensor_message` one:

```{.imandra .input}
let get_min_and_direction msg =
  let max = msg.Sensor_msgs.laserScan_range_max in
  let lst = msg.Sensor_msgs.laserScan_ranges in
  let min_range = get_min_range max lst in
  let mini = foldi ~base:(max, 0)
    (fun i a b -> if a < fst b then (a,i) else b) in
  let _ , idx = mini lst in
  if idx < List.length lst / 2 then min_range, CW else min_range, CCW

let process_sensor_message state min_range min_direction =
  let dirving_state =
    { state with mode = Driving; min_range = None; direction = None } in
  let turning_state =
    { state with
      mode      = Turning
    ; direction = Some min_direction
    ; min_range = Some min_range
    } in
  match state.mode , state.min_range with
  | Driving , _    -> if min_range < 20000 then turning_state else dirving_state
  | Turning , None -> if min_range > 25000 then dirving_state else turning_state
  | Turning , Some old_range ->
    if min_range > 25000 then dirving_state
    else if min_range > old_range then state else turning_state
```

With the help of these functions, we can create our `one_step` transition function, which just dispatches the messages to the appropriate helper function above.

```{.imandra .input}
let one_step state =
  match state.incoming with None -> state | Some in_msg ->
  let state = { state with incoming = None; outgoing = None } in
  match in_msg with
  | Sensor laserScan ->
    let min_range, min_direction = get_min_and_direction laserScan in
    process_sensor_message state min_range min_direction
  | Clock  _ -> process_clock_message state
```

## 2.3 Running the model as a ROS node

Now that we have an early model, let's compile it with our ROS node wrapper into an executable. Here is the model, controlling our "imandrabot" in the Gazebo simulation environment:

![Imandrabot](https://storage.googleapis.com/imandra-notebook-assets/ros/Imandra_Demo.gif)

# 3. Verifying the ROS node model

Formal verification is the process of reasoning mathematically about the correctness of computer programs. We'll use Imandra to formally verify some properties of the ROS node model we've created.

## 3.1 Verifying outgoing `Twist` message at `Clock` ticks

Our model is designed in such a way that it updates its state parameters upon `LaserScan` messages and sends out `Twist` control messages in response to `Clock` messages. Let's verify a simple theorem that on every incoming `Clock` message, there is an outgoing `Twist` message.

We can formally write this statement down as:

$$ \forall s. IsClock(IncomingMessage(s)) \,\Rightarrow\, IsTwist(OutgoingMessage(OneStep(s))) $$

eaning that for every state $s$, if the state contains an incoming message and this message is a `Clock` message, then the state's `outgoing` message is a `Twist` after we've called `one_step` on it.

We can almost literally encode this formal expression as an Imandra `theorem`:

```{.imandra .input}
let is_clock msg = match msg with  Some ( Clock _ ) -> true | _ -> false ;;
let is_twist msg = match msg with  Some ( Twist _ ) -> true | _ -> false ;;

theorem clock_creates_outbound state =
  is_clock state.incoming ==> is_twist (one_step state).outgoing
```

One can see that Imandra says that it "Proved" the theorem, meaning that Imandra has formally checked that this property holds for all possible input states.

## 3.2 Verifying that we never drive backwards

As another example, let us check that, no matter what, the node will never send out a message with negative linear velocity.

```{.imandra .input}
let no_moving_back msg =
    let open Geometry_msgs in
    match msg with None -> true
    | Some (Twist data) -> data.twist_linear.vector3_x >= 0

verify ( fun state -> no_moving_back (one_step state).outgoing  )
```

We have failed to prove the statement and Imandra have created a counterexample `CX` module for us. This module  contains concrete values for the parameters of the verified statement, that violate the statement's condition. Let's examine the value of `CX.state`:

```{.imandra .input}
CX.state
```

The counterexample `state` produced by imandra has the `incoming` message set to `None` and the `outgoing` message set to a `Twist` message with negative `linear.x`. Our `one_step` function keeps the state unchanged if the incoming message is empty.

We can either consider this behavior as a bug and change our `one_step` implementation; or we can consider this a normal behavior and amend our theorem, adding the non-empty incoming message as an extra premise of the theorem:

```{.imandra .input}
theorem never_goes_back state =
  state.incoming <> None
  ==>
  no_moving_back (one_step state).outgoing
```

We've proven that the model never creates negative linear speed in response to any incoming message - alternatively we can set `state.outgoing = None` as a premise, proving that an empty `outgoing` message is never filled with a `Twist` with negative velocity:

```{.imandra .input}
theorem never_goes_back_alt state =
  state.outgoing = None
  ==>
  no_moving_back (one_step state).outgoing
```

# 4. Inductive proofs. Stopping near objects.

As a final formal verification goal, we want to be able to prove that the robot stops and starts turning if one of the values in the scanner `ranges` is lower than 0.2 meters. In general, reasoning about variable-sized lists requires inductive proofs - and these might require proving some lemmas to guide Imandra to the proof. So, we will first try to prove a simpler version of the theorem - if all the ranges in the incoming laser scan message are less than 0.2 meters, then we definitely transition to the `Turning` state. We'll try to encode our theorem using `List.for_all` standard function:

```{.imandra .input}
verify ( fun state ->
  let open Sensor_msgs in
  match state.incoming with None | Some (Clock _ ) -> true
  | Some ( Sensor data ) ->
  (  List.for_all (fun x -> x < 20000) data.laserScan_ranges
  ) ==> (one_step state).mode = Turning
)
```

We have failed to prove the statement and Imandra has created a counterexample `CX` module for us. Examining the counterexample state we notice that the incoming `laserScan_ranges list` is empty.

```{.imandra .input}
CX.state
```

Adding the extra requirement that the list is not `[]`, we successfully verify the statement:

```{.imandra .input}
theorem stopping_if_for_all state =
  let open Sensor_msgs in
  match state.incoming with None | Some (Clock _ ) -> true
  | Some ( Sensor data ) ->
  (  data.laserScan_ranges <> []
  && List.for_all (fun x -> x < 20000) data.laserScan_ranges
  ) ==> (one_step state).mode = Turning
```

Imandra successfully proves the `stopping_if_for_all` theorem, but our ultimate goal is to prove the theorem when **some** of the values in `laserScan_ranges` are less than the cutoff. If we simply try to replace the `List.for_all` with `List.exists`, Imandra will fail to either prove or disprove the theorem.  The inductive structure of this proof is too complex for Imandra to figure out automatically without any hints from the user. We need to help it with the overall logic of the proof. To do that we will break this final theorem into several smaller steps, making a rough "sketch" of the inductive proof we want and and ask Imandra to fill in the gaps.

As a first step, we extract the anonymous threshold function and prove a lemma that if the `get_min_range` function returns a value satisfying the threshold, then the conclusion about the `one_step` function holds:

```{.imandra .input}
let under_threshold x = x < 20000

lemma lemma1 state =
  let open Sensor_msgs in
  match state.incoming with None | Some (Clock _ ) -> true
  | Some ( Sensor data ) ->
  (  data.laserScan_ranges <> []
  && under_threshold (get_min_range data.laserScan_range_max data.laserScan_ranges)
  ) ==> (one_step state).mode = Turning
```

Next, we prove a "bridge" lemma that translates between the `get_min_range` concept and the `List.exists` concept for the `under_threshold` function.

```{.imandra .input}
lemma bridge max lst =
  List.exists under_threshold lst ==> under_threshold (get_min_range max lst)
  [@@induct]
```

Then, we `[@@apply]` the two lemmas above to prove our final theorem with the `List.exists` condition: these proofs require induction - to tell Imandra to use induction one should add the `[@@induct]` attribute to the theorem declaration:

```{.imandra .input}
theorem stopping_if_exists state =
  let open Sensor_msgs in
  match state.incoming with None | Some (Clock _ ) -> true
  | Some ( Sensor data ) ->
  (  data.laserScan_ranges <> []
  && List.exists under_threshold data.laserScan_ranges
  ) ==> (one_step state).mode = Turning
[@@apply lemma1 state]
[@@apply bridge
    (match state.incoming with Some (Sensor data) -> data.laserScan_range_max | _ -> 0)
    (match state.incoming with Some (Sensor data) -> data.laserScan_ranges | _ -> []) ]
[@@induct]
```
