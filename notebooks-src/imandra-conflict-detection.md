# Imandra for automated conflict detection

In this notebook, we will build an Imandra framework for reasoning about concurrent conflict detection. Once we encode this model in Imandra, we'll be able to use Imandra to automatically solve arbitrary problems about concurrent resource detection simply by encoding them in a simple datatype and asking Imandra if a conflict is possible.

Let's begin with an informal description of the problem space.

# Detecting resource conflicts over concurrent workflows

Imagine there are two workflows, WF1 and WF2, that can each access Sharable and Unsharable resources.

We define a conflict as any possible scenario in which WF1 and WF2 both access
an Unsharable resource at the same time.

We want to prove that, for given definitions, a specific sequence of events will either
never lead to a conflict OR that there will be a conflict and at which event
would the conflict occur.

We will 

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





<div><div class="imandra-fold panel panel-default" id="fold-087ce737-6918-4bcf-b2c4-f26f88781771"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>termination proof</span></div></div><div class="panel-body collapse"><div><h3>Termination proof</h3><div class="imandra-fold panel panel-default" id="fold-daf8eadd-8c32-469d-b368-179d239d251d"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>call `eval_guard sensor (Destruct(Or, 0, g))` from `eval_guard sensor g`</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-b5a6d9c1-82ed-4e15-9602-a70006e213a2"><table><tr><td>original:</td><td>eval_guard sensor g</td></tr><tr><td>sub:</td><td>eval_guard sensor (Destruct(Or, 0, g))</td></tr><tr><td>original ordinal:</td><td>Ordinal.Int (_cnt g)</td></tr><tr><td>sub ordinal:</td><td>Ordinal.Int (_cnt (Destruct(Or, 0, g)))</td></tr><tr><td>path:</td><td>[not Is_a(Eq, g)]</td></tr><tr><td>proof:</td><td><div class="imandra-fold panel panel-default" id="fold-6fe797ab-345b-4c04-8117-1303225da39e"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>detailed proof</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-0ee647ae-b0a5-49a7-851a-237d15c87212"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-e0237323-b20b-42e6-b3f1-2a4ff5af47bf"><table><tr><td>ground_instances:</td><td>3</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.010s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-2b162448-a60d-4c0b-a65f-0b6a41107faa"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-8c2cc61b-9ae8-473d-9a01-d883db744bed"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-727aa583-5494-43f4-964e-87b8d393ab01"><table><tr><td>num checks:</td><td>8</td></tr><tr><td>arith assert lower:</td><td>11</td></tr><tr><td>arith tableau max rows:</td><td>6</td></tr><tr><td>arith tableau max columns:</td><td>19</td></tr><tr><td>arith pivots:</td><td>10</td></tr><tr><td>rlimit count:</td><td>5434</td></tr><tr><td>mk clause:</td><td>24</td></tr><tr><td>datatype occurs check:</td><td>27</td></tr><tr><td>mk bool var:</td><td>117</td></tr><tr><td>arith assert upper:</td><td>8</td></tr><tr><td>datatype splits:</td><td>9</td></tr><tr><td>decisions:</td><td>19</td></tr><tr><td>arith row summations:</td><td>10</td></tr><tr><td>propagations:</td><td>19</td></tr><tr><td>conflicts:</td><td>6</td></tr><tr><td>arith fixed eqs:</td><td>4</td></tr><tr><td>datatype accessor ax:</td><td>18</td></tr><tr><td>arith conflicts:</td><td>2</td></tr><tr><td>arith num rows:</td><td>6</td></tr><tr><td>datatype constructor ax:</td><td>31</td></tr><tr><td>num allocs:</td><td>23853164</td></tr><tr><td>final checks:</td><td>6</td></tr><tr><td>added eqs:</td><td>97</td></tr><tr><td>del clause:</td><td>7</td></tr><tr><td>arith eq adapter:</td><td>6</td></tr><tr><td>memory:</td><td>17.130000</td></tr><tr><td>max memory:</td><td>17.130000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-2b162448-a60d-4c0b-a65f-0b6a41107faa';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-1c4e9211-eb93-45e5-b7e3-846603c84739"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.010s]
  let (_x_0 : int) = count.guard g in
  let (_x_1 : guard) = Destruct(Or, 0, g) in
  let (_x_2 : int) = count.guard _x_1 in
  let (_x_3 : bool) = Is_a(Eq, _x_1) in
  not Is_a(Eq, g) &amp;&amp; ((_x_0 &gt;= 0) &amp;&amp; (_x_2 &gt;= 0))
  ==&gt; (_x_3
       &amp;&amp; not (not (eval_guard sensor (Destruct(Or, 0, _x_1))) &amp;&amp; not _x_3))
      || Ordinal.( &lt;&lt; ) (Ordinal.Int _x_2) (Ordinal.Int _x_0)</pre></li><li><div><h6>simplify</h6><div class="imandra-table" id="table-051cd026-9e35-47fb-ab7d-f332ada419dd"><table><tr><td>into:</td><td><pre>let (_x_0 : int) = count.guard g in
let (_x_1 : guard) = Destruct(Or, 0, g) in
let (_x_2 : int) = count.guard _x_1 in
let (_x_3 : bool) = Is_a(Eq, _x_1) in
not (not Is_a(Eq, g) &amp;&amp; (_x_0 &gt;= 0) &amp;&amp; (_x_2 &gt;= 0))
|| Ordinal.( &lt;&lt; ) (Ordinal.Int _x_2) (Ordinal.Int _x_0)
|| (_x_3 &amp;&amp; not (not (eval_guard sensor (Destruct(Or, 0, _x_1))) &amp;&amp; not _x_3))</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-bee11f41-f312-44e9-b117-8b54ec22f0e7"><table><tr><td>expr:</td><td><pre>(|Ordinal.&lt;&lt;| (|Ordinal.Int_79/boot|
                (|count.guard_1263/client| (|get.Or.0_549/serve…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-d8b70292-dd2f-4229-a769-c60a282bb9d7"><table><tr><td>expr:</td><td><pre>(|count.guard_1263/client| (|get.Or.0_549/server| g_552/server))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-c27d59be-95de-4cf1-ba5e-dbb78950954c"><table><tr><td>expr:</td><td><pre>(|count.guard_1263/client| g_552/server)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li>Unsat</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-1c4e9211-eb93-45e5-b7e3-846603c84739';
  fold.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-0ee647ae-b0a5-49a7-851a-237d15c87212';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-6fe797ab-345b-4c04-8117-1303225da39e';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-daf8eadd-8c32-469d-b368-179d239d251d';
  fold.hydrate(target);
});
</script></div><div class="imandra-fold panel panel-default" id="fold-694f3a53-c2dd-453e-8dfd-4074bf03a057"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>call `eval_guard sensor (Destruct(Or, 1, g))` from `eval_guard sensor g`</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-9d3a7302-baa0-4d09-9485-e7dcc5877fd7"><table><tr><td>original:</td><td>eval_guard sensor g</td></tr><tr><td>sub:</td><td>eval_guard sensor (Destruct(Or, 1, g))</td></tr><tr><td>original ordinal:</td><td>Ordinal.Int (_cnt g)</td></tr><tr><td>sub ordinal:</td><td>Ordinal.Int (_cnt (Destruct(Or, 1, g)))</td></tr><tr><td>path:</td><td>[not (eval_guard sensor (Destruct(Or, 0, g))) &amp;&amp; not Is_a(Eq, g)]</td></tr><tr><td>proof:</td><td><div class="imandra-fold panel panel-default" id="fold-95579b48-36b4-4340-8a42-9a92eb1ef8ed"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>detailed proof</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-259e18cc-f065-4b22-b142-502cc0e4f106"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-732e88ea-440f-44af-9a00-e141af4b0ce3"><table><tr><td>ground_instances:</td><td>3</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.012s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-7c141cf0-51eb-4bc2-8dde-07a9443b5f15"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-aa9a3829-d1db-44ac-9194-2a171eebc34e"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-b2fbebec-2f65-40bd-8087-0949548b1249"><table><tr><td>num checks:</td><td>8</td></tr><tr><td>arith assert lower:</td><td>11</td></tr><tr><td>arith tableau max rows:</td><td>6</td></tr><tr><td>arith tableau max columns:</td><td>19</td></tr><tr><td>arith pivots:</td><td>10</td></tr><tr><td>rlimit count:</td><td>2742</td></tr><tr><td>mk clause:</td><td>24</td></tr><tr><td>datatype occurs check:</td><td>27</td></tr><tr><td>mk bool var:</td><td>118</td></tr><tr><td>arith assert upper:</td><td>8</td></tr><tr><td>datatype splits:</td><td>9</td></tr><tr><td>decisions:</td><td>19</td></tr><tr><td>arith row summations:</td><td>10</td></tr><tr><td>propagations:</td><td>19</td></tr><tr><td>conflicts:</td><td>6</td></tr><tr><td>arith fixed eqs:</td><td>4</td></tr><tr><td>datatype accessor ax:</td><td>18</td></tr><tr><td>arith conflicts:</td><td>2</td></tr><tr><td>arith num rows:</td><td>6</td></tr><tr><td>datatype constructor ax:</td><td>31</td></tr><tr><td>num allocs:</td><td>17118784</td></tr><tr><td>final checks:</td><td>6</td></tr><tr><td>added eqs:</td><td>97</td></tr><tr><td>del clause:</td><td>7</td></tr><tr><td>arith eq adapter:</td><td>6</td></tr><tr><td>memory:</td><td>17.130000</td></tr><tr><td>max memory:</td><td>17.130000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-7c141cf0-51eb-4bc2-8dde-07a9443b5f15';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-b983ecc4-424d-4a44-87da-6881e9636da7"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.012s]
  let (_x_0 : int) = count.guard g in
  let (_x_1 : guard) = Destruct(Or, 1, g) in
  let (_x_2 : int) = count.guard _x_1 in
  let (_x_3 : bool) = Is_a(Eq, _x_1) in
  not (eval_guard sensor (Destruct(Or, 0, g)))
  &amp;&amp; (not Is_a(Eq, g) &amp;&amp; ((_x_0 &gt;= 0) &amp;&amp; (_x_2 &gt;= 0)))
  ==&gt; (_x_3
       &amp;&amp; not (not (eval_guard sensor (Destruct(Or, 0, _x_1))) &amp;&amp; not _x_3))
      || Ordinal.( &lt;&lt; ) (Ordinal.Int _x_2) (Ordinal.Int _x_0)</pre></li><li><div><h6>simplify</h6><div class="imandra-table" id="table-720f3120-35cb-4b82-ab9f-7a526ac53cc3"><table><tr><td>into:</td><td><pre>let (_x_0 : guard) = Destruct(Or, 1, g) in
let (_x_1 : bool) = Is_a(Eq, _x_0) in
let (_x_2 : int) = count.guard _x_0 in
let (_x_3 : int) = count.guard g in
(_x_1 &amp;&amp; not (not (eval_guard sensor (Destruct(Or, 0, _x_0))) &amp;&amp; not _x_1))
|| Ordinal.( &lt;&lt; ) (Ordinal.Int _x_2) (Ordinal.Int _x_3)
|| not
   (not (eval_guard sensor (Destruct(Or, 0, g))) &amp;&amp; not Is_a(Eq, g)
    &amp;&amp; (_x_3 &gt;= 0) &amp;&amp; (_x_2 &gt;= 0))</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-c56bee34-aafa-40dc-96b0-c67768584691"><table><tr><td>expr:</td><td><pre>(|Ordinal.&lt;&lt;| (|Ordinal.Int_79/boot|
                (|count.guard_1263/client| (|get.Or.1_550/serve…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-78fbcf54-ac91-4391-b54a-883b9dd1b866"><table><tr><td>expr:</td><td><pre>(|count.guard_1263/client| (|get.Or.1_550/server| g_552/server))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-bdef6b80-1d26-4347-9bd3-82c09a0c2ec0"><table><tr><td>expr:</td><td><pre>(|count.guard_1263/client| g_552/server)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li>Unsat</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-b983ecc4-424d-4a44-87da-6881e9636da7';
  fold.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-259e18cc-f065-4b22-b142-502cc0e4f106';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-95579b48-36b4-4340-8a42-9a92eb1ef8ed';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-694f3a53-c2dd-453e-8dfd-4074bf03a057';
  fold.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-087ce737-6918-4bcf-b2c4-f26f88781771';
  fold.hydrate(target);
});
</script></div></div>




<div><div class="imandra-fold panel panel-default" id="fold-e3bb756f-611c-41e4-8813-d340e4b59b7f"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>termination proof</span></div></div><div class="panel-body collapse"><div><h3>Termination proof</h3><div class="imandra-fold panel panel-default" id="fold-fabe83b9-9b53-4cf1-a131-0438055284b1"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>call `run (step s (List.hd sensors)) (List.tl sensors)` from `run s sensors`</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-72a1b1c3-47c9-4341-8cac-d1f74e4f31bb"><table><tr><td>original:</td><td>run s sensors</td></tr><tr><td>sub:</td><td>run (step s (List.hd sensors)) (List.tl sensors)</td></tr><tr><td>original ordinal:</td><td>Ordinal.Int (_cnt sensors)</td></tr><tr><td>sub ordinal:</td><td>Ordinal.Int (_cnt (List.tl sensors))</td></tr><tr><td>path:</td><td>[(step s (List.hd sensors)).conflict = None &amp;&amp; sensors &lt;&gt; []]</td></tr><tr><td>proof:</td><td><div class="imandra-fold panel panel-default" id="fold-fe2b1aa3-ccab-40f8-8440-bca0687301ec"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>detailed proof</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-ed47a306-df3a-41e8-bb97-747e1735ee2d"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-4f43e707-6670-4a46-a712-e3627c2b8675"><table><tr><td>ground_instances:</td><td>3</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.017s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-2995cbb5-347b-4f22-ae1e-079282cec67d"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-5916abda-6f3e-4a99-a959-1b58efacfd88"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-d343a4e6-e065-4b13-a2cb-cebe2bb4ab67"><table><tr><td>num checks:</td><td>8</td></tr><tr><td>arith assert lower:</td><td>12</td></tr><tr><td>arith tableau max rows:</td><td>5</td></tr><tr><td>arith tableau max columns:</td><td>16</td></tr><tr><td>arith pivots:</td><td>13</td></tr><tr><td>rlimit count:</td><td>17922</td></tr><tr><td>mk clause:</td><td>204</td></tr><tr><td>datatype occurs check:</td><td>299</td></tr><tr><td>mk bool var:</td><td>1203</td></tr><tr><td>arith assert upper:</td><td>14</td></tr><tr><td>datatype splits:</td><td>309</td></tr><tr><td>decisions:</td><td>456</td></tr><tr><td>arith row summations:</td><td>23</td></tr><tr><td>arith bound prop:</td><td>1</td></tr><tr><td>propagations:</td><td>523</td></tr><tr><td>conflicts:</td><td>28</td></tr><tr><td>arith fixed eqs:</td><td>5</td></tr><tr><td>datatype accessor ax:</td><td>153</td></tr><tr><td>minimized lits:</td><td>2</td></tr><tr><td>arith conflicts:</td><td>2</td></tr><tr><td>arith num rows:</td><td>5</td></tr><tr><td>arith assert diseq:</td><td>2</td></tr><tr><td>datatype constructor ax:</td><td>702</td></tr><tr><td>num allocs:</td><td>33535690</td></tr><tr><td>final checks:</td><td>14</td></tr><tr><td>added eqs:</td><td>2994</td></tr><tr><td>del clause:</td><td>9</td></tr><tr><td>arith eq adapter:</td><td>13</td></tr><tr><td>memory:</td><td>18.150000</td></tr><tr><td>max memory:</td><td>18.150000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-2995cbb5-347b-4f22-ae1e-079282cec67d';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-107b1d47-6b15-4844-91e6-db29cfd5e36b"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.017s]
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
      || Ordinal.( &lt;&lt; ) (Ordinal.Int _x_5) (Ordinal.Int _x_3)</pre></li><li><div><h6>simplify</h6><div class="imandra-table" id="table-24a15687-4940-48ed-bc9f-2ed5dbc8d328"><table><tr><td>into:</td><td><pre>let (_x_0 : int list) = List.tl sensors in
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
    &amp;&amp; sensors &lt;&gt; [] &amp;&amp; (_x_2 &gt;= 0) &amp;&amp; (_x_1 &gt;= 0))</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-368ac8ea-8531-47ef-9076-cb5cdeeb7d89"><table><tr><td>expr:</td><td><pre>(|Ordinal.&lt;&lt;| (|Ordinal.Int_79/boot|
                (|count.list_702/server|
                  (|ge…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-58b857ef-fd44-43e9-8065-4de490563903"><table><tr><td>expr:</td><td><pre>(|count.list_702/server| (|get.::.1_684/server| sensors_690/server))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-aa23b4c0-77c7-4bba-a383-11e63dd1e06e"><table><tr><td>expr:</td><td><pre>(|count.list_702/server| sensors_690/server)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li>Unsat</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-107b1d47-6b15-4844-91e6-db29cfd5e36b';
  fold.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-ed47a306-df3a-41e8-bb97-747e1735ee2d';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-fe2b1aa3-ccab-40f8-8440-bca0687301ec';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-fabe83b9-9b53-4cf1-a131-0438055284b1';
  fold.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-e3bb756f-611c-41e4-8813-d340e4b59b7f';
  fold.hydrate(target);
});
</script></div></div>



