---
title: "Verifying a Simple Autonomous Vehicle Controller in Imandra"
description: "In this notebook, we'll design and verify a simple autonomous vehicle controller in Imandra. The controller we analyse is due to Boyer, Green and Moore, and is described and analysed in their article The Use of a Formal Simulator to Verify a Simple Real Time Control Program."
kernel: imandra
slug: simple-vehicle-controller
difficulty: beginner
expected-error-report: { "errors": 1, "exceptions": 0 }
---

# Verifying a simple autonomous vehicle controller in Imandra

<img src="https://storage.googleapis.com/imandra-notebook-assets/imandra_sd-car-controller.png" width=500>

In this notebook, we'll design and verify a simple autonomous vehicle controller in Imandra. The controller we analyse is due to Boyer, Green and Moore, and is described and analysed in their article [The Use of a Formal Simulator to Verify a Simple Real Time Control Program](https://link.springer.com/chapter/10.1007/978-1-4612-4476-9_7).

This controller will receive sequences of sensor readings measuring changes in wind speed, and will have to respond to keep the vehicle on course. The final theorems we prove will establish the following safety and correctness properties:

 - If the vehicle starts at the initial state `(0,0,0)`, then the controller guarantees the vehicle never strays
   farther than `3` units from the `x`-axis.
 - If the wind ever becomes constant for at least `4` sampling intervals, then the vehicle returns to the `x`-axis and stays there as long as the wind remains constant.

These results formally prove that the simulated vehicle appropriately stays on course under each of the _infinite number_ of possible wind histories.


## The controller and its environment

Quantities in the model are measured using integral units. The model is one-dimensional: it considers the `y`-components of both the vehicle and wind velocity.

Wind speed is measured in terms of the number of units in the `y`-direction the wind would blow a passive vehicle in one sampling interval. From one sampling interval to the next, the wind speed can change by at most one unit in either direction. The wind is permitted to blow up to arbitrarily high velocities.

At each sampling interval, the controller may increment or decrement the `y`-component of its velocity. We let `v` be the accumulated speed in the `y`-direction measured as the number of units the vehicle would move in one sampling interval if there were no wind. We make no assumption limiting how fast `v` may be changed by the control program. We permit `v` to become arbitrary large.

# The Imandra model

The Imandra model of our system and its environment is rooted in a `state` vector consisting of three values:
 - `w` - current wind velocity
 - `y` - current y-position of the vehicle
 - `v` - accumulated velocity of the vehicle

```{.imandra .input}
type state = {
  w : int; (* current wind speed *)
  y : int; (* y-position of the vehicle *)
  v : int; (* accumulated velocity *)
}
```

# Our controller and state transitions

```{.imandra .input}
let controller sgn_y sgn_old_y =
  (-3 * sgn_y) + (2 * sgn_old_y)
```

```{.imandra .input}
let sgn x =
  if x < 0 then -1
  else if x = 0 then 0
  else 1
```

Given a wind-speed delta sensor reading and a current state, `next_state` computes the next state of the system as dictated by our controller.

```{.imandra .input}
let next_state dw s =
  { w = s.w + dw;
    y = s.y + s.v + s.w + dw;
    v = s.v +
        controller
          (sgn (s.y + s.v + s.w + dw))
          (sgn s.y)
  }
```

# Sensing the environment

The behaviour of the wind over `n` sampling intervals is represented as
a sequence of length `n`. Each element of the sequence is either `-1`, `0`, or `1`
indicating how the wind changed between sampling intervals.

We define the predicate `arbitrary_delta_ws` to describe valid sequences of wind sensor readings.

```{.imandra .input}
let arbitrary_delta_ws = List.for_all (fun x -> x = -1 || x = 0 || x = 1)
```

# The top-level state machine

We now define the `final_state` function which takes a description of an arbitrary wind sampling history
   and an initial state, and computes the result of running the controller
   (i.e., simulating the vehicle) as it responds to the changes in wind.

```{.imandra .input}
let rec final_state s dws =
  match dws with
  | [] -> s
  | dw :: dws' ->
    let s' = next_state dw s in
    final_state s' dws'
[@@adm dws]
```

# Verifying our controller

We now partition our state-space into a collection of regions, some "good,"
most "bad," and show that if we start in a "good" state (like `(0,0,0)`), then we'll (inductively)
always end up in a "good" state.

