---
title: "Tic Tac Toe with ReasonML"
description: "As ReasonML syntax is just a frontend to OCaml, we can use ReasonML syntax with Imandra. Here we walk through a model of Tic Tac Toe (that we've attached a ReasonReact frontend to separately), and show how Imandra can help understand the various functions, as well as help check the model is functioning correctly."
kernel: imandra-reason
slug: reasonml-tic-tac-toe
key-phrases:
  - proof
  - counterexample
  - instance
  - ReasonML
  - interactive development
  - document printers
---

# Tic Tac Toe with ReasonML

ReasonML provides an alternative syntax for OCaml, which Imandra can read. Let's walk through an example ReasonML model of Tic Tac Toe and use Imandra to understand and verify some properties of it.

This model is wired into some ReasonReact components in order to produce [this final, playable version](https://docs.imandra.ai/reasonml-tic-tac-toe/). You can see the model code and components as a ReasonReact project in [this github repo](https://github.com/AestheticIntegration/reasonml-tic-tac-toe).

## Setting up the model

Let's start by adding some definitions for the player, state of a square on the game grid, and the grid itself.

```{.imandra .input}
type player =
  | X
  | O;
  
/* the state of a particular square - None = (no move yet), Some(X/O) = either X or O has moved there */
type square_state = option(player);

/* each letter represents a square on the grid, starting in the top left and going along each row */
type grid = {
  a: square_state,
  b: square_state,
  c: square_state,
  d: square_state,
  e: square_state,
  f: square_state,
  g: square_state,
  h: square_state,
  i: square_state,
};
```

(NB: we're inputting in Reason syntax, but Imandra currently outputs OCaml syntax - this is something we'll have resolved very soon!).

## Grid document printer

Here's an example grid:

```{.imandra .input}
let a_grid = {
  a: Some(O),
  b: Some(X),
  c: Some(O),
  d: None,
  e: None,
  f: Some(X),
  g: None,
  h: None,
  i: None,
};

```

As you can tell, it's not the easiest thing to interpret from Imandra's output given the way we've described the grid. Let's setup a custom document mapping for the grid type. Imandra will render the `Document` data structures as richer output to display our types in a clearer way:

```{.imandra .input}
[@program] let doc_of_square_state = (s : square_state) =>
  Document.s(switch (s) {
  | Some(X) => "❌" /* emojis! */
  | Some(O) => "⭕"
  | None => "·"
});

[@program] let doc_of_grid = (g: grid) => {
  let f = doc_of_square_state;
  Document.tbl([[f(g.a), f(g.b), f(g.c)], [f(g.d), f(g.e), f(g.f)], [f(g.g), f(g.h), f(g.i)]])
};
[@install_doc doc_of_grid];
```

```{.imandra .input}
a_grid
```

Much better! The `[@program]` annotation tells Imandra that we're only going to be using these functions for non-analytical (and potentially side-effecting) operations, and that it doesn't have to worry about analysing them. See [Logic and program modes](Logic%20and%20program%20modes.md) for more information.

## More definitions

Let's continue adding some more definitions:

```{.imandra .input}
/* maps to the grid entries */
type move =
  | A
  | B
  | C
  | D
  | E
  | F
  | G
  | H
  | I;

/* the full game state - the current grid, and who went last */
type game_state = {
  grid,
  last_player: option(player),
};

type game_status =
  | Won(player)
  | InProgress
  | InvalidMove(move)
  | Tied;

let initial_game = {
  grid: {
    a: None,
    b: None,
    c: None,
    d: None,
    e: None,
    f: None,
    g: None,
    h: None,
    i: None,
  },
  last_player: None,
};

let initial_player = X;

/* convenience function from our move variant to the value in that grid position */
let value = ({grid: {a, b, c, d, e, f, g, h, i}, _}) =>
  fun
  | A => a
  | B => b
  | C => c
  | D => d
  | E => e
  | F => f
  | G => g
  | H => h
  | I => i;

```

## Game state document printer

Let's also add another document for printing `game_state`s, showing both the grid and who went last:

```{.imandra .input}
[@program] let doc_of_game_state = (gs: game_state) => {
  Document.tbl([[doc_of_grid(gs.grid), Document.s("Last:"), doc_of_square_state(gs.last_player)]])
};

[@install_doc doc_of_game_state];

initial_game;
```

## Some logic and our first instance

Now for our first bit of proper logic - whether or not a game is won for a particular player:

```{.imandra .input}
let is_winning = ({grid: {a, b, c, d, e, f, g, h, i}, _}, player) => {
  let winning_state = (Some(player), Some(player), Some(player));
  (a, b, c) == winning_state
  || (d, e, f) == winning_state
  || (g, h, i) == winning_state
  || (a, d, g) == winning_state
  || (b, e, h) == winning_state
  || (c, f, i) == winning_state
  || (a, e, i) == winning_state
  || (c, e, g) == winning_state;
};

```

Let's use Imandra to get a feel for this function - let's ask for an instance of a game where the game is being won by the player X. We use Imandra's `instance` mechanism, and ask for a game `g` where the predicate `is_winning(g, X)` is true:

```{.imandra .input}
instance((g : game_state) => is_winning(g, X));
```

Rather than executing our function with random inputs as you might imagine, Imandra has examined our definitions mathematically, and generated an instance that matches what we asked for based on the code itself, without executing it directly. This means we don't have to write generators as we would if we were using a library like QuickCheck for example. We can also use Imandra's other tools, such as state space decomposition, to identify edge cases we may not have thought about. See the other documentation pages/notebooks for more detail.

In this case we explicitly annotated the type of `g` as `game_state`, but if this can be inferred using the usual ReasonML/OCaml inference rules, it can be omitted.

`instance` has also reflected the value it found back into our Imandra session, so we can take a look at it:

```{.imandra .input}
CX.g
```

and compute with it:

```{.imandra .input}
is_winning(CX.g, X)
```

We can see here that `X` is definitely 'winning', although the game doesn't look particularly valid. `O` hasn't made any moves, and the game state hasn't got a `last_player` set. That's fine for now though, we'll build up additional layers in our logic to handle these other cases. It can be very useful to see a concrete example of our function in action!

## Valid grids

Let's continue:

```{.imandra .input}
let other_player =
  fun
  | X => O
  | O => X;

/* count up the number of moves for each player across the whole grid - sounds useful! */
let move_counts = ({a, b, c, d, e, f, g, h, i}) =>
  List.fold_right(
    (el, (x, o)) =>
      switch (el) {
      | None => (x, o)
      | Some(X) => (x + 1, o)
      | Some(O) => (x, o + 1)
      },
    ~base=(0, 0),
    [a, b, c, d, e, f, g, h, i],
  );

/* whether a grid is 'valid' - the difference between move totals should never be more than 1 */
/* with these rules, either player can go first so we check that one player is never too far ahead */
let is_valid_grid = (grid, last_player) => {
  let (x, o) = move_counts(grid);
  if (x > o) {
    last_player == Some(X) && x - o == 1;
  } else if (x < o) {
    last_player == Some(O) && o - x == 1;
  } else if (x + o == 0) {
    last_player == None;
  } else {
    true
  };
};


```

Let's grab a game where the grid is valid:

```{.imandra .input}
instance((game) => is_valid_grid(game.grid, game.last_player));
```

```{.imandra .input}
CX.game;
```

This is a bit better - the grid looks more like a real game of Tic Tac Toe now.

Let's also see what happens if we ask for an instance that we know shouldn't be possible - if a player is more than 1 move ahead:

```{.imandra .input}
instance((game) => {
   let (x, o) = move_counts(game.grid);
   is_valid_grid(game.grid, game.last_player) && ((x - o) >= 2)
});
```

As this is invalid according to the description we've provided, Imandra can't find an instance. In fact, this `Unsatisfiable` judgment tells us that Imandra has actually constructed a mathematical proof that no such instance exists.

## Verifying

We can invert this question, and turn it into a verification statement and ask Imandra to check it for us like a test.

```{.imandra .input}
verify((game) => {
   let (x, o) = move_counts(game.grid);
   not(is_valid_grid(game.grid, game.last_player) && ((x - o) >= 2))
});
```

## Valid games

Let's continue adding some more definitions - we haven't really covered winning criteria as part of `is_valid_grid`, so let's include a few:

```{.imandra .input}
let is_tie = ({grid: {a, b, c, d, e, f, g, h, i}, _}) =>
  List.for_all((!=)(None), [a, b, c, d, e, f, g, h, i]);
```

```{.imandra .input}
let is_valid_game = game => {
  let winning_X = is_winning(game, X);
  let winning_O = is_winning(game, O);
  is_valid_grid(game.grid, game.last_player)
  && (! winning_X && ! winning_O || winning_X != winning_O);
};

```

... and let's ask for a valid game where X is winning:

```{.imandra .input}
instance((game) => is_valid_game(game) && is_winning(game, X));
```

```{.imandra .input}
CX.game;
```

## Valid moves

Looks good! We're on the home stretch now - let's add the last few helper functions around playing moves:

```{.imandra .input}
let is_valid_move = (game, player, move) =>
  ! (is_winning(game, X) || is_winning(game, O) || is_tie(game))
  && is_valid_game(game)
  && (
    game.last_player == None
    && player == initial_player
    || game.last_player == Some(other_player(player))
  );

let play_move = ({grid, _}, player, move) => {
  let play = Some(player);
  let grid =
    switch (move) {
    | A => {...grid, a: play}
    | B => {...grid, b: play}
    | C => {...grid, c: play}
    | D => {...grid, d: play}
    | E => {...grid, e: play}
    | F => {...grid, f: play}
    | G => {...grid, g: play}
    | H => {...grid, h: play}
    | I => {...grid, i: play}
    };
  {grid, last_player: play};
};

let status = game =>
  if (is_winning(game, X)) {
    Won(X);
  } else if (is_winning(game, O)) {
    Won(O);
  } else if (is_tie(game)) {
    Tied;
  } else {
    InProgress;
  };
```

And finally, the function we call from the ReasonReact frontend to actually play the game!

```{.imandra .input}
let play = ({last_player, _} as game, move) => {
  let player =
    switch (last_player) {
    | None => initial_player
    | Some(player) => other_player(player)
    };
  if (is_valid_move(game, player, move)) {
    let game = play_move(game, player, move);
    (game, status(game));
  } else {
    (game, InvalidMove(move));
  };
};
```

...and we're done! Let's add one more verification statement to check that these functions work as we expect. If we've got a valid game, and a valid move, then if we play the move on the game, we should still have a valid game.

```
verify((game, player, move) =>
  (is_valid_game(game) && is_valid_move(game, player, move))
  ==> is_valid_game(play_move(game, player, move))
);
```


The `a ==> b` operator here is the logical "implies" - "if `a` is true, then `b` is also true". It's defined as a regular infix operator in the Imandra prelude:

```{.imandra .input}
(==>)
```

Anyway! Let's actually run the statement:

```{.imandra .input}
verify((game, player, move) =>
  (is_valid_game(game) && is_valid_move(game, player, move))
  ==> is_valid_game(play_move(game, player, move))
);

```

```{.imandra .input}
CX.game;
```

Uh oh! What's gone wrong?

In this case, the problem is clear - player `O` is moving in square `B`, but there's already a move there. If you try out [the initial version of the game](https://docs.imandra.ai/reasonml-tic-tac-toe/index-initial.html) based on the code so far, you'll see the bug if you try and make a move in a square that's already filled.

Imandra has spotted the issue for us from a straightforward statement about the logic of the game!

The culprit is the `is_valid_move` function - we don't check that the square is empty. Let's add `&& value(game, move) == None` to our check:

```{.imandra .input}
let is_valid_move = (game, player, move) =>
  ! (is_winning(game, X) || is_winning(game, O) || is_tie(game))
  && is_valid_game(game)
  && (
    game.last_player == None
    && player == initial_player
    || game.last_player == Some(other_player(player))
  )
  && value(game, move) == None
;

```

... and verify once more (using `[@blast]` to speed it up):

```{.imandra .input}
[@blast]
verify((game, player, move) =>
  (is_valid_game(game) && is_valid_move(game, player, move))
  ==> is_valid_game(play_move(game, player, move))
);
```

Much better! You can play [the final version here](https://docs.imandra.ai/reasonml-tic-tac-toe/), and you'll see that the bug is fixed. Hopefully this gives you a feel for an interactive development workflow with Imandra, in particular how seeing concrete examples can be really useful to understanding what's going on.
