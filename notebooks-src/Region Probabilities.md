---
title: "Region Probabilities"
description: "Estimating Region Probabilities from Statistical Models and Datasets"
kernel: imandra
slug: region-probabilities
difficulty: advanced
---

# Region Probabilities

In this notebook we provide an introduction to the latest Imandra Tools module, `Region_probs`, which includes a small probabilistic programming library that allows users reason about Imandra Modelling Language (IML) models probabilistically. In particular, users can easily create custom hierarchical statistical models defining joint distributions over inputs to their programs or functions, then sample from these models to get a probability distribution over regions, or query them with Boolean conditions. Alternatively, a dataset in the form of a `CSV` file can be imported and used as a set of samples. In a later notebook we'll illustrate how these tools can be used to analyse and verify the fairness of decision-making algorithms, but here we'll keep things simple and just demonstrate the basic functionalities of the module.

### Setup

We'll begin by opening the module and installing a pretty printer that will display a decimal version of the real numbers that we'll often be using in this notebook:

```{.imandra .input}
open Imandra_tools.Region_probs;;
let pp_approx fmt r = CCFormat.fprintf fmt "%s" (Real.to_string_approx r) [@@program];;
#install_printer pp_approx;;
```

Note that the module's interface and type signatures can be found [in the docs pages](https://docs.imandra.ai/imandra-docs/odoc/imandra-tools/Imandra_tools/Region_probs/index.html).

### Basic Distributions

The `Region_probs` module contains 13 of the most common discrete and continuous univariate probability distributions which can be parameterised and then used directly. In particular, we support the following distributions:

* Bernoulli
* Beta
* Binomial
* Categorical
* Cauchy
* Exponential
* Gamma
* Guassian
* Laplace
* Logistic
* LogNormal
* Poisson
* Uniform

Each distribution has named parameters and can take an optional argument `~constraints` which truncates the distribution to within the bounds specified by the constraint list. For example, we can define a Gaussian random variable `x` with mean `5` and standard deviation `1.3`, that is restricted to the regions `[2.5, 5]` and `[5.8, 10.3]` as:

```{.imandra .input}
let x = gaussian ~mu:5. ~sigma:1.3 ~constraints:[(2.5,5.); (5.8,10.3)] [@@program]
```

We then sample from the distribution to get a particular value by calling `x` with the unit argument `()`:

```{.imandra .input}
x ();;
x ();;
x ();;
```

### Building Statistical Models

Using the basic univariate distributions above as building blocks we can create more complex custom joint distributions over inputs by generating samples sequentially. For example, let's define a distribution over some apples in a shop. Let's consider three kinds of apple, `Braeburn`, `Granny_Smith`, and `Red_Delicious` which are stocked in varying proportions. We can also suppose that their weights might be normally distributed according to their kind. Let's assume that each apple stays in the shop for a week at a time and that there is a `0.4` chance that any particular apple gets bought on a particular day. Then the number of days an apple has been in the shop can be modelled by a Binomial distribution. Finally, let's say that the apples tend to turn ripe quickly after `3` days, if they're not already ripe. Thus, a joint distribution over apples can be given as follows:

```{.imandra .input}
type kind = Braeburn | Granny_Smith | Red_Delicious

type apple = { kind: kind;
               mass: Q.t;
               days_old: Z.t;
               is_ripe: bool }

let apple_dist () =
  let k = categorical ~classes:[Braeburn; Granny_Smith; Red_Delicious] ~probs:[0.25; 0.6; 0.15] () in
  let mean_mass = function
  | Braeburn -> 85.
  | Granny_Smith -> 80.
  | Red_Delicious -> 100. in
  let mu = mean_mass k in
  let m = gaussian ~mu ~sigma:5. () in
  let d_o = binomial ~n:7 ~p:0.4 () in
  let ripe_chance days = if days >= 3 then 0.9 else 0.4 in
  let p = ripe_chance d_o in
  let i_r = bernoulli ~p () in
  {kind = k; mass = m; days_old = d_o; is_ripe = i_r} [@@program];;

apple_dist ();;
apple_dist ();;
apple_dist ();;
```

In general, distributions may be defined over abitrary groups of types, as long as they are outputted as tuples, in the end. For example, we could have a distribution over a list of `fruit`s in a bowl and a distribution over the colour of the bowl, but the final output would be a tuple `(fruits, bowl_colour)` of type `fruit list * colour`.

### Estimating Region Probabilities

There are two ways we can estimate region probabilities: the first is to sample from a model using a custom distribution (such as the one above), and the second is to use an existing dataset of samples whose distribution we might not be able easily write down. Given one of these we create a `Distribution` module which can then be used to get region probabilities, estimate Boolean queries, and save/load sample data. To estimate some region probabilities, we'll first need some regions! We'll right a simple function calculating the price, in pennies, of the apple then decompose it:

```{.imandra .input}
let price apple =
  let per_gram = function
  | Braeburn -> 0.4
  | Granny_Smith -> 0.35
  | Red_Delicious -> 0.3
  in let p = (per_gram apple.kind) *. apple.mass in
  if apple.days_old >= 5 then p /. 2. else p;;

let d = Modular_decomp.top ~prune:true "price" [@@program];;

let regions = Modular_decomp.get_concrete_regions d [@@program];;

```