# Top-level problem interpreter and problem-specific conflict detection

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





<div><div class="imandra-fold panel panel-default" id="fold-7ba9d5f6-a1fe-46a7-b892-459423ce1cc9"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>termination proof</span></div></div><div class="panel-body collapse"><div><h3>Termination proof</h3><div class="imandra-fold panel panel-default" id="fold-47702a49-189b-4d8c-83e3-5009e1f8b624"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>call `mk_agents_map (List.tl actors)` from `mk_agents_map actors`</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-76db7c68-eaa1-4f1d-99d0-5b154202f752"><table><tr><td>original:</td><td>mk_agents_map actors</td></tr><tr><td>sub:</td><td>mk_agents_map (List.tl actors)</td></tr><tr><td>original ordinal:</td><td>Ordinal.Int (_cnt actors)</td></tr><tr><td>sub ordinal:</td><td>Ordinal.Int (_cnt (List.tl actors))</td></tr><tr><td>path:</td><td>[actors &lt;&gt; []]</td></tr><tr><td>proof:</td><td><div class="imandra-fold panel panel-default" id="fold-c50174a5-2de8-46ed-a910-d319a86e9db5"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>detailed proof</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-4afb5654-2b6d-439e-8398-e4a074d33e50"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-0d13d211-b593-409c-a793-da7f2bb29cd9"><table><tr><td>ground_instances:</td><td>3</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.012s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-4c810aed-e83e-400f-9c05-5ae3912775a0"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-80d7f7cc-ddc0-485e-9cf9-c6e35b81fa8a"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-d0987767-72b8-4da6-b8fc-75ec9d7f0e68"><table><tr><td>num checks:</td><td>8</td></tr><tr><td>arith assert lower:</td><td>17</td></tr><tr><td>arith tableau max rows:</td><td>10</td></tr><tr><td>arith tableau max columns:</td><td>24</td></tr><tr><td>arith pivots:</td><td>13</td></tr><tr><td>rlimit count:</td><td>3758</td></tr><tr><td>mk clause:</td><td>38</td></tr><tr><td>datatype occurs check:</td><td>25</td></tr><tr><td>mk bool var:</td><td>187</td></tr><tr><td>arith assert upper:</td><td>12</td></tr><tr><td>datatype splits:</td><td>21</td></tr><tr><td>decisions:</td><td>35</td></tr><tr><td>arith row summations:</td><td>34</td></tr><tr><td>propagations:</td><td>32</td></tr><tr><td>conflicts:</td><td>11</td></tr><tr><td>arith fixed eqs:</td><td>9</td></tr><tr><td>datatype accessor ax:</td><td>30</td></tr><tr><td>minimized lits:</td><td>1</td></tr><tr><td>arith conflicts:</td><td>2</td></tr><tr><td>arith num rows:</td><td>10</td></tr><tr><td>datatype constructor ax:</td><td>71</td></tr><tr><td>num allocs:</td><td>81608215</td></tr><tr><td>final checks:</td><td>6</td></tr><tr><td>added eqs:</td><td>222</td></tr><tr><td>del clause:</td><td>15</td></tr><tr><td>arith eq adapter:</td><td>12</td></tr><tr><td>memory:</td><td>19.050000</td></tr><tr><td>max memory:</td><td>19.050000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-4c810aed-e83e-400f-9c05-5ae3912775a0';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-babcb924-bf88-4ffe-8b99-936e9d3af075"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.012s]
  let (_x_0 : int) = count.list count.agent actors in
  let (_x_1 : agent list) = List.tl actors in
  let (_x_2 : int) = count.list count.agent _x_1 in
  actors &lt;&gt; [] &amp;&amp; ((_x_0 &gt;= 0) &amp;&amp; (_x_2 &gt;= 0))
  ==&gt; not (_x_1 &lt;&gt; [])
      || Ordinal.( &lt;&lt; ) (Ordinal.Int _x_2) (Ordinal.Int _x_0)</pre></li><li><div><h6>simplify</h6><div class="imandra-table" id="table-711a0609-6568-4b6e-8413-2b606879d392"><table><tr><td>into:</td><td><pre>let (_x_0 : agent list) = List.tl actors in
