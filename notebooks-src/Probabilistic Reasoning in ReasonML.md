---
title: "Probabilistic Reasoning in ReasonML"
description: "In this ReasonML notebook, we employ Imandra ability to reason about functional values to analyse probabilistic scenarios following the example of the Monty Hall problem."
kernel: imandra-reason
slug: probabilistic-reasoning-in-reasonml
key-phrases:
  - ReasonML
  - proof
  - probabilities
  - counterexample
  - instance
---


An amazing feature of Imandra is the ability to reason about functional inputs and generate functional instances and counterexamples. For example we can introduce a variant type and a second-order function that evaluates its argument on each variant and computes the sum of the results. 


```{.imandra .input}
type t = A | B | C
let sum = (f) => f(A) + f(B) + f(C)  
```

Now, let's ask Imandra to come up with an instance of a function `f` that returns positive values and that produces `42` when calling `sum(f)`:


```{.imandra .input}
instance( (f) => f(A) > 0 && f(B) > 0 && sum(f) == 42 )
```

A natural application of this ability is to apply it to formal reasoning about random variables and probability distributions over them. In the following, we'll consider an application of this kind of reasoning to analyse the famous Monty Hall problem.

# Monty Hall problem

In the Monty Hall problem, you are participating in a game where you are given three doors to choose from. One of the doors randomly contains a $1,000,000 prize. Let’s encode that in ReasonML — we’ll introduce the value of the prize and the variant type for the doors.



```{.imandra .input}
let prize = 1000000.0

type door =
  | DoorA
  | DoorB
  | DoorC
```

The game then proceeds as follows: first, you guess one of the doors, then the host opens another door — a door that, the host knows, doesn’t contain the prize. The host then offers you to change your initial guess or stay with it.

To encode that, we’ll introduce another variant type for the player choice and gather all the values that describe a single Monty Hall trial into a `scenario` record.


```{.imandra .input}
type choice =
  | Stay
  | Swap

type scenario = 
  { prize       : door
  , first_guess : door
  , choice      : choice
  }
```

## Probability mass functions 

