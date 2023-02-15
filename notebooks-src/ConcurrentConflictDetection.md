# Imandra for automated conflict detection

In this notebook, we will build an Imandra framework for reasoning about concurrent conflict detection. Once we encode the problem domain, we'll be able to use Imandra to automatically solve arbitrary problems in this domain of concurrent resource conflict detection simply by encoding them in a simple datatype and asking Imandra if a sequence of events leading to a conflict is possible.

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

```{.imandra .input}
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

# Problems

Next, we'll define the *problem* datatype, which will allow us to succinctly express an arbitrary conflict detection problem of the above form to Imandra for analysis.

As above, a problem will consist of a pair of workflows, a collection of agents (each with their own identities, guards and resource accesses) and a resource access policy specifying which resources can be shared.

```{.imandra .input}
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

# Operational Semantics

Next, we're going to encode the "meaning" or "semantics" of concurrent conflicts in Imandra by defining an *interpreter* which evaluates a problem over arbitrary states of the world. Then, we'll be able to use Imandra's symbolic reasoning power to prove or disprove the existence of a conflict for a given problem by asking it to symbolically evaluate all possible behaviors of the interpreter over a given problem specification.

## State

The `state` datatype will encode the current state of the world. This is core datatype over which a problem execution trace will take place.

## Interpreter

Armed with the `state` type, we will define an interpreter which accepts a problem and a sequence of sensor readings, and yields the result.

```{.imandra .input}
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

# Top-level problem runner and problem-specific conflict detection

Next, we'll add the ability to define problems, run them and detect conflicts.

```{.imandra .input}
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

# Now, let's encode some problems and check for conflicts!

# Problem 1

```{.imandra .input}
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

# Is a conflict possible? Let's ask Imandra!

```{.imandra .input}
instance (fun sensors -> conflict_reachable ex_1 sensors)
```

# Problem 2

```{.imandra .input}
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

```{.imandra .input}
instance (fun sensors -> conflict_reachable ex_2 sensors)
```

## This means no conflicts are possible for Problem 2!

Imandra has *proved* that this goal is unsatisfiable, i.e., that no such conflict is possible. In fact,
we can use Imandra's *verify* command to restate this as a safety property and prove it:

```{.imandra .input}
verify (fun sensors -> not (conflict_reachable ex_2 sensors))
```

## Problem 3: the use of OR in guards

Finally, let's consider a problem in which we use the guard disjunctions (OR), which makes the search space quite a bit more complex.

```{.imandra .input}
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

```{.imandra .input}
verify (fun sensors -> not (conflict_reachable ex_3 sensors))
```

As we can see, Imandra has proved for us that a conflict is possible for `ex_3`. It's a very nice
exercise to go through the counterexample manually and understand how this conflict occurs. We can also
use Imandra's concrete execution facilities to investigate the state for this conflict, by running the problem along the counterexample Imandra synthesized (`CX.sensors`):

```{.imandra .input}
run_problem ex_3 CX.sensors
```

We can see that the conflict Imandra found, which happens with a sensor sequence of `[2;3;1]` results in
both `Node A` and `Node F` trying to access `Apple` at the same time, which is not allowed by the
resource access policy.

You can modify these problems as you see fit and experiment with Imandra verifying or refuting conflict
safety. Happy reasoning!

```{.imandra .input}

```