let (_x_1 : int) = count.list count.agent _x_0 in
let (_x_2 : int) = count.list count.agent actors in
not (_x_0 &lt;&gt; []) || Ordinal.( &lt;&lt; ) (Ordinal.Int _x_1) (Ordinal.Int _x_2)
|| not (actors &lt;&gt; [] &amp;&amp; (_x_2 &gt;= 0) &amp;&amp; (_x_1 &gt;= 0))</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-36139d26-939a-44f8-95fd-da4c489f306c"><table><tr><td>expr:</td><td><pre>(|Ordinal.&lt;&lt;| (|Ordinal.Int_79/boot|
                (|count.list_931/server|
                  (|ge…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-503ef5c3-7865-46e2-9fe6-14b5fbc11949"><table><tr><td>expr:</td><td><pre>(|count.list_931/server| (|get.::.1_917/server| actors_920/server))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-8911c575-79f6-4c87-b170-06ee1c95f124"><table><tr><td>expr:</td><td><pre>(|count.list_931/server| actors_920/server)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li>Unsat</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-babcb924-bf88-4ffe-8b99-936e9d3af075';
  fold.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-4afb5654-2b6d-439e-8398-e4a074d33e50';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-c50174a5-2de8-46ed-a910-d319a86e9db5';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-47702a49-189b-4d8c-83e3-5009e1f8b624';
  fold.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-7ba9d5f6-a1fe-46a7-b892-459423ce1cc9';
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





<div><pre>Instance (after 21 steps, 0.058s):
let sensors : int list = [1; 2]
</pre></div>




<div><div style="font-size: 1.2em; padding: 0.5em; border-top: 1px solid green; border-bottom: 1px solid green"><i class="fa fa-check-circle" style="margin-right: 0.5em; color: green"></i><span>Instance</span></div><div><div class="imandra-alternatives" id="alt-3bd86697-e1c3-4ca8-8be8-bad16a2825b0"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>call graph</a></li><li class="" data-toggle="tab"><a>proof</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-graphviz" id="graphviz-83577a6d-1576-4f00-87c7-602154764f1e"><textarea style="display: none">digraph &quot;call graph&quot; {
goal [label=&quot;let (_x_0 : (state * int list))\l    = run\l      \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l       conflict = …\}\l      (List.take 5 sensors)\lin not (_x_0.0.conflict = None) &amp;&amp; (_x_0.1 = [])&quot;,shape=box,style=filled,color=&quot;cyan&quot;,fontname=&quot;courier&quot;,fontsize=14];
goal -&gt; call_66 [label=&quot;calls&quot;];
goal -&gt; call_127 [label=&quot;calls&quot;];
goal -&gt; call_125 [label=&quot;calls&quot;];
goal -&gt; call_147 [label=&quot;calls&quot;];
call_66 [label=&quot;…&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_66 -&gt; call_1902 [label=&quot;calls&quot;];
call_127 [label=&quot;…&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_127 -&gt; call_1024 [label=&quot;calls&quot;];
call_125 [label=&quot;run\l\{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l conflict = …\}\l(List.take 5 sensors)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_125 -&gt; call_1208 [label=&quot;calls&quot;];
call_125 -&gt; call_1192 [label=&quot;calls&quot;];
call_125 -&gt; call_1176 [label=&quot;calls&quot;];
call_147 [label=&quot;List.take 5 sensors&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_147 -&gt; call_916 [label=&quot;calls&quot;];
call_1902 [label=&quot;Map.of_list Sharable [(Banana, Unsharable); (…, Sharable)]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1902 -&gt; call_2396 [label=&quot;calls&quot;];
call_1024 [label=&quot;mk_agents_map\l(\{agent_id = Node …; guard = Eq (…, 2); accesses = Banana\} ::\l (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1024 -&gt; call_2287 [label=&quot;calls&quot;];
call_1208 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Option.get (Map.get' (mk_agents_map …) A)).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1208 -&gt; call_3411 [label=&quot;calls&quot;];
call_1208 -&gt; call_3409 [label=&quot;calls&quot;];
call_1192 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Option.get (Map.get' … D)).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1192 -&gt; call_2768 [label=&quot;calls&quot;];
call_1192 -&gt; call_2766 [label=&quot;calls&quot;];
call_1176 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\lrun\l(step\l \{wf_1 = A :: …; wf_2 = … :: …; sensor = None;\l  agents = mk_agents_map …; policy = Map.of_list … …; conflict = None\}\l (List.hd _x_0))\l(List.tl _x_0)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1176 -&gt; call_3718 [label=&quot;calls&quot;];
call_1176 -&gt; call_3703 [label=&quot;calls&quot;];
call_1176 -&gt; call_3713 [label=&quot;calls&quot;];
call_916 [label=&quot;List.take 4 (List.tl sensors)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_916 -&gt; call_2039 [label=&quot;calls&quot;];
call_2396 [label=&quot;Map.of_list Sharable [(…, Sharable)]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2396 -&gt; call_2578 [label=&quot;calls&quot;];
call_2287 [label=&quot;mk_agents_map (\{agent_id = …; guard = …; accesses = …\} :: (… :: …))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2287 -&gt; call_2501 [label=&quot;calls&quot;];
call_3411 [label=&quot;eval_guard … (Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3409 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, (Option.get (Map.get' (mk_agents_map …) A)).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2768 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2768 -&gt; call_5621 [label=&quot;calls&quot;];
call_2768 -&gt; call_5619 [label=&quot;calls&quot;];
call_2766 [label=&quot;eval_guard … (Destruct(Or, 0, ….guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3718 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : state)\l    = step\l      \{wf_1 = A :: …; wf_2 = … :: …; sensor = None;\l       agents = mk_agents_map …; policy = Map.of_list … …;\l       conflict = None\}\l      (List.hd _x_0)\lin\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3718 -&gt; call_5143 [label=&quot;calls&quot;];
call_3718 -&gt; call_5141 [label=&quot;calls&quot;];
call_3703 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : int list) = List.tl _x_0 in\lrun\l(step\l (step\l  \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l   conflict = …\}\l  (List.hd _x_0))\l (List.hd _x_1))\l(List.tl _x_1)&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3713 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : state)\l    = step\l      \{wf_1 = A :: …; wf_2 = … :: …; sensor = None;\l       agents = mk_agents_map …; policy = Map.of_list … …;\l       conflict = None\}\l      (List.hd _x_0)\lin\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3713 -&gt; call_5805 [label=&quot;calls&quot;];
call_3713 -&gt; call_5803 [label=&quot;calls&quot;];
call_2039 [label=&quot;List.take 3 (List.tl (List.tl sensors))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2039 -&gt; call_5355 [label=&quot;calls&quot;];
call_2578 [label=&quot;Map.of_list Sharable []&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2578 -&gt; call_2750 [label=&quot;calls&quot;];
call_2501 [label=&quot;mk_agents_map (… :: …)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2501 -&gt; call_2943 [label=&quot;calls&quot;];
call_5621 [label=&quot;eval_guard … (Destruct(Or, 1, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5619 [label=&quot;eval_guard … (Destruct(Or, 0, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5143 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5141 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5805 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5803 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5355 [label=&quot;List.take 2 …&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2750 [label=&quot;Map.of_list Sharable (List.tl [])&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2943 [label=&quot;mk_agents_map …&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2943 -&gt; call_3099 [label=&quot;calls&quot;];
call_3099 [label=&quot;mk_agents_map [\{agent_id = Node …; guard = …; accesses = Apple\}]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3099 -&gt; call_3298 [label=&quot;calls&quot;];
call_3298 [label=&quot;mk_agents_map []&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3298 -&gt; call_3612 [label=&quot;calls&quot;];
call_3612 [label=&quot;mk_agents_map (List.tl [])&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-83577a6d-1576-4f00-87c7-602154764f1e';
  graphviz.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-proof-top"><div class="imandra-fold panel panel-default" id="fold-014e1dee-c47e-4012-9cbd-a71b6d368204"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>proof attempt</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-0fccff63-36f6-432c-b8ac-ae646e641f76"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li><li class="" data-toggle="tab"><a>graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-9460b172-d02b-4f59-9615-79dc7c4630b8"><table><tr><td>ground_instances:</td><td>21</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.058s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-cfdc0bd3-da82-408b-ab86-42a70c629dbf"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-3cc39be9-acf0-4bc5-80dc-75ab1897242b"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-d809dbac-eba3-4c7a-bebb-c6b7074fedb7"><table><tr><td>array def const:</td><td>2</td></tr><tr><td>num checks:</td><td>43</td></tr><tr><td>array sel const:</td><td>35</td></tr><tr><td>array def store:</td><td>141</td></tr><tr><td>array exp ax2:</td><td>259</td></tr><tr><td>array splits:</td><td>54</td></tr><tr><td>rlimit count:</td><td>91407</td></tr><tr><td>array ext ax:</td><td>29</td></tr><tr><td>mk clause:</td><td>812</td></tr><tr><td>array ax1:</td><td>9</td></tr><tr><td>datatype occurs check:</td><td>4619</td></tr><tr><td>mk bool var:</td><td>5169</td></tr><tr><td>array ax2:</td><td>345</td></tr><tr><td>datatype splits:</td><td>861</td></tr><tr><td>decisions:</td><td>3346</td></tr><tr><td>propagations:</td><td>2379</td></tr><tr><td>conflicts:</td><td>156</td></tr><tr><td>datatype accessor ax:</td><td>271</td></tr><tr><td>minimized lits:</td><td>19</td></tr><tr><td>datatype constructor ax:</td><td>2316</td></tr><tr><td>num allocs:</td><td>105225016</td></tr><tr><td>final checks:</td><td>159</td></tr><tr><td>added eqs:</td><td>16592</td></tr><tr><td>del clause:</td><td>579</td></tr><tr><td>time:</td><td>0.002000</td></tr><tr><td>memory:</td><td>21.750000</td></tr><tr><td>max memory:</td><td>21.800000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-cfdc0bd3-da82-408b-ab86-42a70c629dbf';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-c16b61fc-697a-4e6a-bcdf-8c3a8a716430"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.058s]
  let (_x_0 : (state * int list))
      = run
        {wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;
         conflict = …}
        (List.take … ( :var_0: ))
  in not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = [])</pre></li><li><div><h4>simplify</h4><div class="imandra-table" id="table-640d0c32-ba67-4767-8334-66fb19b1cd21"><table><tr><td>into:</td><td><pre>let (_x_0 : (state * int list))
    = run
      {wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;
       conflict = …}
      (List.take 5 ( :var_0: ))
in not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = [])</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-f58cdee3-81ef-4627-a533-d1582c0dd38e"><table><tr><td>expr:</td><td><pre>(|List.take_1116/server| 5 sensors_1433/client)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-03e43d3d-1c32-449d-81db-c515616bf81e"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1091/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-f34b92c0-8ba1-4773-9694-dada2839a92d"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-b2827e06-7627-4075-a697-8c8969ef3a9b"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (tuple_mk_1101/server Apple_1272/client Sharable_1278/client)
                 (|::…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-39069bbf-30e0-4718-bb27-22784cc3d68e"><table><tr><td>expr:</td><td><pre>(|List.take_1116/server| 4 (|get.::.1_1084/server| sensors_1433/client))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-2d0d6127-e88e-40d0-9240-aa1941c893d9"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1091/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-9f2be3af-7882-4348-b53d-b6e53a203ae4"><table><tr><td>expr:</td><td><pre>(|Map.of_list_1109/server|
  Sharable_1278/client
  (|::| (tuple_mk_1101/server Banana_1273/client U…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-055206ef-902e-4902-94f9-a750f45c448c"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1091/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-7c7f8570-1cbe-4012-aea1-1a46112117e1"><table><tr><td>expr:</td><td><pre>(|Map.of_list_1109/server|
  Sharable_1278/client
  (|::| (tuple_mk_1101/server Orange_1274/client S…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-8399a2a5-ecf8-4e7a-9c55-b49a21fef999"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1091/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-b6a8bf5a-c002-4425-9b65-460941d33b6e"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1091/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-bc1bf025-8f50-4c5c-b61b-60206db7f0cf"><table><tr><td>expr:</td><td><pre>(|Map.of_list_1109/server| Sharable_1278/client |[]|)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-a8bde8d6-4715-464c-9554-484b9e21db59"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1091/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-1d302bd0-dda7-4d67-9025-09d021e1fb21"><table><tr><td>expr:</td><td><pre>(mk_agents_map_1408/client
  (|::| (|rec_mk.agent_1091/server|
          (Node_1246/client F_1252/cl…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-ee0eee92-f5ac-4ed6-a7b3-4aa70a0a80ac"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1091/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-46e75137-ca82-44aa-8a13-1be5a17762b0"><table><tr><td>expr:</td><td><pre>(mk_agents_map_1408/client |[]|)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-30a7a5e5-904e-4233-a601-ad33a60e8c1a"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-c299ae62-9472-4677-a2cc-065556804d51"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-0622399b-4e17-48de-9a40-bd9548a5902a"><table><tr><td>expr:</td><td><pre>(|List.take_1116/server|
  3
  (|get.::.1_1084/server| (|get.::.1_1084/server| sensors_1433/client))…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-3ed9798d-4ce9-41d5-ab7e-c2c4362ae502"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1091/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-98bb4090-fbe6-4206-bb4b-615ed5488fa4"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li>Sat (Some let sensors : int list = [(Z.of_nativeint (1n)); (Z.of_nativeint (2n))]
)</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-c16b61fc-697a-4e6a-bcdf-8c3a8a716430';
  fold.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-2e559496-a754-455f-af2f-c9ab54ee1e10"><textarea style="display: none">digraph &quot;proof&quot; {
p_77 [label=&quot;Start (let (_x_0 : (state * int list))\l           = run\l             \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l              policy = …; conflict = …\}\l             (List.take … ( :var_0: ))\l       in not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = []) :time 0.058s)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_77 -&gt; p_76 [label=&quot;&quot;];
p_76 [label=&quot;Simplify (let (_x_0 : (state * int list))\l              = run\l                \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l                 policy = …; conflict = …\}\l                (List.take 5 ( :var_0: ))\l          in not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = []) :expansions []\l          :rw [] :fc [])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_76 -&gt; p_75 [label=&quot;&quot;];
p_75 [label=&quot;Unroll ([List.take 5 sensors], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_75 -&gt; p_74 [label=&quot;&quot;];
p_74 [label=&quot;Unroll ([…], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_74 -&gt; p_73 [label=&quot;&quot;];
p_73 [label=&quot;Unroll ([run\l         \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l          conflict = …\}\l         (List.take 5 sensors)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_73 -&gt; p_72 [label=&quot;&quot;];
p_72 [label=&quot;Unroll ([…], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_72 -&gt; p_71 [label=&quot;&quot;];
p_71 [label=&quot;Unroll ([List.take 4 (List.tl sensors)], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_71 -&gt; p_70 [label=&quot;&quot;];
p_70 [label=&quot;Unroll ([mk_agents_map\l         (\{agent_id = Node …; guard = Eq (…, 2); accesses = Banana\} ::\l          (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_70 -&gt; p_69 [label=&quot;&quot;];
p_69 [label=&quot;Unroll ([Map.of_list Sharable [(Banana, Unsharable); (…, Sharable)]], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_69 -&gt; p_68 [label=&quot;&quot;];
p_68 [label=&quot;Unroll ([mk_agents_map\l         (\{agent_id = …; guard = …; accesses = …\} :: (… :: …))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_68 -&gt; p_67 [label=&quot;&quot;];
p_67 [label=&quot;Unroll ([Map.of_list Sharable [(…, Sharable)]], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_67 -&gt; p_66 [label=&quot;&quot;];
p_66 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Option.get (Map.get' … D)).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_66 -&gt; p_65 [label=&quot;&quot;];
p_65 [label=&quot;Unroll ([mk_agents_map (… :: …)], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_65 -&gt; p_64 [label=&quot;&quot;];
p_64 [label=&quot;Unroll ([Map.of_list Sharable []], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_64 -&gt; p_63 [label=&quot;&quot;];
p_63 [label=&quot;Unroll ([mk_agents_map …], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_63 -&gt; p_62 [label=&quot;&quot;];
p_62 [label=&quot;Unroll ([mk_agents_map [\{agent_id = Node …; guard = …; accesses = Apple\}]],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_62 -&gt; p_61 [label=&quot;&quot;];
p_61 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Option.get (Map.get' (mk_agents_map …) A)).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_61 -&gt; p_60 [label=&quot;&quot;];
p_60 [label=&quot;Unroll ([mk_agents_map []], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_60 -&gt; p_59 [label=&quot;&quot;];
p_59 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         run\l         (step\l          \{wf_1 = A :: …; wf_2 = … :: …; sensor = None;\l           agents = mk_agents_map …; policy = Map.of_list … …;\l           conflict = None\}\l          (List.hd _x_0))\l         (List.tl _x_0)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_59 -&gt; p_58 [label=&quot;&quot;];
p_58 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         let (_x_1 : state)\l             = step\l               \{wf_1 = A :: …; wf_2 = … :: …; sensor = None;\l                agents = mk_agents_map …; policy = Map.of_list … …;\l                conflict = None\}\l               (List.hd _x_0)\l         in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_58 -&gt; p_57 [label=&quot;&quot;];
p_57 [label=&quot;Unroll ([List.take 3 (List.tl (List.tl sensors))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_57 -&gt; p_56 [label=&quot;&quot;];
p_56 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 1, (Option.get …).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_56 -&gt; p_55 [label=&quot;&quot;];
p_55 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         let (_x_1 : state)\l             = step\l               \{wf_1 = A :: …; wf_2 = … :: …; sensor = None;\l                agents = mk_agents_map …; policy = Map.of_list … …;\l                conflict = None\}\l               (List.hd _x_0)\l         in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_55 -&gt; p_54 [label=&quot;&quot;];
p_54 [label=&quot;Sat (Some let sensors : int list = [(Z.of_nativeint (1n)); (Z.of_nativeint (2n))]\l)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-2e559496-a754-455f-af2f-c9ab54ee1e10';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-0fccff63-36f6-432c-b8ac-ae646e641f76';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-014e1dee-c47e-4012-9cbd-a71b6d368204';
  fold.hydrate(target);
});
</script></div></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-3bd86697-e1c3-4ca8-8be8-bad16a2825b0';
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




Are conflicts possible? Let's ask Imandra!


```ocaml
instance (fun sensors -> conflict_reachable ex_2 sensors)
```




    - : Z.t list -> bool = <fun>





<div><div style="font-size: 1.2em; padding: 0.5em; border-top: 1px dashed #D84315; border-bottom: 1px dashed #D84315"><i class="fa fa-times-circle-o" style="margin-right: 0.5em; color: #D84315"></i><span>Unsatisfiable</span></div><div><div class="imandra-alternatives" id="alt-06bbaad8-6a1f-48f7-9d9a-b6be441b9b8e"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>proof</a></li><li class="" data-toggle="tab"><a>call graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-proof-top"><div class="imandra-fold panel panel-default" id="fold-dece381a-5815-4035-afce-98150870128e"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>proof</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-668bb23e-6b13-4661-8887-11dfdfca53f5"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li><li class="" data-toggle="tab"><a>graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-ebe39359-6e51-48e1-94ad-36687a8ddd02"><table><tr><td>ground_instances:</td><td>37</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.727s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-ea4f20cf-ab47-4051-aa44-68e80661705b"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-efa60d73-b2ca-4b07-8b85-e7bc94c0bdd6"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-ec790fa0-1e76-4377-a53a-40a68a642bd3"><table><tr><td>array def const:</td><td>2</td></tr><tr><td>num checks:</td><td>75</td></tr><tr><td>array sel const:</td><td>734</td></tr><tr><td>array def store:</td><td>1594</td></tr><tr><td>array exp ax2:</td><td>2235</td></tr><tr><td>array splits:</td><td>382</td></tr><tr><td>rlimit count:</td><td>3193225</td></tr><tr><td>array ext ax:</td><td>192</td></tr><tr><td>mk clause:</td><td>7686</td></tr><tr><td>array ax1:</td><td>9</td></tr><tr><td>datatype occurs check:</td><td>31464</td></tr><tr><td>restarts:</td><td>5</td></tr><tr><td>mk bool var:</td><td>113837</td></tr><tr><td>array ax2:</td><td>4870</td></tr><tr><td>datatype splits:</td><td>31964</td></tr><tr><td>decisions:</td><td>172099</td></tr><tr><td>propagations:</td><td>116889</td></tr><tr><td>conflicts:</td><td>1173</td></tr><tr><td>datatype accessor ax:</td><td>2542</td></tr><tr><td>minimized lits:</td><td>621</td></tr><tr><td>datatype constructor ax:</td><td>95261</td></tr><tr><td>num allocs:</td><td>186772757</td></tr><tr><td>final checks:</td><td>798</td></tr><tr><td>added eqs:</td><td>601779</td></tr><tr><td>del clause:</td><td>6344</td></tr><tr><td>time:</td><td>0.003000</td></tr><tr><td>memory:</td><td>27.810000</td></tr><tr><td>max memory:</td><td>27.900000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-ea4f20cf-ab47-4051-aa44-68e80661705b';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-e83b9214-0f95-4898-8316-ffbe45e9a7ea"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.727s]
  let (_x_0 : (state * int list))
      = run
        {wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;
         conflict = …}
        (List.take … ( :var_0: ))
  in not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = [])</pre></li><li><div><h4>simplify</h4><div class="imandra-table" id="table-9ac127f4-039f-43fb-bf71-9ddda3153236"><table><tr><td>into:</td><td><pre>let (_x_0 : (state * int list))
    = run
      {wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;
       conflict = …}
      (List.take 5 ( :var_0: ))
in not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = [])</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-9cc6dcb5-e15e-48d0-b960-d447a858eb03"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-36ad2d2a-fcf9-45f0-b8b0-078351a653d6"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1219/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-a71a308d-32c3-45a9-b1fb-f790f20c3f47"><table><tr><td>expr:</td><td><pre>(|List.take_1244/server| 5 sensors_1436/client)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-d6174b0a-7cef-4849-b909-f0f332562716"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (tuple_mk_1229/server Apple_1272/client Unsharable_1279/client)
                 (|…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-bad117fa-93a7-4a36-a8dd-2db01e6fdad3"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1219/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-943a7669-6d6f-4c38-8e48-07fa78fe46ff"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1219/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-1eb09a45-e552-471a-ad1c-9f8feb38787b"><table><tr><td>expr:</td><td><pre>(|List.take_1244/server| 4 (|get.::.1_1212/server| sensors_1436/client))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-d6aa8a9c-5ff8-4f2c-b181-e1aa45c83a28"><table><tr><td>expr:</td><td><pre>(|Map.of_list_1237/server|
  Sharable_1278/client
  (|::| (tuple_mk_1229/server Banana_1273/client S…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-38ba11fc-8881-4c78-99e0-f90e768566f5"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1219/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-2c83f6de-26e0-4ea3-9c92-eeea4ed9951d"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1219/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-c3d7589f-d5b6-40de-9a05-45fd8043de54"><table><tr><td>expr:</td><td><pre>(|Map.of_list_1237/server|
  Sharable_1278/client
  (|::| (tuple_mk_1229/server Orange_1274/client S…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-779a0f45-1cd5-4235-86ce-4386f05ff17c"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1219/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-6aac1856-ac94-4f31-8f96-5aa86d45d3c1"><table><tr><td>expr:</td><td><pre>(|Map.of_list_1237/server| Sharable_1278/client |[]|)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-1d96e565-dd4d-474d-815b-f0b773eecc8c"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1219/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-17400c3e-3601-4551-9692-716913504d8c"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-1ac70323-179e-4000-b704-0e62b15dbe22"><table><tr><td>expr:</td><td><pre>(mk_agents_map_1408/client
  (|::| (|rec_mk.agent_1219/server|
          (Node_1246/client F_1252/cl…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-2e582232-45c8-48de-8e1d-becb7e435280"><table><tr><td>expr:</td><td><pre>(mk_agents_map_1408/client |[]|)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-e00495c5-7f62-4751-9038-74ceb97c016c"><table><tr><td>expr:</td><td><pre>(|List.take_1244/server|
  3
  (|get.::.1_1212/server| (|get.::.1_1212/server| sensors_1436/client))…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-c7270605-0c11-4c8a-912d-76d9db22d595"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-117cc80f-1f67-48d9-a1bd-4755d1751769"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1219/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-fa0f23f0-66ec-44eb-81c8-ef47e14afb30"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-2a640fb9-9cba-4bf6-ba1c-e3f384513406"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-25bd1b82-74f7-4c68-8f13-0c740e1eadfb"><table><tr><td>expr:</td><td><pre>(|List.take_1244/server|
  2
  (|get.::.1_1212/server|
    (|get.::.1_1212/server| (|get.::.1_1212/s…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-be2c4739-b129-42fb-8615-bdfda5b9ab7b"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.0_1211/server|
             (|get.::.1_1212/server|
               (|get.::.1_12…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-1902fb2d-0554-4052-9e67-012da164a568"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1219/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-e9d5123d-b2c9-4d69-beb1-d83fd197a85d"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.0_1211/server|
             (|get.::.1_1212/server|
               (|get.::.1_12…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-2630de2d-27c1-460b-8b6b-fa677a4dfc03"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-36891e60-a9d7-4192-baba-78c59b264305"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_1212/server|
             (|get.::.1_1212/server|
               (|get.::.1_12…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-1d0bed03-3d7e-4ddb-9dac-6b3fcd88897a"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_1212/server|
             (|get.::.1_1212/server|
               (|get.::.1_12…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-8023c5c9-3858-4dbb-83de-9fcef1dfc63b"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1219/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-b0f7fb34-2162-4cf6-91c2-9ba43877390a"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_1212/server|
             (|get.::.1_1212/server|
               (|get.::.1_12…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-9e7872e3-3cff-4328-8f7b-b9b892232c02"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-dec13bd2-cc98-4d18-a144-a404f04ba580"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_1212/server|
             (|get.::.1_1212/server|
               (|get.::.1_12…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-3ac172ba-fd15-45cf-90bc-e3f5c8967a97"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_1212/server|
             (|get.::.1_1212/server|
               (|get.::.1_12…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-f931c73d-bc16-4afb-b452-3bcc5225e248"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1219/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-897c2eb5-2819-4a26-8ba0-59eb7f047d5a"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_1212/server|
             (|get.::.1_1212/server|
               (|get.::.1_12…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-bc11d3eb-a9c5-46aa-9bd2-3a1694335196"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li>Unsat</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-e83b9214-0f95-4898-8316-ffbe45e9a7ea';
  fold.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-6f3a1ddc-9f33-41f1-9fa7-f9a0f506a796"><textarea style="display: none">digraph &quot;proof&quot; {
p_117 [label=&quot;Start (let (_x_0 : (state * int list))\l           = run\l             \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l              policy = …; conflict = …\}\l             (List.take … ( :var_0: ))\l       in not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = []) :time 0.727s)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_117 -&gt; p_116 [label=&quot;&quot;];
p_116 [label=&quot;Simplify (let (_x_0 : (state * int list))\l              = run\l                \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l                 policy = …; conflict = …\}\l                (List.take 5 ( :var_0: ))\l          in not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = []) :expansions []\l          :rw [] :fc [])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_116 -&gt; p_115 [label=&quot;&quot;];
p_115 [label=&quot;Unroll ([run\l         \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l          conflict = …\}\l         (List.take 5 sensors)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_115 -&gt; p_114 [label=&quot;&quot;];
p_114 [label=&quot;Unroll ([mk_agents_map\l         (\{agent_id = Node …; guard = Eq (…, 1); accesses = Apple\} ::\l          (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_114 -&gt; p_113 [label=&quot;&quot;];
p_113 [label=&quot;Unroll ([List.take 5 sensors], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_113 -&gt; p_112 [label=&quot;&quot;];
p_112 [label=&quot;Unroll ([Map.of_list Sharable\l         ((Apple, Unsharable) :: ((…, Sharable) :: (… :: …)))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_112 -&gt; p_111 [label=&quot;&quot;];
p_111 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Option.get (Map.get' … D)).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_111 -&gt; p_110 [label=&quot;&quot;];
p_110 [label=&quot;Unroll ([mk_agents_map\l         (\{agent_id = Node …; guard = Eq (…, 2); accesses = Banana\} ::\l          (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_110 -&gt; p_109 [label=&quot;&quot;];
p_109 [label=&quot;Unroll ([List.take 4 (List.tl sensors)], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_109 -&gt; p_108 [label=&quot;&quot;];
p_108 [label=&quot;Unroll ([Map.of_list Sharable [(Banana, Sharable); (…, Sharable)]], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_108 -&gt; p_107 [label=&quot;&quot;];
p_107 [label=&quot;Unroll ([mk_agents_map\l         (\{agent_id = …; guard = …; accesses = …\} :: (… :: …))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_107 -&gt; p_106 [label=&quot;&quot;];
p_106 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Option.get (Map.get' … A)).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_106 -&gt; p_105 [label=&quot;&quot;];
p_105 [label=&quot;Unroll ([Map.of_list Sharable [(…, Sharable)]], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_105 -&gt; p_104 [label=&quot;&quot;];
p_104 [label=&quot;Unroll ([mk_agents_map (… :: …)], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_104 -&gt; p_103 [label=&quot;&quot;];
p_103 [label=&quot;Unroll ([Map.of_list Sharable []], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_103 -&gt; p_102 [label=&quot;&quot;];
p_102 [label=&quot;Unroll ([mk_agents_map …], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_102 -&gt; p_101 [label=&quot;&quot;];
p_101 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         run\l         (step\l          \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l           conflict = …\}\l          (List.hd _x_0))\l         (List.tl _x_0)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_101 -&gt; p_100 [label=&quot;&quot;];
p_100 [label=&quot;Unroll ([mk_agents_map [\{agent_id = Node …; guard = …; accesses = Apple\}]],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_100 -&gt; p_99 [label=&quot;&quot;];
p_99 [label=&quot;Unroll ([mk_agents_map []], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_99 -&gt; p_98 [label=&quot;&quot;];
p_98 [label=&quot;Unroll ([List.take 3 (List.tl (List.tl sensors))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_98 -&gt; p_97 [label=&quot;&quot;];
p_97 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         let (_x_1 : state)\l             = step\l               \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l                policy = …; conflict = …\}\l               (List.hd _x_0)\l         in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_97 -&gt; p_96 [label=&quot;&quot;];
p_96 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 1, (Option.get (Map.get' … D)).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_96 -&gt; p_95 [label=&quot;&quot;];
p_95 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         let (_x_1 : state)\l             = step\l               \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l                policy = …; conflict = …\}\l               (List.hd _x_0)\l         in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_95 -&gt; p_94 [label=&quot;&quot;];
p_94 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         let (_x_1 : int list) = List.tl _x_0 in\l         run\l         (step\l          (step\l           \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l            conflict = …\}\l           (List.hd _x_0))\l          (List.hd _x_1))\l         (List.tl _x_1)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_94 -&gt; p_93 [label=&quot;&quot;];
p_93 [label=&quot;Unroll ([List.take 2 (List.tl (List.tl (List.tl sensors)))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_93 -&gt; p_92 [label=&quot;&quot;];
p_92 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : state)\l             = step\l               (step\l                \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l                 policy = …; conflict = …\}\l                (List.hd _x_0))\l               (List.hd _x_1)\l         in\l         eval_guard (List.hd (List.tl _x_1))\l         (Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_92 -&gt; p_91 [label=&quot;&quot;];
p_91 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 0, (Option.get (Map.get' … D)).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_91 -&gt; p_90 [label=&quot;&quot;];
p_90 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : state)\l             = step\l               (step\l                \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l                 policy = …; conflict = …\}\l                (List.hd _x_0))\l               (List.hd _x_1)\l         in\l         eval_guard (List.hd (List.tl _x_1))\l         (Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_90 -&gt; p_89 [label=&quot;&quot;];
p_89 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : int list) = List.tl _x_1 in\l         run\l         (step\l          (step\l           (step\l            \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l             policy = …; conflict = …\}\l            (List.hd _x_0))\l           (List.hd _x_1))\l          (List.hd _x_2))\l         (List.tl _x_2)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_89 -&gt; p_88 [label=&quot;&quot;];
p_88 [label=&quot;Unroll ([List.take 1 (List.tl (List.tl (List.tl (List.tl sensors))))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_88 -&gt; p_87 [label=&quot;&quot;];
p_87 [label=&quot;Unroll ([eval_guard\l         (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l         (Option.get (Map.get' ….agents (List.hd ….wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_87 -&gt; p_86 [label=&quot;&quot;];
p_86 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 1, (Option.get …).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_86 -&gt; p_85 [label=&quot;&quot;];
p_85 [label=&quot;Unroll ([eval_guard\l         (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l         (Option.get (Map.get' ….agents (List.hd ….wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_85 -&gt; p_84 [label=&quot;&quot;];
p_84 [label=&quot;Unroll ([let (_x_0 : int list)\l             = List.tl (List.tl (List.tl (List.take 5 sensors)))\l         in run (step … (List.hd _x_0)) (List.tl _x_0)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_84 -&gt; p_83 [label=&quot;&quot;];
p_83 [label=&quot;Unroll ([List.take 0\l         (List.tl (List.tl (List.tl (List.tl (List.tl sensors)))))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_83 -&gt; p_82 [label=&quot;&quot;];
p_82 [label=&quot;Unroll ([let (_x_0 : int list)\l             = List.tl (List.tl (List.tl (List.take 5 sensors)))\l         in\l         let (_x_1 : state) = step … (List.hd _x_0) in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_82 -&gt; p_81 [label=&quot;&quot;];
p_81 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 0, (Option.get …).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_81 -&gt; p_80 [label=&quot;&quot;];
p_80 [label=&quot;Unroll ([let (_x_0 : int list)\l             = List.tl (List.tl (List.tl (List.take 5 sensors)))\l         in\l         let (_x_1 : state) = step … (List.hd _x_0) in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_80 -&gt; p_79 [label=&quot;&quot;];
p_79 [label=&quot;Unroll ([let (_x_0 : int list)\l             = List.tl (List.tl (List.tl (List.take 5 sensors)))\l         in\l         let (_x_1 : int list) = List.tl _x_0 in\l         run (step (step … (List.hd _x_0)) (List.hd _x_1)) (List.tl _x_1)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_79 -&gt; p_78 [label=&quot;&quot;];
p_78 [label=&quot;Unsat&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-6f3a1ddc-9f33-41f1-9fa7-f9a0f506a796';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-668bb23e-6b13-4661-8887-11dfdfca53f5';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-dece381a-5815-4035-afce-98150870128e';
  fold.hydrate(target);
});
</script></div></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-b38b924f-fef0-498f-82aa-810d8a6c7743"><textarea style="display: none">digraph &quot;call graph&quot; {
goal [label=&quot;let (_x_0 : (state * int list))\l    = run\l      \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l       conflict = …\}\l      (List.take 5 sensors)\lin not (_x_0.0.conflict = None) &amp;&amp; (_x_0.1 = [])&quot;,shape=box,style=filled,color=&quot;cyan&quot;,fontname=&quot;courier&quot;,fontsize=14];
goal -&gt; call_66 [label=&quot;calls&quot;];
goal -&gt; call_124 [label=&quot;calls&quot;];
goal -&gt; call_154 [label=&quot;calls&quot;];
goal -&gt; call_127 [label=&quot;calls&quot;];
call_66 [label=&quot;Map.of_list Sharable\l((Apple, Unsharable) :: ((…, Sharable) :: (… :: …)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_66 -&gt; call_2031 [label=&quot;calls&quot;];
call_124 [label=&quot;List.take 5 sensors&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_124 -&gt; call_1846 [label=&quot;calls&quot;];
call_154 [label=&quot;run\l\{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l conflict = …\}\l(List.take 5 sensors)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_154 -&gt; call_1040 [label=&quot;calls&quot;];
call_154 -&gt; call_1024 [label=&quot;calls&quot;];
call_154 -&gt; call_1008 [label=&quot;calls&quot;];
call_127 [label=&quot;mk_agents_map\l(\{agent_id = Node …; guard = Eq (…, 1); accesses = Apple\} ::\l (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_127 -&gt; call_1733 [label=&quot;calls&quot;];
call_2031 [label=&quot;Map.of_list Sharable [(Banana, Sharable); (…, Sharable)]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2031 -&gt; call_2742 [label=&quot;calls&quot;];
call_1846 [label=&quot;List.take 4 (List.tl sensors)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1846 -&gt; call_2596 [label=&quot;calls&quot;];
call_1040 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Option.get (Map.get' … A)).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1040 -&gt; call_3103 [label=&quot;calls&quot;];
call_1040 -&gt; call_3101 [label=&quot;calls&quot;];
call_1024 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Option.get (Map.get' … D)).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1024 -&gt; call_2185 [label=&quot;calls&quot;];
call_1024 -&gt; call_2183 [label=&quot;calls&quot;];
call_1008 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\lrun\l(step\l \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l  conflict = …\}\l (List.hd _x_0))\l(List.tl _x_0)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1008 -&gt; call_4199 [label=&quot;calls&quot;];
call_1008 -&gt; call_4189 [label=&quot;calls&quot;];
call_1008 -&gt; call_4204 [label=&quot;calls&quot;];
call_1733 [label=&quot;mk_agents_map\l(\{agent_id = Node …; guard = Eq (…, 2); accesses = Banana\} ::\l (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1733 -&gt; call_2464 [label=&quot;calls&quot;];
call_2742 [label=&quot;Map.of_list Sharable [(…, Sharable)]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2742 -&gt; call_3329 [label=&quot;calls&quot;];
call_2596 [label=&quot;List.take 3 (List.tl (List.tl sensors))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2596 -&gt; call_6165 [label=&quot;calls&quot;];
call_3103 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3103 -&gt; call_22070 [label=&quot;calls&quot;];
call_3103 -&gt; call_22068 [label=&quot;calls&quot;];
call_3101 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3101 -&gt; call_26177 [label=&quot;calls&quot;];
call_3101 -&gt; call_26175 [label=&quot;calls&quot;];
call_2185 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, (Option.get (Map.get' … D)).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2185 -&gt; call_7550 [label=&quot;calls&quot;];
call_2185 -&gt; call_7548 [label=&quot;calls&quot;];
call_2183 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, (Option.get (Map.get' … D)).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2183 -&gt; call_11024 [label=&quot;calls&quot;];
call_2183 -&gt; call_11022 [label=&quot;calls&quot;];
call_4199 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : state)\l    = step\l      \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l       conflict = …\}\l      (List.hd _x_0)\lin\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4199 -&gt; call_6716 [label=&quot;calls&quot;];
call_4199 -&gt; call_6714 [label=&quot;calls&quot;];
call_4189 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : int list) = List.tl _x_0 in\lrun\l(step\l (step\l  \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l   conflict = …\}\l  (List.hd _x_0))\l (List.hd _x_1))\l(List.tl _x_1)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4189 -&gt; call_8671 [label=&quot;calls&quot;];
call_4189 -&gt; call_8686 [label=&quot;calls&quot;];
call_4189 -&gt; call_8681 [label=&quot;calls&quot;];
call_4204 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : state)\l    = step\l      \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l       conflict = …\}\l      (List.hd _x_0)\lin\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4204 -&gt; call_8102 [label=&quot;calls&quot;];
call_4204 -&gt; call_8100 [label=&quot;calls&quot;];
call_2464 [label=&quot;mk_agents_map (\{agent_id = …; guard = …; accesses = …\} :: (… :: …))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2464 -&gt; call_2972 [label=&quot;calls&quot;];
call_3329 [label=&quot;Map.of_list Sharable []&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3329 -&gt; call_3750 [label=&quot;calls&quot;];
call_6165 [label=&quot;List.take 2 (List.tl (List.tl (List.tl sensors)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6165 -&gt; call_9933 [label=&quot;calls&quot;];
call_22070 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_22068 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_26177 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_26175 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_7550 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_7548 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_11024 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_11022 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6716 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6714 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_8671 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : int list) = List.tl _x_1 in\lrun\l(step\l (step\l  (step\l   \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l    conflict = …\}\l   (List.hd _x_0))\l  (List.hd _x_1))\l (List.hd _x_2))\l(List.tl _x_2)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_8671 -&gt; call_13778 [label=&quot;calls&quot;];
call_8671 -&gt; call_13773 [label=&quot;calls&quot;];
call_8671 -&gt; call_13763 [label=&quot;calls&quot;];
call_8686 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : state)\l    = step\l      (step\l       \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l        conflict = …\}\l       (List.hd _x_0))\l      (List.hd _x_1)\lin\leval_guard (List.hd (List.tl _x_1))\l(Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_8686 -&gt; call_11627 [label=&quot;calls&quot;];
call_8686 -&gt; call_11625 [label=&quot;calls&quot;];
call_8681 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : state)\l    = step\l      (step\l       \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l        conflict = …\}\l       (List.hd _x_0))\l      (List.hd _x_1)\lin\leval_guard (List.hd (List.tl _x_1))\l(Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_8681 -&gt; call_10741 [label=&quot;calls&quot;];
call_8681 -&gt; call_10739 [label=&quot;calls&quot;];
call_8102 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_8100 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2972 [label=&quot;mk_agents_map (… :: …)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2972 -&gt; call_3525 [label=&quot;calls&quot;];
call_3750 [label=&quot;Map.of_list Sharable (List.tl [])&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_9933 [label=&quot;List.take 1 (List.tl (List.tl (List.tl (List.tl sensors))))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_9933 -&gt; call_14425 [label=&quot;calls&quot;];
call_13778 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Option.get (Map.get' ….agents (List.hd ….wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_13778 -&gt; call_22336 [label=&quot;calls&quot;];
call_13778 -&gt; call_22334 [label=&quot;calls&quot;];
call_13773 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Option.get (Map.get' ….agents (List.hd ….wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_13773 -&gt; call_15449 [label=&quot;calls&quot;];
call_13773 -&gt; call_15447 [label=&quot;calls&quot;];
call_13763 [label=&quot;let (_x_0 : int list) = List.tl (List.tl (List.tl (List.take 5 sensors))) in\lrun (step … (List.hd _x_0)) (List.tl _x_0)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_13763 -&gt; call_23342 [label=&quot;calls&quot;];
call_13763 -&gt; call_23327 [label=&quot;calls&quot;];
call_13763 -&gt; call_23337 [label=&quot;calls&quot;];
call_11627 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_11625 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_10741 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_10739 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3525 [label=&quot;mk_agents_map …&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3525 -&gt; call_3976 [label=&quot;calls&quot;];
call_14425 [label=&quot;List.take 0 (List.tl (List.tl (List.tl (List.tl (List.tl sensors)))))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_14425 -&gt; call_24522 [label=&quot;calls&quot;];
call_22336 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_22334 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_15449 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_15447 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_23342 [label=&quot;let (_x_0 : int list) = List.tl (List.tl (List.tl (List.take 5 sensors))) in\llet (_x_1 : state) = step … (List.hd _x_0) in\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_23342 -&gt; call_26405 [label=&quot;calls&quot;];
call_23342 -&gt; call_26403 [label=&quot;calls&quot;];
call_23327 [label=&quot;let (_x_0 : int list) = List.tl (List.tl (List.tl (List.take 5 sensors))) in\llet (_x_1 : int list) = List.tl _x_0 in\lrun (step (step … (List.hd _x_0)) (List.hd _x_1)) (List.tl _x_1)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_23327 -&gt; call_28956 [label=&quot;calls&quot;];
call_23327 -&gt; call_28966 [label=&quot;calls&quot;];
call_23327 -&gt; call_28971 [label=&quot;calls&quot;];
call_23337 [label=&quot;let (_x_0 : int list) = List.tl (List.tl (List.tl (List.take 5 sensors))) in\llet (_x_1 : state) = step … (List.hd _x_0) in\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_23337 -&gt; call_25872 [label=&quot;calls&quot;];
call_23337 -&gt; call_25870 [label=&quot;calls&quot;];
call_3976 [label=&quot;mk_agents_map [\{agent_id = Node …; guard = …; accesses = Apple\}]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3976 -&gt; call_5388 [label=&quot;calls&quot;];
call_24522 [label=&quot;List.take (-1) (List.tl (List.tl …))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_26405 [label=&quot;eval_guard\l(List.hd (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors))))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_26403 [label=&quot;eval_guard\l(List.hd (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors))))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_28956 [label=&quot;let (_x_0 : int list)\l    = List.tl (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors)))))\lin run (step … (List.hd _x_0)) (List.tl _x_0)&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_28966 [label=&quot;eval_guard\l(List.hd\l (List.tl (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors)))))))\l(Option.get (Map.get' ….agents (List.hd ….wf_2))).guard&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_28971 [label=&quot;eval_guard\l(List.hd\l (List.tl (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors)))))))\l(Option.get (Map.get' ….agents (List.hd ….wf_1))).guard&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_25872 [label=&quot;eval_guard\l(List.hd (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors))))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_25870 [label=&quot;eval_guard\l(List.hd (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors))))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5388 [label=&quot;mk_agents_map []&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5388 -&gt; call_5654 [label=&quot;calls&quot;];
call_5654 [label=&quot;mk_agents_map (List.tl [])&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-b38b924f-fef0-498f-82aa-810d8a6c7743';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-06bbaad8-6a1f-48f7-9d9a-b6be441b9b8e';
  alternatives.hydrate(target);
});
</script></div></div></div>



# This means no conflicts are possible for Problem 2!

Imandra has *proved* that this goal is unsatisfiable, i.e., that no such conflict is possible. In fact, we can use Imandra's *verify* command to restate this as a safety property and prove it:


```ocaml
verify (fun sensors -> not (conflict_reachable ex_2 sensors))
```




    - : Z.t list -> bool = <fun>





<div><div style="font-size: 1.2em; padding: 0.5em; border-top: 1px solid green; border-bottom: 1px solid green"><i class="fa fa-check-circle" style="margin-right: 0.5em; color: green"></i><span>Proved</span></div><div><div class="imandra-alternatives" id="alt-f000c0b1-99b3-4431-b1b4-5f16af3b6a67"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>proof</a></li><li class="" data-toggle="tab"><a>call graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-proof-top"><div class="imandra-fold panel panel-default" id="fold-3c72ec03-ef8a-4187-a80f-fde6d5292016"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>proof</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-d5e6d274-7e96-4636-9730-227309aba041"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li><li class="" data-toggle="tab"><a>graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-bf536bfa-151f-42fd-a09c-2bc2fd1a2035"><table><tr><td>ground_instances:</td><td>39</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.233s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-52c753c5-cb16-43e1-ad56-ada98e111d91"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-81b4a4e3-49e8-4255-9aa7-0a1631f1f484"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-f953c6cf-aa42-4f78-98eb-e902df6fe33a"><table><tr><td>array def const:</td><td>2</td></tr><tr><td>num checks:</td><td>79</td></tr><tr><td>array sel const:</td><td>270</td></tr><tr><td>array def store:</td><td>340</td></tr><tr><td>array exp ax2:</td><td>620</td></tr><tr><td>array splits:</td><td>143</td></tr><tr><td>rlimit count:</td><td>602884</td></tr><tr><td>array ext ax:</td><td>57</td></tr><tr><td>mk clause:</td><td>2812</td></tr><tr><td>array ax1:</td><td>10</td></tr><tr><td>datatype occurs check:</td><td>10617</td></tr><tr><td>restarts:</td><td>1</td></tr><tr><td>mk bool var:</td><td>23138</td></tr><tr><td>array ax2:</td><td>1808</td></tr><tr><td>datatype splits:</td><td>5336</td></tr><tr><td>decisions:</td><td>26717</td></tr><tr><td>propagations:</td><td>26724</td></tr><tr><td>conflicts:</td><td>646</td></tr><tr><td>datatype accessor ax:</td><td>1702</td></tr><tr><td>minimized lits:</td><td>511</td></tr><tr><td>datatype constructor ax:</td><td>13332</td></tr><tr><td>num allocs:</td><td>336747425</td></tr><tr><td>final checks:</td><td>311</td></tr><tr><td>added eqs:</td><td>129986</td></tr><tr><td>del clause:</td><td>1974</td></tr><tr><td>time:</td><td>0.003000</td></tr><tr><td>memory:</td><td>29.200000</td></tr><tr><td>max memory:</td><td>29.300000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-52c753c5-cb16-43e1-ad56-ada98e111d91';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-472c4502-fe5e-443e-b6ce-543b4f61f352"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.233s]
  let (_x_0 : (state * int list))
      = run
        {wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;
         conflict = …}
        (List.take … ( :var_0: ))
  in not (not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = []))</pre></li><li><div><h4>simplify</h4><div class="imandra-table" id="table-79695f25-e5c1-42a9-87e5-565a2a830fd2"><table><tr><td>into:</td><td><pre>let (_x_0 : (state * int list))
    = run
      {wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;
       conflict = …}
      (List.take 5 ( :var_0: ))
in not (not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = []))</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-d6372abc-8a46-4d81-8b5a-de961a50f21b"><table><tr><td>expr:</td><td><pre>(|List.take_1448/server| 5 sensors_1438/client)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-11937124-aaa4-4d59-9cde-8c949d4da272"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1423/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-376dae8e-4657-4ba8-a62c-48443d521abd"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-8f986d89-b1f4-4168-b6e5-97b08075c5a2"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (tuple_mk_1433/server Apple_1272/client Unsharable_1279/client)
                 (|…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-5fa77e4a-1bd0-4095-ad0d-5c2ea47e7065"><table><tr><td>expr:</td><td><pre>(|List.take_1448/server| 4 (|get.::.1_1416/server| sensors_1438/client))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-3a1a124d-3576-401c-803c-6f53746878bb"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1423/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-f025c9ae-e26c-4f30-8676-3090394e8855"><table><tr><td>expr:</td><td><pre>(|Map.of_list_1441/server|
  Sharable_1278/client
  (|::| (tuple_mk_1433/server Banana_1273/client S…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-80d0c70b-dd59-467c-a751-af5e0f7e9022"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1423/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-42c64d32-83cd-4e7b-bbe3-826d2a636972"><table><tr><td>expr:</td><td><pre>(|Map.of_list_1441/server|
  Sharable_1278/client
  (|::| (tuple_mk_1433/server Orange_1274/client S…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-62e9c28f-96cc-46ae-a87f-499334f9a6d3"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1423/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-440c798b-8c40-46f4-a800-27f137df3776"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1423/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-3e9d3be4-a458-43d1-bc8f-54a956bf4590"><table><tr><td>expr:</td><td><pre>(|Map.of_list_1441/server| Sharable_1278/client |[]|)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-784e2712-d06d-4c05-bbc1-f9c5137e34ac"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1423/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-b9c25103-171f-4ac6-bc09-a2d38e016dcc"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-1ebb47d3-7742-4da5-8568-652864f835cd"><table><tr><td>expr:</td><td><pre>(|List.take_1448/server|
  3
  (|get.::.1_1416/server| (|get.::.1_1416/server| sensors_1438/client))…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-bf1963bc-0493-4a12-b4a4-28ed23c8099a"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1423/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-c7ed4599-41ef-47a7-a6c8-af49758f62f3"><table><tr><td>expr:</td><td><pre>(mk_agents_map_1408/client
  (|::| (|rec_mk.agent_1423/server|
          (Node_1246/client F_1252/cl…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-269c4adf-7fa8-4c17-a91b-8954c9a22dac"><table><tr><td>expr:</td><td><pre>(mk_agents_map_1408/client |[]|)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-d4605378-2b81-4d81-b421-1d64d0775e36"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-7b727eee-451f-4569-b5fa-a13d34054301"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1423/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-d3b5beaa-5114-4d8d-a5f7-8b3d9d5ecd37"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-8cd9f557-a6a3-4c9c-9205-bafedb071c9a"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-293746bc-929e-4f68-94d1-43591f6f8c05"><table><tr><td>expr:</td><td><pre>(|List.take_1448/server|
  2
  (|get.::.1_1416/server|
    (|get.::.1_1416/server| (|get.::.1_1416/s…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-c541bc3a-6cb8-4bf7-9840-a2d82e078175"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.0_1415/server|
             (|get.::.1_1416/server|
               (|get.::.1_14…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-d76eb4f2-7772-4650-8a35-2355b01edf9c"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1423/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-73f19f48-eac0-4b95-baae-849c5e9a6f01"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.0_1415/server|
             (|get.::.1_1416/server|
               (|get.::.1_14…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-ff1a497c-ba51-42b2-91f5-3c751b545837"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-a625721e-1be5-4e0b-936f-53ef7a4963cf"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_1416/server|
             (|get.::.1_1416/server|
               (|get.::.1_14…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-4d3694fa-b6ee-4ebf-89ad-27ad9ae67ecb"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_1416/server|
             (|get.::.1_1416/server|
               (|get.::.1_14…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-4e666e43-6d3d-43d5-af8d-d572111a2865"><table><tr><td>expr:</td><td><pre>(|Map.of_list_1441/server| Sharable_1278/client (|get.::.1_1438/server| |[]|))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-e5e751cb-b4d3-4b65-9c72-1474692898b1"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_1416/server|
             (|get.::.1_1416/server|
               (|get.::.1_14…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-a7523217-43b4-40e7-a1e1-4cc84be36f96"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-06db7740-c1ec-4411-b5c0-0b9bd14477b5"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_1416/server|
             (|get.::.1_1416/server|
               (|get.::.1_14…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-906eaf59-b810-4980-a3ec-28628ec27c80"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_1416/server|
             (|get.::.1_1416/server|
               (|get.::.1_14…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-2a115974-a24c-47f5-97f7-9080dc2e3810"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1423/server|
                   (Node_1246/client E_1251/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-4a3a862f-dee0-4598-9da2-60293ef43bae"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_1416/server|
             (|get.::.1_1416/server|
               (|get.::.1_14…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-9256ff3a-d212-4053-a663-58efd0aee36a"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.0_1415/server|
             (|get.::.1_1416/server|
               (|get.::.1_14…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-93cc4d14-0d84-47d1-a138-f154fda02183"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.0_1415/server|
             (|get.::.1_1416/server|
               (|get.::.1_14…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-29bc381f-f65c-4742-8830-40fc3a5518a1"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li>Unsat</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-472c4502-fe5e-443e-b6ce-543b4f61f352';
  fold.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-cfeb3175-259e-4314-a266-3836870fca59"><textarea style="display: none">digraph &quot;proof&quot; {
p_159 [label=&quot;Start (let (_x_0 : (state * int list))\l           = run\l             \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l              policy = …; conflict = …\}\l             (List.take … ( :var_0: ))\l       in not (not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = [])) :time 0.233s)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_159 -&gt; p_158 [label=&quot;&quot;];
p_158 [label=&quot;Simplify (let (_x_0 : (state * int list))\l              = run\l                \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l                 policy = …; conflict = …\}\l                (List.take 5 ( :var_0: ))\l          in not (not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = []))\l          :expansions [] :rw [] :fc [])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_158 -&gt; p_157 [label=&quot;&quot;];
p_157 [label=&quot;Unroll ([List.take 5 sensors], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_157 -&gt; p_156 [label=&quot;&quot;];
p_156 [label=&quot;Unroll ([mk_agents_map\l         (\{agent_id = Node …; guard = Eq (…, 1); accesses = Apple\} ::\l          (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_156 -&gt; p_155 [label=&quot;&quot;];
p_155 [label=&quot;Unroll ([run\l         \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l          conflict = …\}\l         (List.take 5 sensors)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_155 -&gt; p_154 [label=&quot;&quot;];
p_154 [label=&quot;Unroll ([Map.of_list Sharable\l         ((Apple, Unsharable) :: ((…, Sharable) :: (… :: …)))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_154 -&gt; p_153 [label=&quot;&quot;];
p_153 [label=&quot;Unroll ([List.take 4 (List.tl sensors)], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_153 -&gt; p_152 [label=&quot;&quot;];
p_152 [label=&quot;Unroll ([mk_agents_map\l         (\{agent_id = Node …; guard = Eq (…, 2); accesses = Banana\} ::\l          (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_152 -&gt; p_151 [label=&quot;&quot;];
p_151 [label=&quot;Unroll ([Map.of_list Sharable [(Banana, Sharable); (…, Sharable)]], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_151 -&gt; p_150 [label=&quot;&quot;];
p_150 [label=&quot;Unroll ([mk_agents_map\l         (\{agent_id = …; guard = …; accesses = …\} :: (… :: …))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_150 -&gt; p_149 [label=&quot;&quot;];
p_149 [label=&quot;Unroll ([Map.of_list Sharable [(…, Sharable)]], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_149 -&gt; p_148 [label=&quot;&quot;];
p_148 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Option.get (Map.get' … D)).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_148 -&gt; p_147 [label=&quot;&quot;];
p_147 [label=&quot;Unroll ([mk_agents_map (… :: …)], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_147 -&gt; p_146 [label=&quot;&quot;];
p_146 [label=&quot;Unroll ([Map.of_list Sharable []], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_146 -&gt; p_145 [label=&quot;&quot;];
p_145 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Option.get (Map.get' … A)).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_145 -&gt; p_144 [label=&quot;&quot;];
p_144 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         run\l         (step\l          \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l           conflict = …\}\l          (List.hd _x_0))\l         (List.tl _x_0)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_144 -&gt; p_143 [label=&quot;&quot;];
p_143 [label=&quot;Unroll ([List.take 3 (List.tl (List.tl sensors))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_143 -&gt; p_142 [label=&quot;&quot;];
p_142 [label=&quot;Unroll ([mk_agents_map …], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_142 -&gt; p_141 [label=&quot;&quot;];
p_141 [label=&quot;Unroll ([mk_agents_map [\{agent_id = Node …; guard = …; accesses = Apple\}]],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_141 -&gt; p_140 [label=&quot;&quot;];
p_140 [label=&quot;Unroll ([mk_agents_map []], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_140 -&gt; p_139 [label=&quot;&quot;];
p_139 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         let (_x_1 : state)\l             = step\l               \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l                policy = …; conflict = …\}\l               (List.hd _x_0)\l         in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_139 -&gt; p_138 [label=&quot;&quot;];
p_138 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 1, (Option.get …).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_138 -&gt; p_137 [label=&quot;&quot;];
p_137 [label=&quot;Unroll ([eval_guard (List.hd (List.tl (List.take 5 sensors)))\l         (Option.get (Map.get' ….agents (List.hd ….wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_137 -&gt; p_136 [label=&quot;&quot;];
p_136 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 sensors) in\l         run (step … (List.hd _x_0)) (List.tl _x_0)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_136 -&gt; p_135 [label=&quot;&quot;];
p_135 [label=&quot;Unroll ([List.take 2 (List.tl (List.tl (List.tl sensors)))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_135 -&gt; p_134 [label=&quot;&quot;];
p_134 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 sensors) in\l         let (_x_1 : state) = step … (List.hd _x_0) in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_134 -&gt; p_133 [label=&quot;&quot;];
p_133 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 0, (Option.get …).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_133 -&gt; p_132 [label=&quot;&quot;];
p_132 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 sensors) in\l         let (_x_1 : state) = step … (List.hd _x_0) in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_132 -&gt; p_131 [label=&quot;&quot;];
p_131 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 sensors) in\l         let (_x_1 : int list) = List.tl _x_0 in\l         run (step (step … (List.hd _x_0)) (List.hd _x_1)) (List.tl _x_1)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_131 -&gt; p_130 [label=&quot;&quot;];
p_130 [label=&quot;Unroll ([List.take 1 (List.tl (List.tl (List.tl (List.tl sensors))))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_130 -&gt; p_129 [label=&quot;&quot;];
p_129 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 sensors) in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : state) = step (step … (List.hd _x_0)) (List.hd _x_1)\l         in\l         eval_guard (List.hd (List.tl _x_1))\l         (Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_129 -&gt; p_128 [label=&quot;&quot;];
p_128 [label=&quot;Unroll ([Map.of_list Sharable (List.tl [])], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_128 -&gt; p_127 [label=&quot;&quot;];
p_127 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 sensors) in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : state) = step (step … (List.hd _x_0)) (List.hd _x_1)\l         in\l         eval_guard (List.hd (List.tl _x_1))\l         (Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_127 -&gt; p_126 [label=&quot;&quot;];
p_126 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\l         let (_x_1 : int list) = List.tl _x_0 in\l         run (step (step (step … …) (List.hd _x_0)) (List.hd _x_1))\l         (List.tl _x_1)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_126 -&gt; p_125 [label=&quot;&quot;];
p_125 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : state)\l             = step (step (step … …) (List.hd _x_0)) (List.hd _x_1)\l         in\l         eval_guard (List.hd (List.tl _x_1))\l         (Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_125 -&gt; p_124 [label=&quot;&quot;];
p_124 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : state)\l             = step (step (step … …) (List.hd _x_0)) (List.hd _x_1)\l         in\l         eval_guard (List.hd (List.tl _x_1))\l         (Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_124 -&gt; p_123 [label=&quot;&quot;];
p_123 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 1, (Option.get …).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_123 -&gt; p_122 [label=&quot;&quot;];
p_122 [label=&quot;Unroll ([List.take 0\l         (List.tl (List.tl (List.tl (List.tl (List.tl sensors)))))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_122 -&gt; p_121 [label=&quot;&quot;];
p_121 [label=&quot;Unroll ([eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l         (Destruct(Or, 0, (Option.get …).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_121 -&gt; p_120 [label=&quot;&quot;];
p_120 [label=&quot;Unroll ([eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l         (Destruct(Or, 0, (Option.get …).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_120 -&gt; p_119 [label=&quot;&quot;];
p_119 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\l         let (_x_1 : int list) = List.tl _x_0 in\l         let (_x_2 : int list) = List.tl _x_1 in\l         run\l         (step (step (step (step … …) (List.hd _x_0)) (List.hd _x_1))\l          (List.hd _x_2))\l         (List.tl _x_2)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_119 -&gt; p_118 [label=&quot;&quot;];
p_118 [label=&quot;Unsat&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-cfeb3175-259e-4314-a266-3836870fca59';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-d5e6d274-7e96-4636-9730-227309aba041';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-3c72ec03-ef8a-4187-a80f-fde6d5292016';
  fold.hydrate(target);
});
</script></div></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-27f80b28-ef59-409a-b150-f5020c89c3ef"><textarea style="display: none">digraph &quot;call graph&quot; {
goal [label=&quot;let (_x_0 : (state * int list))\l    = run\l      \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l       conflict = …\}\l      (List.take 5 sensors)\lin not (_x_0.0.conflict = None) &amp;&amp; (_x_0.1 = [])&quot;,shape=box,style=filled,color=&quot;cyan&quot;,fontname=&quot;courier&quot;,fontsize=14];
goal -&gt; call_125 [label=&quot;calls&quot;];
goal -&gt; call_152 [label=&quot;calls&quot;];
goal -&gt; call_67 [label=&quot;calls&quot;];
goal -&gt; call_129 [label=&quot;calls&quot;];
call_125 [label=&quot;run\l\{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l conflict = …\}\l(List.take 5 sensors)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_125 -&gt; call_1210 [label=&quot;calls&quot;];
call_125 -&gt; call_1242 [label=&quot;calls&quot;];
call_125 -&gt; call_1226 [label=&quot;calls&quot;];
call_152 [label=&quot;List.take 5 sensors&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_152 -&gt; call_956 [label=&quot;calls&quot;];
call_67 [label=&quot;Map.of_list Sharable\l((Apple, Unsharable) :: ((…, Sharable) :: (… :: …)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_67 -&gt; call_1958 [label=&quot;calls&quot;];
call_129 [label=&quot;mk_agents_map\l(\{agent_id = Node …; guard = Eq (…, 1); accesses = Apple\} ::\l (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_129 -&gt; call_1067 [label=&quot;calls&quot;];
call_1210 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\lrun\l(step\l \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l  conflict = …\}\l (List.hd _x_0))\l(List.tl _x_0)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1210 -&gt; call_4561 [label=&quot;calls&quot;];
call_1210 -&gt; call_4576 [label=&quot;calls&quot;];
call_1210 -&gt; call_4571 [label=&quot;calls&quot;];
call_1242 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Option.get (Map.get' … A)).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1242 -&gt; call_4034 [label=&quot;calls&quot;];
call_1242 -&gt; call_4036 [label=&quot;calls&quot;];
call_1226 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Option.get (Map.get' … D)).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1226 -&gt; call_3294 [label=&quot;calls&quot;];
call_1226 -&gt; call_3296 [label=&quot;calls&quot;];
call_956 [label=&quot;List.take 4 (List.tl sensors)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_956 -&gt; call_2155 [label=&quot;calls&quot;];
call_1958 [label=&quot;Map.of_list Sharable [(Banana, Sharable); (…, Sharable)]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1958 -&gt; call_2546 [label=&quot;calls&quot;];
call_1067 [label=&quot;mk_agents_map\l(\{agent_id = Node …; guard = Eq (…, 2); accesses = Banana\} ::\l (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1067 -&gt; call_2318 [label=&quot;calls&quot;];
call_4561 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 sensors) in\lrun (step … (List.hd _x_0)) (List.tl _x_0)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4561 -&gt; call_7021 [label=&quot;calls&quot;];
call_4561 -&gt; call_7016 [label=&quot;calls&quot;];
call_4561 -&gt; call_7006 [label=&quot;calls&quot;];
call_4576 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : state)\l    = step\l      \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l       conflict = …\}\l      (List.hd _x_0)\lin\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4576 -&gt; call_6208 [label=&quot;calls&quot;];
call_4576 -&gt; call_6210 [label=&quot;calls&quot;];
call_4571 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Option.get (Map.get' ….agents (List.hd ….wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4571 -&gt; call_6671 [label=&quot;calls&quot;];
call_4571 -&gt; call_6673 [label=&quot;calls&quot;];
call_4034 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4036 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4036 -&gt; call_18559 [label=&quot;calls&quot;];
call_4036 -&gt; call_18561 [label=&quot;calls&quot;];
call_3294 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3294 -&gt; call_9358 [label=&quot;calls&quot;];
call_3294 -&gt; call_9360 [label=&quot;calls&quot;];
call_3296 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3296 -&gt; call_6380 [label=&quot;calls&quot;];
call_3296 -&gt; call_6382 [label=&quot;calls&quot;];
call_2155 [label=&quot;List.take 3 (List.tl (List.tl sensors))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2155 -&gt; call_5772 [label=&quot;calls&quot;];
call_2546 [label=&quot;Map.of_list Sharable [(…, Sharable)]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2546 -&gt; call_2979 [label=&quot;calls&quot;];
call_2318 [label=&quot;mk_agents_map (\{agent_id = …; guard = …; accesses = …\} :: (… :: …))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2318 -&gt; call_2769 [label=&quot;calls&quot;];
call_7021 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 sensors) in\llet (_x_1 : state) = step … (List.hd _x_0) in\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_7021 -&gt; call_9515 [label=&quot;calls&quot;];
call_7021 -&gt; call_9517 [label=&quot;calls&quot;];
call_7016 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 sensors) in\llet (_x_1 : state) = step … (List.hd _x_0) in\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_7016 -&gt; call_8932 [label=&quot;calls&quot;];
call_7016 -&gt; call_8934 [label=&quot;calls&quot;];
call_7006 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 sensors) in\llet (_x_1 : int list) = List.tl _x_0 in\lrun (step (step … (List.hd _x_0)) (List.hd _x_1)) (List.tl _x_1)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_7006 -&gt; call_10039 [label=&quot;calls&quot;];
call_7006 -&gt; call_10054 [label=&quot;calls&quot;];
call_7006 -&gt; call_10049 [label=&quot;calls&quot;];
call_6208 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6210 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6671 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6673 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_18559 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_18561 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_9358 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_9360 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6380 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6382 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5772 [label=&quot;List.take 2 (List.tl (List.tl (List.tl sensors)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5772 -&gt; call_7911 [label=&quot;calls&quot;];
call_2979 [label=&quot;Map.of_list Sharable []&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2979 -&gt; call_3503 [label=&quot;calls&quot;];
call_2769 [label=&quot;mk_agents_map (… :: …)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2769 -&gt; call_3516 [label=&quot;calls&quot;];
call_9515 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_9515 -&gt; call_21839 [label=&quot;calls&quot;];
call_9515 -&gt; call_21837 [label=&quot;calls&quot;];
call_9517 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_8932 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_8932 -&gt; call_21153 [label=&quot;calls&quot;];
call_8932 -&gt; call_21151 [label=&quot;calls&quot;];
call_8934 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_10039 [label=&quot;let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\llet (_x_1 : int list) = List.tl _x_0 in\lrun (step (step (step … …) (List.hd _x_0)) (List.hd _x_1)) (List.tl _x_1)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_10039 -&gt; call_13744 [label=&quot;calls&quot;];
call_10039 -&gt; call_13739 [label=&quot;calls&quot;];
call_10039 -&gt; call_13729 [label=&quot;calls&quot;];
call_10054 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 sensors) in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : state) = step (step … (List.hd _x_0)) (List.hd _x_1) in\leval_guard (List.hd (List.tl _x_1))\l(Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_10054 -&gt; call_12609 [label=&quot;calls&quot;];
call_10054 -&gt; call_12611 [label=&quot;calls&quot;];
call_10049 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 sensors) in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : state) = step (step … (List.hd _x_0)) (List.hd _x_1) in\leval_guard (List.hd (List.tl _x_1))\l(Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_10049 -&gt; call_12049 [label=&quot;calls&quot;];
call_10049 -&gt; call_12051 [label=&quot;calls&quot;];
call_7911 [label=&quot;List.take 1 (List.tl (List.tl (List.tl (List.tl sensors))))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_7911 -&gt; call_11145 [label=&quot;calls&quot;];
call_3503 [label=&quot;Map.of_list Sharable (List.tl [])&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3503 -&gt; call_12300 [label=&quot;calls&quot;];
call_3516 [label=&quot;mk_agents_map …&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3516 -&gt; call_5862 [label=&quot;calls&quot;];
call_21839 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 1, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_21837 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 0, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_21153 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 1, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_21151 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 0, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_13744 [label=&quot;let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : state) = step (step (step … …) (List.hd _x_0)) (List.hd _x_1)\lin\leval_guard (List.hd (List.tl _x_1))\l(Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_13744 -&gt; call_15719 [label=&quot;calls&quot;];
call_13744 -&gt; call_15721 [label=&quot;calls&quot;];
call_13739 [label=&quot;let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : state) = step (step (step … …) (List.hd _x_0)) (List.hd _x_1)\lin\leval_guard (List.hd (List.tl _x_1))\l(Option.get (Map.get' _x_2.agents (List.hd _x_2.wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_13739 -&gt; call_16463 [label=&quot;calls&quot;];
call_13739 -&gt; call_16461 [label=&quot;calls&quot;];
call_13729 [label=&quot;let (_x_0 : int list) = List.tl (List.tl (List.take 5 sensors)) in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : int list) = List.tl _x_1 in\lrun\l(step (step (step (step … …) (List.hd _x_0)) (List.hd _x_1))\l (List.hd _x_2))\l(List.tl _x_2)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_13729 -&gt; call_22279 [label=&quot;calls&quot;];
call_13729 -&gt; call_22274 [label=&quot;calls&quot;];
call_13729 -&gt; call_22264 [label=&quot;calls&quot;];
call_12609 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_12611 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_12049 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_12051 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_11145 [label=&quot;List.take 0 (List.tl (List.tl (List.tl (List.tl (List.tl sensors)))))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_11145 -&gt; call_18693 [label=&quot;calls&quot;];
call_12300 [label=&quot;Map.of_list … (List.tl (List.tl …))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5862 [label=&quot;mk_agents_map [\{agent_id = Node …; guard = …; accesses = Apple\}]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5862 -&gt; call_5954 [label=&quot;calls&quot;];
call_15719 [label=&quot;eval_guard\l(List.hd (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors))))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_15721 [label=&quot;eval_guard\l(List.hd (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors))))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_16463 [label=&quot;eval_guard\l(List.hd (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors))))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_16461 [label=&quot;eval_guard\l(List.hd (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors))))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_22279 [label=&quot;eval_guard\l(List.hd\l (List.tl (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors)))))))\l(Option.get (Map.get' ….agents (List.hd ….wf_1))).guard&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_22274 [label=&quot;eval_guard\l(List.hd\l (List.tl (List.tl (List.tl (List.tl (List.tl (List.take 5 sensors)))))))\l(Option.get (Map.get' ….agents (List.hd ….wf_2))).guard&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_22264 [label=&quot;let (_x_0 : int list)\l    = List.tl (List.tl (List.tl (List.tl (List.take 5 sensors))))\lin\llet (_x_1 : int list) = List.tl _x_0 in\lrun (step (step (step … …) (List.hd _x_0)) (List.hd _x_1)) (List.tl _x_1)&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_18693 [label=&quot;List.take (-1) (List.tl (List.tl (List.tl …)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5954 [label=&quot;mk_agents_map []&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5954 -&gt; call_6058 [label=&quot;calls&quot;];
call_6058 [label=&quot;mk_agents_map (List.tl [])&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-27f80b28-ef59-409a-b150-f5020c89c3ef';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-f000c0b1-99b3-4431-b1b4-5f16af3b6a67';
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





<div><pre>Counterexample (after 34 steps, 0.202s):
let sensors : int list = [2; 3; 1]
</pre></div>




<div><div style="font-size: 1.2em; padding: 0.5em; border-top: 1px dashed #D84315; border-bottom: 1px dashed #D84315"><i class="fa fa-times-circle-o" style="margin-right: 0.5em; color: #D84315"></i><span>Refuted</span></div><div><div class="imandra-alternatives" id="alt-b53cef12-71cc-41a1-bb32-70d8efd4ebfd"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>call graph</a></li><li class="" data-toggle="tab"><a>proof</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-graphviz" id="graphviz-e5bc5544-4a81-4708-aedb-d3efdcda4364"><textarea style="display: none">digraph &quot;call graph&quot; {
goal [label=&quot;let (_x_0 : (state * int list))\l    = run\l      \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l       conflict = …\}\l      (List.take 5 sensors)\lin not (_x_0.0.conflict = None) &amp;&amp; (_x_0.1 = [])&quot;,shape=box,style=filled,color=&quot;cyan&quot;,fontname=&quot;courier&quot;,fontsize=14];
goal -&gt; call_129 [label=&quot;calls&quot;];
goal -&gt; call_139 [label=&quot;calls&quot;];
goal -&gt; call_70 [label=&quot;calls&quot;];
goal -&gt; call_132 [label=&quot;calls&quot;];
call_129 [label=&quot;List.take 5 sensors&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_129 -&gt; call_1823 [label=&quot;calls&quot;];
call_139 [label=&quot;run\l\{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l conflict = …\}\l(List.take 5 sensors)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_139 -&gt; call_100 [label=&quot;calls&quot;];
call_139 -&gt; call_1028 [label=&quot;calls&quot;];
call_139 -&gt; call_1012 [label=&quot;calls&quot;];
call_70 [label=&quot;Map.of_list Sharable [(Apple, Unsharable); (…, Sharable); …]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_70 -&gt; call_1978 [label=&quot;calls&quot;];
call_132 [label=&quot;let (_x_0 : agent_id) = Node … in\llet (_x_1 : guard) = Or (…, …) in\lmk_agents_map\l[\{agent_id = _x_0; guard = …; accesses = Apple\};\l \{agent_id = …; guard = …; accesses = …\}; …;\l \{agent_id = _x_0; guard = _x_1; accesses = Orange\};\l \{agent_id = _x_0; guard = _x_1; accesses = …\};\l \{agent_id = …; guard = …; accesses = Apple\}]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_132 -&gt; call_1768 [label=&quot;calls&quot;];
call_1823 [label=&quot;List.take 4 (List.tl sensors)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1823 -&gt; call_2537 [label=&quot;calls&quot;];
call_100 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\lrun\l(step\l \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l  conflict = …\}\l (List.hd _x_0))\l(List.tl _x_0)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_100 -&gt; call_4591 [label=&quot;calls&quot;];
call_100 -&gt; call_4581 [label=&quot;calls&quot;];
call_100 -&gt; call_4596 [label=&quot;calls&quot;];
call_1028 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Option.get (Map.get' … A)).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1028 -&gt; call_3082 [label=&quot;calls&quot;];
call_1028 -&gt; call_3084 [label=&quot;calls&quot;];
call_1012 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Option.get (Map.get' … D)).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1012 -&gt; call_2129 [label=&quot;calls&quot;];
call_1012 -&gt; call_2131 [label=&quot;calls&quot;];
call_1978 [label=&quot;Map.of_list Sharable [(Banana, Sharable); (…, Sharable)]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1978 -&gt; call_2673 [label=&quot;calls&quot;];
call_1768 [label=&quot;mk_agents_map\l(\{agent_id = Node …; guard = Eq (…, 2); accesses = Banana\} ::\l (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1768 -&gt; call_2405 [label=&quot;calls&quot;];
call_2537 [label=&quot;List.take 3 (List.tl (List.tl sensors))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2537 -&gt; call_7099 [label=&quot;calls&quot;];
call_4591 [label=&quot;let (_x_0 : int list) = List.take 5 sensors in\llet (_x_1 : state)\l    = step\l      \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l       conflict = …\}\l      (List.hd _x_0)\lin\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4591 -&gt; call_7582 [label=&quot;calls&quot;];
call_4591 -&gt; call_7584 [label=&quot;calls&quot;];
call_4581 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 sensors) in\lrun (step … (List.hd _x_0)) (List.tl _x_0)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4581 -&gt; call_9730 [label=&quot;calls&quot;];
call_4581 -&gt; call_9740 [label=&quot;calls&quot;];
call_4581 -&gt; call_9745 [label=&quot;calls&quot;];
call_4596 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Option.get (Map.get' ….agents (List.hd ….wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4596 -&gt; call_9137 [label=&quot;calls&quot;];
call_4596 -&gt; call_9139 [label=&quot;calls&quot;];
call_3082 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3082 -&gt; call_15217 [label=&quot;calls&quot;];
call_3082 -&gt; call_15219 [label=&quot;calls&quot;];
call_3084 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3084 -&gt; call_11822 [label=&quot;calls&quot;];
call_3084 -&gt; call_11824 [label=&quot;calls&quot;];
call_2129 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, (Option.get (Map.get' … D)).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2129 -&gt; call_6866 [label=&quot;calls&quot;];
call_2129 -&gt; call_6868 [label=&quot;calls&quot;];
call_2131 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, (Option.get (Map.get' … D)).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2131 -&gt; call_5590 [label=&quot;calls&quot;];
call_2131 -&gt; call_5592 [label=&quot;calls&quot;];
call_2673 [label=&quot;Map.of_list Sharable [(…, Sharable)]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2673 -&gt; call_3316 [label=&quot;calls&quot;];
call_2405 [label=&quot;mk_agents_map (\{agent_id = …; guard = …; accesses = …\} :: (… :: …))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2405 -&gt; call_2894 [label=&quot;calls&quot;];
call_7099 [label=&quot;List.take 2 (List.tl (List.tl (List.tl sensors)))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_7099 -&gt; call_12065 [label=&quot;calls&quot;];
call_7582 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_7582 -&gt; call_11254 [label=&quot;calls&quot;];
call_7582 -&gt; call_11256 [label=&quot;calls&quot;];
call_7584 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_7584 -&gt; call_14072 [label=&quot;calls&quot;];
call_7584 -&gt; call_14074 [label=&quot;calls&quot;];
call_9730 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 sensors) in\llet (_x_1 : int list) = List.tl _x_0 in\lrun (step (step … (List.hd _x_0)) (List.hd _x_1)) (List.tl _x_1)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_9730 -&gt; call_15528 [label=&quot;calls&quot;];
call_9730 -&gt; call_15533 [label=&quot;calls&quot;];
call_9730 -&gt; call_15518 [label=&quot;calls&quot;];
call_9740 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 sensors) in\llet (_x_1 : state) = step … (List.hd _x_0) in\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_9740 -&gt; call_14430 [label=&quot;calls&quot;];
call_9740 -&gt; call_14432 [label=&quot;calls&quot;];
call_9745 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 sensors) in\llet (_x_1 : state) = step … (List.hd _x_0) in\leval_guard (List.hd (List.tl _x_0))\l(Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_1))).guard&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_9745 -&gt; call_14740 [label=&quot;calls&quot;];
call_9745 -&gt; call_14742 [label=&quot;calls&quot;];
call_9137 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_9139 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, (Option.get (Map.get' ….agents (List.hd ….wf_1))).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_15217 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_15219 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_11822 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_11824 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6866 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6868 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, Destruct(Or, 0, (Option.get …).guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5590 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 0, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5592 [label=&quot;eval_guard (List.hd (List.take 5 sensors))\l(Destruct(Or, 1, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3316 [label=&quot;Map.of_list Sharable []&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3316 -&gt; call_4267 [label=&quot;calls&quot;];
call_2894 [label=&quot;mk_agents_map (… :: …)&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_2894 -&gt; call_3746 [label=&quot;calls&quot;];
call_12065 [label=&quot;List.take 1 (List.tl (List.tl (List.tl (List.tl sensors))))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_12065 -&gt; call_16600 [label=&quot;calls&quot;];
call_11254 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_11256 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_14072 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 0, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_14074 [label=&quot;eval_guard (List.hd (List.tl (List.take 5 sensors)))\l(Destruct(Or, 1, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_15528 [label=&quot;let (_x_0 : state) = step … … in\leval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Option.get (Map.get' _x_0.agents (List.hd _x_0.wf_2))).guard&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_15533 [label=&quot;let (_x_0 : state) = step … … in\leval_guard (List.hd (List.tl (List.tl (List.tl (List.take 5 sensors)))))\l(Option.get (Map.get' _x_0.agents (List.hd _x_0.wf_1))).guard&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_15518 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 sensors) in\llet (_x_1 : int list) = List.tl _x_0 in\llet (_x_2 : int list) = List.tl _x_1 in\lrun (step (step (step … (List.hd _x_0)) (List.hd _x_1)) (List.hd _x_2))\l(List.tl _x_2)&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_14430 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 sensors) in\llet (_x_1 : state) = step … (List.hd _x_0) in\leval_guard (List.hd (List.tl _x_0))\l(Destruct(Or, 0,\l          (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_14430 -&gt; call_17050 [label=&quot;calls&quot;];
call_14430 -&gt; call_17048 [label=&quot;calls&quot;];
call_14432 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 sensors) in\llet (_x_1 : state) = step … (List.hd _x_0) in\leval_guard (List.hd (List.tl _x_0))\l(Destruct(Or, 1,\l          (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard))&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_14432 -&gt; call_1734 [label=&quot;calls&quot;];
call_14432 -&gt; call_1743 [label=&quot;calls&quot;];
call_14740 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 0, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_14742 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 1, (Option.get …).guard))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_4267 [label=&quot;Map.of_list Sharable (List.tl [])&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3746 [label=&quot;mk_agents_map …&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_3746 -&gt; call_5949 [label=&quot;calls&quot;];
call_16600 [label=&quot;List.take 0 (List.tl (List.tl (List.tl (List.tl (List.tl sensors)))))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_17050 [label=&quot;eval_guard … (Destruct(Or, 1, Destruct(Or, 0, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_17048 [label=&quot;let (_x_0 : int list) = List.tl (List.take 5 sensors) in\llet (_x_1 : state) = step … (List.hd _x_0) in\leval_guard (List.hd (List.tl _x_0))\l(Destruct(Or, 0,\l          Destruct(Or, 0,\l                   (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1734 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 0, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_1743 [label=&quot;eval_guard (List.hd (List.tl (List.tl (List.take 5 sensors))))\l(Destruct(Or, 1, Destruct(Or, 1, ….guard)))&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5949 [label=&quot;mk_agents_map\l[\{agent_id = Node …; guard = Or (…, …); accesses = Apple\}]&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_5949 -&gt; call_6225 [label=&quot;calls&quot;];
call_6225 [label=&quot;mk_agents_map []&quot;,shape=box,style=filled,color=&quot;green&quot;,fontname=&quot;courier&quot;,fontsize=14];
call_6225 -&gt; call_6715 [label=&quot;calls&quot;];
call_6715 [label=&quot;mk_agents_map (List.tl [])&quot;,shape=box,style=filled,color=&quot;yellow&quot;,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-e5bc5544-4a81-4708-aedb-d3efdcda4364';
  graphviz.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-proof-top"><div class="imandra-fold panel panel-default" id="fold-fe238402-98f7-41be-a81e-05d37c7d72c3"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>proof attempt</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-0da7ce94-6448-4d09-b814-e6859a15c390"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li><li class="" data-toggle="tab"><a>graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-981a56af-c63c-4257-9b04-e60e307fbf33"><table><tr><td>ground_instances:</td><td>34</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.202s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-b55d52ae-2cef-4975-9d34-c9401de95201"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-931c83ec-59f4-48b5-8ad5-2614374d0ca4"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-a4acb12f-6740-44d5-8b51-c8d62cb78dde"><table><tr><td>array def const:</td><td>2</td></tr><tr><td>num checks:</td><td>69</td></tr><tr><td>array sel const:</td><td>361</td></tr><tr><td>array def store:</td><td>384</td></tr><tr><td>array exp ax2:</td><td>654</td></tr><tr><td>array splits:</td><td>87</td></tr><tr><td>rlimit count:</td><td>635962</td></tr><tr><td>array ext ax:</td><td>46</td></tr><tr><td>mk clause:</td><td>2640</td></tr><tr><td>array ax1:</td><td>9</td></tr><tr><td>datatype occurs check:</td><td>9640</td></tr><tr><td>restarts:</td><td>1</td></tr><tr><td>mk bool var:</td><td>18264</td></tr><tr><td>array ax2:</td><td>1724</td></tr><tr><td>datatype splits:</td><td>6273</td></tr><tr><td>decisions:</td><td>30118</td></tr><tr><td>propagations:</td><td>27353</td></tr><tr><td>conflicts:</td><td>708</td></tr><tr><td>datatype accessor ax:</td><td>649</td></tr><tr><td>minimized lits:</td><td>314</td></tr><tr><td>datatype constructor ax:</td><td>12841</td></tr><tr><td>num allocs:</td><td>488776832</td></tr><tr><td>final checks:</td><td>281</td></tr><tr><td>added eqs:</td><td>132509</td></tr><tr><td>del clause:</td><td>1776</td></tr><tr><td>time:</td><td>0.008000</td></tr><tr><td>memory:</td><td>31.840000</td></tr><tr><td>max memory:</td><td>31.940000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-b55d52ae-2cef-4975-9d34-c9401de95201';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-a0acc7ec-f8d4-4a7a-9108-fc25e3b85188"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.202s]
  let (_x_0 : (state * int list))
      = run
        {wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;
         conflict = …}
        (List.take … ( :var_0: ))
  in not (not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = []))</pre></li><li><div><h4>simplify</h4><div class="imandra-table" id="table-b702b014-3b1e-4a8e-b072-79a7889a5d95"><table><tr><td>into:</td><td><pre>let (_x_0 : (state * int list))
    = run
      {wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;
       conflict = …}
      (List.take 5 ( :var_0: ))
in not (not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = []))</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-ae652b7e-8e23-4926-b1eb-8f375ba38da1"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-fa9034ef-2f26-4eac-967c-e9f37e48158b"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1670/server|
                   (Node_1246/client F_1252/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-2b970b8f-4ec4-407f-9bd8-7220d71402c0"><table><tr><td>expr:</td><td><pre>(|List.take_1695/server| 5 sensors_1441/client)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-ef6009df-64d7-4ece-81a1-103ae1c04f94"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (tuple_mk_1680/server Apple_1272/client Unsharable_1279/client)
                 (|…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-b457faaa-44bf-4496-b217-da4c857998a6"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1670/server|
                   (Node_1246/client F_1252/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-f6e54459-2f9f-478f-976f-e7ec8f62ee89"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1670/server|
                   (Node_1246/client F_1252/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-0642c6d3-cc6b-4a4e-84e0-ebec1747d439"><table><tr><td>expr:</td><td><pre>(|List.take_1695/server| 4 (|get.::.1_1663/server| sensors_1441/client))</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-1bbe61ea-ea28-4c9f-b805-4db6b3361123"><table><tr><td>expr:</td><td><pre>(|Map.of_list_1688/server|
  Sharable_1278/client
  (|::| (tuple_mk_1680/server Banana_1273/client S…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-b0a51cd1-5d48-42e9-bc52-aa9c08f2d90a"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1670/server|
                   (Node_1246/client F_1252/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-a36c2ed8-59de-4c51-a06d-d3ff84c98769"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1670/server|
                   (Node_1246/client F_1252/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-08976ebd-9218-4f40-85b7-3847a0749c1a"><table><tr><td>expr:</td><td><pre>(|Map.of_list_1688/server|
  Sharable_1278/client
  (|::| (tuple_mk_1680/server Orange_1274/client S…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-450c8358-7468-4397-a91a-2fc2ca8a8a31"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1670/server|
                   (Node_1246/client F_1252/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-d11a2efe-71ec-437a-b149-554d5f34f0a2"><table><tr><td>expr:</td><td><pre>(|Map.of_list_1688/server| Sharable_1278/client |[]|)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-ffd0c1ba-0c26-445c-87c3-9bdedc61cd73"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-07840588-0af4-499f-93ff-5809346bf69c"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1670/server|
                   (Node_1246/client F_1252/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-7f628543-b1ed-4167-af71-b897f24c8c2b"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1670/server|
                   (Node_1246/client F_1252/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-824ff84a-c60d-4041-b702-003a479b2c2a"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1670/server|
                   (Node_1246/client F_1252/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-b85c5423-d9ee-4ba4-9854-547c32768204"><table><tr><td>expr:</td><td><pre>(mk_agents_map_1408/client |[]|)</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-94efa2cd-0557-4781-9c77-3936fd8b5c82"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1670/server|
                   (Node_1246/client F_1252/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-95482ad7-2e0a-4bb1-805f-d0f8cb8dbde7"><table><tr><td>expr:</td><td><pre>(|List.take_1695/server|
  3
  (|get.::.1_1663/server| (|get.::.1_1663/server| sensors_1441/client))…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-82e0cbcd-dde3-4cc9-9a77-c78a84229a9d"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-02341f31-f59d-4085-8768-26af112d1b0d"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-e937a4d3-c360-4bcd-a9e0-3c13cd8aba78"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-00459ca7-ce40-4a85-bd22-44e6b38867d5"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-6dd5024c-fcc8-4c2c-bec9-f246549b0871"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1670/server|
                   (Node_1246/client F_1252/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-7b063629-531e-4c6d-8e2e-63c2933bd868"><table><tr><td>expr:</td><td><pre>(|List.take_1695/server|
  2
  (|get.::.1_1663/server|
    (|get.::.1_1663/server| (|get.::.1_1663/s…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-244a72c5-91b9-4d3d-9c4f-9c556a1410b0"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-1bed164c-fa2c-458b-87f7-9da8afc1e63b"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.0_1662/server|
             (|get.::.1_1663/server|
               (|get.::.1_16…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-c6692f0f-1193-427b-b318-b52f13b399d1"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.0_1662/server|
             (|get.::.1_1663/server|
               (|get.::.1_16…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-42687fd6-4af3-4936-a646-7ab91fd03836"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| (|rec_mk.agent_1670/server|
                   (Node_1246/client F_1252/client)
   …</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-eb1dae37-040d-4dfd-bd5b-99289580023c"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|::| A_1247/client
                 (|::| B_1248/client
                       (|::| C_1…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-9f51f556-e419-49ed-b6ca-e501b3855731"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.1_1663/server|
             (|get.::.1_1663/server|
               (|get.::.1_16…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-f09c5d5d-3f10-464b-b4fa-dfe560c95d77"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.0_1662/server|
             (|get.::.1_1663/server|
               (|get.::.1_16…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li><div>unroll<div class="imandra-table" id="table-fae7e7f9-b077-4225-9edb-69a3c4286128"><table><tr><td>expr:</td><td><pre>(let ((a!1 (|get.::.0_1662/server|
             (|get.::.1_1663/server|
               (|get.::.1_16…</pre></td></tr><tr><td>expansions:</td><td><ul></ul></td></tr></table></div></div></li><li>Sat (Some let sensors : int list =
  [(Z.of_nativeint (2n)); (Z.of_nativeint (3n)); (Z.of_nativeint (1n))]
)</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-a0acc7ec-f8d4-4a7a-9108-fc25e3b85188';
  fold.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-e7803768-3870-47aa-8f33-d778cc3dade8"><textarea style="display: none">digraph &quot;proof&quot; {
p_196 [label=&quot;Start (let (_x_0 : (state * int list))\l           = run\l             \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l              policy = …; conflict = …\}\l             (List.take … ( :var_0: ))\l       in not (not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = [])) :time 0.202s)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_196 -&gt; p_195 [label=&quot;&quot;];
p_195 [label=&quot;Simplify (let (_x_0 : (state * int list))\l              = run\l                \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l                 policy = …; conflict = …\}\l                (List.take 5 ( :var_0: ))\l          in not (not (_x_0.0.conflict = …) &amp;&amp; (_x_0.1 = []))\l          :expansions [] :rw [] :fc [])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_195 -&gt; p_194 [label=&quot;&quot;];
p_194 [label=&quot;Unroll ([run\l         \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l          conflict = …\}\l         (List.take 5 sensors)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_194 -&gt; p_193 [label=&quot;&quot;];
p_193 [label=&quot;Unroll ([…], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_193 -&gt; p_192 [label=&quot;&quot;];
p_192 [label=&quot;Unroll ([List.take 5 sensors], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_192 -&gt; p_191 [label=&quot;&quot;];
p_191 [label=&quot;Unroll ([…], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_191 -&gt; p_190 [label=&quot;&quot;];
p_190 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Option.get (Map.get' … D)).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_190 -&gt; p_189 [label=&quot;&quot;];
p_189 [label=&quot;Unroll ([mk_agents_map\l         (\{agent_id = Node …; guard = Eq (…, 2); accesses = Banana\} ::\l          (\{agent_id = …; guard = …; accesses = …\} :: (… :: …)))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_189 -&gt; p_188 [label=&quot;&quot;];
p_188 [label=&quot;Unroll ([List.take 4 (List.tl sensors)], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_188 -&gt; p_187 [label=&quot;&quot;];
p_187 [label=&quot;Unroll ([Map.of_list Sharable [(Banana, Sharable); (…, Sharable)]], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_187 -&gt; p_186 [label=&quot;&quot;];
p_186 [label=&quot;Unroll ([mk_agents_map\l         (\{agent_id = …; guard = …; accesses = …\} :: (… :: …))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_186 -&gt; p_185 [label=&quot;&quot;];
p_185 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Option.get (Map.get' … A)).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_185 -&gt; p_184 [label=&quot;&quot;];
p_184 [label=&quot;Unroll ([Map.of_list Sharable [(…, Sharable)]], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_184 -&gt; p_183 [label=&quot;&quot;];
p_183 [label=&quot;Unroll ([mk_agents_map (… :: …)], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_183 -&gt; p_182 [label=&quot;&quot;];
p_182 [label=&quot;Unroll ([Map.of_list Sharable []], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_182 -&gt; p_181 [label=&quot;&quot;];
p_181 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         run\l         (step\l          \{wf_1 = …; wf_2 = …; sensor = …; agents = …; policy = …;\l           conflict = …\}\l          (List.hd _x_0))\l         (List.tl _x_0)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_181 -&gt; p_180 [label=&quot;&quot;];
p_180 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 1, (Option.get (Map.get' … D)).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_180 -&gt; p_179 [label=&quot;&quot;];
p_179 [label=&quot;Unroll ([mk_agents_map …], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_179 -&gt; p_178 [label=&quot;&quot;];
p_178 [label=&quot;Unroll ([mk_agents_map\l         [\{agent_id = Node …; guard = Or (…, …); accesses = Apple\}]],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_178 -&gt; p_177 [label=&quot;&quot;];
p_177 [label=&quot;Unroll ([mk_agents_map []], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_177 -&gt; p_176 [label=&quot;&quot;];
p_176 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 0, (Option.get (Map.get' … D)).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_176 -&gt; p_175 [label=&quot;&quot;];
p_175 [label=&quot;Unroll ([List.take 3 (List.tl (List.tl sensors))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_175 -&gt; p_174 [label=&quot;&quot;];
p_174 [label=&quot;Unroll ([let (_x_0 : int list) = List.take 5 sensors in\l         let (_x_1 : state)\l             = step\l               \{wf_1 = …; wf_2 = …; sensor = …; agents = …;\l                policy = …; conflict = …\}\l               (List.hd _x_0)\l         in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_174 -&gt; p_173 [label=&quot;&quot;];
p_173 [label=&quot;Unroll ([eval_guard (List.hd (List.tl (List.take 5 sensors)))\l         (Option.get (Map.get' ….agents (List.hd ….wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_173 -&gt; p_172 [label=&quot;&quot;];
p_172 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 sensors) in\l         run (step … (List.hd _x_0)) (List.tl _x_0)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_172 -&gt; p_171 [label=&quot;&quot;];
p_171 [label=&quot;Unroll ([eval_guard (List.hd (List.tl (List.take 5 sensors)))\l         (Destruct(Or, 0, (Option.get …).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_171 -&gt; p_170 [label=&quot;&quot;];
p_170 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 1, (Option.get …).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_170 -&gt; p_169 [label=&quot;&quot;];
p_169 [label=&quot;Unroll ([List.take 2 (List.tl (List.tl (List.tl sensors)))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_169 -&gt; p_168 [label=&quot;&quot;];
p_168 [label=&quot;Unroll ([eval_guard (List.hd (List.tl (List.take 5 sensors)))\l         (Destruct(Or, 1, (Option.get …).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_168 -&gt; p_167 [label=&quot;&quot;];
p_167 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 sensors) in\l         let (_x_1 : state) = step … (List.hd _x_0) in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_167 -&gt; p_166 [label=&quot;&quot;];
p_166 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 sensors) in\l         let (_x_1 : state) = step … (List.hd _x_0) in\l         eval_guard (List.hd (List.tl _x_0))\l         (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_1))).guard],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_166 -&gt; p_165 [label=&quot;&quot;];
p_165 [label=&quot;Unroll ([eval_guard (List.hd (List.take 5 sensors))\l         (Destruct(Or, 0, (Option.get …).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_165 -&gt; p_164 [label=&quot;&quot;];
p_164 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 sensors) in\l         let (_x_1 : int list) = List.tl _x_0 in\l         run (step (step … (List.hd _x_0)) (List.hd _x_1)) (List.tl _x_1)],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_164 -&gt; p_163 [label=&quot;&quot;];
p_163 [label=&quot;Unroll ([List.take 1 (List.tl (List.tl (List.tl (List.tl sensors))))], [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_163 -&gt; p_162 [label=&quot;&quot;];
p_162 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 sensors) in\l         let (_x_1 : state) = step … (List.hd _x_0) in\l         eval_guard (List.hd (List.tl _x_0))\l         (Destruct(Or, 0,\l                   (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_162 -&gt; p_161 [label=&quot;&quot;];
p_161 [label=&quot;Unroll ([let (_x_0 : int list) = List.tl (List.take 5 sensors) in\l         let (_x_1 : state) = step … (List.hd _x_0) in\l         eval_guard (List.hd (List.tl _x_0))\l         (Destruct(Or, 1,\l                   (Option.get (Map.get' _x_1.agents (List.hd _x_1.wf_2))).guard))],\l        [[]])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_161 -&gt; p_160 [label=&quot;&quot;];
p_160 [label=&quot;Sat (Some let sensors : int list =\l  [(Z.of_nativeint (2n)); (Z.of_nativeint (3n)); (Z.of_nativeint (1n))]\l)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-e7803768-3870-47aa-8f33-d778cc3dade8';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-0da7ce94-6448-4d09-b814-e6859a15c390';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-fe238402-98f7-41be-a81e-05d37c7d72c3';
  fold.hydrate(target);
});
</script></div></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-b53cef12-71cc-41a1-bb32-70d8efd4ebfd';
  alternatives.hydrate(target);
});
</script></div></div></div>



As we can see, Imandra has proved for us that a conflict is possible for `ex_3`. It's a very nice exercise to go through the counterexample manually and understand how this conflict occurs. You can also use Imandra's concrete execution facilities to investigate the state for this conflict:


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




We can see that the conflict Imandra found, which happens with a sensor sequence of `[2;3;1]` results in both `Node A` and `Node F` trying to access `Apple` at the same time, which is not allowed by the resource access policy. 

You can modify these problems as you see fit and experiment with Imandra verifying or refuting conflict safety. Happy reasoning!


```ocaml

```
