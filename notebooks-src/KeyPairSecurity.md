---
title: "Key Pair Security in Imandra"
description: "In this ReasonML notebook, we use imandra to very quickly discover the 'man in the middle' attack for protocols with private/public key exchance protocols."
kernel: imandra-reason
slug: key-pair-security
key-phrases:
  - ReasonML
  - proof
  - probabilities
  - counterexample
  - verify
---

# Key Pair Security in Imandra

In this notebook we introduce a simple implementation of a key pair exchange protocol in ReasonML. Messages can either be key requests, unencrypted responses to key requests with a public key or encrypted messages with a private key. In addition to this we introduce the concept of a "listener" - an agent who can intercept other messagers.

```{.imandra .input}
type person =
  | Mallory
  | Bob
  | Alice;

type public_key =
  | Public(person);
type private_key =
  | Private(person);

/* identifier person (purporting from) + payload */
type full_unencrypted_payload = (person, public_key);
type full_encrypted_payload = (person, int);

type data =
  | UnEncrypted(full_unencrypted_payload)
  /* where it's believed to be being sent and the actual public key used */
  | Encrypted((person, public_key), full_encrypted_payload);

/* actual people */
type channel = {
  from: person,
  to_: person,
};

let swap = (c: channel): channel => {from: c.to_, to_: c.from};

type known = {
  asker: person,
  ident: person,
  actual: person,
};

type msg = {
  channel,
  data,
};

type action =
  | Listen(person, channel)
  | KeyRequest(person, person)
  | Send(msg);

type state = {
  /* fst arg believes 2nd arg to be that person */
  believed_identities: list((person, person)),
  /* can learn a key */
  can_learn_keys: list((person, person)),
  /* person knows a given key */
  known_keys: list(known),
  /* a 'listener' / spy on a channel */
  listeners: list((person, channel)),
  /* msg was decrypted and read by person */
  decrypted: list((person, full_encrypted_payload)),
  /* actual encrypted channel messages sent */
  msgs: list((channel, full_encrypted_payload)),
};

let believed_identity = (s: state, a: person, b: person) =>
  List.mem((a, b), s.believed_identities);

/* Has person A requested person B's key? */

let can_learn_key = (s: state, a: person, b: person) =>
  List.mem((a, b), s.can_learn_keys);

/* Does person A know person B's key? */

let knows_key = (s: state, asker: person, ident: person, actual: person) =>
  asker == actual || List.mem({asker, ident, actual}, s.known_keys);

/* Is person A listening to channel C? Partially reflexive and symmetric! */

let listening = (s: state, a: person, c: channel) =>
  c.to_ == a
  || List.exists(
       ((p, c2)) => a == p && (c == c2 || c == swap(c2)),
       s.listeners,
     );

/* For all appropriate listeners on a given channel, do something */

let map_listeners =
    (s: state, c: channel, guard: person => bool, f: person => 'b) => {
  let doit = ((l_p, l_c)) =>
    if (listening(s, l_p, c) && guard(l_p)) {
      Some(f(l_p));
    } else {
      None;
    };
  List.filter_map(x => doit(x), s.listeners);
};

let step = (s: state, a: action) =>
  switch (a) {
  /* We can only listen in on messages between distinct people */
  | Listen(p, c) when c.from != c.to_ && c.from != p && c.to_ != p => {
      ...s,
      listeners: [(p, c), ...s.listeners],
    }
  | KeyRequest(asker, key_owner) =>
    /* filter out self requests */
    if (asker == key_owner) {
      s;
    } else {
      let ks =
        map_listeners(
          s,
          {from: asker, to_: key_owner},
          l => true,
          l => (l, key_owner),
        );
      /* once asker asks key_owner for his key, he believes this person's identity */
      {
        ...s,
        can_learn_keys: [(asker, key_owner), ...ks] @ s.can_learn_keys,
        believed_identities: [(key_owner, asker), ...s.believed_identities],
      };
    }
  | Send({channel, data: UnEncrypted((person, Public(key_owner)))}) =>
    /* filter out self sends */
    if (channel.from == channel.to_ || person == channel.to_) {
      s;
    } else if
      /* if the asker already believes he knows a key belonging to person then don't accept the key */
      (List.exists(
         ({asker, ident, actual}) => asker == channel.to_ && ident == person,
         s.known_keys,
       )) {
      s;
    } else if
      /* the recipent must be able to learn the key and the sender must know the key of key_owner believing it to be of person */
      (can_learn_key(s, channel.to_, person)
       && knows_key(s, channel.from, person, key_owner)) {
      /* The sink of the channel now knows the sent key */
      let r = {asker: channel.to_, ident: person, actual: key_owner};
      /* All listeners on the channel now know p's key */
      let ks =
        map_listeners(
          s,
          channel,
          l => can_learn_key(s, l, person),
          l => {asker: l, ident: person, actual: key_owner},
        );
      {...s, known_keys: [r, ...ks] @ s.known_keys};
    } else {
      s;
    }
  | Send({
      channel,
      data: Encrypted((recipient_ident, Public(t)), (p, msg)),
    }) =>
    /* filter out self sends */
    if (channel.from == channel.to_
        || recipient_ident == channel.from
        || p == channel.to_
        || recipient_ident == p) {
      s;
    } else if
      /* if channel.from asked for the key and the identity is different don't accept the message */
      (believed_identity(s, channel.to_, channel.from) && p != channel.from) {
      s;
    } else if
      /* if public key is known by sender and the key matches the channel.to_ */
      (knows_key(s, channel.from, recipient_ident, channel.to_)
       && t == channel.to_) {
      {
        ...s,
        decrypted: [(channel.to_, (p, msg)), ...s.decrypted],
        msgs: [(channel, (p, msg)), ...s.msgs],
      };
    } else {
      s;
    }
  | _ => s
  };

let init: state = {
  believed_identities: [],
  can_learn_keys: [],
  known_keys: [],
  listeners: [],
  decrypted: [],
  msgs: [],
};
```

