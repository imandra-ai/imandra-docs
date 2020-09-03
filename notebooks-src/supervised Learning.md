---
title: "Supervised Learning"
description: "Analysing Machine Learning Models with Imandra"
kernel: imandra
slug: supervised-learning
difficulty: advanced
---

# Analysing Machine Learning Models With Imandra

In this notebook we show how Imandra can be used to analyse and reason about models that have been learnt from data, an important and exciting topic bridging the gap between formal methods and machine learning (ML). Brief notes and some links are included, but for a fuller explanation (with code snippets included for reference) see our [corresponding Medium post](). You can also find all of our code for both learning and analysing our models on [GitHub](https://github.com/AestheticIntegration/imandra-stats-experiments/tree/master/supervised_learning).

To illustrate this approach we'll be looking at (relatively simple) examples from two of the most common tasks within supervised learning (and ML more generally): classification and regression. In particular, we'll show how two of the most common kinds of model used to perform these tasks, random forests and neural networks, can be analysed using Imandra. For each task we'll use a real-world benchmark dataset from the [UCI Machine Learning Repository](https://archive.ics.uci.edu/ml/index.php) and create our models using Python with some standard ML libraries.

We'll mostly be working with reals in this notebook so we'll start by installing a pretty printer so that we're not overrun with digits.

```{.imandra .input}
let pp_approx fmt r = CCFormat.fprintf fmt "%s" (Real.to_string_approx r) [@@program]
#install_printer pp_approx
```

## Classification

In a classification task we want to learn to predict the label of a datapoint based on previous data. In the classic [Wisconsin Breast Cancer (Diagnostic) dataset](https://archive.ics.uci.edu/ml/datasets/Breast+Cancer+Wisconsin+(Diagnostic)) the task is to predict whether the cancer is benign or malignant based on the features of cell nuclei. In the dataset we have the following variables:

```
1. ID number
2. Diagnosis (malignant or benign)
3-32. Real values for the mean, standard error, and the 'worst' value for each cell nucleus'
      a) Radius
      b) Texture
      c) Perimeter
      d) Area
      e) Smoothness
      f) Compactness
      g) Concavity
      h) Concave points
      i) Symmetry
      j) Fractal dimension
```

As is standard practice we pre-process the data before learning. First we standardise each variable to have zero mean and unit variance, then remove all but one from sets of highly correlated variables, along with those that have low mutual information with respect to the target variable. The data is split into training (80%) and test (20%) sets and we use Scikit-Learn to learn a random forest of 3 decision trees of maximum depth 3. As this is a relatively straightforward problem even this simple model achieves a fairly high accuracy. Using a short Python script each tree is then converted to Imandra Modelling Language (IML) and can be reasoned about using Imandra.

```{.imandra .input}
let tree_0 (f_0 : real) (f_1 : real) (f_2 : real) (f_3 : real) (f_4 : real) (f_5 : real) (f_6 : real) = let open Real in
  if f_2 <=. (-0.10815) then
    if f_0 <=. (0.26348) then
      if f_6 <=. (-0.06176) then
        (236.0, 1.0)
      else
        (17.0, 5.0)
    else
      if f_3 <=. (-0.54236) then
        (8.0, 2.0)
      else
        (3.0, 7.0)
  else
    if f_6 <=. (0.09812) then
      if f_6 <=. (-0.17063) then
        (24.0, 0.0)
      else
        (4.0, 2.0)
    else
      if f_2 <=. (2.65413) then
        (6.0, 128.0)
      else
        (7.0, 5.0);;

let tree_1 (f_0 : real) (f_1 : real) (f_2 : real) (f_3 : real) (f_4 : real) (f_5 : real) (f_6 : real) = let open Real in
  if f_5 <=. (-0.05799) then
    if f_0 <=. (0.68524) then
      if f_1 <=. (-0.83180) then
        (110.0, 3.0)
      else
        (137.0, 0.0)
    else
      if f_3 <=. (0.45504) then
        (1.0, 8.0)
      else
        (0.0, 7.0)
  else
    if f_0 <=. (-0.18668) then
      if f_6 <=. (0.45214) then
        (39.0, 0.0)
      else
        (2.0, 11.0)
    else
      if f_6 <=. (-0.00009) then
        (8.0, 4.0)
      else
        (5.0, 120.0);;

let tree_2 (f_0 : real) (f_1 : real) (f_2 : real) (f_3 : real) (f_4 : real) (f_5 : real) (f_6 : real) = let open Real in
  if f_2 <=. (0.10459) then
    if f_5 <=. (-0.38015) then
      if f_5 <=. (-0.60659) then
        (139.0, 1.0)
      else
        (44.0, 3.0)
    else
      if f_6 <=. (-0.07927) then
        (38.0, 2.0)
      else
        (25.0, 17.0)
  else
    if f_6 <=. (0.46888) then
      if f_3 <=. (0.41642) then
        (28.0, 3.0)
      else
        (1.0, 4.0)
    else
      if f_2 <=. (1.74327) then
        (3.0, 122.0)
      else
        (4.0, 21.0);;

let rf (f_0, f_1, f_2, f_3, f_4, f_5, f_6) = let open Real in
let (a_0, b_0) = tree_0 f_0 f_1 f_2 f_3 f_4 f_5 f_6 in
let (a_1, b_1) = tree_1 f_0 f_1 f_2 f_3 f_4 f_5 f_6 in
let (a_2, b_2) = tree_2 f_0 f_1 f_2 f_3 f_4 f_5 f_6 in
let a = a_0 + a_1 + a_2 in
let b = b_0 + b_1 + b_2 in
(a, b);;
```

We can create a custom input type in Imandra for our model, so that we can keep track of the different features of our data.

```{.imandra .input}
type rf_input = {
  radius_mean : real;
  compactness_mean : real;
  concavity_mean : real;
  radius_se : real;
  compactness_worst : real;
  concavity_worst : real;
  concave_points_worst : real;
}
```

However, remember that we also processed our data before learning. To make things easier we'll add in a function applying this transformation to each input variable. Here we simply use some multiplicative and additive scaling values extracted during our data pre-processing stage. After that we can define a full model which combines these pre-processing steps and the random forest.

```{.imandra .input}
let process_rf_input input = let open Real in
let f_0 = (input.radius_mean          - 14.12729) / 3.52405 in
let f_1 = (input.compactness_mean     - 0.10434)  / 0.05281 in
let f_2 = (input.concavity_mean       - 0.08880)  / 0.07972 in
let f_3 = (input.radius_se            - 0.40517)  / 0.27731 in
let f_4 = (input.compactness_worst    - 0.25427)  / 0.15734 in
let f_5 = (input.concavity_worst      - 0.27219)  / 0.20862 in
let f_6 = (input.concave_points_worst - 0.11461)  / 0.06573 in
(f_0, f_1, f_2, f_3, f_4, f_5, f_6)

let process_rf_output c =
let (a, b) = c in
if a >. b then "benign" else "malignant"

let rf_model input = input |> process_rf_input |> rf |> process_rf_output
```

As our model is fully executable we can both query it as well as find counterexamples, prove properties, apply logical side-conditions, decompose its regions, and more. As a quick sanity check to make sure everything is working, let's run a datum from our dataset through the model. In particular, we'll input  `(17.99, 0.2776, 0.3001, 1.095, 0.6656, 0.7119, 0.2654)` which is classified as `malignant` in the data.

```{.imandra .input}
let x = {
  radius_mean = 17.99;
  compactness_mean = 0.2776;
  concavity_mean = 0.3001;
  radius_se = 1.095;
  compactness_worst = 0.6656;
  concavity_worst = 0.7119;
  concave_points_worst = 0.7119;
}

let y = rf_model x
```

Great, just what we'd expect. Now we'll use Imandra to generate an example datapoint for us given that diagnosis is `benign`.

```{.imandra .input}
instance (fun x -> rf_model x = "benign")
```

```{.imandra .input}
CX.x
```

This looks a bit funny however; notice how the unspecified input variables are unbounded in a way that doesn't make sense with respect to the data. In general we might only care about the performance of our model when some reasonable bounds are placed on the input (for example, the mean radius can't be negative, and if the values for this variable in our dataset range between 6.98 and 28.11 we wouldn't really expect any value greater than, say, 35). Using the description of each variable in the dataset we can form a condition describing valid and reasonable inputs to our model. In machine learning more generally, we are typically only interested in the performance and quality of a model over some particular distribution of data, which we often have particular prior beliefs about.

```{.imandra .input}
let is_valid_rf input =
  5.0 <=. input.radius_mean && input.radius_mean <=. 35.0 &&
  0.0 <=. input.compactness_mean && input.compactness_mean <=. 0.4 &&
  0.0 <=. input.concavity_mean && input.concavity_mean <=. 0.5 &&
  0.0 <=. input.radius_se && input.radius_se <=. 3.5 &&
  0.0 <=. input.compactness_worst && input.compactness_worst <=. 1.2 &&
  0.0 <=. input.concavity_worst && input.concavity_worst <=. 1.5 &&
  0.0 <=. input.concave_points_worst && input.concave_points_worst <=. 0.35

instance (fun x -> rf_model x = "benign" && is_valid_rf x)
```

```{.imandra .input}
CX.x
```

This looks much better. Now let's move on to reasoning about our model in more interesting ways. One thing we can do is check the validity of certain constraints we might want our model to satisfy. For example, if the surface of a cell nucleus has many, large concave sections then is a particularly negative sign indicating that the cancer is likely to be malignant. We can use Imandra to easily verify that our model always classifies a sample of highly concave cells as `malignant`.

```{.imandra .input}
verify (fun x -> is_valid_rf x
        && x.concavity_mean >=. 0.4
        && x.concavity_worst >=. 1.0
        && x.concave_points_worst >=. 0.25
        ==> rf_model x = "malignant")
```

The nested `if ... then ... else` statements in how the trees are defined mean that they are a prime candidate for Imandra's region decomposition functionality. As well as the total model we can of course also decompose the individual trees making up the ensemble.

```{.imandra .input}
Modular_decomp.top ~assuming:"is_valid_rf" "rf_model"
```

```{.imandra .input}
Modular_decomp.top "tree_0"
```

We can also use side conditions on the region decomposition of our model by using the `~assuming:` flag. One application here is in simulating partial observability. Perhaps we know most of the measurements for a particular set of cells and we'd like to see how the classification of the input depends on the remaining features. Let's imagine that we only have the concavity measurements for a particular patient's cell sample and we'd like to see how the output of our model depends on the values of the other features.

```{.imandra .input}
let partial_observation x =
  is_valid_rf x &&
  x.concavity_mean = 0.04295 &&
  x.concavity_worst = 0.26000 &&
  x.concave_points_worst = 0.11460;;

Modular_decomp.top ~prune:true ~assuming:"partial_observation" "rf_model" [@@program];;
```

## Regression

In a regression task we want to learn to predict the value(s) of some variable(s) based on previous data. In the commonly used [Forest Fires dataset](https://archive.ics.uci.edu/ml/datasets/forest+fires) the aim is to predict the area burned by forest fires, in the northeast region of Portugal, by using meteorological and other data. This is a fairly difficult task and while the neural network below doesn't achieve state-of-the-art performance, it's enough to demonstrate how we can analyse relatively simple models in Imandra. In the dataset we have the following variables:

```
1. X-axis spatial coordinate (within the Montesinho park map)
2. Y-axis spatial coordinate (within the Montesinho park map)
3. Month
4. Day
5. FFMC index (from the FWI system)
6. DMC index (from the FWI system)
7. DC index (from the FWI system)
8. ISI index (from the FWI system)
9. Temperature
10. Relative percentage humidity
11. Wind speed
12. Rainfall
13. Area of forest burned
```

We again pre-process the data before learning by first transforming the month and day variables into a numerical value and applying a sine transformation (so that similar times are close in value), as well as removing outliers and applying an approximate logarithmic transformation to the area variable (as recommended in the dataset description). Each variable is scaled to lie between 0 and 1, and those with high correlations and/or low mutual information respect to the target variable are removed. We then split the data into training (80%) and test (20%) sets and use Keras to learn a simple feed-forward neural network with one (6 neuron) hidden layer, ReLU activation functions, and stochastic gradient descent to optimise the mean squared error. After saving our model as a `.h5` file we use a short Python script to extract the network into an IML file and reason about it using Imandra.

```{.imandra .input}
let relu x = Real.(if x > 0.0 then x else 0.0);;

let linear x = Real.(x)

let layer_0 (x_0, x_1, x_2, x_3, x_4, x_5) = let open Real in
  let y_0 = relu @@ (0.20124)*x_0 + (-0.15722)*x_1 + (-0.19063)*x_2 + (-0.54562)*x_3 + (0.03425)*x_4 + (0.50104)*x_5 + -0.02768 in
  let y_1 = relu @@ (0.29103)*x_0 + (0.03180)*x_1 + (-0.16336)*x_2 + (0.17919)*x_3 + (0.32971)*x_4 + (-0.43206)*x_5 + -0.02620 in
  let y_2 = relu @@ (0.66419)*x_0 + (0.25399)*x_1 + (0.00449)*x_2 + (0.03841)*x_3 + (-0.51482)*x_4 + (0.58299)*x_5 + 0.11858 in
  let y_3 = relu @@ (0.47598)*x_0 + (-0.36142)*x_1 + (0.38981)*x_2 + (0.27632)*x_3 + (-0.61231)*x_4 + (-0.03662)*x_5 + -0.02890 in
  let y_4 = relu @@ (0.10277)*x_0 + (-0.28841)*x_1 + (0.04637)*x_2 + (0.28808)*x_3 + (0.05957)*x_4 + (-0.22041)*x_5 + 0.18270 in
  let y_5 = relu @@ (0.55604)*x_0 + (-0.04015)*x_1 + (0.10557)*x_2 + (0.60757)*x_3 + (-0.32314)*x_4 + (0.47933)*x_5 + -0.24876 in
  (y_0, y_1, y_2, y_3, y_4, y_5)

let layer_1 (x_0, x_1, x_2, x_3, x_4, x_5) = let open Real in
  let y_0 = linear @@ (0.28248)*x_0 + (-0.25208)*x_1 + (-0.50075)*x_2 + (-0.07092)*x_3 + (-0.43189)*x_4 + (0.60065)*x_5 + 0.47136 in
  (y_0)

let nn (x_0, x_1, x_2, x_3, x_4, x_5) = let open Real in
  (x_0, x_1, x_2, x_3, x_4, x_5) |> layer_0 |> layer_1
```

Given the description of the dataset above we can again create some custom input types in Imandra for our model.

```{.imandra .input}
type month = Jan | Feb | Mar | Apr | May | Jun| Jul | Aug | Sep | Oct | Nov | Dec

type day = Mon | Tue | Wed | Thu | Fri | Sat | Sun

type nn_input = {
  month : month;
  day : day;
  dmc : real;
  temp : real;
  rh : real;
  rain : real
}
```

As before, because we pre-processed our data, we'll add in a function applying this transform to each input variable. Equally, we'll need to convert back to hectares for our output variable, again using some minimum and maximum values extracted during our data pre-processing stage. After that we define a full model which combines these pre/post-processing steps and the network above.

```{.imandra .input}
let month_2_num = let open Real in function
  | Jan -> 0.134
  | Feb -> 0.500
  | Mar -> 1.000
  | Apr -> 1.500
  | May -> 1.866
  | Jun -> 2.000
  | Jul -> 1.866
  | Aug -> 1.500
  | Sep -> 1.000
  | Oct -> 0.500
  | Nov -> 0.133
  | Dec -> 0.000

let day_2_num = let open Real in function
  | Mon -> 0.377
  | Tue -> 1.223
  | Wed -> 1.901
  | Thu -> 1.901
  | Fri -> 1.223
  | Sat -> 0.377
  | Sun -> 0.000

let process_nn_input input = let open Real in
  let real_month = month_2_num input.month in
  let real_day = day_2_num input.day in
  let x_0 = (real_month - 0.0)  / (2.0   - 0.0)  in
  let x_1 = (real_day   - 0.0)  / (1.901 - 0.0)  in
  let x_2 = (input.dmc  - 1.1)  / (291.3 - 1.1)  in
  let x_3 = (input.temp - 2.2)  / (33.3  - 2.2)  in
  let x_4 = (input.rh   - 15.0) / (100.0 - 15.0) in
  let x_5 = (input.rain - 0.0)  / (6.40  - 0.0)  in
  (x_0, x_1, x_2, x_3, x_4, x_5)

let process_nn_output y_0 = let open Real in
  let y = 4.44323 * y_0 in
  if y <= 1.0 then (y - 0.00000) * 1.71828 else
  if y <= 2.0 then (y - 0.63212) * 4.67077 else
  if y <= 3.0 then (y - 1.49679) * 12.69648 else
  if y <= 4.0 then (y - 2.44700) * 34.51261 else
  (y - 3.42868) * 93.81501

let nn_model input = input |> process_nn_input |> nn |> process_nn_output
```

Let's start as in the previous section by running a datum from our dataset through the model. In particular, we'll input  `x = (Aug, Sat, 231.1, 26.9, 31.0, 0.0)` which has an area of `y = 4.96` hectares in the data.

```{.imandra .input}
let x = {
  month = Aug;
  day = Sat;
  dmc = 231.1;
  temp = 26.9;
  rh = 31.0;
  rain = 0.0
}

let y = nn_model x
```

Our answer is both roughly similar to the recorded datapoint value and also to the value we get from our original Keras model, `2.13683266556`. The small disparity here is due to our rounding the weight values in our network to 5 decimal places when we extracted them to IML, though it wasn't necessary to do so. Now we'll use Imandra to generate an example for us with some particular side conditions.

```{.imandra .input}
instance (fun x -> nn_model x >. 20.0 && x.temp = 20.0 && x.month = May)
```

```{.imandra .input}
CX.x
```

Notice how the unspecified input variables are unbounded, just as in our original classification instances. Using the description of each variable in the data (plus some reasonable assumptions about Portugal's climate) we can form the following condition describing valid inputs to the network.

```{.imandra .input}
let is_valid_nn input =
  0.0 <=. input.dmc && input.dmc <=. 500.0 &&
  0.0 <=. input.temp && input.temp <=. 40.0 &&
  0.0 <=. input.rh && input.rh <=. 100.0 &&
  0.0 <=. input.rain && input.rain <=. 15.0

instance (fun x -> nn_model x >. 20.0 && x.temp = 20.0 && x.month = May && is_valid_nn x)
```

```{.imandra .input}
CX.x;;

nn_model CX.x
```

These constraints mean it is slightly harder for Imandra to find a particular instance satisfying our original demand, but nonetheless it's possible. Now let's try something a bit more interesting. First of all let's check for one desirable property of the model, namely that it never outputs a negative area as a prediction.

```{.imandra .input}
verify (fun x -> is_valid_nn x ==> nn_model x >=. 0.0)
```

Finally, we'll try something slightly more ambitious and test a hypothesis. All other things remaining equal, we would expect that the higher the temperature, the larger the area of forest that would be burned. Due to the imperfections in our model (because of limited data, stochasticity in training, the complicated patterns present in natural physical phenomena, and so on) this assertion is in fact easily falsifiable by Imandra.

```{.imandra .input}
verify (fun a b ->
        is_valid_nn a &&
        is_valid_nn b &&
        a.month = b.month &&
        a.day = b.day &&
        a.dmc = b.dmc &&
        a.rh = b.rh &&
        a.rain = b.rain &&
        a.temp >=. b.temp ==>
        nn_model a >=. nn_model b)
```

```{.imandra .input}
CX.a.temp;;
CX.b.temp;;
nn_model CX.a;;
nn_model CX.b;;
```

Although the network doesn't satisfy our original verification statement we can restrict our setting in a sensible way in order to prove something slightly weaker:
* There is very little data from winter months, and so the model is unlikely to generalise well here, hence we'll only consider non-winter months
* We'll increase the tolerance in temperature to 10 degrees celsius
* We'll increase the tolerance in area burned to 25 hectares

```{.imandra .input}
let winter month = month = Oct || month = Nov || month = Dec || month = Jan || month = Feb

verify (fun a b ->
        is_valid_nn a &&
        is_valid_nn b &&
        a.month = b.month &&
        not (winter a.month) &&
        a.day = b.day &&
        a.dmc = b.dmc &&
        a.rh = b.rh &&
        a.rain = b.rain &&
        (a.temp -. 10.0) >=. b.temp ==>
        (nn_model a +. 25.0) >=. nn_model b)
```

We hope you've enjoyed this short introduction to one of the many ways in which formal methods can be applied to machine learning. If you're interested in our work be sure to check our [other notebooks](https://try.imandra.ai/), find out more and get email updates on our [website](https://www.imandra.ai/), join the discussion on our [Discord channel](https://discord.gg/byQApJ3), and subscribe to our [Medium publication](https://medium.com/imandra).