Now we're in a position to calculate the probability mass of each region given our distribution above, or a separate dataset.

#### Sampling Over Regions

Let's first use our `apple_dist` distribution from above to create a `Distribution` module:

```{.imandra .input}
module Apple_S = Distribution.From_Sampler (struct type domain = apple let dist = apple_dist end) [@@program]
```

Now we can find the probabilities using the `get_probs` function, which takes the `regions` and the following optional arguments:

* `n`: The number of samples to be generated for calculating probabilities (only applies when using `From_Sampler`, default value is `10000`)
* `d`: The file name of the dataset of samples to be imported (only applies when using `From_Data`)
* `step_function`: If the distribution is over the initial value of some type `x` and we have a function `val f: x -> x` that we are decomposing that acts a step in some transition system for `x`, then we can apply this step function to `x` multiple times before calculating region probabilities
* `num_steps`: The number of times to apply the step function, if given

```{.imandra .input}
let apple_probs_S = Apple_S.get_probs regions () [@@program]
```

Probabilities can be printed using the `print_probs` function, which takes the hashtable of region probabilities outputted by `get_probs` and the following optional arguments:

* `precision`: The number of decimal places that probabalities are displayed to (default is `4`)
* `full_support`: Whether or not to list regions that have probability `0` or not (default is `false`)
* `verbose`: Whether or not to print out a description of the region, including constraints and the invariant, alongside the probabilities (default is `false`)

```{.imandra .input}
print_probs apple_probs_S ~verbose:true
```

#### Datasets Over Regions

Using a dataset to estimate probabilities is very similar to the procedure above, although as a `CSV` stores strings as opposed to types we need to include a couple of functions mapping each row (a list of strings) to our data type:

```{.imandra .input}
let to_apple apple_string =
  let k = match CCList.nth apple_string 0i with
  | "bb" -> Braeburn
  | "gs" -> Granny_Smith
  | "rd" -> Red_Delicious
  | _ -> failwith "Apple type is not bb, gs, or rd" in
  let m = Q.of_string (CCList.nth apple_string 1i) in
  let d_o = Z.of_string (CCList.nth apple_string 2i) in
  let i_r = if CCList.nth apple_string 3i = "1" then true else false in
  {kind = k; mass = m; days_old = d_o; is_ripe = i_r} [@@program];;

let from_apple apple =
  let k = match apple.kind with
  | Braeburn -> "bb"
  | Granny_Smith -> "gs"
  | Red_Delicious -> "rd" in
  let m = Q.to_string apple.mass in
  let d_o = Z.to_string apple.days_old in
  let i_r = if apple.is_ripe then "1" else "0" in
  [k; m; d_o; i_r] [@@program];;
```

With these two functions (and out `apple` type) we can define a model based on some data `apple.csv` and then use it just as we did with our previous model. Note that we `load` and `save` data from/into `CSV` files with data models, but as byte files with sampling models. Note that this final line is non-executable in this notebook, as we don't actually ahve access to the local `CSV` file

```{.imandra .input}
module Apple_D = Distribution.From_Data (struct
                                         type domain = apple
                                         let from_domain = from_apple
                                         let to_domain = to_apple
                                         end) [@@program];;
```

```
let apple_probs_D = Apple_D.get_probs regions ~d:"apple.csv" () [@@program];;
```

### Estimating Query Probabilities

The last feature we'll introduce in this notebook is the `query` function which, given a statistical model, estimates how likely it is for a particular Boolean query to hold over an instance from that distribution. `query` takes in a Boolean function over the domain (representing some condition) and the following optional arguments:

* `n`: The number of samples to be generated for calculating probabilities (only applies when using `From_Sampler`, default value is `10000`)
* `d`: The file name of the dataset of samples to be imported (only applies when using `From_Data`)
* `max_std_err`: If estimating the probability by generating samples we can improve our estimate to within this optional bound on the standard error by taking more samples
* `precision`: The number of decimal places that probabalities are displayed to (default is `4`)

Let's begin by writing a simple query, then calculate its probability:

```{.imandra .input}
let rip_off (a : apple) = (price a) >=. 30. && not a.is_ripe
```

#### Sampling Queries

```{.imandra .input}
Apple_S.query rip_off ~n:30000 ()
```

#### Dataset Queries

Note once again that as we don't have access to `apple.csv` from this notebook, the following code is non-executable here:

```
Apple_D.query rip_off ~d:"apple.csv" ()
```

### Optional: Changing the Pseudo-Random Number Generator

Sampling in the `Region_probs` module relies on access to a Pseudo-Random Number Generator (PRNG) that can produce uniform samples from the range `[0,1)`. Presently we support three PRNGs which can be changed according to the user's preferences, although in practice this should make little difference. The different PRNGs are:

* `RS`: OCaml's standard PRNG using module Random.State
* `GSL`: GNU Scientific Library's Mersenne Twister PRNG using module Gsl.Rng

`RS` is the default option. The PRNG can be checked and changed using the `get_prng` and `set_prng` functions as follows:

```{.imandra .input}
get_prng ();;
set_prng GSL
```