We can introduce some printing functions so that any traces produced can be visually interpreted.

```{.imandra .input}
let person_to_string = (p) =>
  switch (p) {
    | Alice => "Alice"
    | Mallory => "Mallory"
    | Bob => "Bob"
  };
```

This step allows us to depict message transitions between agents.

```{.imandra .input}

let graph_step = (s: action) =>
  switch (s) {
  | Listen(p, c) =>
    person_to_string(p)
    ++ "->"
    ++ person_to_string(c.from)
    ++ "[style=dotted];\n"
    ++ person_to_string(p)
    ++ "->"
    ++ person_to_string(c.to_)
    ++ "[style=dotted];\n"
  | KeyRequest(a, k) =>
    "edge [color=yellow];\n"
    ++ person_to_string(a)
    ++ "->"
    ++ person_to_string(k)
    ++ ";\n"
  | Send({channel, data: UnEncrypted((person, Public(key_owner)))}) =>
    person_to_string(channel.from)
    ++ "->"
    ++ person_to_string(channel.to_)
    ++ "[label=\""
    ++ person_to_string(key_owner)
    ++ "\",color=blue];\n"
  | Send({
      channel,
      data: Encrypted((recipient_ident, Public(t)), (p, msg)),
    }) =>
    person_to_string(channel.from)
    ++ "->"
    ++ person_to_string(channel.to_)
    ++ "[label=\""
    ++ person_to_string(t)
    ++ "\",color=black];\n"
  };

```

```{.imandra .input}
let rec graph_inner = (xs:list(action)) =>
  switch (xs)
  {
    | [] => ""
    | [h, ...t] =>
      graph_step(h)++graph_inner(t)
  };
```

In the final printer function, we depict encrypted messages with black transition lines, key requests with yellow lines, and unencrypted messages with blue transition lines. Listeners to other parties are depicted with dashed lines.

```{.imandra .input}
[@program] let graph = (xs:list(action)) =>
  Document.graphviz("digraph G {\nAlice [color=blue];\nMallory [color=red];\nBob [color=green];\n"++graph_inner(xs)++"\n}\n");
[@install_doc graph];
```

We can now ask imandra to prove correctness properties about the protocol. For example, is it possible for a message to be decrypted by someone who is not the intended recipient. Click on the `Load graph` button to visually interpret the counterexample found by imandra.

```{.imandra .input}
/* Can xq decrypt a message saying it's from xw, but actually it's been sent by another party? */
[@blast]
verify((x1, x2, m, xs) => {
  let s = List.fold_left(step, init, xs);
  List.mem((x1, (x2, m)), s.decrypted)
  ==> List.mem(({from: x2, to_: x1}, (x2, m)), s.msgs);
});
CX.xs;
```
We see that imandra, and in particular the `[@blast]` capability finds a counterexample very quickly. We can further ask whether if a particpant decodes a message then it must have been sent by the original sender of the message.

```{.imandra .input}
/* if a message has been sent by x2 and x1 decodes that message then they must be the same message */
[@blast]
verify((x1, x2, x3, m, xs) => {
  let s = List.fold_left(step, init, xs);
  (
    List.mem(({from: x2, to_: x3}, (x2, m)), s.msgs)
    && List.mem((x1, (x2, m)), s.decrypted)
  )
  ==> x1 == x3;
});
CX.xs;
```
Here imandra very quickly finds a counter-example which corresponds to the well-known "man in the middle attack" - where Mallory listens to the conversation between Alice and Bob and can intercept and forward messages, potentially tampering with the content. Again - click on the `Load graph` button to visually interpret the counterexample found by imandra.
