---
title: "A comparison with TLA+"
description: "Encoding the examples from Learn TLA+ in Imandra"
kernel: imandra
slug: a-comparison-with-tla-plus
---

# A comparison with TLA+

In this notebook we'll go through the example from Hillel Wayne's [Learn TLA+](https://learntla.com/introduction/example/) to find out how concepts in TLA+ correspond to concepts in Imandra.

This notebook is intended to be read side-by-side with Hillel's example. We'll quote certain snippets from Learn TLA+ and explain how we could achieve the same in Imandra.

## The Problem

> You’re writing software for a bank. You have Alice and Bob as clients, each with a certain amount of money in their accounts. Alice wants to send some money to Bob. How do you model this? Assume all you care about is their bank accounts.

## Step One

For this example, we could model the `transfer` algorithm very simply as a single function in Imandra. However, for comparison we'll try to model in a similar way to the PlusCal style. To do this we'll write our algorithm as a state machine.

The example defines the PlusCal variables `alice_account`, `bob_account` and `money`. For this we'll define a `state` record:

```{.imandra .input}
type state =
  { alice_account : int
  ; bob_account : int
  ; money : int
  }

let init =
  { alice_account = 10
  ; bob_account = 10
  ; money = 5
  }
```

> `A:` and `B:` are labels. They define the steps the algorithm takes. Understanding how labels work is critical to writing more complex algorithms, as they define the places where your concurrency can go horribly awry.

We choose to model the steps `A` and `B` as a variant type `action`. The function `step`, given an `action` and a `state`, computes one step of the algorithm.

```{.imandra .input}
type action =
  | A
  | B

let step action state =
  match action with
  | A -> { state with alice_account = state.alice_account - state.money }
  | B -> { state with bob_account = state.bob_account + state.money }
```

Now we can put everything together to define the `transfer` algorithm:

```{.imandra .input}
let transfer state =
  state |> step A |> step B
```

> So how do we run this? Well, we can’t.

In Imandra, this *is* real code! We can execute it, leveraging the OCaml runtime. Let's take a look at the results of executing each step:

```{.imandra .input}
init;;
init |> step A;;
init |> step A |> step B;;
```

## Assertions and Sets

> Can Alice’s account go negative? Right now our spec allows that, which we don’t want. We can start by adding a basic assert check after the transaction.

In Imandra, we encode contracts and properties using `verify` statements.

```{.imandra .input}
verify (fun state ->
  state.alice_account = 10 &&
  state.bob_account = 10 &&
  state.money = 5
  ==>
  let state' = transfer state in
  state'.alice_account >= 0
)
```

Here we've used the `==>` operator. `a ==> b` can be read as "`a` implies `b`". We're saying: if both Alice and Bob's accounts are `10`, and `money` is `5`, then after the transfer Alice's account will not be negative.

Imandra has shown that our statement is true!

> At the very least, it works for the one number we tried. That doesn’t mean it works for all cases. When testing, it’s often hard to choose just the right test cases to surface the bugs you want to find. This is because most languages make it easy to test a specific state but not a large set of them. In TLA+, though, testing a wide range is simple.

> The only thing we changed was `money = 5` to `money \in 1..20`

Let's amend our verify statement to test the same range:

```{.imandra .input}
verify (fun state ->
  state.alice_account = 10 &&
  state.bob_account = 10 &&
  List.mem state.money List.(1 -- 20)
  ==>
  let state' = transfer state in
  state'.alice_account >= 0
)
```

Now Imandra has found a counterexample to our verify statement. Like TLA+, Imandra gives us concrete values that make our statement false. We can also compute with these values to get more insight:

```{.imandra .input}
CX.state;;
CX.state |> step A;;
CX.state |> step A |> step B;;
```

> We can fix this by wrapping the check in an if-block:

```{.imandra .input}
let transfer state =
  if state.alice_account >= state.money then
    state |> step A |> step B
  else
    state
```

> Which now runs properly.

```{.imandra .input}
verify (fun state ->
  state.alice_account = 10 &&
  state.bob_account = 10 &&
  List.mem state.money List.(1 -- 20)
  ==>
  let state' = transfer state in
  state'.alice_account >= 0
)
```

> Quick aside: this is closer to testing all possible cases, but isn’t testing all possible cases. Would the algorithm break if money was, say, 4997? If we actually wanted to test all possible cases, we could replace `money \in 1..20` with `money \in Nat`, where `Nat` is the set of natural numbers. This is perfectly valid TLA+. Unfortunately, it’s also something the model checker can’t handle. TLC can only check a subset of TLA+, and infinite sets aren’t part of that.

Imandra is capable of handling infinite sets. We can do this by simply removing the constraint that `state.money` is in the range `1` to `20`. Instead, we'll require that it is non-negative:

```{.imandra .input}
verify (fun state ->
  state.alice_account = 10 &&
  state.bob_account = 10 &&
  state.money >= 0
  ==>
  let state' = transfer state in
  state'.alice_account >= 0
)
```

Imandra has shown that this property holds for *all* possible non-negative integer values of `money`.

## TLA+ and Invariants

> Can you transfer a negative amount of money? We could add an `assert money > 0` to the beginning of the algorithm. This time, though, we’re going to introduce a new method in preparation for the next section.

TLA+ allows you write down invariants that will be checked for each state of the system.

We can achieve the same with Imandra:

```{.imandra .input}
verify (fun action state ->
  state.alice_account = 10 &&
  state.bob_account = 10 &&
  state.money >= 0
  ==>
  let state' = step action state in
  state'.money >= 0
)
```

Imandra has proven that for any `state` and after processing any `action`, `money` is always non-negative: the invariant holds for all states of the system.

## One step further: checking Atomicity

> So far we haven’t done anything too out of the ordinary. Everything so far is easily coverable in a real system by unit and property tests. There’s still a lot more ground to cover, but I want to show that we can already use what we’ve learned to find more complicated bugs. Alice wants to give Bob 1,000 dollars. If we’re unlucky, it could play out like this:
>
>  1. System checks that Alice has enough money
>  2. \$1,000 is deducted from her account
>  3. Eve smashes in the server with a baseball bat
>  4. Bob never receives the money
>  5. \$1,000 has completely disappeared from the system
>  6. The SEC shuts you down for fraud.
>
> We already have all of the tools to check this. First, we need to figure out how to represent the broken invariant. We could do that by requiring the total money in the system is always the same:

In our Imandra model we could express this as follows: given any `state` and any `action`, the total money in the system at the start should be equal to the total money in the system afterwards:

```{.imandra .input}
let account_total state =
  state.alice_account + state.bob_account

verify (fun action state ->
  state.money >= 0
  ==>
  let state' = step action state in
  account_total state = account_total state'
)
```

> When we run this, TLC finds a counterexample: between steps A and B the invariant doesn’t hold.

Imandra has found this same counterexample.

> How do we solve this? It depends on the level of abstraction we care about. If you were designing a database, you’d want to spec the exact steps required to keep the system consistent. At our level, though, we probably have access to database transactions and can ‘abstract out’ the atomicity checks. The way we do that is to combine A and B into a single “Transaction” step. That tells TLA+ that both actions happen simultaneously, and the system never passes through an invalid state.

There are many different ways we could choose to model this in Imandra. Here is one:

```{.imandra .input}
type action =
  | Transfer (* In this step we'll check whether Alice's balance is sufficient *)
  | A (* In this step we'll transfer the funds *)
  | End

type state =
  { alice_account : int
  ; bob_account : int
  ; money : int
  ; next_action : action (* The action that should be executed on the next call to step *)
  }

let is_valid_initial_state state =
  state.alice_account >= 0 &&
  state.money >= 0 &&
  state.next_action = Transfer

let step state =
  match state.next_action with
  | Transfer ->
    if state.alice_account >= state.money then
      { state with next_action = A }
    else
      { state with next_action = End }
  | A ->
    { state with
      alice_account = state.alice_account - state.money
    ; bob_account = state.bob_account + state.money
    ; next_action = End
    }
  | End ->
    state

(* step_n repeatedly calls (step state) n times. *)
let rec step_n n state =
  if n > 0 then
    step_n (n-1) (step state)
  else
    state

let account_total state =
  state.alice_account + state.bob_account

verify (fun n state ->
  n < 5 &&
  is_valid_initial_state state
  ==>
  let state' = step_n n state in
  account_total state = account_total state' &&
  state'.alice_account >= 0
)
```

## Multiprocess Algorithms

> As a final part of our example, let’s discuss concurrency.

> The accounts are global variables, while money is a local variable to the process.

In our model, we will treat `state` (which holds the accounts) as a global variable. The state of our processes will be represented by the `process_state` type - each has a local `money` variable. The `world` type will hold the global `state` of the accounts and the `process_state` for each process.

We'll then define a function `run_world`, which takes a `world` state and a scheduled execution order in the form of a list of process `context`s, and executes the processes according to the schedule.

We want to verify that, given any initial `world`, the following invariants hold regardless of the order in which the processes are executed:
  1. The total money in the system does not change.
  2. Alice's account never goes negative.

```{.imandra .input}
(** Global state of accounts *)
type state =
  { alice_account : int
  ; bob_account : int
  }

(** Actions for an individual process *)
type process_action =
  | Transfer
  | A
  | End

(** The state of a process *)
type process_state =
  { money : int
  ; next_action : process_action
  }

(** State of the world *)
type world =
  { state : state
  ; p1_state : process_state
  ; p2_state : process_state
  }

(** Step a process's next_action. Returns the updated global accounts
    state and the new state of this process. *)
let step_process state process_state =
  match process_state.next_action with
  | Transfer ->
    if state.alice_account >= process_state.money then
      (state, { process_state with next_action = A })
    else
      (state, { process_state with next_action = End })
  | A ->
     ( { alice_account = state.alice_account - process_state.money
       ; bob_account = state.bob_account + process_state.money
       }
     , { process_state with next_action = End }
     )
  | End ->
    (state, process_state)

(** Current execution context *)
type context =
  | Process_1
  | Process_2

(** Step the world forward for a given execution context. *)
let step_world context world =
  match context with
  | Process_1 ->
    let (state, p1_state) = step_process world.state world.p1_state in
    { world with state; p1_state }
  | Process_2 ->
    let (state, p2_state) = step_process world.state world.p2_state in
    { world with state; p2_state }

(** run_world takes an initial world state and executes the processes
    according to the schedule specified by contexts *)
let run_world world contexts =
  contexts |> List.fold_right step_world ~base:world
```

Now we can verify that, for any initial state of the world and for any possible sequence of contexts, the invariants hold.

```{.imandra .input}
(** A state is a valid initial state if the accounts are non-negative. *)
let is_valid_initial_state state =
  state.alice_account >= 0 &&
  state.bob_account >= 0

(** This function checks whether a process is in a valid starting state.
    We'll use it to constrain the input to our verify statement below. *)
let is_valid_initial_process_state p =
  p.money >= 0 &&
  p.next_action = Transfer

(** The world is a valid initial state if the accounts and processes are all valid. *)
let is_valid_initial_world world =
  is_valid_initial_state world.state &&
  is_valid_initial_process_state world.p1_state &&
  is_valid_initial_process_state world.p2_state

let account_total state =
  state.alice_account + state.bob_account

verify (fun contexts world ->
  (* Initial states are valid *)
  is_valid_initial_world world
  ==>
  let world' = run_world world contexts in
  account_total world.state = account_total world'.state &&
  world'.state.alice_account >= 0
)
```

> There’s a gap between when we check that Alice has enough money and when we actually transfer the money. With one process this wasn’t a problem, but with two, it means her account can go negative. TLC is nice enough to provide the initial state and steps required to reproduce the bug.

Imandra has also found a counterexample. We can see from the `contexts` in the counterexample that one process interrupted the other.

We can also execute the counterexample to see the final state of the world in this case:

```{.imandra .input}
run_world CX.world CX.contexts
```

## Summary

We've shown how these TLA+ problems can be modeled in Imandra, in an apples-to-apples fashion.

In most cases we've translated the PlusCal examples into a state machine, which is closer to the underlying TLA+ representation. A PlusCal-like DSL for Imandra would be an interesting future project.

Both systems can go much deeper: TLA+ has theorem proving capabilities, and we haven't touched on Imandra's lemmas, theorems, rewrite rules or the induction waterfall. Browse the documentation to find out more!
