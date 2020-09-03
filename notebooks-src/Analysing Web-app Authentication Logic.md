---
title: "Analysing Web-app Authentication Logic"
description: "In this notebook, we look at some typical authentication logic that might be found in a standard web application, and analyse it with Imandra to make sure it's doing what we expect."
kernel: imandra
slug: webservice-auth-logic
keywords:
  - web-app
  - testing
  - counterexample
difficulty: beginner
---

# Analysing Web-app Authentication Logic

When writing and refactoring we often have to make a lot of assumptions about how our code works. Here we'll look at some example authentication logic written in OCaml that you might find a standard web application codebase, and use Imandra as a tool to analyse it.

Let's imagine our system currently has a user represented by this type:

```{.imandra .input}
type user =
{ is_admin: bool
; username: string
; email: string
}
```

Right. Let's take a look at the core of the authentication logic itself.

```{.imandra .input}
type auth_result = Authed | Not_authed;;

let get_auth_result (path: string) (u : user) : auth_result =
    if String.prefix "/user/" path then
        if String.prefix ("/user/" ^ u.username) path then
            Authed
        else
            Not_authed
    else if String.prefix "/admin" path then
        if u.is_admin then
            Authed
        else
            (* Temporary hack to give co-founder accounts admin access for the demo! - DA 06/05/15 *)
            if List.exists (fun au -> au = u.username) ["diego"; "shannon"] then
                Authed
            else
                Not_authed
    else
        Authed
```

There's even a few tests (although they are a bit rusty...)!

```{.imandra .input}
type test_result = Pass | Fail;;
let run_test f = if f then Pass else Fail;;
```

```{.imandra .input}
run_test ((get_auth_result "/" { username = "test"; email = "email"; is_admin = false }) = Authed);;
run_test ((get_auth_result "/admin" { username = "test"; email = "email"; is_admin = false }) = Not_authed);;
run_test ((get_auth_result "/admin" { username = "test"; email = "email"; is_admin = true }) = Authed);;
run_test ((get_auth_result "/user/paula" { username = "joe"; email = "email"; is_admin = false } = Not_authed));;
run_test ((get_auth_result "/user/paula" { username = "paula"; email = "email"; is_admin = false } = Authed));;
run_test ((get_auth_result "/user/paula/profile" { username = "paula"; email = "email"; is_admin = false } = Authed));;
```

However the tests haven't quite covered all the cases. Let's use Imandra to verify a few things. Note that we've got tests for `is_admin = true` (test 2) and `is_admin = false` (test 3) on the `/admin` route above, but this only checks that these inputs give the desired outcome, and not that _all_ inputs do. So let's verify that all non-admin users are not authenticated for the admin area.

```{.imandra .input}
verify (fun u -> u.is_admin = false ==> (get_auth_result "/admin" u) = Not_authed)
```

This verification fails, and Imandra gives us an example input that violates the assumption we gave it - we hadn't considered the users added by the 'temporary hack' code path in our tests!

We can also ask for a decomposition of all the regions in the `get_auth_result` function, which gives us an idea of the various conditions and complexity:

```{.imandra .input}
Modular_decomp.top ~prune:true "get_auth_result" [@@program];;
```