We want to treat scenarios described by the "scenario" record as random. This means, that we would like to deal with [probability mass functions](https://en.wikipedia.org/wiki/Probability_mass_function) (PMFs) over the variables of the declared types. As a first example lets make a PMF for the doors  that distribute over the three doors with equal probabilities:


```{.imandra .input}
let pDoorsEqual : (door => real) = (door) => Real.(1.0 / 3.0)
```

Notice that we are using the `real` type for numeric values in our examples. Internally, Imandra represents reals as arbitrary-precision rational numbers. The real-valued arithmetic operators are gathered in the `Real` module. Further, we’ll be explicitly opening the `Real` module to stress that we are dealing with the rational arithmetic.

Not any function can be a probability mass function — PMFs must satisfy the so-called “measure axioms”: all the returned values must be positive and the total probability over the whole function domain must sum to one. Let’s make a predicate that checks whether a function is a valid PMF over doors.


```{.imandra .input}
let valid_door_pmf : (door => real) => bool =  
  (pmf) => Real.(
    (pmf(DoorA) + pmf(DoorB) + pmf(DoorC) == 1.0) &&
    (pmf(DoorA) >= 0.0) &&
    (pmf(DoorB) >= 0.0) &&
    (pmf(DoorC) >= 0.0)  
  )
```

To check that this predicate works we use it on our `pDoorsEqual` function. 


```{.imandra .input}
valid_door_pmf(pDoorsEqual)
```

The player controls the `first_guess` and the `choice` fields of the `scenario` record. In general, the player can also choose his actions randomly. Following the game theory nomenclature, we’ll call the probability distribution over the player choices a “strategy”. For example, here is a strategy that chooses the first guess door randomly and then stays with that choice:


```{.imandra .input}
let random_then_stay_strategy : (door => choice => real) =
  (door) => (choice) => Real.(
    switch(door,choice){
    | ( _ ,Stay) => 1.0 / 3.0
    | ( _ ,Swap) => 0.0 
    } 
  )
```

A strategy’s type is `door => choice => real`: it takes in which door the player chooses and which choice he makes and returns the probability with which that happens. To check that such a function is a valid probability mass function we introduce and apply a predicate for it:


```{.imandra .input}
let valid_strategy : (door => choice => real) => bool = 
  (strategy) => Real.({  
    (strategy(DoorA,Stay) >= 0.0) && (strategy(DoorA,Swap) >= 0.0) &&
    (strategy(DoorB,Stay) >= 0.0) && (strategy(DoorB,Swap) >= 0.0) &&
    (strategy(DoorC,Stay) >= 0.0) && (strategy(DoorC,Swap) >= 0.0) &&
    ( strategy(DoorA,Stay) + strategy(DoorA,Swap) +
      strategy(DoorB,Stay) + strategy(DoorB,Swap) +
      strategy(DoorC,Stay) + strategy(DoorC,Swap) == 1.0) 
  });
```


```{.imandra .input}
valid_strategy(random_then_stay_strategy)
```

Finally, we’ll need one last function that constructs a PMF over the whole scenario record. It shall take a `door => real` prize PMF, a `door => choice => real` player strategy and return a `scenario => real` PMF over the scenarios. Since we consider the host and the player choices to be independent, the total probability of the full scenario must be the product of the probabilities of the host and player choices:


```{.imandra .input}
let make_scenario_pmf : (door => real) => (door => choice => real) => (scenario => real) = 
  (door_pmf) => (strategy) => (s) => Real.({
    door_pmf(s.prize) * strategy(s.first_guess, s.choice)
  })
```

## Expected rewards

Given a `scenario` variable, we calculate a reward that the player gets. When the first guess is equal to the prize location, then we return the prize value if the player decided to stay. Alternatively, when the first guess is not equal to the prize location, then we return the prize value if the player decided to swap.


```{.imandra .input}
let reward = (scenario) =>
  if( scenario.prize == scenario.first_guess ) { 
      if(scenario.choice == Stay) prize else 0.0;
  } else { 
      if(scenario.choice == Swap) prize else 0.0;
  }
```

Given a probability distribution over scenarios, we want to calculate the expected value of the reward - the probability-weighted average of possible values of the reward for each outcome. 
$$ E[reward] = \sum_s P(s)\,reward(s) $$
We create a function that performs this averaging: it takes in a scenario PMF of type `scenario => real` and returns a `real` value for the expectation value:


```{.imandra .input}
let expected_reward : (scenario => real) => real = 
  (scenario_pmf) => Real.({
    let pr = (s) => scenario_pmf(s) * reward(s);
      let avg = (choice) => {
        let avg = (first_guess) => {
          pr { prize: DoorA, first_guess, choice} +
          pr { prize: DoorB, first_guess, choice} +
          pr { prize: DoorC, first_guess, choice} 
        };
      avg(DoorA) + avg(DoorB) + avg(DoorC) 
      };
    avg(Stay) + avg(Swap)
  })
```

As a final example, let’s use what we’ve built so far to calculate the expected reward for the scenario when the host hides the prize equally randomly and the player uses the `random_then_stay_strategy`:




```{.imandra .input}
expected_reward(
  make_scenario_pmf(pDoorsEqual, random_then_stay_strategy)
) 
```

We get an obvious result that if we choose a random door and stay with it, then the expected reward is 1/3 of a $1,000,000. That seems reasonable and it is not very obvious that one can increase his chances of winning.

# Reasoning about Monty Hall probabilities

Let’s ask Imandra if 1/3 of a 1,000,000$ is the best outcome for any strategy the player can employ. To do this we’ll use Imandra `verify` directive to verify that, for any valid strategy, the scenario with equally probable prize placement gives an expected reward less or equal than 1000000/3.


```{.imandra .input}
verify ( (strategy) => Real.({
  valid_strategy(strategy) ==>
  ( expected_reward (
      make_scenario_pmf(pDoorsEqual,strategy)
  ) <= 1000000.0 / 3.0 ) 
}))
```

Imandra refuted our statement and provided us with a counterexample strategy. Imandra suggests that the expected reward will be greater than 1000000/3 if the player chooses `DoorA` and then `Swap`s his choice in 0.0003% of the cases. The counterexample strategy is defined in the `CX` module, so let's  see what is the expected reward with this strategy:


```{.imandra .input}
expected_reward(
  make_scenario_pmf(pDoorsEqual, CX.strategy)
)
```

The counterexample strategy that Imandra produced increased our expected winnings by 1$. This counterexample strategy employs swapping instead of staying. What would be our expected reward if we always swap?


```{.imandra .input}
let random_then_swap_strategy = (door : door,choice) => 
    switch(door,choice){ | (_,Swap) => Real.(1.0 / 3.0) | _ => 0.0 };
expected_reward(
  make_scenario_pmf(pDoorsEqual,random_then_swap_strategy)
)
```

By always swapping we’ve increased our chances of winning up to 2/3. Is this the best possible expected reward one might get in this game?


```{.imandra .input}
verify ( (strategy) => Real.({
  valid_strategy(strategy) ==>
  ( expected_reward (
      make_scenario_pmf(pDoorsEqual,strategy)
  ) <= 2000000.0 / 3.0 ) 
}))
```

We’ve proven that the best possible expected reward in the Monty Hall game is 2/3 of a $1,000,000 in an (arguably, rather counterintuitive) result that one has to always swap his first choice to double his chances of winning.

Suppose now that we don’t know the winning strategy, but we do know that it is possible to win in 2/3 of the cases. Can we ask Imandra to synthesise the optimal strategy? For this purpose we can use the `instance` directive:


```{.imandra .input}
instance ( (strategy) => Real.({
  valid_strategy(strategy) &&
  ( expected_reward (
      make_scenario_pmf(pDoorsEqual,strategy)
  ) == 2000000.0 / 3.0 ) 
}))
```

We've got an example of an optimal strategy - this one doesn't randomize over doors, but suggests to always choose the DoorA and then swap.

# Biased Monty Hall

Now let's apply what we've learned about the "standard" Monty Hall paradox to a more complicated game setup - suppose that we somehow know that the host is biased towards the `DoorA` -- the probability that the host will hide the prize behind the first door is 3 times higher than the individual probabilities for two other doors. Should one still always swap? Or, maybe, it makes more sense to always choose the more likely `DoorA` and stay?

We encode our biased host in the biased PMF over doors (also doing a sanity check that it is a valid probability distribution):


```{.imandra .input}
let pDoorsBiased = (door : door) => Real.(
  switch (door){
  | DoorA => 3.0 / 5.0
  | DoorB | DoorC => 1.0 / 5.0
  }
);

valid_door_pmf(pDoorsBiased)
```

In the previous section, we've proven that the maximal possible expected reward in the "standard" Monty Hall problem is 2/3 of a million. Again, we ask Imandra whether we can improve on this in the biased case:


```{.imandra .input}
verify ( (strategy) => Real.({
  valid_strategy(strategy) ==>
  ( expected_reward (
      make_scenario_pmf(pDoorsBiased,strategy)
  ) <= 2000000.0 / 3.0 ) 
}))
```

Imandra suggests that we can do better than 2/3 if we use a mixed strategy of either choosing the `DoorA` and staying or choosing the `DoorC` and swapping. Let's test both of these pure strategies and see what would be the expected rewards for each:


```{.imandra .input}
let aStayStrategy = (door,choice) => 
    switch(door,choice){ | (DoorA,Stay) => 1.0 | _ => 0.0 };
expected_reward(
  make_scenario_pmf(pDoorsBiased,aStayStrategy)
);
let cSwapStrategy = (door,choice) => 
    switch(door,choice){ | (DoorC,Swap) => 1.0 | _ => 0.0 };
expected_reward(
  make_scenario_pmf(pDoorsBiased,cSwapStrategy)
);
```

Choosing the `DoorC` and then swapping increases the chances of winning up to 80%! Again, is this the best outcome one can get?


```{.imandra .input}
verify ( (strategy) => Real.({
  valid_strategy(strategy) ==>
  ( expected_reward (
      make_scenario_pmf(pDoorsBiased,strategy)
  ) <= 800000.0 ) 
}))
```

And we've proven that the DoorC-Swap is the best strategy the player can employ in this setup. Intuitively the reason for that is that it is better to choose the least likely door, forcing the host to reveal more information about the prize location in the more likely doors.

# Even more complex example

Using this approach one can go further and analyse even more complicated Monty-Hall-like games (for example, the prize value might depend on the door and/or player actions).

```{.imandra .input}
let pDoorsComplex = (door : door) => Real.(
  switch (door){
  | DoorA => 5.0 / 10.0
  | DoorB => 3.0 / 10.0 
  | DoorC => 2.0 / 10.0
  }
);

let reward_complex = (scenario) => {
  let prize = switch(scenario.prize) {
  | DoorA => 1000000.
  | DoorB => 2000000.
  | DoorC => 4000000.      
  }; 
  if( scenario.prize == scenario.first_guess ) { 
      if(scenario.choice == Stay) prize else 0.0;
  } else { 
      if(scenario.choice == Swap) prize else 0.0;
  }
};

let expected_reward_complex : (scenario => real) => real = 
  (scenario_pmf) => Real.({
    let pr = (s) => scenario_pmf(s) * reward_complex(s);
      let avg = (choice) => {
        let avg = (first_guess) => {
          pr { prize: DoorA, first_guess, choice} +
          pr { prize: DoorB, first_guess, choice} +
          pr { prize: DoorC, first_guess, choice} 
        };
      avg(DoorA) + avg(DoorB) + avg(DoorC) 
      };
    avg(Stay) + avg(Swap)
  })
```


```{.imandra .input}
verify ( (strategy) => Real.({
  valid_strategy(strategy) ==>
  ( expected_reward_complex (
      make_scenario_pmf(pDoorsComplex,strategy)
  ) <= 1400000.0 ) 
}))
```


```{.imandra .input}
instance ( (strategy) => Real.({
  valid_strategy(strategy) &&
  ( expected_reward_complex (
      make_scenario_pmf(pDoorsComplex,strategy)
  ) == 1400000.0 ) 
}))
```

More generally, this illustrates how we can use Imandra’s ability to reason about functional values and real arithmetic to formally prove and refute statements about probability distributions. These abilities allow us to us to formally analyse many kinds of scenarios requiring the ability to reason about random variables.
