# Imandra for automated conflict detection

In this notebook, we will build an Imandra framework for reasoning about concurrent conflict detection. Once we encode this model in Imandra, we'll be able to use Imandra to automatically solve arbitrary problems about concurrent resource detection simply by encoding them in a simple datatype and asking Imandra if a conflict is possible.

Let's begin with an informal description of the problem space.

# Detecting resource conflicts over concurrent workflows

Imagine there are two workflows, WF1 and WF2, that can each access Sharable and Unsharable resources.

We define a conflict as any possible scenario in which WF1 and WF2 both access
an Unsharable resource at the same time.

For a given problem specification, we want to prove either that a conflict can never occur, or to prove that a conflict can occur and synthesize a witness (a sequence of events) realizing the conflict.

## Imagine we have the following work-flows

### WF1
```
A -> B -> C -> A
```

### WF2
```
D -> E -> F -> D
```

## Now, consider the following motivating problems

### Problem 1

Assume that we have the following definitions:

Node A
- Starts when `Sensor == 1`
- Accesses `Apple`

Node B
- Starts when `Sensor == 2`
- Accesses `Banana`

Node C
- Starts when `Sensor == 3`
- Accesses `Orange`

Node D
- Starts when `Sensor == 1`
- Accesses `Orange`

Node E
- Starts when `Sensor == 2`
- Accesses `Banana`

Node F
- Starts when `Sensor == 3`
- Accesses `Apple`

### Problem 1A
Suppose that we define our resources as such:  

Resources
- Apple: `Sharable`
- Banana: `Unsharable`
- Orange: `Sharable`

If the following sequence of events is seen:  
1. `Sensor = 1` (`WF1 -> A`) (`WF2 -> D`)
2. `Sensor = 2` (`WF1 -> B`) (`WF2 -> E`)

Then `B` and `E` will access `Banana` (which is an Unsharable resource) at the same time, and there exists a sequence of events such that **a conflict is possible**.

### Problem 1B
Suppose that we now define our resources as such:  

Resources
- Apple: `Unsharable`
- Banana: `Sharable`
- Orange: `Sharable`

Then there is **no such sequence of events such that a conflict is possible**.

### Problem 1C
Suppose we keep the resource definition as in 1B but now change the definition of the Nodes to be:

Node D
- Starts when `Sensor == 1` OR `Sensor == 2` 

Node E
- Starts when `Sensor == 2` OR `Sensor == 3`

Node F
- Starts when `Sensor == 3` OR `Sensor == 1`
- Accesses `Apple`

If the following sequence of events is seen:  
1. `Sensor = 2` (`WF2 -> D`)
2. `Sensor = 3` (`WF2 -> E`)
3. `Sensor = 1` (`WF2 -> F`) (`WF1 -> A`)

Then `F` and `A` will access `Apple` (which is an Unsharable resource) at the same time, and there exists a sequence of events such that **a conflict is possible**.

# Let's now build a framework in Imandra to allow us to answer these questions automatically

We'll start with defining *agents*, *resources*, *guards* and *policies*.


```ocaml
type agent_id =
  | Node of node_id

and node_id =
  A | B | C | D | E | F

type guard =
  | Eq of sensor * int
  | Or of guard * guard

and sensor =
  | Sensor

type resource =
  | Apple
  | Banana
  | Orange

type sharability =
  | Sharable
  | Unsharable

type policy =
  (resource, sharability) Map.t
```




    type agent_id = Node of node_id
    and node_id = A | B | C | D | E | F
    type guard = Eq of sensor * Z.t | Or of guard * guard
    and sensor = Sensor
    type resource = Apple | Banana | Orange
    type sharability = Sharable | Unsharable
    type policy = (resource, sharability) Map.t




# Problems

Next, we'll define the *problem* datatype, which will allow us to succinctly express an arbitrary conflict detection problem of the above form to Imandra for analysis.

As above, a problem will consist of a pair of workflows, a collection of agents (each with their own identities, guards and resource accesses) and a resource access policy specifying which resources can be shared.


```ocaml
type problem = {
  work_flow_1: work_flow;
  work_flow_2: work_flow;
  agents: agent list;
  policy: policy;
}

and work_flow = node_id list

and agent = {
  agent_id: agent_id;
  guard: guard;
  accesses: resource;
}
```




    type problem = {
      work_flow_1 : work_flow;
      work_flow_2 : work_flow;
      agents : agent list;
      policy : policy;
    }
    and work_flow = node_id list
    and agent = { agent_id : agent_id; guard : guard; accesses : resource; }




# Operational Semantics

Next, we're going to encode the "meaning" or "semantics" of concurrent conflicts in Imandra by defining an *interpreter* which evaluates a problem over arbitrary states of the world. Then, we'll be able to use Imandra's symbolic reasoning power to prove or disprove the existence of a conflict for a given problem by asking it to symbolically evaluate all possible behaviors of the interpreter over a given problem specification.

## State

The `state` datatype will encode the current state of the world. This is core datatype over which a problem execution trace will take place.

## Interpreter

Armed with the `state` type, we will define an interpreter which accepts a problem and a sequence of sensor readings, and yields the result.


```ocaml
(* The current state of the world *)

type state = {
  wf_1: work_flow;
  wf_2: work_flow;
  sensor: int option;
  agents: (node_id, agent option) Map.t;
  policy: policy;
  conflict: (agent_id * agent_id * resource) option;
}

let rec eval_guard (sensor:int) (g:guard) =
  match g with
  | Eq (Sensor, n) -> sensor = n
  | Or (g1, g2) ->
    eval_guard sensor g1 || eval_guard sensor g2

let step (s:state) (sensor:int) =
  let in_conflict r1 r2 policy =
    r1 = r2 && Map.get r1 policy = Unsharable
  in
  match s.wf_1, s.wf_2 with
  | agent_1 :: wf_1', agent_2 :: wf_2' ->
    begin match Map.get agent_1 s.agents, Map.get agent_2 s.agents with
      | Some actor_1, Some actor_2 ->
        let g_1, g_2 = eval_guard sensor actor_1.guard,
                       eval_guard sensor actor_2.guard in
        if g_1 && g_2 && in_conflict actor_1.accesses actor_2.accesses s.policy then (
          { s with
            sensor = Some sensor;
            conflict = Some (Node agent_1, Node agent_2, actor_1.accesses);
          }
        ) else (
          { s with
            sensor = Some sensor;
            wf_1 = if g_1 then wf_1' else s.wf_1;
            wf_2 = if g_2 then wf_2' else s.wf_2;
          }
        )
      | _ -> s
    end
  | _ -> s

let rec run (s:state) (sensors:int list) =
  match sensors with
  | [] -> (s, [])
  | sensor :: sensors ->
    let s' = step s sensor in
    if s'.conflict = None then (
      run s' sensors
    ) else (
      (s', sensors)
    )
[@@adm sensors]
```




    type state = {
      wf_1 : work_flow;
      wf_2 : work_flow;
      sensor : Z.t option;
      agents : (node_id, agent option) Map.t;
      policy : policy;
      conflict : (agent_id * agent_id * resource) option;
    }
    val eval_guard : Z.t -> guard -> bool = <fun>
    val step : state -> Z.t -> state = <fun>
    val run : state -> Z.t list -> state * Z.t list = <fun>





<div><div class="imandra-fold panel panel-default" id="fold-bfadf49f-094a-4018-947b-c852f6772614"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>termination proof</span></div></div><div class="panel-body collapse"><div><h3>Termination proof</h3><div class="imandra-fold panel panel-default" id="fold-1b0fe267-128b-43b8-8330-0fb79575d041"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>call `eval_guard sensor (Destruct(Or, 0, g))` from `eval_guard sensor g`</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-3596f910-6f7d-48dc-9f63-bcea25ec8ce3"><table><tr><td>original:</td><td>eval_guard sensor g</td></tr><tr><td>sub:</td><td>eval_guard sensor (Destruct(Or, 0, g))</td></tr><tr><td>original ordinal:</td><td>Ordinal.Int (_cnt g)</td></tr><tr><td>sub ordinal:</td><td>Ordinal.Int (_cnt (Destruct(Or, 0, g)))</td></tr><tr><td>path:</td><td>[not Is_a(Eq, g)]</td></tr><tr><td>proof:</td><td><div class="imandra-fold panel panel-default" id="fold-28ca26b1-db17-4da7-921d-46474f1abd11"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>detailed proof</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-8198442c-8782-4e98-889b-3c452df0bb53"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-b674f7df-6a2d-458c-8c97-7af1116e03cc"><table><tr><td>ground_instances:</td><td>3</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.011s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-b8d3116f-5bd1-486e-95d9-e26f8f7e0a22"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-4a3f9b2b-7b4c-4f70-b165-a8e955957889"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-6b649856-a0c4-42c5-946e-d7e4cbf32978"><table><tr><td>num checks:</td><td>8</td></tr><tr><td>arith assert lower:</td><td>11</td></tr><tr><td>arith tableau max rows:</td><td>6</td></tr><tr><td>arith tableau max columns:</td><td>19</td></tr><tr><td>arith pivots:</td><td>10</td></tr><tr><td>rlimit count:</td><td>5442</td></tr><tr><td>mk clause:</td><td>24</td></tr><tr><td>datatype occurs check:</td><td>27</td></tr><tr><td>mk bool var:</td><td>117</td></tr><tr><td>arith assert upper:</td><td>8</td></tr><tr><td>datatype splits:</td><td>9</td></tr><tr><td>decisions:</td><td>19</td></tr><tr><td>arith row summations:</td><td>10</td></tr><tr><td>propagations:</td><td>19</td></tr><tr><td>conflicts:</td><td>6</td></tr><tr><td>arith fixed eqs:</td><td>4</td></tr><tr><td>datatype accessor ax:</td><td>18</td></tr><tr><td>arith conflicts:</td><td>2</td></tr><tr><td>arith num rows:</td><td>6</td></tr><tr><td>datatype constructor ax:</td><td>31</td></tr><tr><td>num allocs:</td><td>685043017</td></tr><tr><td>final checks:</td><td>6</td></tr><tr><td>added eqs:</td><td>97</td></tr><tr><td>del clause:</td><td>7</td></tr><tr><td>arith eq adapter:</td><td>6</td></tr><tr><td>memory:</td><td>32.360000</td></tr><tr><td>max memory:</td><td>32.370000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-b8d3116f-5bd1-486e-95d9-e26f8f7e0a22';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-5993652e-4676-4da5-87d6-d1dcd1437433"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.011s]
  let (_x_0 : int) = count.guard g in
  let (_x_1 : guard) = Destruct(Or, 0, g) in
  let (_x_2 : int) = count.guard _x_1 in
  let (_x_3 : bool) = Is_a(Eq, _x_1) in
  not Is_a(Eq, g) &amp;&amp; ((_x_0 &gt;= 0) &amp;&amp; (_x_2 &gt;= 0))
  ==&gt; (_x_3
       &amp;&amp; not (not (eval_guard sensor (Destruct(Or, 0, _x_1))) &amp;&amp; not _x_3))
      || Ordinal.( &lt;&lt; ) (Ordinal.Int _x_2) (Ordinal.Int _x_0)</pre></li><li><div><h6>simplify</h6><div class="imandra-table" id="table-3435ebc1-a4bb-4f30-97c6-744f5faf6f92"><table><tr><td>into:</td><td><pre>let (_x_0 : int) = count.guard g in
let (_x_1 : guard) = Destruct(Or, 0, g) in
let (_x_2 : int) = count.guard _x_1 in
let (_x_3 : bool) = Is_a(Eq, _x_1) in
not (not Is_a(Eq, g) &amp;&amp; (_x_0 &gt;= 0) &amp;&amp; (_x_2 &gt;= 0))
|| Ordinal.( &lt;&lt; ) (Ordinal.Int _x_2) (Ordinal.Int _x_0)
|| (_x_3 &amp;&amp; not (not (eval_guard sensor (Destruct(Or, 0, _x_1))) &amp;&amp; not _x_3))</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-ea7082d4-81bf-4a93-b88a-f86bf6624bd5"><table><tr><td>expr:</td><td><pre>(|Ordinal.&lt;&lt;| (|Ordinal.Int_79/boot|
                (|count.guard_1519/client|
                  (|…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-24450e19-2737-428c-bd73-875769942f05"><table><tr><td>expr:</td><td><pre>(|count.guard_1519/client| (|get.Or.0_1913/server| g_1916/server))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-e025b9d9-48e5-4a3d-b4f6-14c75b20096a"><table><tr><td>expr:</td><td><pre>(|count.guard_1519/client| g_1916/server)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li>Unsat</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-5993652e-4676-4da5-87d6-d1dcd1437433';
  fold.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-8198442c-8782-4e98-889b-3c452df0bb53';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-28ca26b1-db17-4da7-921d-46474f1abd11';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-1b0fe267-128b-43b8-8330-0fb79575d041';
  fold.hydrate(target);
});
</script></div><div class="imandra-fold panel panel-default" id="fold-1c07faaf-90bc-4525-857e-9e9455f36b81"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>call `eval_guard sensor (Destruct(Or, 1, g))` from `eval_guard sensor g`</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-1aaf81aa-6546-4ea9-af79-50a371a136e3"><table><tr><td>original:</td><td>eval_guard sensor g</td></tr><tr><td>sub:</td><td>eval_guard sensor (Destruct(Or, 1, g))</td></tr><tr><td>original ordinal:</td><td>Ordinal.Int (_cnt g)</td></tr><tr><td>sub ordinal:</td><td>Ordinal.Int (_cnt (Destruct(Or, 1, g)))</td></tr><tr><td>path:</td><td>[not (eval_guard sensor (Destruct(Or, 0, g))) &amp;&amp; not Is_a(Eq, g)]</td></tr><tr><td>proof:</td><td><div class="imandra-fold panel panel-default" id="fold-d5f69639-1147-49a3-aff0-967a56ec916e"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>detailed proof</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-c867d2a2-19a9-4e32-8db9-53cd8ae59844"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-ed88ec0b-3bb5-474b-9f35-f233c36b4eb8"><table><tr><td>ground_instances:</td><td>3</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.011s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-a2148348-c05a-4881-938c-df8bc91cbcf2"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-4dfd6fa9-deba-4dd2-965d-54756d80ba60"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-d279b8bd-90e6-4563-a7e0-5f1f0883d927"><table><tr><td>num checks:</td><td>8</td></tr><tr><td>arith assert lower:</td><td>11</td></tr><tr><td>arith tableau max rows:</td><td>6</td></tr><tr><td>arith tableau max columns:</td><td>19</td></tr><tr><td>arith pivots:</td><td>10</td></tr><tr><td>rlimit count:</td><td>2742</td></tr><tr><td>mk clause:</td><td>24</td></tr><tr><td>datatype occurs check:</td><td>27</td></tr><tr><td>mk bool var:</td><td>118</td></tr><tr><td>arith assert upper:</td><td>8</td></tr><tr><td>datatype splits:</td><td>9</td></tr><tr><td>decisions:</td><td>19</td></tr><tr><td>arith row summations:</td><td>10</td></tr><tr><td>propagations:</td><td>19</td></tr><tr><td>conflicts:</td><td>6</td></tr><tr><td>arith fixed eqs:</td><td>4</td></tr><tr><td>datatype accessor ax:</td><td>18</td></tr><tr><td>arith conflicts:</td><td>2</td></tr><tr><td>arith num rows:</td><td>6</td></tr><tr><td>datatype constructor ax:</td><td>31</td></tr><tr><td>num allocs:</td><td>617614653</td></tr><tr><td>final checks:</td><td>6</td></tr><tr><td>added eqs:</td><td>97</td></tr><tr><td>del clause:</td><td>7</td></tr><tr><td>arith eq adapter:</td><td>6</td></tr><tr><td>memory:</td><td>32.370000</td></tr><tr><td>max memory:</td><td>32.370000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-a2148348-c05a-4881-938c-df8bc91cbcf2';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-6d54fff5-88b9-4f3e-ae1b-b59a7401e92a"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.011s]
  let (_x_0 : int) = count.guard g in
  let (_x_1 : guard) = Destruct(Or, 1, g) in
  let (_x_2 : int) = count.guard _x_1 in
  let (_x_3 : bool) = Is_a(Eq, _x_1) in
  not (eval_guard sensor (Destruct(Or, 0, g)))
  &amp;&amp; (not Is_a(Eq, g) &amp;&amp; ((_x_0 &gt;= 0) &amp;&amp; (_x_2 &gt;= 0)))
  ==&gt; (_x_3
       &amp;&amp; not (not (eval_guard sensor (Destruct(Or, 0, _x_1))) &amp;&amp; not _x_3))
      || Ordinal.( &lt;&lt; ) (Ordinal.Int _x_2) (Ordinal.Int _x_0)</pre></li><li><div><h6>simplify</h6><div class="imandra-table" id="table-a3c6abdd-1dce-44cb-8684-ceef592bb85b"><table><tr><td>into:</td><td><pre>let (_x_0 : guard) = Destruct(Or, 1, g) in
let (_x_1 : bool) = Is_a(Eq, _x_0) in
let (_x_2 : int) = count.guard _x_0 in
let (_x_3 : int) = count.guard g in
(_x_1 &amp;&amp; not (not (eval_guard sensor (Destruct(Or, 0, _x_0))) &amp;&amp; not _x_1))
|| Ordinal.( &lt;&lt; ) (Ordinal.Int _x_2) (Ordinal.Int _x_3)
|| not
   (not (eval_guard sensor (Destruct(Or, 0, g))) &amp;&amp; not Is_a(Eq, g)
    &amp;&amp; (_x_3 &gt;= 0) &amp;&amp; (_x_2 &gt;= 0))</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-8994e076-5d68-426f-8cb6-6f5ae8ffa033"><table><tr><td>expr:</td><td><pre>(|Ordinal.&lt;&lt;| (|Ordinal.Int_79/boot|
                (|count.guard_1519/client|
                  (|…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-4d8b3bfd-003b-4d59-be2c-23b40d50d45b"><table><tr><td>expr:</td><td><pre>(|count.guard_1519/client| (|get.Or.1_1914/server| g_1916/server))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-17beec61-6ced-4c7c-8d42-77c18340f850"><table><tr><td>expr:</td><td><pre>(|count.guard_1519/client| g_1916/server)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li>Unsat</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-6d54fff5-88b9-4f3e-ae1b-b59a7401e92a';
  fold.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-c867d2a2-19a9-4e32-8db9-53cd8ae59844';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-d5f69639-1147-49a3-aff0-967a56ec916e';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-1c07faaf-90bc-4525-857e-9e9455f36b81';
  fold.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-bfadf49f-094a-4018-947b-c852f6772614';
  fold.hydrate(target);
});
</script></div></div>




