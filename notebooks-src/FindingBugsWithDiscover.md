# Finding Bugs With Discover

Let's see a simple example of using Imandra Discover to quickly and easily find potential bugs in your code.  In this example we will consider a database containing background checks of individuals, and see if there is a potential problem with our access model.  First, we will `open` the module containing the top level functions for Discover.

```{.imandra .input}
open Imandra_discover_bridge.User_level;;
```

  We define a small module containing a type for whether or not an individual's background is good or bad.

```{.imandra .input}
module Background = struct

  type t =
    | Clean
    | Bad

end;;

```

We define a permissions module meant to reflect whether a user has access privileges to the database.

```{.imandra .input}
module Permissions = struct

  type t =
    | None
    | Full

end;;

```

A person has both a name and a permission level.

```{.imandra .input}
module Person = struct

  type t =
    {
      name : string;
      permission_level : Permissions.t;
    }

  let mk name permission_level =
    {name; permission_level}

end;;

```

The connection to the database is either open or closed.

```{.imandra .input}
module Connection = struct

  type t =
    | Open
    | Closed

  let is_open = function
    | Open -> true
    | Closed -> false

end;;

```

Our database consists of a store that is a mapping from a person to their background and a status field that determines whether or not the connection to the database is active.

```{.imandra .input}
module DB = struct

  type t =
    {
      store : (Person.t,Background.t) Map.t;
      status : Connection.t;
    }

  let is_open x =
    Connection.is_open x.status

end;;

```

Now, let's define some small functions.  `admin` is a superuser with full permissions to the database.  `open_connection` gives us the database with the connection open if the user has the appropriate permissions and returns the database otherwise.  `get` returns the background status of an individual if the connection is open.

```{.imandra .input}
let admin = Person.mk "admin" Permissions.Full;;

let open_connection (db : DB.t) (person : Person.t) : DB.t =
  match person.permission_level with
  | None -> db
  | Full -> {db with status = Open};;

let get (db : DB.t) (query : Person.t) : Background.t option =
  match db.status with
  | Open -> Option.return @@ Map.get query db.store
  | Closed -> None;;

```

To use Imandra Discover, we need to specify a list of functions that we are interested in investigating.

```{.imandra .input}
let funlist = ["admin";"DB.is_open";"open_connection";"get";"true"];;

```

Now, we will run Discover on these functions.

```{.imandra .input}
Imandra_discover_bridge.User_level.discover db funlist;;

```

Discover quickly returns with some conjectures for us to look at.  The first one says that the connection to the database is open if the admin attempts to open it, which seems fine.  The third one is that if the same person attempts to open the database twice, the result is the same.  The fourth one says that the order in which users attempt to open the connection does not matter.

However, let's look at the second conjecture.  It says that if an admin first opens the connection, then anyone else who attempts to open the connection afterwards will have full access!  This is a security vulnerability, and so we need to think about how to fix `open_connection`.  One idea would be to ensure that the connection to the database is closed if someone without access privileges attempts to connect.  

In this example, we demonstrated that Discover is a general purpose tool that can be used for quickly and easily detecting bugs in arbitrary programs, in addition to its other uses like finding lemmas for use in theorem proving.

```{.imandra .input}

```
