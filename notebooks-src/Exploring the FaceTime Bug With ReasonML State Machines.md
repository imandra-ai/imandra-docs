---
title: "Exploring The Apple FaceTime Bug with ReasonML State Machines"
description: "In this notebook we explore the Apple FaceTime bug and different ways of modelling our applications as state machines."
kernel: imandra-reason
slug: reasonml-facetime-state-machines
key-phrases:
  - proof
  - counterexample
  - instance
  - ReasonML
  - interactive development
  - state machines
---

# Exploring The Apple FaceTime Bug with ReasonML State Machines

[The Apple FaceTime bug](https://www.bbc.co.uk/news/technology-47037846) swept the news in early 2019 - callers using FaceTime were able to hear the microphone of a new participant being added to a call, before the new participant had accepted the incoming call request. Yikes!

[@DavidKPiano](https://twitter.com/DavidKPiano) recently wrote [a very interesting Medium article](https://medium.com/@DavidKPiano/the-facetime-bug-and-the-dangers-of-implicit-state-machines-a5f0f61bdaa2) about the bug, using it to illustrate the dangers of implicit state machines in your codebase. David's post presents a strong case for explicitly identifying your state machines - by making them a prominent part of your design and your code itself, your thinking about changes becomes more robust. I encourage you to check out his post and also his JS library [xstate](https://github.com/davidkpiano/xstate)!

I'm going to explore the adapted example from that post from a slightly different angle - we'll look at various ways of encoding his example as a state machine in ReasonML code, and show how this process can help us prevent invalid states from being admitted in the first place. We'll also have a look at using [Imandra](https://www.imandra.ai) to verify properties of our state machines.

I'll also add that we're in no way making any assumptions or judgements about how Apple employees actually develop FaceTime here - this post is more to illustrate that these kind of bugs are pervasive, and the more tools we have to help eliminate them, the better.

Overall, I hope to reiterate David's message that state machines are a very useful tool for modelling parts of your applications. Writing them explicitly and using a tool like `xstate` can help make it easier for you to reason about your system, but it turns out they also make it easier for computers to reason about your system too! Let's dive in.

Remember, you can hit 'Try this!' to open an interactive notebook and play around with the model yourself.

## A simplified call model

Let's start with some simple types represeting actions in an application for receiving incoming calls. We'll assume that once remote users make it into the `peopleInCall` list, they can hear the microphone of the phone running the app:

```{.imandra .input}
type person = int;

type action =
  | CallIncomingFrom(person)
  | CallAccepted
  | CallRejected
  | EndCall;
```

We can receive incoming calls from a person, accept or reject an incoming call, and then end a call. So far so good - next, let's come up with a state type for these actions to act on:

```{.imandra .input}
type status =
  | Idle
  | CallActive
  | CallIncoming;

type state = {
  status: status,
  callIncomingFrom: option(person),
  peopleInCall: list(person),
};
```

Nothing looks too out of the ordinary here - these are all fields we're likely to need as our app runs. Now let's write the core state update logic:

```{.imandra .input}
let update = (state: state, action): state =>
  switch (action) {
  | CallIncomingFrom(person) => {...state, status: CallIncoming, callIncomingFrom: Some(person)}
  | CallRejected => {...state, status: Idle, callIncomingFrom: None}
  | CallAccepted =>
    switch (state.callIncomingFrom) {
    | Some(p) => {status: CallActive, callIncomingFrom: None, peopleInCall: [p]}
    | None => state
    }
  | EndCall => {...state, status: Idle, peopleInCall: []}
  };
```

This function represents the transitions of a state machine!

Encoding this in the Reason/OCaml type system gives us a couple of advantages - the `switch` statement (`match` in OCaml syntax) can also check that we've exhaustively covered all the actions. Also, if we decide to wire this up to a React UI, ReasonML's React bindings include a ReducerComponent out of the box that expects a function of this shape. React's new Hooks API also has a similar primitive in the form of the `useReducer` Hook.

## Changing the model

Now let's imagine a new requirement comes in.

> Handle messages from the system requesting new people be added to a call.

Let's give that a go. We'll add a new action `AddPerson` representing the system message:

```{.imandra .input}
type action_v2 =
  | CallIncomingFrom(person)
  | CallAccepted
  | CallRejected
  | EndCall
  | AddPerson(person);
```

```{.imandra .input}
let update_v2 = (state: state, action: action_v2): state =>
  switch (action) {
  | CallIncomingFrom(person) => {...state, status: CallIncoming, callIncomingFrom: Some(person)}
  | CallRejected => {...state, status: Idle, callIncomingFrom: None}
  | CallAccepted =>
    switch (state.callIncomingFrom) {
    | Some(p) => {status: CallActive, callIncomingFrom: None, peopleInCall: [p]}
    | None => state
    }
  | EndCall => {...state, status: Idle, peopleInCall: []}
  | AddPerson(person) => {...state, peopleInCall: [person, ...state.peopleInCall]}
  };
```

We'll even write a test for it:

```{.imandra .input}
type test_outcome = | Pass | Fail;

let test_add_person_action = {
  let start_state = { status: CallActive, peopleInCall: [1, 2], callIncomingFrom: None };
  let end_state = update_v2(start_state, AddPerson(3));
  if (List.exists(x => x == 3, end_state.peopleInCall) && end_state.status == CallActive) {
      Pass
  } else {
      Fail
  }
};

```

...and all is right with the world. Or is it? If you look carefully, we've baked into our test an assumption about the starting status of the state when handling the `AddPerson` action - something that's easily done if we've got our feature implementation blinkers on.

What the test misses is the `AddPerson` action being used in a state that isn't `CallActive`. As nothing actually validates that the state is correct, we could potentially end up having a person added to `peopleInCall` before the call is accepted - similar to what happened with the real bug.

## The ideal approach

Although the type system has helped us out here a bit, we can leverage it even further by writing our states in a way that makes expressing this bug impossible in the first place.

```{.imandra .input}
type call = {people: list(person)};

type ideal_state =
  | Idle
  | CallActive(call)
  | CallIncoming(person);

```

Here we're using a variant type to represent mutually exclusive bits of state. This means we can't have any `call` state unless we're actually in an active call, and similarly it eliminates some possible uncertainty in the `CallIncoming` state about the person we're receiving the call from.

We also define a type for the outcome of an update:

```{.imandra .input}
type update_outcome('a) =
  | Updated('a)
  | Invalid;

```

Previously we only returned the original state for unexpected actions (returning `state` for the `state.callIncomingFrom == None` branch of the `CallAccepted` action, in `update_v2`). We know intuitively this shouldn't happen, but let's use the type system to our advantage by explicitly making cases like that an invalid outcome. That way the code that's actually running our state machine can check for invalid outcomes and log an error message to let us know that something is wired up incorrectly, which may indicate another bug somewhere.

Now let's use these new types in our new and improved update function:

```{.imandra .input}
let ideal_update = (state: ideal_state, action : action_v2): update_outcome(ideal_state) =>
  switch (state, action) {
  | (Idle, CallIncomingFrom(p)) => Updated(CallIncoming(p))
  | (CallIncoming(_), CallRejected) => Updated(Idle)
  | (CallIncoming(p), CallAccepted) => Updated(CallActive({people: [p]}))
  | (CallActive(_), EndCall) => Updated(Idle)
  | (CallActive(call), AddPerson(p)) =>
    Updated(CallActive({people: [p, ...call.people]}))
  | _ => Invalid
  };
```

The types have actually guided us here to make our transition function more correct - we are now forced to switch on both the action coming in _and_ the current state in order to have access to the call state that we need to update when adding a new person to the call.

## Meeting halfway

While this representation is ideal for this small example, we can't always quite pull this off. Sometimes we simply can't express the type of constraint we want, due to the limitations of the type system. Sometimes we can, but by doing so we make the code unreadable or very unwieldy to use. Alternatively, we may have started with the original representation, but have too much code dependent on it to be able to make the change under given time constraints (although the Reason/OCaml type system would definitely help with the refactoring!). So let's not let the 'perfect' be the enemy of the good - instead, let's take a step back to the original version of our update function in order to demonstrate what it looks like to meet somewhere in the middle.

One way of looking at static type systems like this is as tools for proving properties of your code at compile time. By writing our code in a way that satisfies the rules of the type system, we're given a certain class of guarantees about our programs - the tradeoff is that we lose some expressiveness. In our ideal representation we can no longer express certain invalid states, which is what we want! But sometimes by following the rules of the type system we find it hard to express certain things that we do want.

If we're using Reason/OCaml, we have another option - we can use [Imandra](https://www.imandra.ai), a cloud-native automated reasoning engine.

Like a type system, Imandra is also a tool that can be used to prove that properties of your program hold true, but we can express these properties themselves as snippets of Reason/OCaml code. This allows us to direct the checking process in a way that's much more tailored to the domain of the program itself, rather than on the more generic language level.

What does this all mean? Let's start by writing a property, or verification goal, about our earlier implementation `update_v2`:

```{.imandra .input}
let add_person_property =
    (state: state, person: int) => {
  let new_state = update_v2(state, AddPerson(person));
  if (List.length(new_state.peopleInCall) > 0) {
    new_state.status == CallActive;
  } else {
    true;
  };
};
```

This is a function that takes an arbitrary state and person, performs some actions on them, and then returns `true` or `false` to indicate whether the property holds. So here we're saying that if there are people in the call after responding to the `AddPerson` message, we're in the `CallActive` state, which is a nice general concept we'd like to be true! We are specifically testing the action that we know is broken here, but let's accept that for now and see what happens when we ask Imandra to verify the property for us (we're specifying a max unrolling depth for verification of 50 with the `~upto` flag - we'll come back to this later):

```{.imandra .input}
verify ~upto=50 add_person_property;
```

Imandra analyses our code symbolically and we don't just get a pass/failure result - we get concrete counterexample values for the inputs to our function that illustrate the flaw in our thinking. If we want, we can compute and experiment with them (which can be very useful for investigating bugs Imandra has found):

```{.imandra .input}
List.length(CX._x_0.peopleInCall);
```

As we said, the goal above is fairly focused in on our new feature, and we've written it already knowing there's a bug in the area we're targeting - let's work with something that's more universal, helped by the fact that we've modeled things as a state machine. A helpful pattern when dealing with state machines is to check that properties hold under arbitrary sequences of actions:

```{.imandra .input}
let call_with_people_in_is_active_property = (update_fn, initial_state, actions : list('a)) => {
  let final_state = List.fold_left(update_fn, initial_state, actions);
  if (List.length(final_state.peopleInCall) > 0) {
    final_state.status == CallActive;
  } else {
    true;
  };
};
```

This checks the same underlying idea that we never have more than 0 people in the call unless the call is active, but in a more general way - we no longer check the single specific action. The nice thing about properties like this is that we can imagine that we'd still want them to hold true as we make additional changes to our state machine, and staying decoupled from specific actions helps us achieve that.

We simulate actions run in a react-like reducer using a `fold` (`fold` and `reduce` are synonymous). We're also passing in a target `update_fn` as we're going to use it on multiple versions of `update` as we progress. Imandra will check that the property holds for all possible values of the type 'list of actions' (the last parameter to our property function). Let's try it out:

```{.imandra .input}
let initial_state = { status: Idle, callIncomingFrom: None, peopleInCall: [] };
verify ~upto=50 call_with_people_in_is_active_property(update_v2, initial_state);
```

The sequence of actions with a single `AddPerson` item already contradicts our property, which immediately shows us our issue and gives us an example to help out:

```{.imandra .input}
update_v2(initial_state, AddPerson(4));
```

Let's try running the same property on our original update function, from before we added the new `AddPerson` action:

```{.imandra .input}
verify ~upto=50 call_with_people_in_is_active_property(update, initial_state);
```

This reveals another case we hadn't considered! We don't handle the `CallIncomingFrom` action from the `CallActive` state - it drops us straight out of `CallActive` back into `CallIncoming` while leaving people in the call, which might not be what we want.

```{.imandra .input}
update(update(update(initial_state, CallIncomingFrom(4)), CallAccepted), CallIncomingFrom(5));
```

Now we know there's a problem, we can re-work our update logic to accommodate. We learnt earlier while working on our 'ideal' representation that checking the current state is a good idea, so let's incorporate that here:

```{.imandra .input}
let good_update = (state: state, action: action_v2): state =>
  switch (state.status, action) {
  | (Idle, CallIncomingFrom(person)) =>
    {...state, status: CallIncoming, callIncomingFrom: Some(person)}
  | (CallIncoming, CallRejected) =>
    {...state, status: Idle, callIncomingFrom: None}
  | (CallIncoming, CallAccepted) =>
    switch (state.callIncomingFrom) {
    | Some(p) =>
      {status: CallActive, callIncomingFrom: None, peopleInCall: [p]}
    | _ => state
    }

  | (CallActive, AddPerson(p)) =>
    {...state, peopleInCall: [p, ...state.peopleInCall]}
  | (CallActive, EndCall) =>
    {...state, status: Idle, peopleInCall: []}
  | _ => state
  };

```

Next, let's check it with our general property:

```{.imandra .input}
verify ~upto=50 call_with_people_in_is_active_property(good_update, initial_state);
```

Imandra's standard unrolling verification method can't find any issues up to our fairly high bound of 50 here. Although it hasn't totally proved things for us, this is a good indicator that we're on the right lines as it can't find any counterexamples. It's pretty hard for us to prove things completely in this case using this method, due to the nature of our property - as the list of actions is arbitrary and our state machine contains cycles, there are valid sequences of actions that are infinite, for example `[CallIncoming(1), CallAccepted, EndCall, CallIncoming(1), CallAccepted, EndCall, ...]`.

If we want to increase our level of confidence even further, we can spend a bit longer to get a complete proof. In this case we can try Imandra's `[@auto]` method, which performs a proof by induction for all possible inputs:

```{.imandra .input}
[@auto] verify call_with_people_in_is_active_property(good_update, initial_state);
```

We run into a limit here due to our use of `fold_left`. A common trick when using induction is to switch to using `fold_right` instead, which is easier to induct on (this also means the actions list is 'reduced' in reverse order, but that doesn't make a difference here):

```{.imandra .input}
let call_with_people_in_is_active_property_fold_right = (update_fn, initial_state, actions : list('a)) => {
  let final_state = List.fold_right((a, b) => update_fn(b, a), ~base=initial_state, actions);
  if (List.length(final_state.peopleInCall) > 0) {
    final_state.status == CallActive;
  } else {
    true;
  };
};
```

```{.imandra .input}
[@auto] verify(call_with_people_in_is_active_property_fold_right(good_update, initial_state));
```

Fully proved! For larger functions going into Imandra's more advanced features will require more expertise, and may or may not be worth it over the guarantees that the basic unrolling method gives us. Whether the cost makes sense will depend on what you're working on.

One other improvement we could make is to incorporate the `update_outcome` concept from our ideal version, and check that the property holds for valid resulting states only. This would enable us to stop passing the concrete, valid `initial_state` in as an argument and allow Imandra to verify that this works for all possible `state` values in our property arguments, as the update function would handle filtering out invalid states for us. Analogously we can 'guard' our states with a separate `is_valid` function as part of the property. Have a go at doing this yourself in the notebook!

We've given you a quick taste of some new possibilities here, but the takeaway is that state machines are a useful tool - having a formalized way of thinking about a class of system makes life easier for both you _and_ the computer, whether that's via pure human brain power, a type system or an automated reasoning tool like [Imandra](https://www.imandra.ai).