<div><div class="imandra-fold panel panel-default" id="fold-a23f5ee7-8606-4f65-a8aa-ad694eeb934c"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>termination proof</span></div></div><div class="panel-body collapse"><div><h3>Termination proof</h3><div class="imandra-fold panel panel-default" id="fold-8dd56530-25c7-41e6-b93d-c881bef23010"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>call `run (step s (List.hd sensors)) (List.tl sensors)` from `run s sensors`</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-16b3a9ea-4154-4a4f-8335-3043eb8d20ba"><table><tr><td>original:</td><td>run s sensors</td></tr><tr><td>sub:</td><td>run (step s (List.hd sensors)) (List.tl sensors)</td></tr><tr><td>original ordinal:</td><td>Ordinal.Int (_cnt sensors)</td></tr><tr><td>sub ordinal:</td><td>Ordinal.Int (_cnt (List.tl sensors))</td></tr><tr><td>path:</td><td>[(step s (List.hd sensors)).conflict = None &amp;&amp; sensors &lt;&gt; []]</td></tr><tr><td>proof:</td><td><div class="imandra-fold panel panel-default" id="fold-f730970c-6af6-4fd6-b35e-8fc999a3606e"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>detailed proof</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-e0a2b4f2-9cd0-4a1b-aedb-8ee2fb68dfa2"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-c2770921-9dc6-4450-bb3d-76b792ad1a82"><table><tr><td>ground_instances:</td><td>3</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.017s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-cde4701f-f9a1-4fa5-9ca1-dfb705e3203c"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-400bb5f1-cc4f-4b72-85ea-14a5d37b4ccd"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-6fa5fcb2-f08b-41cb-8d34-5ecd2d55c9b5"><table><tr><td>num checks:</td><td>8</td></tr><tr><td>arith assert lower:</td><td>30</td></tr><tr><td>arith tableau max rows:</td><td>8</td></tr><tr><td>arith tableau max columns:</td><td>19</td></tr><tr><td>arith pivots:</td><td>19</td></tr><tr><td>rlimit count:</td><td>17662</td></tr><tr><td>mk clause:</td><td>222</td></tr><tr><td>datatype occurs check:</td><td>268</td></tr><tr><td>mk bool var:</td><td>1105</td></tr><tr><td>arith assert upper:</td><td>25</td></tr><tr><td>datatype splits:</td><td>290</td></tr><tr><td>decisions:</td><td>450</td></tr><tr><td>arith row summations:</td><td>28</td></tr><tr><td>arith bound prop:</td><td>1</td></tr><tr><td>propagations:</td><td>550</td></tr><tr><td>conflicts:</td><td>29</td></tr><tr><td>arith fixed eqs:</td><td>14</td></tr><tr><td>datatype accessor ax:</td><td>141</td></tr><tr><td>minimized lits:</td><td>5</td></tr><tr><td>arith conflicts:</td><td>2</td></tr><tr><td>arith num rows:</td><td>8</td></tr><tr><td>arith assert diseq:</td><td>5</td></tr><tr><td>datatype constructor ax:</td><td>603</td></tr><tr><td>num allocs:</td><td>768512040</td></tr><tr><td>final checks:</td><td>13</td></tr><tr><td>added eqs:</td><td>2772</td></tr><tr><td>del clause:</td><td>21</td></tr><tr><td>arith eq adapter:</td><td>25</td></tr><tr><td>memory:</td><td>33.450000</td></tr><tr><td>max memory:</td><td>33.450000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-cde4701f-f9a1-4fa5-9ca1-dfb705e3203c';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-d7d75d80-d6a0-4f76-bf51-eaa24b18501a"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.017s]
  let (_x_0 : bool) = Is_a(Some, …) in
  let (_x_1 : bool) = s.wf_1 &lt;&gt; [] in
  let (_x_2 : bool) = s.wf_2 &lt;&gt; [] in
  let (_x_3 : int) = count.list mk_nat sensors in
  let (_x_4 : int list) = List.tl sensors in
  let (_x_5 : int) = count.list mk_nat _x_4 in
  let (_x_6 : state) = if _x_2 then … else s in
  ((if _x_2 then if _x_1 then if _x_0 then … else s else s else s).conflict
   = None)
  &amp;&amp; (sensors &lt;&gt; [] &amp;&amp; ((_x_3 &gt;= 0) &amp;&amp; (_x_5 &gt;= 0)))
  ==&gt; not
      (((if _x_6.wf_2 &lt;&gt; []
         then if ….wf_1 &lt;&gt; [] then if _x_0 then … else … else _x_6
         else if _x_2 then if _x_1 then … else s else s).conflict
        = None)
       &amp;&amp; _x_4 &lt;&gt; [])
      || Ordinal.( &lt;&lt; ) (Ordinal.Int _x_5) (Ordinal.Int _x_3)</pre></li><li><div><h6>simplify</h6><div class="imandra-table" id="table-3ccedf76-9d84-4486-8dac-6da6e2cfb5ea"><table><tr><td>into:</td><td><pre>let (_x_0 : int list) = List.tl sensors in
let (_x_1 : int) = count.list mk_nat _x_0 in
let (_x_2 : int) = count.list mk_nat sensors in
let (_x_3 : bool) = s.wf_1 &lt;&gt; [] in
let (_x_4 : bool) = s.wf_2 &lt;&gt; [] in
let (_x_5 : state) = if _x_4 then … else s in
let (_x_6 : bool) = Is_a(Some, …) in
Ordinal.( &lt;&lt; ) (Ordinal.Int _x_1) (Ordinal.Int _x_2)
|| not
   (((if _x_5.wf_2 &lt;&gt; []
      then if ….wf_1 &lt;&gt; [] then if _x_6 then … else … else _x_5
      else if _x_4 then if _x_3 then … else s else s).conflict
     = None)
    &amp;&amp; _x_0 &lt;&gt; [])
|| not
   (((if _x_4 then if _x_3 then if _x_6 then … else s else s else s).conflict
     = None)
    &amp;&amp; sensors &lt;&gt; [] &amp;&amp; (_x_2 &gt;= 0) &amp;&amp; (_x_1 &gt;= 0))</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-20d6fa7a-fe19-4f53-8cb2-f5702cc5464a"><table><tr><td>expr:</td><td><pre>(|Ordinal.&lt;&lt;| (|Ordinal.Int_79/boot|
                (|count.list_2066/server|
                  (|g…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-31ebac24-0b43-4d70-806a-dc7fa6ff0511"><table><tr><td>expr:</td><td><pre>(|count.list_2066/server| (|get.::.1_2048/server| sensors_2054/server))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-7cf51e30-92bb-4362-9377-fde338004420"><table><tr><td>expr:</td><td><pre>(|count.list_2066/server| sensors_2054/server)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li>Unsat</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-d7d75d80-d6a0-4f76-bf51-eaa24b18501a';
  fold.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-e0a2b4f2-9cd0-4a1b-aedb-8ee2fb68dfa2';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-f730970c-6af6-4fd6-b35e-8fc999a3606e';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-8dd56530-25c7-41e6-b93d-c881bef23010';
  fold.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-a23f5ee7-8606-4f65-a8aa-ad694eeb934c';
  fold.hydrate(target);
});
</script></div></div>



# Top-level problem runner and problem-specific conflict detection

Next, we'll add the ability to define problems, run them and detect conflicts.


```ocaml
let rec mk_agents_map actors =
  let agent_name = function Node a -> a in
  match actors with
  | [] -> Map.const None
  | agent :: agents ->
    Map.add (agent_name agent.agent_id) (Some agent) (mk_agents_map agents)

(* Run a problem along sensor readings *)

let run_problem (p:problem) sensors =
  let init_state = {
    wf_1 = p.work_flow_1;
    wf_2 = p.work_flow_2;
    sensor = None;
    agents = mk_agents_map p.agents;
    policy = p.policy;
    conflict = None;
  } in
  run init_state sensors

(* Is a conflict reachable from an initial state? *)

let conflict_reachable ?(k=5) (p:problem) sensors =
  let sensors = List.take k sensors in
  let (s, sensors_left) = run_problem p sensors in
  (s.conflict <> None && sensors_left = [])

(* Make a policy from a list of declarations *)

let mk_policy xs =
  Map.of_list ~default:Sharable xs
```




    val mk_agents_map : agent list -> (node_id, agent option) Map.t = <fun>
    val run_problem : problem -> Z.t list -> state * Z.t list = <fun>
    val conflict_reachable : ?k:Z.t -> problem -> Z.t list -> bool = <fun>
    val mk_policy : ('a * sharability) list -> ('a, sharability) Map.t = <fun>





<div><div class="imandra-fold panel panel-default" id="fold-080aa83f-9be0-4f4a-a131-63a9d97730f1"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>termination proof</span></div></div><div class="panel-body collapse"><div><h3>Termination proof</h3><div class="imandra-fold panel panel-default" id="fold-b6d7a4b1-e75c-4480-9b2f-fa8c2e58715e"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>call `mk_agents_map (List.tl actors)` from `mk_agents_map actors`</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-1b64c9c3-9fa8-4e42-8cd8-fe94822956e6"><table><tr><td>original:</td><td>mk_agents_map actors</td></tr><tr><td>sub:</td><td>mk_agents_map (List.tl actors)</td></tr><tr><td>original ordinal:</td><td>Ordinal.Int (_cnt actors)</td></tr><tr><td>sub ordinal:</td><td>Ordinal.Int (_cnt (List.tl actors))</td></tr><tr><td>path:</td><td>[actors &lt;&gt; []]</td></tr><tr><td>proof:</td><td><div class="imandra-fold panel panel-default" id="fold-a61603c2-2558-40c3-be6d-7470cb9ad7ac"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>detailed proof</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-832554b5-393b-4cab-9cf1-9e44bf90cecd"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-0252de1e-c2a4-40c4-9290-385e6fbb6c4d"><table><tr><td>ground_instances:</td><td>3</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.012s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-f66dbc05-3a50-42b5-97ae-85a2d948e5e0"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-0b66cc11-57c2-46d3-8b30-7aa459c2da4d"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-7315c82f-3802-4ccb-b18f-9294a012bf36"><table><tr><td>num checks:</td><td>8</td></tr><tr><td>arith assert lower:</td><td>17</td></tr><tr><td>arith tableau max rows:</td><td>10</td></tr><tr><td>arith tableau max columns:</td><td>24</td></tr><tr><td>arith pivots:</td><td>13</td></tr><tr><td>rlimit count:</td><td>3758</td></tr><tr><td>mk clause:</td><td>38</td></tr><tr><td>datatype occurs check:</td><td>25</td></tr><tr><td>mk bool var:</td><td>187</td></tr><tr><td>arith assert upper:</td><td>12</td></tr><tr><td>datatype splits:</td><td>21</td></tr><tr><td>decisions:</td><td>35</td></tr><tr><td>arith row summations:</td><td>34</td></tr><tr><td>propagations:</td><td>32</td></tr><tr><td>conflicts:</td><td>11</td></tr><tr><td>arith fixed eqs:</td><td>9</td></tr><tr><td>datatype accessor ax:</td><td>30</td></tr><tr><td>minimized lits:</td><td>1</td></tr><tr><td>arith conflicts:</td><td>2</td></tr><tr><td>arith num rows:</td><td>10</td></tr><tr><td>datatype constructor ax:</td><td>71</td></tr><tr><td>num allocs:</td><td>846908204</td></tr><tr><td>final checks:</td><td>6</td></tr><tr><td>added eqs:</td><td>222</td></tr><tr><td>del clause:</td><td>15</td></tr><tr><td>arith eq adapter:</td><td>12</td></tr><tr><td>memory:</td><td>33.340000</td></tr><tr><td>max memory:</td><td>33.450000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-f66dbc05-3a50-42b5-97ae-85a2d948e5e0';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-017a5066-6a8a-4e1b-b3b7-8e8b39a582e9"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.012s]
  let (_x_0 : int) = count.list count.agent actors in
  let (_x_1 : agent list) = List.tl actors in
  let (_x_2 : int) = count.list count.agent _x_1 in
  actors &lt;&gt; [] &amp;&amp; ((_x_0 &gt;= 0) &amp;&amp; (_x_2 &gt;= 0))
  ==&gt; not (_x_1 &lt;&gt; [])
      || Ordinal.( &lt;&lt; ) (Ordinal.Int _x_2) (Ordinal.Int _x_0)</pre></li><li><div><h6>simplify</h6><div class="imandra-table" id="table-7e56f213-9058-4710-ab14-13a1941bb0e1"><table><tr><td>into:</td><td><pre>let (_x_0 : agent list) = List.tl actors in
let (_x_1 : int) = count.list count.agent _x_0 in
let (_x_2 : int) = count.list count.agent actors in
not (_x_0 &lt;&gt; []) || Ordinal.( &lt;&lt; ) (Ordinal.Int _x_1) (Ordinal.Int _x_2)
|| not (actors &lt;&gt; [] &amp;&amp; (_x_2 &gt;= 0) &amp;&amp; (_x_1 &gt;= 0))</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-e51dcc88-beea-4576-ba28-12acc68593af"><table><tr><td>expr:</td><td><pre>(|Ordinal.&lt;&lt;| (|Ordinal.Int_79/boot|
                (|count.list_2142/server|
                  (|g…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-31712300-13ca-41ba-b1b1-7953fbbb2d9d"><table><tr><td>expr:</td><td><pre>(|count.list_2142/server| (|get.::.1_2128/server| actors_2131/server))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-d340a333-01ad-4f6b-9888-25800af2d84a"><table><tr><td>expr:</td><td><pre>(|count.list_2142/server| actors_2131/server)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li>Unsat</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-017a5066-6a8a-4e1b-b3b7-8e8b39a582e9';
  fold.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-832554b5-393b-4cab-9cf1-9e44bf90cecd';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-a61603c2-2558-40c3-be6d-7470cb9ad7ac';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-b6d7a4b1-e75c-4480-9b2f-fa8c2e58715e';
  fold.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-080aa83f-9be0-4f4a-a131-63a9d97730f1';
  fold.hydrate(target);
});
</script></div></div>



# Now, let's encode some problems and check for conflicts!

# Problem 1


```ocaml
let ex_1 = {
  work_flow_1 = [A; B; C; A];
  work_flow_2 = [D; E; F; D];
  agents=[

    {agent_id=Node A;
     guard=Eq(Sensor, 1);
     accesses=Apple};

    {agent_id=Node B;
     guard=Eq(Sensor, 2);
     accesses=Banana};

    {agent_id=Node C;
     guard=Eq(Sensor, 3);
     accesses=Orange};

    {agent_id=Node D;
     guard=Eq(Sensor, 1);
     accesses=Orange};

    {agent_id=Node E;
     guard=Eq(Sensor, 2);
     accesses=Banana};

    {agent_id=Node F;
     guard=Eq(Sensor, 3);
     accesses=Apple};

  ];
  policy=(mk_policy
          [(Apple, Sharable);
           (Banana, Unsharable);
           (Orange, Sharable)]);
}
```




    val ex_1 : problem =
      {work_flow_1 = [A;B;C;A]; work_flow_2 = [D;E;F;D];
       agents =
        [{agent_id = Node A; guard = Eq (Sensor, 1); accesses = Apple};
         {agent_id = Node B; guard = Eq (Sensor, 2); accesses = Banana};
         {agent_id = Node C; guard = Eq (Sensor, 3); accesses = Orange};
         {agent_id = Node D; guard = Eq (Sensor, 1); accesses = Orange};
         {agent_id = Node E; guard = Eq (Sensor, 2); accesses = Banana};
         {agent_id = Node F; guard = Eq (Sensor, 3); accesses = Apple}];
       policy = (Map.of_list ~default:Sharable [(Banana, Unsharable)])}




# Is a conflict possible? Let's ask Imandra!


```ocaml
instance (fun sensors -> conflict_reachable ex_1 sensors)
```




    - : Z.t list -> bool = <fun>
    module CX : sig val sensors : Z.t list end





<div><pre>Instance (after 20 steps, 0.052s):
let sensors : int list = [1; 2]
</pre></div>