```{.imandra .input}
(* What it means to be a ``good'' state *)

let good_state s =
  match s.y, s.w + s.v with
  | -3, 1 -> true
  | -2, 1 -> true
  | -2, 2 -> true
  | -1, 2 -> true
  | -1, 3 -> true
  | 0, -1 -> true
  | 0, 0  -> true
  | 0, 1  -> true
  | 1, -2 -> true
  | 1, -3 -> true
  | 2, -1 -> true
  | 2, -2 -> true
  | 3, -1 -> true
  | _ -> false
```

## Theorem: Single step safety

We prove: `If we start in a good state and evolve the system responding to one sensor reading, we end up in a good state.`

```{.imandra .input}
theorem safety_1 s dw =
  good_state s
  && (dw = -1 || dw = 0 || dw = 1)
 ==>
  good_state (next_state dw s)
  [@@rewrite]
```

## Theorem: Multistep safety

We prove: `If we start in a good state and simulate the controller w.r.t. an arbitrary sequence of sensor readings, then we still end up in a good state.`

```{.imandra .input}
#disable next_state;;
#disable good_state;;

theorem all_good s dws =
  good_state s && arbitrary_delta_ws dws
  ==>
  good_state ((final_state s dws) [@trigger])
[@@induct functional final_state]
[@@forward_chaining]
```

# Theorem: Cannot get more than 3 units off course.

We prove: `No matter how the wind behaves, if the vehicle starts at the initial state (0,0,0), then the controller guarantees the vehicle never strays farther than 3 units from the x-axis.`

```{.imandra .input}
#enable next_state;;
#enable good_state;;

theorem vehicle_stays_within_3_units_of_course dws =
 arbitrary_delta_ws dws
 ==>
 let s' = final_state {y=0;w=0;v=0} dws in
 -3 <= s'.y && s'.y <= 3
 [@@simp]
```

# Theorem: If wind is stable for 4 intervals, we get back on course.

We prove: `If the wind ever becomes constant for at least 4 sampling intervals, then the vehicle returns to the x-axis and stays there as long as the wind remains constant.`

```{.imandra .input}
let steady_wind = List.for_all (fun x -> x = 0)

let at_least_4 xs = match xs with
    _ :: _ :: _ :: _ :: _ -> true
  | _ -> false
```

```{.imandra .input}
#disable next_state;;
#disable good_state;;
#max_induct 4;;

theorem good_state_find_and_stay_zt_zero s dws =
 good_state s
 && steady_wind dws
 && at_least_4 dws
 ==>
 let s' = (final_state s dws) [@trigger] in
 s'.y = 0
[@@induct functional final_state]
[@@forward_chaining]
;;
```

You may enjoy reading the above proof! Now, we prove the final part of our main safety theorem.

```{.imandra .input}
#enable good_state;;

theorem good_state_find_and_stay_0_from_origin dws =
 steady_wind dws
 && at_least_4 dws
 ==>
 let s' = final_state {y=0;w=0;v=0} dws in
 s'.y = 0
[@@simp]
```

# Experiments with a flawed version

Now that we've verified the controller, let us imagine instead that we'd made a mistake in its design and use Imandra to find such a mistake. For example, what if we'd defined the controller as follows?

```{.imandra .input}
let bad_controller sgn_y sgn_old_y =
  (-4 * sgn_y) + (2 * sgn_old_y)
```

```{.imandra .input}
let bad_next_state dw s =
  { w = s.w + dw;
    y = s.y + s.v + s.w + dw;
    v = s.v +
        bad_controller
          (sgn (s.y + s.v + s.w + dw))
          (sgn s.y)
  }
```

```{.imandra .input}
let rec bad_final_state s dws =
  match dws with
  | [] -> s
  | dw :: dws' ->
    let s' = bad_next_state dw s in
    bad_final_state s' dws'
[@@adm dws]
```

Now, let's try one of our main safety theorems:

```{.imandra .input}
theorem vehicle_stays_within_3_units_of_course dws =
 arbitrary_delta_ws dws
 ==>
 let s' = bad_final_state {y=0;w=0;v=0} dws in
 -3 <= s'.y && s'.y <= 3
```

Imandra shows us that with our flawed controller, this conjecture is not true! In fact, Imandra computes a counterexample consisting of a sequence of three `1`-valued wind speed sensor readings.

If we plug these in, we can see the counterexample in action:

```{.imandra .input}
bad_final_state {y=0; w=0; v=0} [1;1;1]
```

Happy verifying!