<div><div style="font-size: 1.2em; padding: 0.5em; border-top: 1px solid green; border-bottom: 1px solid green"><i class="fa fa-check-circle" style="margin-right: 0.5em; color: green"></i><span>Instance</span></div><div><div class="imandra-alternatives" id="alt-b3d2a388-a651-4fac-a571-15089c862925"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>call graph</a></li><li class="" data-toggle="tab"><a>proof</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-graphviz" id="graphviz-390023ce-b4e6-45e9-9032-008fa1177ce2"><textarea style="display: none">digraph &quot;call graph&quot; {
goal [label=&quot;let (_x_0 : (state * int list))\l    = run\l      \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l       conflict = …\}\l      (List.take 5 sensors)\lin not (_x_0.0.conflict = None) &amp;&amp; (_x_0.1 = [])&quot;,shape=box,style=filled,color=&quot;cyan&quot;,fontname=&quot;courier&quot;,fontsize=14];
goal -&gt; call_128 [label=&quot;calls&quot;];
goal -&gt; call_127 [label=&quot;calls&quot;];
goal -&gt; call_156 [label=&quot;calls&quot;];
goal -&gt; call_66 [label=&quot;calls&quot;];
call_128 [label=&quot;run\l\{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l conflict = …\}\l(List.take 5 sensors)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_128 -&gt; call_1079 [label=&quot;calls&quot;];
call_128 -&gt; call_1111 [label=&quot;calls&quot;];
call_128 -&gt; call_1095 [label=&quot;calls&quot;];
call_127 [label=&quot;mk_agents_map\l(\{agent_id = Node …; guard = Eq (…, 1); accesses = Apple\} ::\l (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_127 -&gt; call_1818 [label=&quot;calls&quot;];
call_156 [label=&quot;List.take 5 sensors&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_156 -&gt; call_914 [label=&quot;calls&quot;];
call_66 [label=&quot;Map.of_list Sharable ((Apple, Sharable) :: ((…, …) :: (… :: …)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_66 -&gt; call_1893 [label=&quot;calls&quot;];
call_1079 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\lrun\l(step\l \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l  conflict = …\}\l (List.hd _x_0))\l(List.tl _x_0)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1079 -&gt; call_4022 [label=&quot;calls&quot;];
call_1079 -&gt; call_4012 [label=&quot;calls&quot;];
call_1079 -&gt; call_4027 [label=&quot;calls&quot;];
call_1111 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Option.get (Map.get' … A)).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1111 -&gt; call_3429 [label=&quot;calls&quot;];
call_1111 -&gt; call_3427 [label=&quot;calls&quot;];
call_1095 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Option.get (Map.get' … D)).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1095 -&gt; call_2890 [label=&quot;calls&quot;];
call_1095 -&gt; call_2888 [label=&quot;calls&quot;];
call_1818 [label=&quot;mk_agents_map\l(\{agent_id = Node …; guard = Eq (…, 2); accesses = Banana\} ::\l (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1818 -&gt; call_2244 [label=&quot;calls&quot;];
call_914 [label=&quot;List.take 4 (List.tl sensors)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_914 -&gt; call_2032 [label=&quot;calls&quot;];
call_1893 [label=&quot;Map.of_list Sharable [(Banana, Unsharable); (…, Sharable)]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1893 -&gt; call_2436 [label=&quot;calls&quot;];
call_4022 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Option.get (Map.get' ….agents (List.hd ….wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4022 -&gt; call_5611 [label=&quot;calls&quot;];
call_4022 -&gt; call_5609 [label=&quot;calls&quot;];
call_4012 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : int list) = List.tl _x_0 in\lrun\l(step\l (step\l  \{wf_1 = …; wf_2 = …; sensor = …;\l   agents =\l   mk_agents_map\l   (\{agent_id = Node …; guard = Eq (…, 1); accesses = Apple\} ::\l    (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)));\l   policy =\l   Map.of_list Sharable ((Apple, Sharable) :: ((…, …) :: (… :: …)));\l   conflict = …\}\l  (List.hd _x_0))\l (List.hd _x_1))\l(List.tl _x_1)&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4027 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Option.get (Map.get' ….agents (List.hd ….wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4027 -&gt; call_5106 [label=&quot;calls&quot;];
call_4027 -&gt; call_5104 [label=&quot;calls&quot;];
call_3429 [label=&quot;eval_guard … (Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3427 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2890 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2888 [label=&quot;eval_guard … (Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2244 [label=&quot;mk_agents_map (\{agent_id = …; guard = …; accesses = …\} :: (… :: …))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2244 -&gt; call_2642 [label=&quot;calls&quot;];
call_2032 [label=&quot;List.take 3 (List.tl (List.tl sensors))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2032 -&gt; call_5746 [label=&quot;calls&quot;];
call_2436 [label=&quot;Map.of_list Sharable [(…, Sharable)]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2436 -&gt; call_2714 [label=&quot;calls&quot;];
call_5611 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5609 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, (Option.get (Map.get' ….agents (List.hd ….wf_2))).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5106 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, (Option.get (Map.get' ….agents (List.hd ….wf_1))).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5104 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, (Option.get (Map.get' ….agents (List.hd ….wf_1))).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2642 [label=&quot;mk_agents_map (… :: …)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2642 -&gt; call_3069 [label=&quot;calls&quot;];
call_5746 [label=&quot;List.take 2 …&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2714 [label=&quot;Map.of_list Sharable []&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2714 -&gt; call_2703 [label=&quot;calls&quot;];
call_3069 [label=&quot;mk_agents_map …&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3069 -&gt; call_3182 [label=&quot;calls&quot;];
call_2703 [label=&quot;Map.of_list Sharable (List.tl [])&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3182 [label=&quot;mk_agents_map [\{agent_id = Node …; guard = …; accesses = Apple\}]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3182 -&gt; call_3298 [label=&quot;calls&quot;];
call_3298 [label=&quot;mk_agents_map []&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3298 -&gt; call_3625 [label=&quot;calls&quot;];
call_3625 [label=&quot;mk_agents_map (List.tl [])&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-390023ce-b4e6-45e9-9032-008fa1177ce2';
  graphviz.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-proof-top"><div class="imandra-fold panel panel-default" id="fold-7c5be74b-5a8b-4548-b564-8fe28179c802"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>proof attempt</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-2f74e304-30b1-4e05-9589-209cb31b72d3"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li><li class="" data-toggle="tab"><a>graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-cde93609-b0a3-457e-a118-4026d5f791d7"><table><tr><td>ground_instances:</td><td>20</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.052s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-f2b21712-af0c-4af2-a74d-511f1384ce92"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-351ba396-fe9d-4889-ae19-33df1f2b22fa"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-5a55a2fc-406c-41d3-92a8-d65948ec51a6"><table><tr><td>array def const:</td><td>2</td></tr><tr><td>num checks:</td><td>41</td></tr><tr><td>array sel const:</td><td>49</td></tr><tr><td>array def store:</td><td>119</td></tr><tr><td>array exp ax2:</td><td>208</td></tr><tr><td>array splits:</td><td>49</td></tr><tr><td>rlimit count:</td><td>90757</td></tr><tr><td>array ext ax:</td><td>27</td></tr><tr><td>mk clause:</td><td>714</td></tr><tr><td>array ax1:</td><td>9</td></tr><tr><td>datatype occurs check:</td><td>3861</td></tr><tr><td>mk bool var:</td><td>4711</td></tr><tr><td>array ax2:</td><td>357</td></tr><tr><td>datatype splits:</td><td>880</td></tr><tr><td>decisions:</td><td>3574</td></tr><tr><td>propagations:</td><td>2772</td></tr><tr><td>conflicts:</td><td>149</td></tr><tr><td>datatype accessor ax:</td><td>220</td></tr><tr><td>minimized lits:</td><td>42</td></tr><tr><td>datatype constructor ax:</td><td>2343</td></tr><tr><td>num allocs:</td><td>962813774</td></tr><tr><td>final checks:</td><td>134</td></tr><tr><td>added eqs:</td><td>16165</td></tr><tr><td>del clause:</td><td>480</td></tr><tr><td>time:</td><td>0.002000</td></tr><tr><td>memory:</td><td>36.100000</td></tr><tr><td>max memory:</td><td>36.150000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-f2b21712-af0c-4af2-a74d-511f1384ce92';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-b015f240-1635-43af-8e6d-3b7b3864ea3e"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.052s]
  let (_x_0 : (state * int list))
      = run
        {wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;
         conflict = …}
        (List.take … ( :var_0: ))
  in not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = [])</pre></li><li><div><h4>simplify</h4><div class="imandra-table" id="table-4fc944ab-65f4-4def-ae61-d3f2adc8e2e7"><table><tr><td>into:</td><td><pre>let (_x_0 : (state * int list))
    = run
      {wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;
       conflict = …}
      (List.take 5 ( :var_0: ))
in not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = [])</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-e74009bd-c908-43c2-bfff-17419c875469"><table><tr><td>expr:</td><td><pre>(|List.take_2327/server| 5 sensors_1646/client)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-7f016450-7e0b-488f-8c35-5322fa4cdf0d"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-4d6270ee-7f27-4eba-b266-7bd58c266331"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2302/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-4dfa94a1-9e1d-49ea-b5e2-a319ba5787b7"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (tuple_mk_2312/server Apple_1528/client Sharable_1534/client)
                 (|::…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-f6327f01-707d-4b92-a87a-c4a7efb43d3b"><table><tr><td>expr:</td><td><pre>(|List.take_2327/server| 4 (|get.::.1_2295/server| sensors_1646/client))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-e5f1026e-7851-428c-b5b3-45f07457c140"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2302/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-383d90e3-8175-4997-a572-df0548049542"><table><tr><td>expr:</td><td><pre>(|Map.of_list_2320/server|
  Sharable_1534/client
  (|::| (tuple_mk_2312/server Banana_1529/client U…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-9284ee19-0002-47ee-b697-3e66557e48f4"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2302/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-bbf7b568-1214-465c-8f98-67e23b735664"><table><tr><td>expr:</td><td><pre>(|Map.of_list_2320/server|
  Sharable_1534/client
  (|::| (tuple_mk_2312/server Orange_1530/client S…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-1d4752a6-10ca-4149-a70c-594e1b080ff9"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2302/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-d2805aa3-9873-43f9-bad1-5079288d9bd7"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2302/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-307c5299-bb0b-4f4b-a178-69d14fcd49de"><table><tr><td>expr:</td><td><pre>(|Map.of_list_2320/server| Sharable_1534/client |[]|)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-3942d18c-bb9b-4e6c-b5b7-c8bc6c2ce455"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2302/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-f2a4e68b-0416-4fbc-9966-7dbd2465e586"><table><tr><td>expr:</td><td><pre>(mk_agents_map_1621/client
  (|::| (|rec_mk.agent_2302/server|
          (Node_1502/client F_1508/cl…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-a2ee5368-96d3-4c58-bbf5-b77852bf6df3"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2302/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-52973d21-b7cf-4a2c-8a8b-8eeffb0d8556"><table><tr><td>expr:</td><td><pre>(mk_agents_map_1621/client |[]|)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-f2ea4551-f9ab-4339-984c-b9de46a85069"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-d6143327-fec7-451e-842e-eb6ac06d7092"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-d3629143-42d3-4281-8453-dad40c470061"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-8e4d395d-b7fa-4ae6-ae9c-7da6a2f01989"><table><tr><td>expr:</td><td><pre>(|List.take_2327/server|
  3
  (|get.::.1_2295/server| (|get.::.1_2295/server| sensors_1646/client))…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li>Sat (Some let sensors : int list = [(Z.of_nativeint (1n)); (Z.of_nativeint (2n))]
)</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-b015f240-1635-43af-8e6d-3b7b3864ea3e';
  fold.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-ffcd3058-ff1d-49c2-a4a2-2cac10c0854b"><textarea style="display: none">digraph &quot;proof&quot; {
p_243 [label=&quot;Start (let (_x_0 : (state * int list))\l           = run\l             \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l              policy = …; conflict = …\}\l             (List.take … ( :var_0: ))\l       in not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = []) :time 0.052s)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_243 -&gt; p_242 [label=&quot;&quot;];
p_242 [label=&quot;Simplify (let (_x_0 : (state * int list))\l              = run\l                \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l                 policy = …; conflict = …\}\l                (List.take 5 ( :var_0: ))\l          in not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = []) :expansions []\l          :rw [] :fc [])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_242 -&gt; p_241 [label=&quot;&quot;];
p_241 [label=&quot;Unroll ([List.take 5 sensors], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_241 -&gt; p_240 [label=&quot;&quot;];
p_240 [label=&quot;Unroll ([run\l         \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l          conflict = …\}\l         (List.take 5 sensors)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_240 -&gt; p_239 [label=&quot;&quot;];
p_239 [label=&quot;Unroll ([…], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_239 -&gt; p_238 [label=&quot;&quot;];
p_238 [label=&quot;Unroll ([…], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_238 -&gt; p_237 [label=&quot;&quot;];
p_237 [label=&quot;Unroll ([List.take 4 (List.tl sensors)], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_237 -&gt; p_236 [label=&quot;&quot;];
p_236 [label=&quot;Unroll ([mk_agents_map\l         (\{agent_id = Node …; guard = Eq (…, 2); accesses = Banana\} ::\l          (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_236 -&gt; p_235 [label=&quot;&quot;];
p_235 [label=&quot;Unroll ([Map.of_list Sharable [(Banana, Unsharable); (…, Sharable)]], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_235 -&gt; p_234 [label=&quot;&quot;];
p_234 [label=&quot;Unroll ([mk_agents_map\l         (\{agent_id = …; guard = …; accesses = …\} :: (… :: …))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_234 -&gt; p_233 [label=&quot;&quot;];
p_233 [label=&quot;Unroll ([Map.of_list Sharable [(…, Sharable)]], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_233 -&gt; p_232 [label=&quot;&quot;];
p_232 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Option.get (Map.get' … D)).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_232 -&gt; p_231 [label=&quot;&quot;];
p_231 [label=&quot;Unroll ([mk_agents_map (… :: …)], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_231 -&gt; p_230 [label=&quot;&quot;];
p_230 [label=&quot;Unroll ([Map.of_list Sharable []], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_230 -&gt; p_229 [label=&quot;&quot;];
p_229 [label=&quot;Unroll ([mk_agents_map …], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_229 -&gt; p_228 [label=&quot;&quot;];
p_228 [label=&quot;Unroll ([mk_agents_map [\{agent_id = Node …; guard = …; accesses = Apple\}]],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_228 -&gt; p_227 [label=&quot;&quot;];
p_227 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Option.get (Map.get' … A)).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_227 -&gt; p_226 [label=&quot;&quot;];
p_226 [label=&quot;Unroll ([mk_agents_map []], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_226 -&gt; p_225 [label=&quot;&quot;];
p_225 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         run\l         (step\l          \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l           conflict = …\}\l          (List.hd _x_0))\l         (List.tl _x_0)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_225 -&gt; p_224 [label=&quot;&quot;];
p_224 [label=&quot;Unroll ([eval_guard (List.hd (List.tl (List.take 5 sensors)))\l         (Option.get (Map.get' ….agents (List.hd ….wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_224 -&gt; p_223 [label=&quot;&quot;];
p_223 [label=&quot;Unroll ([eval_guard (List.hd (List.tl (List.take 5 sensors)))\l         (Option.get (Map.get' ….agents (List.hd ….wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_223 -&gt; p_222 [label=&quot;&quot;];
p_222 [label=&quot;Unroll ([List.take 3 (List.tl (List.tl sensors))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_222 -&gt; p_221 [label=&quot;&quot;];
p_221 [label=&quot;Sat (Some let sensors : int list = [(Z.of_nativeint (1n)); (Z.of_nativeint (2n))]\l)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-ffcd3058-ff1d-49c2-a4a2-2cac10c0854b';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-2f74e304-30b1-4e05-9589-209cb31b72d3';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-7c5be74b-5a8b-4548-b564-8fe28179c802';
  fold.hydrate(target);
});
</script></div></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-b3d2a388-a651-4fac-a571-15089c862925';
  alternatives.hydrate(target);
});
</script></div></div></div>



# Problem 2


```ocaml
(* Example 2 *)

let ex_2 = {
  work_flow_1 = [A; B; C; A];
  work_flow_2 = [D; E; F; D];

  agents=[

    {agent_id=Node A;
     guard=Eq(Sensor, 1);
     accesses=Apple};

    {agent_id=Node B;
     guard=Eq(Sensor, 2);
     accesses=Banana};

    {agent_id=Node C;
     guard=Eq(Sensor, 3);
     accesses=Orange};

    {agent_id=Node D;
     guard=Eq(Sensor, 1);
     accesses=Orange};

    {agent_id=Node E;
     guard=Eq(Sensor, 2);
     accesses=Banana};

    {agent_id=Node F;
     guard=Eq(Sensor, 3);
     accesses=Apple};

  ];
  policy=(mk_policy
          [(Apple, Unsharable);
           (Banana, Sharable);
           (Orange, Sharable)]);
}

```




    val ex_2 : problem =
      {work_flow_1 = [A;B;C;A]; work_flow_2 = [D;E;F;D];
       agents =
        [{agent_id = Node A; guard = Eq (Sensor, 1); accesses = Apple};
         {agent_id = Node B; guard = Eq (Sensor, 2); accesses = Banana};
         {agent_id = Node C; guard = Eq (Sensor, 3); accesses = Orange};
         {agent_id = Node D; guard = Eq (Sensor, 1); accesses = Orange};
         {agent_id = Node E; guard = Eq (Sensor, 2); accesses = Banana};
         {agent_id = Node F; guard = Eq (Sensor, 3); accesses = Apple}];
       policy = (Map.of_list ~default:Sharable [(Apple, Unsharable)])}





```ocaml
instance (fun sensors -> conflict_reachable ex_2 sensors)
```




    - : Z.t list -> bool = <fun>





<div><div style="font-size: 1.2em; padding: 0.5em; border-top: 1px dashed #D84315; border-bottom: 1px dashed #D84315"><i class="fa fa-times-circle-o" style="margin-right: 0.5em; color: #D84315"></i><span>Unsatisfiable</span></div><div><div class="imandra-alternatives" id="alt-d8808738-35e4-4e8b-b8f0-d0c7cc11adf2"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>proof</a></li><li class="" data-toggle="tab"><a>call graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-proof-top"><div class="imandra-fold panel panel-default" id="fold-dc65f44e-ef83-47b3-9b96-ef229ce85156"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>proof</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-7e018d69-e674-4d5f-9cbd-bb4e3892d95f"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li><li class="" data-toggle="tab"><a>graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-715acfdb-0a21-4bdc-91b1-d64e1128d146"><table><tr><td>ground_instances:</td><td>41</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.285s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-754b42f8-4737-4751-b89b-d7a6f361bbe1"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-4c7187c1-77ec-4c8d-a1cc-7c06dee9f75a"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-b721c4d9-e656-4185-b2d9-098f25748624"><table><tr><td>array def const:</td><td>2</td></tr><tr><td>num checks:</td><td>84</td></tr><tr><td>array sel const:</td><td>399</td></tr><tr><td>array def store:</td><td>426</td></tr><tr><td>array exp ax2:</td><td>689</td></tr><tr><td>array splits:</td><td>117</td></tr><tr><td>rlimit count:</td><td>765729</td></tr><tr><td>array ext ax:</td><td>54</td></tr><tr><td>mk clause:</td><td>3597</td></tr><tr><td>array ax1:</td><td>10</td></tr><tr><td>datatype occurs check:</td><td>10642</td></tr><tr><td>mk bool var:</td><td>24304</td></tr><tr><td>array ax2:</td><td>2551</td></tr><tr><td>datatype splits:</td><td>6758</td></tr><tr><td>decisions:</td><td>34285</td></tr><tr><td>propagations:</td><td>34283</td></tr><tr><td>conflicts:</td><td>845</td></tr><tr><td>datatype accessor ax:</td><td>1299</td></tr><tr><td>minimized lits:</td><td>598</td></tr><tr><td>datatype constructor ax:</td><td>16141</td></tr><tr><td>num allocs:</td><td>1214194445</td></tr><tr><td>final checks:</td><td>301</td></tr><tr><td>added eqs:</td><td>167715</td></tr><tr><td>del clause:</td><td>2650</td></tr><tr><td>time:</td><td>0.006000</td></tr><tr><td>memory:</td><td>41.160000</td></tr><tr><td>max memory:</td><td>41.680000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-754b42f8-4737-4751-b89b-d7a6f361bbe1';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-ee7cf01f-b680-4b83-a3dc-5be548d44b6b"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.285s]
  let (_x_0 : (state * int list))
      = run
        {wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;
         conflict = …}
        (List.take … ( :var_0: ))
  in not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = [])</pre></li><li><div><h4>simplify</h4><div class="imandra-table" id="table-73ac9e75-5419-4298-bbf3-a869e230779d"><table><tr><td>into:</td><td><pre>let (_x_0 : (state * int list))
    = run
      {wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;
       conflict = …}
      (List.take 5 ( :var_0: ))
in not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = [])</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-f7b75367-9a9f-4bc0-b0ce-7096584a9d2e"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-01ec1735-72d6-440a-a7f5-77a117d2bd97"><table><tr><td>expr:</td><td><pre>(|List.take_2447/server| 5 sensors_1649/client)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-475e395c-4e21-42e5-a056-91afe46d24d3"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2422/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-5223c01f-1382-4656-b291-1d46212bc859"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (tuple_mk_2432/server Apple_1528/client Unsharable_1535/client)
                 (|…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-9cacaf43-6c74-4fdd-974c-70c17844429f"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2422/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-c6b69956-f4d5-4dc2-aaef-f038e70a10c4"><table><tr><td>expr:</td><td><pre>(|List.take_2447/server| 4 (|get.::.1_2415/server| sensors_1649/client))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-31bf0fc8-9eaa-4a03-8d74-a94bf4e42c7d"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2422/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-e39f28d8-6304-45d2-b63e-5318d3619072"><table><tr><td>expr:</td><td><pre>(|Map.of_list_2440/server|
  Sharable_1534/client
  (|::| (tuple_mk_2432/server Banana_1529/client S…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-2cf22e15-695a-4c30-8300-f83e68b9712b"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2422/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-1150ee54-d940-48b1-b9ef-dd55daf1968c"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2422/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-28063b08-01c9-48c8-bb5f-1d452fa12416"><table><tr><td>expr:</td><td><pre>(|Map.of_list_2440/server|
  Sharable_1534/client
  (|::| (tuple_mk_2432/server Orange_1530/client S…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-25572530-5139-4f2e-8ec3-4648483bbc15"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2422/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-1db00370-31e6-48e1-a293-22a38b7bef8b"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-83db0728-ee49-49cd-a5ba-957223c157a6"><table><tr><td>expr:</td><td><pre>(|Map.of_list_2440/server| Sharable_1534/client |[]|)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-e4957040-05b1-4764-befa-777621230fc2"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2422/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-08d8d86d-bc62-4e2a-9f26-b18068229a79"><table><tr><td>expr:</td><td><pre>(|List.take_2447/server|
  3
  (|get.::.1_2415/server| (|get.::.1_2415/server| sensors_1649/client))…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-65431c80-fa10-47df-b3f0-b904472852f3"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2422/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-57d59ffa-f5cf-4235-bcc5-e285b72b74c5"><table><tr><td>expr:</td><td><pre>(mk_agents_map_1621/client
  (|::| (|rec_mk.agent_2422/server|
          (Node_1502/client F_1508/cl…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-9cb5d4f7-1308-4939-8f70-39e566842dfe"><table><tr><td>expr:</td><td><pre>(mk_agents_map_1621/client |[]|)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-237e7396-4462-4f59-bdee-4106234fe44e"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2422/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-65f64d34-6fb1-49ed-81f4-8eaad46903ae"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-33c89014-d9a1-4542-b91c-80735552a77e"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-d3d0e88c-9455-49a9-85bd-572c39f5a55c"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-69a390d3-0686-43ea-9489-f2e0505e7e43"><table><tr><td>expr:</td><td><pre>(|List.take_2447/server|
  2
  (|get.::.1_2415/server|
    (|get.::.1_2415/server| (|get.::.1_2415/s…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-06a111d0-a31e-4bd6-bece-9db193fa250d"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2422/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-11949c66-8324-4511-ad3f-dacd0f6515e5"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.0_2414/server|
             (|get.::.1_2415/server|
               (|get.::.1_24…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-ea26c3d7-b2b0-4c59-a995-62785db12b4e"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.0_2414/server|
             (|get.::.1_2415/server|
               (|get.::.1_24…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-63f1c1ce-c2a1-41da-99c9-5b4763a8cb48"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-f95352b6-c6b8-41b7-b659-382f75839efe"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_2415/server|
             (|get.::.1_2415/server|
               (|get.::.1_24…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-4112a964-b798-4211-b277-bfd2f0760e4f"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2422/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-abc1e387-e573-4f17-b892-60f2f1ec9ae2"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_2415/server|
             (|get.::.1_2415/server|
               (|get.::.1_24…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-97033241-034e-4153-a678-b3ca1344ebbd"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_2415/server|
             (|get.::.1_2415/server|
               (|get.::.1_24…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-53ad35f0-ff64-4e35-a6cf-30c8eab421dc"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-ef1e16f3-8517-4e79-9680-f90d035102c0"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_2415/server|
             (|get.::.1_2415/server|
               (|get.::.1_24…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-48ec6fbb-5ad8-4b96-b650-ab9eaa9696b8"><table><tr><td>expr:</td><td><pre>(|Map.of_list_2440/server| Sharable_1534/client (|get.::.1_2437/server| |[]|))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-bc9f100e-b6c7-4a2d-8186-36b40abaf3fd"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_2415/server|
             (|get.::.1_2415/server|
               (|get.::.1_24…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-20e3261f-4508-468e-8d24-4ee4a1c501d7"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_2415/server|
             (|get.::.1_2415/server|
               (|get.::.1_24…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-9009a858-b6e2-448e-ba98-b0c7d564ef61"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-4cafcc19-70d7-41c6-b7c9-c08e32d99433"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-0e30b695-e5ce-4d9f-b4df-4fa2f57ca801"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2422/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-60d225ad-a308-4bc3-bed1-975b4122a2f9"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li>Unsat</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-ee7cf01f-b680-4b83-a3dc-5be548d44b6b';
  fold.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-397ad744-8584-4b19-b348-281878234eed"><textarea style="display: none">digraph &quot;proof&quot; {
p_287 [label=&quot;Start (let (_x_0 : (state * int list))\l           = run\l             \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l              policy = …; conflict = …\}\l             (List.take … ( :var_0: ))\l       in not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = []) :time 0.285s)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_287 -&gt; p_286 [label=&quot;&quot;];
p_286 [label=&quot;Simplify (let (_x_0 : (state * int list))\l              = run\l                \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l                 policy = …; conflict = …\}\l                (List.take 5 ( :var_0: ))\l          in not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = []) :expansions []\l          :rw [] :fc [])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_286 -&gt; p_285 [label=&quot;&quot;];
p_285 [label=&quot;Unroll ([let (_x_0 : node_id list) = … :: … in\l         run\l         \{wf_1 = A :: _x_0; wf_2 = D :: _x_0; sensor = None;\l          agents = mk_agents_map (… :: …);\l          policy = Map.of_list Sharable (… :: …); conflict = None\}\l         (List.take 5 sensors)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_285 -&gt; p_284 [label=&quot;&quot;];
p_284 [label=&quot;Unroll ([List.take 5 …], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_284 -&gt; p_283 [label=&quot;&quot;];
p_283 [label=&quot;Unroll ([mk_agents_map\l         (\{agent_id = Node …; guard = Eq (…, 1); accesses = Apple\} ::\l          (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_283 -&gt; p_282 [label=&quot;&quot;];
p_282 [label=&quot;Unroll ([Map.of_list Sharable\l         ((Apple, Unsharable) :: ((…, Sharable) :: (… :: …)))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_282 -&gt; p_281 [label=&quot;&quot;];
p_281 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Option.get (Map.get' (mk_agents_map (… :: …)) D)).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_281 -&gt; p_280 [label=&quot;&quot;];
p_280 [label=&quot;Unroll ([List.take 4 (List.tl sensors)], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_280 -&gt; p_279 [label=&quot;&quot;];
p_279 [label=&quot;Unroll ([mk_agents_map …], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_279 -&gt; p_278 [label=&quot;&quot;];
p_278 [label=&quot;Unroll ([Map.of_list Sharable …], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_278 -&gt; p_277 [label=&quot;&quot;];
p_277 [label=&quot;Unroll ([mk_agents_map\l         (\{agent_id = Node …; guard = Eq (…, 3); accesses = Orange\} ::\l          (\{agent_id = …; guard = …; accesses = Orange\} :: (… :: …)))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_277 -&gt; p_276 [label=&quot;&quot;];
p_276 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Option.get (Map.get' (mk_agents_map (… :: …)) A)).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_276 -&gt; p_275 [label=&quot;&quot;];
p_275 [label=&quot;Unroll ([Map.of_list Sharable [(Orange, Sharable)]], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_275 -&gt; p_274 [label=&quot;&quot;];
p_274 [label=&quot;Unroll ([mk_agents_map\l         (\{agent_id = …; guard = …; accesses = Orange\} :: (… :: …))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_274 -&gt; p_273 [label=&quot;&quot;];
p_273 [label=&quot;Unroll ([let (_x_0 : node_id list) = … :: … in\l         let (_x_1 : int list) = List.take 5 sensors in\l         run\l         (step\l          \{wf_1 = A :: _x_0; wf_2 = D :: _x_0; sensor = None;\l           agents = mk_agents_map (… :: …);\l           policy = Map.of_list Sharable (… :: …); conflict = None\}\l          (List.hd _x_1))\l         (List.tl _x_1)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_273 -&gt; p_272 [label=&quot;&quot;];
p_272 [label=&quot;Unroll ([Map.of_list Sharable []], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_272 -&gt; p_271 [label=&quot;&quot;];
p_271 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 1,\l                   (Option.get (Map.get' (mk_agents_map (… :: …)) D)).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_271 -&gt; p_270 [label=&quot;&quot;];
p_270 [label=&quot;Unroll ([List.take 3 (List.tl (List.tl sensors))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_270 -&gt; p_269 [label=&quot;&quot;];
p_269 [label=&quot;Unroll ([mk_agents_map (… :: …)], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_269 -&gt; p_268 [label=&quot;&quot;];
p_268 [label=&quot;Unroll ([mk_agents_map …], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_268 -&gt; p_267 [label=&quot;&quot;];
p_267 [label=&quot;Unroll ([mk_agents_map []], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_267 -&gt; p_266 [label=&quot;&quot;];
p_266 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 0,\l                   (Option.get (Map.get' (mk_agents_map (… :: …)) D)).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_266 -&gt; p_265 [label=&quot;&quot;];
p_265 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         let (_x_1 : node_id list) = … :: … in\l         let (_x_2 : state)\l             = step\l               \{wf_1 = A :: _x_1; wf_2 = D :: _x_1; sensor = None;\l                agents = mk_agents_map (… :: …);\l                policy = Map.of_list Sharable (… :: …); conflict = None\}\l               (List.hd _x_0)\l         in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_265 -&gt; p_264 [label=&quot;&quot;];
p_264 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         let (_x_1 : node_id list) = … :: … in\l         let (_x_2 : state)\l             = step\l               \{wf_1 = A :: _x_1; wf_2 = D :: _x_1; sensor = None;\l                agents = mk_agents_map (… :: …);\l                policy = Map.of_list Sharable (… :: …); conflict = None\}\l               (List.hd _x_0)\l         in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_264 -&gt; p_263 [label=&quot;&quot;];
p_263 [label=&quot;Unroll ([let (_x_0 : node_id list) = … :: … in\l         let (_x_1 : int list) = List.take 5 sensors in\l         let (_x_2 : int list) = List.tl _x_1 in\l         run\l         (step\l          (step\l           \{wf_1 = A :: _x_0; wf_2 = D :: _x_0; sensor = None;\l            agents = mk_agents_map (… :: …);\l            policy = Map.of_list Sharable (… :: …); conflict = None\}\l           (List.hd _x_1))\l          (List.hd _x_2))\l         (List.tl _x_2)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_263 -&gt; p_262 [label=&quot;&quot;];
p_262 [label=&quot;Unroll ([List.take 2 (List.tl (List.tl (List.tl sensors)))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_262 -&gt; p_261 [label=&quot;&quot;];
p_261 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 1,\l                   (Option.get (Map.get' (mk_agents_map (… :: …)) A)).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_261 -&gt; p_260 [label=&quot;&quot;];
p_260 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : node_id list) = … :: … in\l         let (_x_3 : state)\l             = step\l               (step\l                \{wf_1 = A :: _x_2; wf_2 = D :: _x_2; sensor = None;\l                 agents = mk_agents_map (… :: …);\l                 policy = Map.of_list Sharable (… :: …); conflict = None\}\l                (List.hd _x_0))\l               (List.hd _x_1)\l         in\l         eval_guard (List.hd (List.tl _x_1))\l         (Option.get (Map.get' _x_3.agents (List.hd _x_3.wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_260 -&gt; p_259 [label=&quot;&quot;];
p_259 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : node_id list) = … :: … in\l         let (_x_3 : state)\l             = step\l               (step\l                \{wf_1 = A :: _x_2; wf_2 = D :: _x_2; sensor = None;\l                 agents = mk_agents_map (… :: …);\l                 policy = Map.of_list Sharable (… :: …); conflict = None\}\l                (List.hd _x_0))\l               (List.hd _x_1)\l         in\l         eval_guard (List.hd (List.tl _x_1))\l         (Option.get (Map.get' _x_3.agents (List.hd _x_3.wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_259 -&gt; p_258 [label=&quot;&quot;];
p_258 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 …) in\l         let (_x_1 : int list) = List.tl _x_0 in\l         run (step (step (step … …) (List.hd _x_0)) (List.hd _x_1))\l         (List.tl _x_1)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_258 -&gt; p_257 [label=&quot;&quot;];
p_257 [label=&quot;Unroll ([List.take 1 (List.tl (List.tl (List.tl (List.tl …))))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_257 -&gt; p_256 [label=&quot;&quot;];
p_256 [label=&quot;Unroll ([eval_guard … (Destruct(Or, 0, (Option.get …).guard))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_256 -&gt; p_255 [label=&quot;&quot;];
p_255 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 …) in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : state)\l             = step (step (step … …) (List.hd _x_0)) (List.hd _x_1)\l         in\l         eval_guard (List.hd (List.tl _x_1))\l         (Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_255 -&gt; p_254 [label=&quot;&quot;];
p_254 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 …) in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : state)\l             = step (step (step … …) (List.hd _x_0)) (List.hd _x_1)\l         in\l         eval_guard (List.hd (List.tl _x_1))\l         (Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_254 -&gt; p_253 [label=&quot;&quot;];
p_253 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 …) in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : int list) = List.tl _x_1 in\l         run\l         (step (step (step (step … …) (List.hd _x_0)) (List.hd _x_1))\l          (List.hd _x_2))\l         (List.tl _x_2)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_253 -&gt; p_252 [label=&quot;&quot;];
p_252 [label=&quot;Unroll ([List.take 0 (List.tl (List.tl (List.tl (List.tl (List.tl …)))))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_252 -&gt; p_251 [label=&quot;&quot;];
p_251 [label=&quot;Unroll ([Map.of_list Sharable (List.tl [])], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_251 -&gt; p_250 [label=&quot;&quot;];
p_250 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 …) in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : int list) = List.tl _x_1 in\l         let (_x_3 : state)\l             = step\l               (step (step (step … …) (List.hd _x_0)) (List.hd _x_1))\l               (List.hd _x_2)\l         in\l         eval_guard (List.hd (List.tl _x_2))\l         (Option.get (Map.get' _x_3.agents (List.hd _x_3.wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_250 -&gt; p_249 [label=&quot;&quot;];
p_249 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 …) in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : int list) = List.tl _x_1 in\l         let (_x_3 : state)\l             = step\l               (step (step (step … …) (List.hd _x_0)) (List.hd _x_1))\l               (List.hd _x_2)\l         in\l         eval_guard (List.hd (List.tl _x_2))\l         (Option.get (Map.get' _x_3.agents (List.hd _x_3.wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_249 -&gt; p_248 [label=&quot;&quot;];
p_248 [label=&quot;Unroll ([eval_guard (List.hd (List.tl (List.take 5 …)))\l         (Destruct(Or, 0, (Option.get …).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_248 -&gt; p_247 [label=&quot;&quot;];
p_247 [label=&quot;Unroll ([eval_guard (List.hd (List.tl (List.take 5 …)))\l         (Destruct(Or, 0, (Option.get …).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_247 -&gt; p_246 [label=&quot;&quot;];
p_246 [label=&quot;Unroll ([eval_guard … (Destruct(Or, 1, Destruct(Or, 1, ….guard)))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_246 -&gt; p_245 [label=&quot;&quot;];
p_245 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 …) in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : int list) = List.tl _x_1 in\l         let (_x_3 : int list) = List.tl _x_2 in\l         run\l         (step\l          (step (step (step (step … …) (List.hd _x_0)) (List.hd _x_1))\l           (List.hd _x_2))\l          (List.hd _x_3))\l         (List.tl _x_3)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_245 -&gt; p_244 [label=&quot;&quot;];
p_244 [label=&quot;Unsat&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-397ad744-8584-4b19-b348-281878234eed';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-7e018d69-e674-4d5f-9cbd-bb4e3892d95f';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-dc65f44e-ef83-47b3-9b96-ef229ce85156';
  fold.hydrate(target);
});
</script></div></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-5c84c78f-090d-487e-8b85-1367836501b2"><textarea style="display: none">digraph &quot;call graph&quot; {
goal [label=&quot;let (_x_0 : node_id list) = … :: … in\llet (_x_1 : (state * int list))\l    = run\l      \{wf_1 = A :: _x_0; wf_2 = D :: _x_0; sensor = None;\l       agents = mk_agents_map (… :: …);\l       policy = Map.of_list Sharable (… :: …); conflict = None\}\l      (List.take 5 sensors)\lin not (_x_1.0.conflict = None) &amp;&amp; (_x_1.1 = [])&quot;,shape=box,style=filled,color=&quot;cyan&quot;,fontname=&quot;courier&quot;,fontsize=14];
goal -&gt; call_127 [label=&quot;calls&quot;];
goal -&gt; call_66 [label=&quot;calls&quot;];
goal -&gt; call_163 [label=&quot;calls&quot;];
goal -&gt; call_153 [label=&quot;calls&quot;];
call_127 [label=&quot;mk_agents_map\l(\{agent_id = Node …; guard = Eq (…, 1); accesses = Apple\} ::\l (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_127 -&gt; call_1882 [label=&quot;calls&quot;];
call_66 [label=&quot;Map.of_list Sharable\l((Apple, Unsharable) :: ((…, Sharable) :: (… :: …)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_66 -&gt; call_2027 [label=&quot;calls&quot;];
call_163 [label=&quot;let (_x_0 : node_id list) = … :: … in\lrun\l\{wf_1 = A :: _x_0; wf_2 = D :: _x_0; sensor = None;\l agents = mk_agents_map (… :: …);\l policy = Map.of_list Sharable (… :: …); conflict = None\}\l(List.take 5 sensors)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_163 -&gt; call_1024 [label=&quot;calls&quot;];
call_163 -&gt; call_1008 [label=&quot;calls&quot;];
call_163 -&gt; call_1040 [label=&quot;calls&quot;];
call_153 [label=&quot;List.take 5 sensors&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_153 -&gt; call_1729 [label=&quot;calls&quot;];
call_1882 [label=&quot;mk_agents_map …&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1882 -&gt; call_2683 [label=&quot;calls&quot;];
call_2027 [label=&quot;Map.of_list Sharable …&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2027 -&gt; call_2785 [label=&quot;calls&quot;];
call_1024 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Option.get (Map.get' (mk_agents_map (… :: …)) D)).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1024 -&gt; call_2213 [label=&quot;calls&quot;];
call_1024 -&gt; call_2211 [label=&quot;calls&quot;];
call_1008 [label=&quot;let (_x_0 : node_id list) = … :: … in\llet (_x_1 : int list) = List.take 5 sensors in\lrun\l(step\l \{wf_1 = A :: _x_0; wf_2 = D :: _x_0; sensor = None;\l  agents = mk_agents_map (… :: …);\l  policy = Map.of_list Sharable (… :: …); conflict = None\}\l (List.hd _x_1))\l(List.tl _x_1)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1008 -&gt; call_3905 [label=&quot;calls&quot;];
call_1008 -&gt; call_3890 [label=&quot;calls&quot;];
call_1008 -&gt; call_3900 [label=&quot;calls&quot;];
call_1040 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Option.get (Map.get' (mk_agents_map (… :: …)) A)).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1040 -&gt; call_3196 [label=&quot;calls&quot;];
call_1040 -&gt; call_3194 [label=&quot;calls&quot;];
call_1729 [label=&quot;List.take 4 (List.tl sensors)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1729 -&gt; call_2528 [label=&quot;calls&quot;];
call_2683 [label=&quot;mk_agents_map\l(\{agent_id = Node …; guard = Eq (…, 3); accesses = Orange\} ::\l (\{agent_id = …; guard = …; accesses = Orange\} :: (… :: …)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2683 -&gt; call_2964 [label=&quot;calls&quot;];
call_2785 [label=&quot;Map.of_list Sharable [(Orange, Sharable)]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2785 -&gt; call_3471 [label=&quot;calls&quot;];
call_2213 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, (Option.get (Map.get' (mk_agents_map (… :: …)) D)).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2213 -&gt; call_5413 [label=&quot;calls&quot;];
call_2213 -&gt; call_5411 [label=&quot;calls&quot;];
call_2211 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, (Option.get (Map.get' (mk_agents_map (… :: …)) D)).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2211 -&gt; call_7125 [label=&quot;calls&quot;];
call_2211 -&gt; call_7123 [label=&quot;calls&quot;];
call_3905 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : node_id list) = … :: … in\llet (_x_2 : state)\l    = step\l      \{wf_1 = A :: _x_1; wf_2 = D :: _x_1; sensor = None;\l       agents = mk_agents_map (… :: …);\l       policy = Map.of_list Sharable (… :: …); conflict = None\}\l      (List.hd _x_0)\lin\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3905 -&gt; call_7980 [label=&quot;calls&quot;];
call_3905 -&gt; call_7978 [label=&quot;calls&quot;];
call_3890 [label=&quot;let (_x_0 : node_id list) = … :: … in\llet (_x_1 : int list) = List.take 5 sensors in\llet (_x_2 : int list) = List.tl _x_1 in\lrun\l(step\l (step\l  \{wf_1 = A :: _x_0; wf_2 = D :: _x_0; sensor = None;\l   agents = mk_agents_map (… :: …);\l   policy = Map.of_list Sharable (… :: …); conflict = None\}\l  (List.hd _x_1))\l (List.hd _x_2))\l(List.tl _x_2)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3890 -&gt; call_8440 [label=&quot;calls&quot;];
call_3890 -&gt; call_8450 [label=&quot;calls&quot;];
call_3890 -&gt; call_8455 [label=&quot;calls&quot;];
call_3900 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : node_id list) = … :: … in\llet (_x_2 : state)\l    = step\l      \{wf_1 = A :: _x_1; wf_2 = D :: _x_1; sensor = None;\l       agents = mk_agents_map (… :: …);\l       policy = Map.of_list Sharable (… :: …); conflict = None\}\l      (List.hd _x_0)\lin\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3900 -&gt; call_7616 [label=&quot;calls&quot;];
call_3900 -&gt; call_7618 [label=&quot;calls&quot;];
call_3196 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, (Option.get (Map.get' (mk_agents_map (… :: …)) A)).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3196 -&gt; call_10564 [label=&quot;calls&quot;];
call_3196 -&gt; call_10566 [label=&quot;calls&quot;];
call_3194 [label=&quot;eval_guard … (Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3194 -&gt; call_15126 [label=&quot;calls&quot;];
call_3194 -&gt; call_15128 [label=&quot;calls&quot;];
call_2528 [label=&quot;List.take 3 (List.tl (List.tl sensors))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2528 -&gt; call_5784 [label=&quot;calls&quot;];
call_2964 [label=&quot;mk_agents_map\l(\{agent_id = …; guard = …; accesses = Orange\} :: (… :: …))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2964 -&gt; call_3707 [label=&quot;calls&quot;];
call_3471 [label=&quot;Map.of_list Sharable []&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3471 -&gt; call_5214 [label=&quot;calls&quot;];
call_5413 [label=&quot;eval_guard … (Destruct(Or, 1, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5413 -&gt; call_24516 [label=&quot;calls&quot;];
call_5413 -&gt; call_24514 [label=&quot;calls&quot;];
call_5411 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_7125 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_7123 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 0, …)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_7980 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_7978 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 …)))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_7978 -&gt; call_23975 [label=&quot;calls&quot;];
call_7978 -&gt; call_23977 [label=&quot;calls&quot;];
call_8440 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 …) in\llet (_x_1 : int list) = List.tl _x_0 in\lrun (step (step (step … …) (List.hd _x_0)) (List.hd _x_1)) (List.tl _x_1)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_8440 -&gt; call_12612 [label=&quot;calls&quot;];
call_8440 -&gt; call_12602 [label=&quot;calls&quot;];
call_8440 -&gt; call_12617 [label=&quot;calls&quot;];
call_8450 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : node_id list) = … :: … in\llet (_x_3 : state)\l    = step\l      (step\l       \{wf_1 = A :: _x_2; wf_2 = D :: _x_2; sensor = None;\l        agents = mk_agents_map (… :: …);\l        policy = Map.of_list Sharable (… :: …); conflict = None\}\l       (List.hd _x_0))\l      (List.hd _x_1)\lin\leval_guard (List.hd (List.tl _x_1))\l(Option.get (Map.get' _x_3.agents (List.hd _x_3.wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_8450 -&gt; call_10961 [label=&quot;calls&quot;];
call_8450 -&gt; call_10959 [label=&quot;calls&quot;];
call_8455 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : node_id list) = … :: … in\llet (_x_3 : state)\l    = step\l      (step\l       \{wf_1 = A :: _x_2; wf_2 = D :: _x_2; sensor = None;\l        agents = mk_agents_map (… :: …);\l        policy = Map.of_list Sharable (… :: …); conflict = None\}\l       (List.hd _x_0))\l      (List.hd _x_1)\lin\leval_guard (List.hd (List.tl _x_1))\l(Option.get (Map.get' _x_3.agents (List.hd _x_3.wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_8455 -&gt; call_11569 [label=&quot;calls&quot;];
call_8455 -&gt; call_11567 [label=&quot;calls&quot;];
call_7616 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 …)))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_7616 -&gt; call_23634 [label=&quot;calls&quot;];
call_7616 -&gt; call_23632 [label=&quot;calls&quot;];
call_7618 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_10564 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_10566 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_15126 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_15128 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5784 [label=&quot;List.take 2 (List.tl (List.tl (List.tl sensors)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5784 -&gt; call_9908 [label=&quot;calls&quot;];
call_3707 [label=&quot;mk_agents_map (… :: …)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3707 -&gt; call_5970 [label=&quot;calls&quot;];
call_5214 [label=&quot;Map.of_list Sharable (List.tl [])&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5214 -&gt; call_18627 [label=&quot;calls&quot;];
call_24516 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, Destruct(Or, 1, Destruct(Or, 1, ….guard))))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_24514 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 1, Destruct(Or, 1, …))))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_23975 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, Destruct(Or, 0, (Option.get …).guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_23977 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_12612 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 …) in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : state) = step (step (step … …) (List.hd _x_0)) (List.hd _x_1)\lin\leval_guard (List.hd (List.tl _x_1))\l(Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_12612 -&gt; call_15355 [label=&quot;calls&quot;];
call_12612 -&gt; call_15353 [label=&quot;calls&quot;];
call_12602 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 …) in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : int list) = List.tl _x_1 in\lrun\l(step (step (step (step … …) (List.hd _x_0)) (List.hd _x_1))\l (List.hd _x_2))\l(List.tl _x_2)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_12602 -&gt; call_16497 [label=&quot;calls&quot;];
call_12602 -&gt; call_16492 [label=&quot;calls&quot;];
call_12602 -&gt; call_16482 [label=&quot;calls&quot;];
call_12617 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 …) in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : state) = step (step (step … …) (List.hd _x_0)) (List.hd _x_1)\lin\leval_guard (List.hd (List.tl _x_1))\l(Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_12617 -&gt; call_15185 [label=&quot;calls&quot;];
call_12617 -&gt; call_15181 [label=&quot;calls&quot;];
call_10961 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_10959 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_11569 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_11567 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_23634 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_23632 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_9908 [label=&quot;List.take 1 (List.tl (List.tl (List.tl (List.tl …))))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_9908 -&gt; call_14236 [label=&quot;calls&quot;];
call_5970 [label=&quot;mk_agents_map …&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5970 -&gt; call_6419 [label=&quot;calls&quot;];
call_18627 [label=&quot;Map.of_list Sharable (List.tl (List.tl []))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_15355 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_15353 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_16497 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 …) in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : int list) = List.tl _x_1 in\llet (_x_3 : state)\l    = step (step (step (step … …) (List.hd _x_0)) (List.hd _x_1))\l      (List.hd _x_2)\lin\leval_guard (List.hd (List.tl _x_2))\l(Option.get (Map.get' _x_3.agents (List.hd _x_3.wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_16497 -&gt; call_19691 [label=&quot;calls&quot;];
call_16497 -&gt; call_19690 [label=&quot;calls&quot;];
call_16492 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 …) in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : int list) = List.tl _x_1 in\llet (_x_3 : state)\l    = step (step (step (step … …) (List.hd _x_0)) (List.hd _x_1))\l      (List.hd _x_2)\lin\leval_guard (List.hd (List.tl _x_2))\l(Option.get (Map.get' _x_3.agents (List.hd _x_3.wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_16492 -&gt; call_19188 [label=&quot;calls&quot;];
call_16492 -&gt; call_19186 [label=&quot;calls&quot;];
call_16482 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 …) in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : int list) = List.tl _x_1 in\llet (_x_3 : int list) = List.tl _x_2 in\lrun\l(step\l (step (step (step (step … …) (List.hd _x_0)) (List.hd _x_1))\l  (List.hd _x_2))\l (List.hd _x_3))\l(List.tl _x_3)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_16482 -&gt; call_24752 [label=&quot;calls&quot;];
call_16482 -&gt; call_24742 [label=&quot;calls&quot;];
call_16482 -&gt; call_24757 [label=&quot;calls&quot;];
call_15185 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_15181 [label=&quot;eval_guard … (Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_14236 [label=&quot;List.take 0 (List.tl (List.tl (List.tl (List.tl (List.tl …)))))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_14236 -&gt; call_17361 [label=&quot;calls&quot;];
call_6419 [label=&quot;mk_agents_map []&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6419 -&gt; call_6796 [label=&quot;calls&quot;];
call_19691 [label=&quot;eval_guard\l(List.hd (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors))))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_19690 [label=&quot;eval_guard\l(List.hd (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors))))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_19188 [label=&quot;eval_guard\l(List.hd (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors))))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_19186 [label=&quot;eval_guard\l(List.hd (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors))))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_24752 [label=&quot;eval_guard\l(List.hd\l (List.tl (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors)))))))\l(Option.get (Map.get' ….agents (List.hd ….wf_2))).guard&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_24742 [label=&quot;let (_x_0 : int list)\l    = List.tl (List.tl (List.tl (List.tl (List.take 5 sensors))))\lin\llet (_x_1 : int list) = List.tl _x_0 in\lrun (step (step (step … …) (List.hd _x_0)) (List.hd _x_1)) (List.tl _x_1)&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_24757 [label=&quot;eval_guard\l(List.hd\l (List.tl (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors)))))))\l(Option.get (Map.get' ….agents (List.hd ….wf_1))).guard&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_17361 [label=&quot;List.take (-1) …&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6796 [label=&quot;mk_agents_map (List.tl [])&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-5c84c78f-090d-487e-8b85-1367836501b2';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-d8808738-35e4-4e8b-b8f0-d0c7cc11adf2';
  alternatives.hydrate(target);
});
</script></div></div></div>



## This means no conflicts are possible for Problem 2!

Imandra has *proved* that this goal is unsatisfiable, i.e., that no such conflict is possible. In fact,
we can use Imandra's *verify* command to restate this as a safety property and prove it:


```ocaml
verify (fun sensors -> not (conflict_reachable ex_2 sensors))
```




    - : Z.t list -> bool = <fun>





<div><div style="font-size: 1.2em; padding: 0.5em; border-top: 1px solid green; border-bottom: 1px solid green"><i class="fa fa-check-circle" style="margin-right: 0.5em; color: green"></i><span>Proved</span></div><div><div class="imandra-alternatives" id="alt-224d02fb-fe2c-43fe-afb5-7a9c88450944"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>proof</a></li><li class="" data-toggle="tab"><a>call graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-proof-top"><div class="imandra-fold panel panel-default" id="fold-2ac57b98-c30c-45a8-a95c-266a779ce983"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>proof</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-c9239dc8-ec98-4f45-b97d-9e2a0884c2ec"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li><li class="" data-toggle="tab"><a>graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-0b1b8b4c-4481-45fc-93e4-6f3ba0dfc0aa"><table><tr><td>ground_instances:</td><td>38</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.776s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-5c284893-26e5-4b73-a8d0-15dca162c4c9"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-6dd37c5d-0054-4a43-a13d-8365028b5245"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-b0400a4f-c3bc-428e-a37c-9b2ae264d449"><table><tr><td>array def const:</td><td>2</td></tr><tr><td>num checks:</td><td>78</td></tr><tr><td>array sel const:</td><td>1154</td></tr><tr><td>array def store:</td><td>2238</td></tr><tr><td>array exp ax2:</td><td>3272</td></tr><tr><td>array splits:</td><td>1246</td></tr><tr><td>rlimit count:</td><td>3340081</td></tr><tr><td>array ext ax:</td><td>608</td></tr><tr><td>mk clause:</td><td>10001</td></tr><tr><td>array ax1:</td><td>11</td></tr><tr><td>datatype occurs check:</td><td>37365</td></tr><tr><td>restarts:</td><td>6</td></tr><tr><td>mk bool var:</td><td>132443</td></tr><tr><td>array ax2:</td><td>5751</td></tr><tr><td>datatype splits:</td><td>47670</td></tr><tr><td>decisions:</td><td>186847</td></tr><tr><td>propagations:</td><td>123283</td></tr><tr><td>conflicts:</td><td>1205</td></tr><tr><td>datatype accessor ax:</td><td>3241</td></tr><tr><td>minimized lits:</td><td>655</td></tr><tr><td>datatype constructor ax:</td><td>104470</td></tr><tr><td>num allocs:</td><td>1557465167</td></tr><tr><td>final checks:</td><td>949</td></tr><tr><td>added eqs:</td><td>608330</td></tr><tr><td>del clause:</td><td>8676</td></tr><tr><td>time:</td><td>0.001000</td></tr><tr><td>memory:</td><td>45.640000</td></tr><tr><td>max memory:</td><td>45.660000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-5c284893-26e5-4b73-a8d0-15dca162c4c9';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-f0d6fddb-6c0d-4f8b-8f9c-d0e49e1a7894"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.776s]
  let (_x_0 : (state * int list))
      = run
        {wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;
         conflict = …}
        (List.take … ( :var_0: ))
  in not (not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = []))</pre></li><li><div><h4>simplify</h4><div class="imandra-table" id="table-db6fc293-4d69-4c5c-a1ed-4b313978afb6"><table><tr><td>into:</td><td><pre>let (_x_0 : (state * int list))
    = run
      {wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;
       conflict = …}
      (List.take 5 ( :var_0: ))
in not (not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = []))</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-b3604f9a-e727-4b6b-a4d0-b77aba03fff0"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2696/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-97c03773-f879-4737-8a42-e2c70fbc767c"><table><tr><td>expr:</td><td><pre>(|List.take_2721/server| 5 sensors_1651/client)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-12595bd5-c71b-40c8-bad3-214ef56f59b9"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-5a276859-81e1-4bf0-a858-b52ccbbdd66e"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (tuple_mk_2706/server Apple_1528/client Unsharable_1535/client)
                 (|…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-e16fbe7a-9a0a-4e97-a8c9-33fa136dc422"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2696/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-bebc0669-96a7-40fa-b41d-7f208fae0403"><table><tr><td>expr:</td><td><pre>(|Map.of_list_2714/server|
  Sharable_1534/client
  (|::| (tuple_mk_2706/server Banana_1529/client S…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-67f72311-240c-4a39-9e64-c39ab21c3f04"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2696/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-66c494df-c08b-4bc6-8835-fd9e446d2155"><table><tr><td>expr:</td><td><pre>(|Map.of_list_2714/server|
  Sharable_1534/client
  (|::| (tuple_mk_2706/server Orange_1530/client S…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-7997f368-9ddc-4eca-83ac-8bfc730113a0"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2696/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-4590821e-9475-45e5-8b1d-b2e2f7cf935f"><table><tr><td>expr:</td><td><pre>(|List.take_2721/server| 4 (|get.::.1_2689/server| sensors_1651/client))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-a7de0376-bd27-4fc6-bf87-56c502acb4ca"><table><tr><td>expr:</td><td><pre>(|Map.of_list_2714/server| Sharable_1534/client |[]|)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-74837145-a42e-4fe2-b566-5f6ad8821980"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2696/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-9bc3a0c7-ef9d-4243-b466-ee11747f122f"><table><tr><td>expr:</td><td><pre>(mk_agents_map_1621/client
  (|::| (|rec_mk.agent_2696/server|
          (Node_1502/client F_1508/cl…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-5d5d1d33-8cb0-42b4-a594-ad0f2b6df1fd"><table><tr><td>expr:</td><td><pre>(mk_agents_map_1621/client |[]|)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-6a7c0dbd-18d5-494c-b7f6-91057849d8e2"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2696/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-031071ba-2a8d-4ba1-8d5d-a9dc311fbd1a"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2696/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-371c8308-75ab-4956-a3db-a6ee1605d805"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-2ec2aa78-a77d-4f7b-8d08-f26f197c8edc"><table><tr><td>expr:</td><td><pre>(|List.take_2721/server|
  3
  (|get.::.1_2689/server| (|get.::.1_2689/server| sensors_1651/client))…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-90445b65-842c-4b89-ab25-9bd9aa5b3ac9"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-81c678cc-faf9-4ffe-9638-3ca508af2dcb"><table><tr><td>expr:</td><td><pre>(|Map.of_list_2714/server| Sharable_1534/client (|get.::.1_2711/server| |[]|))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-348e7476-1083-4d9d-b536-8734ee6189d7"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-8bc14664-cd98-4c93-aab2-e377605592fc"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-339e6389-c0b1-4200-afdc-0ac4b3290497"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.0_2688/server|
             (|get.::.1_2689/server|
               (|get.::.1_26…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-64c9b504-b248-42d1-a40d-6c997c718348"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.0_2688/server|
             (|get.::.1_2689/server|
               (|get.::.1_26…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-e33962ca-d00b-440b-8019-da8c5008bca8"><table><tr><td>expr:</td><td><pre>(mk_agents_map_1621/client (|get.::.1_2704/server| |[]|))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-b045322a-df4d-4423-97f1-8b1ab18574eb"><table><tr><td>expr:</td><td><pre>(|List.take_2721/server|
  2
  (|get.::.1_2689/server|
    (|get.::.1_2689/server| (|get.::.1_2689/s…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-4adb90e3-b801-4e1d-ab6e-2c6c68a6e808"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-aff3489f-36f2-40ab-90a8-3f79c9e84a66"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_2689/server|
             (|get.::.1_2689/server|
               (|get.::.1_26…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-c3be50a2-45e1-4706-a0c9-a37df5865290"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.0_2688/server|
             (|get.::.1_2689/server|
               (|get.::.1_26…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-94db26cc-4de2-40a0-8dd7-e3acb8c7bb45"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2696/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-1f0f7aa6-345c-42bf-aa09-48c52189c01b"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_2689/server|
             (|get.::.1_2689/server|
               (|get.::.1_26…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-e936c228-56b5-45b1-9915-d555dfedb288"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_2689/server|
             (|get.::.1_2689/server|
               (|get.::.1_26…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-f4ac38bc-a829-4d69-886b-e58ace81f364"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-27a7b72f-b4fa-48b6-bf12-fd7d5c698c60"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_2689/server|
             (|get.::.1_2689/server|
               (|get.::.1_26…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-b02f20d8-7099-4c65-ac53-4d954515183e"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_2696/server|
                   (Node_1502/client E_1507/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-3ccad054-ac32-45d7-a166-bc2e28ec5561"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_2689/server|
             (|get.::.1_2689/server|
               (|get.::.1_26…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-5f8bc857-eec7-4fce-8925-e8ddbacd270d"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_2689/server|
             (|get.::.1_2689/server|
               (|get.::.1_26…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-12f7b8d5-efc3-4a30-b0c4-e1127e7b3ce8"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li>Unsat</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-f0d6fddb-6c0d-4f8b-8f9c-d0e49e1a7894';
  fold.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-5e7c948b-e32a-465f-ad51-69cd34ced934"><textarea style="display: none">digraph &quot;proof&quot; {
p_328 [label=&quot;Start (let (_x_0 : (state * int list))\l           = run\l             \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l              policy = …; conflict = …\}\l             (List.take … ( :var_0: ))\l       in not (not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = [])) :time 0.776s)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_328 -&gt; p_327 [label=&quot;&quot;];
p_327 [label=&quot;Simplify (let (_x_0 : (state * int list))\l              = run\l                \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l                 policy = …; conflict = …\}\l                (List.take 5 ( :var_0: ))\l          in not (not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = []))\l          :expansions [] :rw [] :fc [])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_327 -&gt; p_326 [label=&quot;&quot;];
p_326 [label=&quot;Unroll ([mk_agents_map\l         (\{agent_id = Node …; guard = Eq (…, 1); accesses = Apple\} ::\l          (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_326 -&gt; p_325 [label=&quot;&quot;];
p_325 [label=&quot;Unroll ([List.take 5 sensors], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_325 -&gt; p_324 [label=&quot;&quot;];
p_324 [label=&quot;Unroll ([run\l         \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l          conflict = …\}\l         (List.take 5 sensors)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_324 -&gt; p_323 [label=&quot;&quot;];
p_323 [label=&quot;Unroll ([Map.of_list Sharable\l         ((Apple, Unsharable) :: ((…, Sharable) :: (… :: …)))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_323 -&gt; p_322 [label=&quot;&quot;];
p_322 [label=&quot;Unroll ([mk_agents_map\l         (\{agent_id = Node …; guard = Eq (…, 2); accesses = Banana\} ::\l          (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_322 -&gt; p_321 [label=&quot;&quot;];
p_321 [label=&quot;Unroll ([Map.of_list Sharable [(Banana, Sharable); (…, Sharable)]], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_321 -&gt; p_320 [label=&quot;&quot;];
p_320 [label=&quot;Unroll ([mk_agents_map\l         (\{agent_id = …; guard = …; accesses = …\} :: (… :: …))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_320 -&gt; p_319 [label=&quot;&quot;];
p_319 [label=&quot;Unroll ([Map.of_list Sharable [(…, Sharable)]], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_319 -&gt; p_318 [label=&quot;&quot;];
p_318 [label=&quot;Unroll ([mk_agents_map (… :: …)], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_318 -&gt; p_317 [label=&quot;&quot;];
p_317 [label=&quot;Unroll ([List.take 4 (List.tl sensors)], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_317 -&gt; p_316 [label=&quot;&quot;];
p_316 [label=&quot;Unroll ([Map.of_list Sharable []], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_316 -&gt; p_315 [label=&quot;&quot;];
p_315 [label=&quot;Unroll ([mk_agents_map …], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_315 -&gt; p_314 [label=&quot;&quot;];
p_314 [label=&quot;Unroll ([mk_agents_map [\{agent_id = Node …; guard = …; accesses = Apple\}]],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_314 -&gt; p_313 [label=&quot;&quot;];
p_313 [label=&quot;Unroll ([mk_agents_map []], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_313 -&gt; p_312 [label=&quot;&quot;];
p_312 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Option.get (Map.get' … D)).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_312 -&gt; p_311 [label=&quot;&quot;];
p_311 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Option.get (Map.get' … A)).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_311 -&gt; p_310 [label=&quot;&quot;];
p_310 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         run\l         (step\l          \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l           conflict = …\}\l          (List.hd _x_0))\l         (List.tl _x_0)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_310 -&gt; p_309 [label=&quot;&quot;];
p_309 [label=&quot;Unroll ([List.take 3 (List.tl (List.tl sensors))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_309 -&gt; p_308 [label=&quot;&quot;];
p_308 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         let (_x_1 : state)\l             = step\l               \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l                policy = …; conflict = …\}\l               (List.hd _x_0)\l         in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_308 -&gt; p_307 [label=&quot;&quot;];
p_307 [label=&quot;Unroll ([Map.of_list Sharable (List.tl [])], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_307 -&gt; p_306 [label=&quot;&quot;];
p_306 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         let (_x_1 : state)\l             = step\l               \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l                policy = …; conflict = …\}\l               (List.hd _x_0)\l         in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_306 -&gt; p_305 [label=&quot;&quot;];
p_305 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         let (_x_1 : int list) = List.tl _x_0 in\l         run\l         (step\l          (step\l           \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l            conflict = …\}\l           (List.hd _x_0))\l          (List.hd _x_1))\l         (List.tl _x_1)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_305 -&gt; p_304 [label=&quot;&quot;];
p_304 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : state)\l             = step\l               (step\l                \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l                 policy = …; conflict = …\}\l                (List.hd _x_0))\l               (List.hd _x_1)\l         in\l         eval_guard (List.hd (List.tl _x_1))\l         (Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_304 -&gt; p_303 [label=&quot;&quot;];
p_303 [label=&quot;Unroll ([eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l         (Option.get (Map.get' ….agents (List.hd ….wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_303 -&gt; p_302 [label=&quot;&quot;];
p_302 [label=&quot;Unroll ([mk_agents_map (List.tl [])], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_302 -&gt; p_301 [label=&quot;&quot;];
p_301 [label=&quot;Unroll ([List.take 2 (List.tl (List.tl (List.tl sensors)))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_301 -&gt; p_300 [label=&quot;&quot;];
p_300 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\l         run (step … (List.hd _x_0)) (List.tl _x_0)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_300 -&gt; p_299 [label=&quot;&quot;];
p_299 [label=&quot;Unroll ([List.take 1 (List.tl (List.tl (List.tl (List.tl sensors))))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_299 -&gt; p_298 [label=&quot;&quot;];
p_298 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : state)\l             = step\l               (step\l                \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l                 policy = …; conflict = …\}\l                (List.hd _x_0))\l               (List.hd _x_1)\l         in\l         eval_guard (List.hd (List.tl _x_1))\l         (Destruct(Or, 0,\l                   (Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_1))).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_298 -&gt; p_297 [label=&quot;&quot;];
p_297 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 0, (Option.get …).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_297 -&gt; p_296 [label=&quot;&quot;];
p_296 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\l         let (_x_1 : state) = step … (List.hd _x_0) in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_296 -&gt; p_295 [label=&quot;&quot;];
p_295 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\l         let (_x_1 : state) = step … (List.hd _x_0) in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_295 -&gt; p_294 [label=&quot;&quot;];
p_294 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\l         let (_x_1 : int list) = List.tl _x_0 in\l         run (step (step … (List.hd _x_0)) (List.hd _x_1)) (List.tl _x_1)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_294 -&gt; p_293 [label=&quot;&quot;];
p_293 [label=&quot;Unroll ([List.take 0\l         (List.tl (List.tl (List.tl (List.tl (List.tl sensors)))))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_293 -&gt; p_292 [label=&quot;&quot;];
p_292 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 1, (Option.get …).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_292 -&gt; p_291 [label=&quot;&quot;];
p_291 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : state) = step (step … (List.hd _x_0)) (List.hd _x_1)\l         in\l         eval_guard (List.hd (List.tl _x_1))\l         (Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_291 -&gt; p_290 [label=&quot;&quot;];
p_290 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : state) = step (step … (List.hd _x_0)) (List.hd _x_1)\l         in\l         eval_guard (List.hd (List.tl _x_1))\l         (Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_290 -&gt; p_289 [label=&quot;&quot;];
p_289 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : int list) = List.tl _x_1 in\l         run\l         (step (step (step … (List.hd _x_0)) (List.hd _x_1)) (List.hd _x_2))\l         (List.tl _x_2)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_289 -&gt; p_288 [label=&quot;&quot;];
p_288 [label=&quot;Unsat&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-5e7c948b-e32a-465f-ad51-69cd34ced934';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-c9239dc8-ec98-4f45-b97d-9e2a0884c2ec';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-2ac57b98-c30c-45a8-a95c-266a779ce983';
  fold.hydrate(target);
});
</script></div></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-183cdb8c-7d02-427e-9a48-7d1d0c154a8b"><textarea style="display: none">digraph &quot;call graph&quot; {
goal [label=&quot;let (_x_0 : (state * int list))\l    = run\l      \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l       conflict = …\}\l      (List.take 5 sensors)\lin not (_x_0.0.conflict = None) &amp;&amp; (_x_0.1 = [])&quot;,shape=box,style=filled,color=&quot;cyan&quot;,fontname=&quot;courier&quot;,fontsize=14];
goal -&gt; call_123 [label=&quot;calls&quot;];
goal -&gt; call_128 [label=&quot;calls&quot;];
goal -&gt; call_129 [label=&quot;calls&quot;];
goal -&gt; call_67 [label=&quot;calls&quot;];
call_123 [label=&quot;run\l\{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l conflict = …\}\l(List.take 5 sensors)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_123 -&gt; call_1215 [label=&quot;calls&quot;];
call_123 -&gt; call_1247 [label=&quot;calls&quot;];
call_123 -&gt; call_1231 [label=&quot;calls&quot;];
call_128 [label=&quot;List.take 5 sensors&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_128 -&gt; call_1067 [label=&quot;calls&quot;];
call_129 [label=&quot;mk_agents_map\l(\{agent_id = Node …; guard = Eq (…, 1); accesses = Apple\} ::\l (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_129 -&gt; call_958 [label=&quot;calls&quot;];
call_67 [label=&quot;Map.of_list Sharable\l((Apple, Unsharable) :: ((…, Sharable) :: (… :: …)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_67 -&gt; call_1968 [label=&quot;calls&quot;];
call_1215 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\lrun\l(step\l \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l  conflict = …\}\l (List.hd _x_0))\l(List.tl _x_0)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1215 -&gt; call_4871 [label=&quot;calls&quot;];
call_1215 -&gt; call_4881 [label=&quot;calls&quot;];
call_1215 -&gt; call_4886 [label=&quot;calls&quot;];
call_1247 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Option.get (Map.get' … A)).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1247 -&gt; call_4682 [label=&quot;calls&quot;];
call_1247 -&gt; call_4684 [label=&quot;calls&quot;];
call_1231 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Option.get (Map.get' … D)).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1231 -&gt; call_1054 [label=&quot;calls&quot;];
call_1231 -&gt; call_125 [label=&quot;calls&quot;];
call_1067 [label=&quot;List.take 4 (List.tl sensors)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1067 -&gt; call_3534 [label=&quot;calls&quot;];
call_958 [label=&quot;mk_agents_map\l(\{agent_id = Node …; guard = Eq (…, 2); accesses = Banana\} ::\l (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_958 -&gt; call_2164 [label=&quot;calls&quot;];
call_1968 [label=&quot;Map.of_list Sharable [(Banana, Sharable); (…, Sharable)]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1968 -&gt; call_2312 [label=&quot;calls&quot;];
call_4871 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : int list) = List.tl _x_0 in\lrun\l(step\l (step\l  \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l   conflict = …\}\l  (List.hd _x_0))\l (List.hd _x_1))\l(List.tl _x_1)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4871 -&gt; call_6802 [label=&quot;calls&quot;];
call_4871 -&gt; call_6792 [label=&quot;calls&quot;];
call_4871 -&gt; call_6807 [label=&quot;calls&quot;];
call_4881 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : state)\l    = step\l      \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l       conflict = …\}\l      (List.hd _x_0)\lin\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4881 -&gt; call_6182 [label=&quot;calls&quot;];
call_4881 -&gt; call_6180 [label=&quot;calls&quot;];
call_4886 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : state)\l    = step\l      \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l       conflict = …\}\l      (List.hd _x_0)\lin\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4886 -&gt; call_6490 [label=&quot;calls&quot;];
call_4886 -&gt; call_6492 [label=&quot;calls&quot;];
call_4682 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4684 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1054 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1054 -&gt; call_15636 [label=&quot;calls&quot;];
call_1054 -&gt; call_15634 [label=&quot;calls&quot;];
call_125 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_125 -&gt; call_930 [label=&quot;calls&quot;];
call_125 -&gt; call_8231 [label=&quot;calls&quot;];
call_3534 [label=&quot;List.take 3 (List.tl (List.tl sensors))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3534 -&gt; call_5857 [label=&quot;calls&quot;];
call_2164 [label=&quot;mk_agents_map (\{agent_id = …; guard = …; accesses = …\} :: (… :: …))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2164 -&gt; call_2523 [label=&quot;calls&quot;];
call_2312 [label=&quot;Map.of_list Sharable [(…, Sharable)]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2312 -&gt; call_2765 [label=&quot;calls&quot;];
call_6802 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Option.get (Map.get' ….agents (List.hd ….wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6802 -&gt; call_8542 [label=&quot;calls&quot;];
call_6802 -&gt; call_8544 [label=&quot;calls&quot;];
call_6792 [label=&quot;let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\lrun (step … (List.hd _x_0)) (List.tl _x_0)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6792 -&gt; call_12395 [label=&quot;calls&quot;];
call_6792 -&gt; call_12390 [label=&quot;calls&quot;];
call_6792 -&gt; call_12380 [label=&quot;calls&quot;];
call_6807 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : state)\l    = step\l      (step\l       \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l        conflict = …\}\l       (List.hd _x_0))\l      (List.hd _x_1)\lin\leval_guard (List.hd (List.tl _x_1))\l(Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6807 -&gt; call_8236 [label=&quot;calls&quot;];
call_6807 -&gt; call_8238 [label=&quot;calls&quot;];
call_6182 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6180 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6490 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6492 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_15636 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_15634 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_930 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_8231 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5857 [label=&quot;List.take 2 (List.tl (List.tl (List.tl sensors)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5857 -&gt; call_9638 [label=&quot;calls&quot;];
call_2523 [label=&quot;mk_agents_map (… :: …)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2523 -&gt; call_3174 [label=&quot;calls&quot;];
call_2765 [label=&quot;Map.of_list Sharable []&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2765 -&gt; call_3918 [label=&quot;calls&quot;];
call_8542 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_8544 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_12395 [label=&quot;let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\llet (_x_1 : state) = step … (List.hd _x_0) in\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_12395 -&gt; call_24531 [label=&quot;calls&quot;];
call_12395 -&gt; call_24533 [label=&quot;calls&quot;];
call_12390 [label=&quot;let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\llet (_x_1 : state) = step … (List.hd _x_0) in\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_12390 -&gt; call_24301 [label=&quot;calls&quot;];
call_12390 -&gt; call_24299 [label=&quot;calls&quot;];
call_12380 [label=&quot;let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\llet (_x_1 : int list) = List.tl _x_0 in\lrun (step (step … (List.hd _x_0)) (List.hd _x_1)) (List.tl _x_1)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_12380 -&gt; call_25173 [label=&quot;calls&quot;];
call_12380 -&gt; call_25183 [label=&quot;calls&quot;];
call_12380 -&gt; call_25188 [label=&quot;calls&quot;];
call_8236 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : state)\l    = step\l      (step\l       \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l        conflict = …\}\l       (List.hd _x_0))\l      (List.hd _x_1)\lin\leval_guard (List.hd (List.tl _x_1))\l(Destruct(Or, 0,\l          (Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_1))).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_8236 -&gt; call_15263 [label=&quot;calls&quot;];
call_8236 -&gt; call_15265 [label=&quot;calls&quot;];
call_8238 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : state)\l    = step\l      (step\l       \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l        conflict = …\}\l       (List.hd _x_0))\l      (List.hd _x_1)\lin\leval_guard (List.hd (List.tl _x_1))\l(Destruct(Or, 1,\l          (Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_1))).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_9638 [label=&quot;List.take 1 (List.tl (List.tl (List.tl (List.tl sensors))))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_9638 -&gt; call_14226 [label=&quot;calls&quot;];
call_3174 [label=&quot;mk_agents_map …&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3174 -&gt; call_4188 [label=&quot;calls&quot;];
call_3918 [label=&quot;Map.of_list Sharable (List.tl [])&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3918 -&gt; call_6335 [label=&quot;calls&quot;];
call_24531 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_24533 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_24301 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_24299 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_25173 [label=&quot;let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : int list) = List.tl _x_1 in\lrun (step (step (step … (List.hd _x_0)) (List.hd _x_1)) (List.hd _x_2))\l(List.tl _x_2)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_25173 -&gt; call_29224 [label=&quot;calls&quot;];
call_25173 -&gt; call_29229 [label=&quot;calls&quot;];
call_25173 -&gt; call_29214 [label=&quot;calls&quot;];
call_25183 [label=&quot;let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : state) = step (step … (List.hd _x_0)) (List.hd _x_1) in\leval_guard (List.hd (List.tl _x_1))\l(Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_25183 -&gt; call_26994 [label=&quot;calls&quot;];
call_25183 -&gt; call_26996 [label=&quot;calls&quot;];
call_25188 [label=&quot;let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : state) = step (step … (List.hd _x_0)) (List.hd _x_1) in\leval_guard (List.hd (List.tl _x_1))\l(Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_25188 -&gt; call_26627 [label=&quot;calls&quot;];
call_25188 -&gt; call_26629 [label=&quot;calls&quot;];
call_15263 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : state)\l    = step\l      (step\l       \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l        conflict = …\}\l       (List.hd _x_0))\l      (List.hd _x_1)\lin\leval_guard (List.hd (List.tl _x_1))\l(Destruct(Or, 0,\l          Destruct(Or, 0,\l                   (Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_1))).guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_15265 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : state)\l    = step\l      (step\l       \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l        conflict = …\}\l       (List.hd _x_0))\l      (List.hd _x_1)\lin\leval_guard (List.hd (List.tl _x_1))\l(Destruct(Or, 1,\l          Destruct(Or, 0,\l                   (Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_1))).guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_14226 [label=&quot;List.take 0 (List.tl (List.tl (List.tl (List.tl (List.tl sensors)))))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_14226 -&gt; call_26145 [label=&quot;calls&quot;];
call_4188 [label=&quot;mk_agents_map [\{agent_id = Node …; guard = …; accesses = Apple\}]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4188 -&gt; call_4092 [label=&quot;calls&quot;];
call_6335 [label=&quot;Map.of_list Sharable (List.tl (List.tl []))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_29224 [label=&quot;let (_x_0 : int list) = List.tl (List.tl (List.tl (List.take 5 sensors))) in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : state) = step (step … (List.hd _x_0)) (List.hd _x_1) in\leval_guard (List.hd (List.tl _x_1))\l(Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_2))).guard&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_29229 [label=&quot;let (_x_0 : int list) = List.tl (List.tl (List.tl (List.take 5 sensors))) in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : state) = step (step … (List.hd _x_0)) (List.hd _x_1) in\leval_guard (List.hd (List.tl _x_1))\l(Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_1))).guard&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_29214 [label=&quot;let (_x_0 : int list) = List.tl (List.tl (List.tl (List.take 5 sensors))) in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : int list) = List.tl _x_1 in\lrun (step (step (step … (List.hd _x_0)) (List.hd _x_1)) (List.hd _x_2))\l(List.tl _x_2)&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_26994 [label=&quot;eval_guard\l(List.hd (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors))))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_26996 [label=&quot;eval_guard\l(List.hd (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors))))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_26627 [label=&quot;eval_guard\l(List.hd (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors))))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_26629 [label=&quot;eval_guard\l(List.hd (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors))))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_26145 [label=&quot;List.take (-1)\l(List.tl (List.tl (List.tl (List.tl (List.tl (List.tl sensors))))))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4092 [label=&quot;mk_agents_map []&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4092 -&gt; call_4282 [label=&quot;calls&quot;];
call_4282 [label=&quot;mk_agents_map (List.tl [])&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4282 -&gt; call_9203 [label=&quot;calls&quot;];
call_9203 [label=&quot;mk_agents_map (List.tl (List.tl []))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-183cdb8c-7d02-427e-9a48-7d1d0c154a8b';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-224d02fb-fe2c-43fe-afb5-7a9c88450944';
  alternatives.hydrate(target);
});
</script></div></div></div>



## Problem 3: the use of OR in guards

Finally, let's consider a problem in which we use the guard disjunctions (OR), which makes the search space quite a bit more complex.


```ocaml
(* Example 3 *)

let ex_3 = {
  work_flow_1 = [A; B; C; A];
  work_flow_2 = [D; E; F; D];

  agents=[

    {guard=Eq(Sensor, 1);
     agent_id=Node A;
     accesses=Apple};

    {guard=Eq(Sensor, 2);
     agent_id=Node B;
     accesses=Banana};

    {guard=Eq(Sensor, 3);
     agent_id=Node C;
     accesses=Orange};

    {guard=Or(Eq(Sensor, 1), Eq(Sensor, 2));
     agent_id=Node D;
     accesses=Orange};

    {guard=Or(Eq(Sensor, 2), Eq(Sensor, 3));
     agent_id=Node E;
     accesses=Banana};

    {guard=Or(Eq(Sensor, 3), Eq(Sensor, 1));
     agent_id=Node F;
     accesses=Apple};

  ];
  policy=(mk_policy
          [(Apple, Unsharable);
           (Banana, Sharable);
           (Orange, Sharable)]);
}
```




    val ex_3 : problem =
      {work_flow_1 = [A;B;C;A]; work_flow_2 = [D;E;F;D];
       agents =
        [{agent_id = Node A; guard = Eq (Sensor, 1); accesses = Apple};
         {agent_id = Node B; guard = Eq (Sensor, 2); accesses = Banana};
         {agent_id = Node C; guard = Eq (Sensor, 3); accesses = Orange};
         {agent_id = Node D; guard = Or (Eq (Sensor, 1), Eq (Sensor, 2));
          accesses = Orange};
         {agent_id = Node E; guard = Or (Eq (Sensor, 2), Eq (Sensor, 3));
          accesses = Banana};
         {agent_id = Node F; guard = Or (Eq (Sensor, 3), Eq (Sensor, 1));
          accesses = Apple}];
       policy = (Map.of_list ~default:Sharable [(Apple, Unsharable)])}





```ocaml
verify (fun sensors -> not (conflict_reachable ex_3 sensors))
```




    - : Z.t list -> bool = <fun>
    module CX : sig val sensors : Z.t list end





<div><pre>Counterexample (after 38 steps, 0.883s):
let sensors : int list = [2; 3; 1]
</pre></div>




<div><div style="font-size: 1.2em; padding: 0.5em; border-top: 1px dashed #D84315; border-bottom: 1px dashed #D84315"><i class="fa fa-times-circle-o" style="margin-right: 0.5em; color: #D84315"></i><span>Refuted</span></div><div><div class="imandra-alternatives" id="alt-d8652e3b-da9b-4cc6-b099-29bb4412aea0"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>call graph</a></li><li class="" data-toggle="tab"><a>proof</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-graphviz" id="graphviz-4e73ae06-650c-4969-8c13-f7c09682290f"><textarea style="display: none">digraph &quot;call graph&quot; {
goal [label=&quot;let (_x_0 : (state * int list))\l    = run\l      \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l       conflict = …\}\l      (List.take 5 sensors)\lin not (_x_0.0.conflict = None) &amp;&amp; (_x_0.1 = [])&quot;,shape=box,style=filled,color=&quot;cyan&quot;,fontname=&quot;courier&quot;,fontsize=14];
goal -&gt; call_158 [label=&quot;calls&quot;];
goal -&gt; call_126 [label=&quot;calls&quot;];
goal -&gt; call_70 [label=&quot;calls&quot;];
goal -&gt; call_132 [label=&quot;calls&quot;];
call_158 [label=&quot;List.take 5 sensors&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_158 -&gt; call_945 [label=&quot;calls&quot;];
call_126 [label=&quot;run\l\{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l conflict = …\}\l(List.take 5 sensors)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_126 -&gt; call_1215 [label=&quot;calls&quot;];
call_126 -&gt; call_1199 [label=&quot;calls&quot;];
call_126 -&gt; call_95 [label=&quot;calls&quot;];
call_70 [label=&quot;let (_x_0 : (resource * sharability)) = (…, Sharable) in\lMap.of_list Sharable [(Apple, Unsharable); _x_0; _x_0]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_70 -&gt; call_1914 [label=&quot;calls&quot;];
call_132 [label=&quot;mk_agents_map\l(\{agent_id = Node …; guard = Eq (…, 1); accesses = Apple\} ::\l (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_132 -&gt; call_1055 [label=&quot;calls&quot;];
call_945 [label=&quot;List.take 4 (List.tl sensors)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_945 -&gt; call_1989 [label=&quot;calls&quot;];
call_1215 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Option.get (Map.get' … A)).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1215 -&gt; call_4120 [label=&quot;calls&quot;];
call_1215 -&gt; call_4122 [label=&quot;calls&quot;];
call_1199 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Option.get (Map.get' … D)).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1199 -&gt; call_3043 [label=&quot;calls&quot;];
call_1199 -&gt; call_3045 [label=&quot;calls&quot;];
call_95 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\lrun\l(step\l \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l  conflict = …\}\l (List.hd _x_0))\l(List.tl _x_0)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_95 -&gt; call_4402 [label=&quot;calls&quot;];
call_95 -&gt; call_4407 [label=&quot;calls&quot;];
call_95 -&gt; call_4392 [label=&quot;calls&quot;];
call_1914 [label=&quot;Map.of_list Sharable [(Banana, Sharable); (…, Sharable)]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1914 -&gt; call_2361 [label=&quot;calls&quot;];
call_1055 [label=&quot;mk_agents_map\l(\{agent_id = Node …; guard = Eq (…, 2); accesses = Banana\} ::\l (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1055 -&gt; call_2261 [label=&quot;calls&quot;];
call_1989 [label=&quot;List.take 3 (List.tl (List.tl sensors))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1989 -&gt; call_5569 [label=&quot;calls&quot;];
call_4120 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4120 -&gt; call_25682 [label=&quot;calls&quot;];
call_4120 -&gt; call_25684 [label=&quot;calls&quot;];
call_4122 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4122 -&gt; call_22387 [label=&quot;calls&quot;];
call_4122 -&gt; call_22389 [label=&quot;calls&quot;];
call_3043 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, (Option.get (Map.get' … D)).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3043 -&gt; call_5313 [label=&quot;calls&quot;];
call_3043 -&gt; call_5315 [label=&quot;calls&quot;];
call_3045 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, (Option.get (Map.get' … D)).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3045 -&gt; call_5845 [label=&quot;calls&quot;];
call_3045 -&gt; call_5847 [label=&quot;calls&quot;];
call_4402 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : state)\l    = step\l      \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l       conflict = …\}\l      (List.hd _x_0)\lin\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4402 -&gt; call_6044 [label=&quot;calls&quot;];
call_4402 -&gt; call_6046 [label=&quot;calls&quot;];
call_4407 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Option.get (Map.get' ….agents (List.hd ….wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4407 -&gt; call_6335 [label=&quot;calls&quot;];
call_4407 -&gt; call_6337 [label=&quot;calls&quot;];
call_4392 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 sensors) in\lrun (step … (List.hd _x_0)) (List.tl _x_0)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4392 -&gt; call_19316 [label=&quot;calls&quot;];
call_4392 -&gt; call_19321 [label=&quot;calls&quot;];
call_4392 -&gt; call_19306 [label=&quot;calls&quot;];
call_2361 [label=&quot;Map.of_list Sharable [(…, Sharable)]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2361 -&gt; call_2780 [label=&quot;calls&quot;];
call_2261 [label=&quot;mk_agents_map (\{agent_id = …; guard = …; accesses = …\} :: (… :: …))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2261 -&gt; call_2598 [label=&quot;calls&quot;];
call_5569 [label=&quot;List.take 2 (List.tl (List.tl (List.tl sensors)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5569 -&gt; call_20858 [label=&quot;calls&quot;];
call_25682 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_25684 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_22387 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_22389 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, Destruct(Or, 1, (Option.get …).guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5313 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5315 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5845 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5847 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1,\l          Destruct(Or, 1,\l                   (Option.get\l                    (Map.get'\l                     (mk_agents_map\l                      (\{agent_id = Node …; guard = Eq (…, 1);\l                        accesses = Apple\}\l                       ::\l                       (\{agent_id = …; guard = …; accesses = …\} ::\l                        (… :: …))))\l                     D)).guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6044 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6044 -&gt; call_21148 [label=&quot;calls&quot;];
call_6044 -&gt; call_21150 [label=&quot;calls&quot;];
call_6046 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6046 -&gt; call_21789 [label=&quot;calls&quot;];
call_6046 -&gt; call_21791 [label=&quot;calls&quot;];
call_6335 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, (Option.get (Map.get' ….agents (List.hd ….wf_1))).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6335 -&gt; call_25169 [label=&quot;calls&quot;];
call_6335 -&gt; call_25171 [label=&quot;calls&quot;];
call_6337 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, (Option.get (Map.get' ….agents (List.hd ….wf_1))).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6337 -&gt; call_25821 [label=&quot;calls&quot;];
call_6337 -&gt; call_25823 [label=&quot;calls&quot;];
call_19316 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 sensors) in\llet (_x_1 : state) = step … (List.hd _x_0) in\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_19316 -&gt; call_21980 [label=&quot;calls&quot;];
call_19316 -&gt; call_21982 [label=&quot;calls&quot;];
call_19321 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 sensors) in\llet (_x_1 : state) = step … (List.hd _x_0) in\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_19321 -&gt; call_22134 [label=&quot;calls&quot;];
call_19321 -&gt; call_22136 [label=&quot;calls&quot;];
call_19306 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 sensors) in\llet (_x_1 : int list) = List.tl _x_0 in\lrun (step (step … (List.hd _x_0)) (List.hd _x_1)) (List.tl _x_1)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_19306 -&gt; call_22557 [label=&quot;calls&quot;];
call_19306 -&gt; call_22562 [label=&quot;calls&quot;];
call_19306 -&gt; call_22547 [label=&quot;calls&quot;];
call_2780 [label=&quot;Map.of_list Sharable []&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2780 -&gt; call_3562 [label=&quot;calls&quot;];
call_2598 [label=&quot;mk_agents_map (… :: …)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2598 -&gt; call_3370 [label=&quot;calls&quot;];
call_20858 [label=&quot;List.take 1 (List.tl (List.tl (List.tl (List.tl sensors))))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_20858 -&gt; call_23870 [label=&quot;calls&quot;];
call_21148 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, Destruct(Or, 0, (Option.get …).guard)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_21148 -&gt; call_26159 [label=&quot;calls&quot;];
call_21148 -&gt; call_26161 [label=&quot;calls&quot;];
call_21150 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_21789 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, Destruct(Or, 1, (Option.get …).guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_21791 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, Destruct(Or, 1, (Option.get …).guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_25169 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_25171 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_25821 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_25823 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_21980 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 sensors) in\llet (_x_1 : state) = step … (List.hd _x_0) in\leval_guard (List.hd (List.tl _x_0))\l(Destruct(Or, 0,\l          (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_21980 -&gt; call_24241 [label=&quot;calls&quot;];
call_21980 -&gt; call_24243 [label=&quot;calls&quot;];
call_21982 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 sensors) in\llet (_x_1 : state) = step … (List.hd _x_0) in\leval_guard (List.hd (List.tl _x_0))\l(Destruct(Or, 1,\l          (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_21982 -&gt; call_26334 [label=&quot;calls&quot;];
call_21982 -&gt; call_26336 [label=&quot;calls&quot;];
call_22134 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_22136 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_22557 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Option.get (Map.get' ….agents (List.hd ….wf_2))).guard&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_22562 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Option.get (Map.get' ….agents (List.hd ….wf_1))).guard&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_22547 [label=&quot;let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\llet (_x_1 : int list) = List.tl _x_0 in\lrun (step (step (step … …) (List.hd _x_0)) (List.hd _x_1)) (List.tl _x_1)&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3562 [label=&quot;Map.of_list Sharable (List.tl [])&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3562 -&gt; call_20975 [label=&quot;calls&quot;];
call_3370 [label=&quot;mk_agents_map …&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3370 -&gt; call_3821 [label=&quot;calls&quot;];
call_23870 [label=&quot;List.take 0 (List.tl …)&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_26159 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, Destruct(Or, 0, Destruct(Or, 0, …))))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_26161 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, Destruct(Or, 0, Destruct(Or, 0, …))))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_24241 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 0, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_24243 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 1, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_26334 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 0, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_26336 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 1, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_20975 [label=&quot;Map.of_list Sharable (List.tl (List.tl []))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3821 [label=&quot;mk_agents_map\l[\{agent_id = Node …; guard = Or (…, …); accesses = Apple\}]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3821 -&gt; call_4031 [label=&quot;calls&quot;];
call_4031 [label=&quot;mk_agents_map []&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4031 -&gt; call_4310 [label=&quot;calls&quot;];
call_4310 [label=&quot;mk_agents_map (List.tl [])&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-4e73ae06-650c-4969-8c13-f7c09682290f';
  graphviz.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-proof-top"><div class="imandra-fold panel panel-default" id="fold-3484eea1-a2b4-4f12-8440-b62a5dbc27aa"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>proof attempt</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-49004914-d94a-44cb-b692-0cd03275e013"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li><li class="" data-toggle="tab"><a>graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-d5e83c98-f747-4ad9-aeb8-967f042c94ec"><table><tr><td>ground_instances:</td><td>38</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.883s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-66d69552-7ded-41d8-adb3-90c36c9def95"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-42ce5174-3866-4657-a06b-e021e6de2293"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-e1fe9f3c-52a6-4668-a7c5-14b12d95e7dd"><table><tr><td>array def const:</td><td>2</td></tr><tr><td>num checks:</td><td>77</td></tr><tr><td>array sel const:</td><td>656</td></tr><tr><td>array def store:</td><td>2094</td></tr><tr><td>array exp ax2:</td><td>2974</td></tr><tr><td>array splits:</td><td>668</td></tr><tr><td>rlimit count:</td><td>4302953</td></tr><tr><td>array ext ax:</td><td>323</td></tr><tr><td>mk clause:</td><td>8366</td></tr><tr><td>array ax1:</td><td>10</td></tr><tr><td>datatype occurs check:</td><td>40016</td></tr><tr><td>restarts:</td><td>7</td></tr><tr><td>mk bool var:</td><td>168851</td></tr><tr><td>array ax2:</td><td>5134</td></tr><tr><td>datatype splits:</td><td>60871</td></tr><tr><td>decisions:</td><td>253055</td></tr><tr><td>propagations:</td><td>165932</td></tr><tr><td>conflicts:</td><td>1140</td></tr><tr><td>datatype accessor ax:</td><td>1364</td></tr><tr><td>minimized lits:</td><td>390</td></tr><tr><td>datatype constructor ax:</td><td>144727</td></tr><tr><td>num allocs:</td><td>2447071197</td></tr><tr><td>final checks:</td><td>1172</td></tr><tr><td>added eqs:</td><td>703697</td></tr><tr><td>del clause:</td><td>7054</td></tr><tr><td>time:</td><td>0.003000</td></tr><tr><td>memory:</td><td>51.610000</td></tr><tr><td>max memory:</td><td>52.060000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-66d69552-7ded-41d8-adb3-90c36c9def95';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-c33a3943-b939-4721-9931-e6ac66bf2550"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.883s]
  let (_x_0 : (state * int list))
      = run
        {wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;
         conflict = …}
        (List.take … ( :var_0: ))
  in not (not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = []))</pre></li><li><div><h4>simplify</h4><div class="imandra-table" id="table-fe49dd74-d9dd-450b-aad4-ca45ca31194c"><table><tr><td>into:</td><td><pre>let (_x_0 : (state * int list))
    = run
      {wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;
       conflict = …}
      (List.take 5 ( :var_0: ))
in not (not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = []))</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-7aff72af-8298-4408-8c8b-f43442a7829c"><table><tr><td>expr:</td><td><pre>(|List.take_3271/server| 5 sensors_1656/client)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-58a6203b-fdad-4213-85ec-2d593c5bc547"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_3246/server|
                   (Node_1502/client F_1508/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-705a39fe-5308-4741-9c9e-3a7b579470c1"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-6d0692ef-4d49-4407-870b-3fa24f19af13"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (tuple_mk_3256/server Apple_1528/client Unsharable_1535/client)
                 (|…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-ba701481-dded-4a53-abf9-ef5a8ea2e310"><table><tr><td>expr:</td><td><pre>(|List.take_3271/server| 4 (|get.::.1_3239/server| sensors_1656/client))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-85267b50-c7ca-4542-838d-6edf40682d60"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_3246/server|
                   (Node_1502/client F_1508/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-154b45b1-5119-482a-9b48-adaeb8891720"><table><tr><td>expr:</td><td><pre>(|Map.of_list_3264/server|
  Sharable_1534/client
  (|::| (tuple_mk_3256/server Banana_1529/client S…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-da6ae6bf-de86-4782-b368-8e48d20c88cf"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_3246/server|
                   (Node_1502/client F_1508/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-85303df5-5181-46cc-950c-9faaa2661944"><table><tr><td>expr:</td><td><pre>(|Map.of_list_3264/server|
  Sharable_1534/client
  (|::| (tuple_mk_3256/server Orange_1530/client S…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-3efc47bd-bfcb-4e1c-be7f-2fb471fec59f"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_3246/server|
                   (Node_1502/client F_1508/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-ae5d5a38-4af2-4e9f-85b1-b8a2c32161da"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_3246/server|
                   (Node_1502/client F_1508/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-4d10783a-a913-405e-9252-bf72cf156ddd"><table><tr><td>expr:</td><td><pre>(|Map.of_list_3264/server| Sharable_1534/client |[]|)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-6d06de47-48f3-49c2-bd3d-477a84087900"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_3246/server|
                   (Node_1502/client F_1508/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-957a08c7-beee-440e-b37d-c1e5bf22b393"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_3246/server|
                   (Node_1502/client F_1508/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-06d6d082-7e86-4cf9-9d5c-c06f5cb84ab6"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_3246/server|
                   (Node_1502/client F_1508/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-bfb4ceca-d935-4d03-bab9-bb760dd2a682"><table><tr><td>expr:</td><td><pre>(mk_agents_map_1621/client |[]|)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-4dc67900-2525-487b-92d7-6071f220de23"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-6f258dfa-6191-4c61-abf1-c0110b4991ef"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_3246/server|
                   (Node_1502/client F_1508/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-4948e321-e564-4ce2-bdb0-812110541954"><table><tr><td>expr:</td><td><pre>(|List.take_3271/server|
  3
  (|get.::.1_3239/server| (|get.::.1_3239/server| sensors_1656/client))…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-fa30c793-cc89-448d-8acb-8dbc1f280004"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_3246/server|
                   (Node_1502/client F_1508/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-ea8f63c0-959c-4585-aafd-b5a9cebe31fc"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-09143efe-fec0-4d67-b28b-eea57cddf4e7"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-f5927b7f-6f8d-4b57-ba77-e4efa676e5cf"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-452abdb2-6d80-4fd6-b99f-d8ce75c9860b"><table><tr><td>expr:</td><td><pre>(|List.take_3271/server|
  2
  (|get.::.1_3239/server|
    (|get.::.1_3239/server| (|get.::.1_3239/s…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-136aed26-07d2-4538-a062-26d970a4c2a3"><table><tr><td>expr:</td><td><pre>(|Map.of_list_3264/server| Sharable_1534/client (|get.::.1_3261/server| |[]|))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-262a188e-af4d-4d8a-a229-4af1274615d6"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-a0b8abc6-6999-44de-a04e-58ee0a885951"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-89c2301d-3963-4170-a0d6-21c87d0f74a0"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.0_3238/server|
             (|get.::.1_3239/server|
               (|get.::.1_32…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-690da7d9-f40c-4ef3-a760-4e6d822d8e96"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.0_3238/server|
             (|get.::.1_3239/server|
               (|get.::.1_32…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-2e18017c-0f22-45ae-bd1e-020ab02ce4c9"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_3246/server|
                   (Node_1502/client F_1508/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-703c9aa4-3677-40ae-80d2-5fda814eee74"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-b333d3f8-bfb4-4a1e-b8ad-0344f8081324"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_3239/server|
             (|get.::.1_3239/server|
               (|get.::.1_32…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-22ea4998-b76c-4744-97f5-8796cb35d9f2"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.0_3238/server|
             (|get.::.1_3239/server|
               (|get.::.1_32…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-46e43deb-31be-4e67-acb0-47507d98b44d"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-cdca7916-7b27-43a3-a794-e5b6d617028e"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_3246/server|
                   (Node_1502/client F_1508/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-a400496a-1fd3-49a4-8571-48768fa6d453"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-20f428f8-ebe7-443f-b260-c18efaa5de57"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1503/client
                 (|::| B_1504/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-a22d2d87-9d6c-4cc6-bb0e-0d19b88b9749"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.0_3238/server|
             (|get.::.1_3239/server|
               (|get.::.1_32…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li>Sat (Some let sensors : int list =
  [(Z.of_nativeint (2n)); (Z.of_nativeint (3n)); (Z.of_nativeint (1n))]
)</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-c33a3943-b939-4721-9931-e6ac66bf2550';
  fold.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-93e62d27-23ad-4df8-978d-8e057397116c"><textarea style="display: none">digraph &quot;proof&quot; {
p_409 [label=&quot;Start (let (_x_0 : (state * int list))\l           = run\l             \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l              policy = …; conflict = …\}\l             (List.take … ( :var_0: ))\l       in not (not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = [])) :time 0.883s)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_409 -&gt; p_408 [label=&quot;&quot;];
p_408 [label=&quot;Simplify (let (_x_0 : (state * int list))\l              = run\l                \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l                 policy = …; conflict = …\}\l                (List.take 5 ( :var_0: ))\l          in not (not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = []))\l          :expansions [] :rw [] :fc [])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_408 -&gt; p_407 [label=&quot;&quot;];
p_407 [label=&quot;Unroll ([List.take 5 sensors], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_407 -&gt; p_406 [label=&quot;&quot;];
p_406 [label=&quot;Unroll ([…], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_406 -&gt; p_405 [label=&quot;&quot;];
p_405 [label=&quot;Unroll ([run\l         \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l          conflict = …\}\l         (List.take 5 sensors)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_405 -&gt; p_404 [label=&quot;&quot;];
p_404 [label=&quot;Unroll ([…], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_404 -&gt; p_403 [label=&quot;&quot;];
p_403 [label=&quot;Unroll ([List.take 4 (List.tl sensors)], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_403 -&gt; p_402 [label=&quot;&quot;];
p_402 [label=&quot;Unroll ([mk_agents_map\l         (\{agent_id = Node …; guard = Eq (…, 2); accesses = Banana\} ::\l          (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_402 -&gt; p_401 [label=&quot;&quot;];
p_401 [label=&quot;Unroll ([Map.of_list Sharable [(Banana, Sharable); (…, Sharable)]], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_401 -&gt; p_400 [label=&quot;&quot;];
p_400 [label=&quot;Unroll ([mk_agents_map\l         (\{agent_id = …; guard = …; accesses = …\} :: (… :: …))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_400 -&gt; p_399 [label=&quot;&quot;];
p_399 [label=&quot;Unroll ([Map.of_list Sharable [(…, Sharable)]], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_399 -&gt; p_398 [label=&quot;&quot;];
p_398 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Option.get (Map.get' … D)).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_398 -&gt; p_397 [label=&quot;&quot;];
p_397 [label=&quot;Unroll ([mk_agents_map (… :: …)], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_397 -&gt; p_396 [label=&quot;&quot;];
p_396 [label=&quot;Unroll ([Map.of_list Sharable []], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_396 -&gt; p_395 [label=&quot;&quot;];
p_395 [label=&quot;Unroll ([mk_agents_map …], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_395 -&gt; p_394 [label=&quot;&quot;];
p_394 [label=&quot;Unroll ([mk_agents_map\l         [\{agent_id = Node …; guard = Or (…, …); accesses = Apple\}]],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_394 -&gt; p_393 [label=&quot;&quot;];
p_393 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Option.get (Map.get' … A)).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_393 -&gt; p_392 [label=&quot;&quot;];
p_392 [label=&quot;Unroll ([mk_agents_map []], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_392 -&gt; p_391 [label=&quot;&quot;];
p_391 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         run\l         (step\l          \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l           conflict = …\}\l          (List.hd _x_0))\l         (List.tl _x_0)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_391 -&gt; p_390 [label=&quot;&quot;];
p_390 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 0, (Option.get (Map.get' … D)).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_390 -&gt; p_389 [label=&quot;&quot;];
p_389 [label=&quot;Unroll ([List.take 3 (List.tl (List.tl sensors))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_389 -&gt; p_388 [label=&quot;&quot;];
p_388 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 1, (Option.get (Map.get' … D)).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_388 -&gt; p_387 [label=&quot;&quot;];
p_387 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         let (_x_1 : state)\l             = step\l               \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l                policy = …; conflict = …\}\l               (List.hd _x_0)\l         in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_387 -&gt; p_386 [label=&quot;&quot;];
p_386 [label=&quot;Unroll ([eval_guard (List.hd (List.tl (List.take 5 sensors)))\l         (Option.get (Map.get' ….agents (List.hd ….wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_386 -&gt; p_385 [label=&quot;&quot;];
p_385 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 sensors) in\l         run (step … (List.hd _x_0)) (List.tl _x_0)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_385 -&gt; p_384 [label=&quot;&quot;];
p_384 [label=&quot;Unroll ([List.take 2 (List.tl (List.tl (List.tl sensors)))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_384 -&gt; p_383 [label=&quot;&quot;];
p_383 [label=&quot;Unroll ([Map.of_list Sharable (List.tl [])], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_383 -&gt; p_382 [label=&quot;&quot;];
p_382 [label=&quot;Unroll ([eval_guard (List.hd (List.tl (List.take 5 sensors)))\l         (Destruct(Or, 0, (Option.get …).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_382 -&gt; p_381 [label=&quot;&quot;];
p_381 [label=&quot;Unroll ([eval_guard (List.hd (List.tl (List.take 5 sensors)))\l         (Destruct(Or, 1, (Option.get …).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_381 -&gt; p_380 [label=&quot;&quot;];
p_380 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 sensors) in\l         let (_x_1 : state) = step … (List.hd _x_0) in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_380 -&gt; p_379 [label=&quot;&quot;];
p_379 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 sensors) in\l         let (_x_1 : state) = step … (List.hd _x_0) in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_379 -&gt; p_378 [label=&quot;&quot;];
p_378 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 1, (Option.get …).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_378 -&gt; p_377 [label=&quot;&quot;];
p_377 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 sensors) in\l         let (_x_1 : int list) = List.tl _x_0 in\l         run (step (step … (List.hd _x_0)) (List.hd _x_1)) (List.tl _x_1)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_377 -&gt; p_376 [label=&quot;&quot;];
p_376 [label=&quot;Unroll ([List.take 1 (List.tl (List.tl (List.tl (List.tl sensors))))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_376 -&gt; p_375 [label=&quot;&quot;];
p_375 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 sensors) in\l         let (_x_1 : state) = step … (List.hd _x_0) in\l         eval_guard (List.hd (List.tl _x_0))\l         (Destruct(Or, 0,\l                   (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_375 -&gt; p_374 [label=&quot;&quot;];
p_374 [label=&quot;Unroll ([eval_guard (List.hd (List.tl (List.take 5 sensors)))\l         (Destruct(Or, 0,\l                   (Option.get (Map.get' ….agents (List.hd ….wf_1))).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_374 -&gt; p_373 [label=&quot;&quot;];
p_373 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 0, (Option.get …).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_373 -&gt; p_372 [label=&quot;&quot;];
p_372 [label=&quot;Unroll ([eval_guard (List.hd (List.tl (List.take 5 sensors)))\l         (Destruct(Or, 1,\l                   (Option.get (Map.get' ….agents (List.hd ….wf_1))).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_372 -&gt; p_371 [label=&quot;&quot;];
p_371 [label=&quot;Unroll ([eval_guard (List.hd (List.tl (List.take 5 sensors)))\l         (Destruct(Or, 0, Destruct(Or, 0, (Option.get …).guard)))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_371 -&gt; p_370 [label=&quot;&quot;];
p_370 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 sensors) in\l         let (_x_1 : state) = step … (List.hd _x_0) in\l         eval_guard (List.hd (List.tl _x_0))\l         (Destruct(Or, 1,\l                   (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_370 -&gt; p_369 [label=&quot;&quot;];
p_369 [label=&quot;Sat (Some let sensors : int list =\l  [(Z.of_nativeint (2n)); (Z.of_nativeint (3n)); (Z.of_nativeint (1n))]\l)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-93e62d27-23ad-4df8-978d-8e057397116c';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-49004914-d94a-44cb-b692-0cd03275e013';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-3484eea1-a2b4-4f12-8440-b62a5dbc27aa';
  fold.hydrate(target);
});
</script></div></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-d8652e3b-da9b-4cc6-b099-29bb4412aea0';
  alternatives.hydrate(target);
});
</script></div></div></div>



As we can see, Imandra has proved for us that a conflict is possible for `ex_3`. It's a very nice
exercise to go through the counterexample manually and understand how this conflict occurs. We can also
use Imandra's concrete execution facilities to investigate the state for this conflict, by running the problem along the counterexample Imandra synthesized (`CX.sensors`):


```ocaml
run_problem ex_3 CX.sensors
```




    - : state * Z.t list =
    ({wf_1 = [A;B;C;A]; wf_2 = [F;D]; sensor = Some 1;
      agents =
       (Map.of_list ~default:None
        [(A, Some {agent_id = Node A; guard = Eq (Sensor, 1); accesses = Apple});
         (B, Some {agent_id = Node B; guard = Eq (Sensor, 2); accesses = Banana});
         (C, Some {agent_id = Node C; guard = Eq (Sensor, 3); accesses = Orange});
         (D,
          Some
           {agent_id = Node D; guard = Or (Eq (Sensor, 1), Eq (Sensor, 2));
            accesses = Orange});
         (E,
          Some
           {agent_id = Node E; guard = Or (Eq (Sensor, 2), Eq (Sensor, 3));
            accesses = Banana});
         (F,
          Some
           {agent_id = Node F; guard = Or (Eq (Sensor, 3), Eq (Sensor, 1));
            accesses = Apple})]);
      policy = (Map.of_list ~default:Sharable [(Apple, Unsharable)]);
      conflict = Some (Node A, Node F, Apple)},
     [])




We can see that the conflict Imandra found, which happens with a sensor sequence of `[2;3;1]` results in
both `Node A` and `Node F` trying to access `Apple` at the same time, which is not allowed by the
resource access policy.

You can modify these problems as you see fit and experiment with Imandra verifying or refuting conflict
safety. Happy reasoning!


```ocaml

```
