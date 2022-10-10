---
title: "Obligation rules."
description: "How to determine the inter-relatedness or consistency of a rule set."
kernel: imandra
slug: singasong
key-phrases:
  - OCaml
  - proof
  - instance
difficulty: easy
---

# Rule consistency or duplications


Here are the background types and functions we can use to represent the obligations and artifacts in these examples.
```{.imandra .input}
type obligations = {
  sing_a_song: bool;
  do_a_dance: bool;
}

type employee = {
  name : string;
  arrival_time : int;
  obligations : obligations;
}

type state = {
  emp: employee;
  meeting_time: int;
}

let on_time st =
  st.emp.arrival_time <= st.meeting_time

let is_late st =
  not (on_time st)
```


Now for a particular rules we can represent this modules, which have a common structure.

```{.imandra .input}
(* Employee E must sing a song
   if E is late for a meeting for n minutes
   and n is greater than 3*)

module Rule0 = struct

 let c1 st =
  is_late st

 let c2 st =
  st.emp.arrival_time - st.meeting_time > 3

 let cs st =
  c1 st && c2 st

 let s st =
  st.emp.obligations.sing_a_song

 let rule st =
  s st <== cs st

end
```





```{.imandra .input}
(*
  Employee E must sing a song
  if E is late for a meeting for n minutes
  and n is greater than 1
*)

module Rule1 = struct

 let c1 st =
  is_late st

 let c2 st =
  st.emp.arrival_time - st.meeting_time > 1

 let cs st =
  c1 st && c2 st

 let s st =
  st.emp.obligations.sing_a_song

 let rule st =
  s st <== cs st

end
```







We can ask questions about these rules such as if the statements overlap using Imandra's instance mechanism:

```{.imandra .input}
(* Do Rule0's and Rule1's conditions overlap? *)

instance (fun st -> (Rule0.c1 st) && (Rule1.c1 st))
```









```{.imandra .input}
(* Employee E must sing a song
   if E is late for a meeting for n minutes
   and n is less than 3*)

module Rule2 = struct

 let c1 st =
  is_late st

 let c2 st =
  st.emp.arrival_time - st.meeting_time < 3

 let cs st =
  c1 st && c2 st

 let s st =
  st.emp.obligations.sing_a_song

 let rule st =
  s st <== cs st

end
```





```{.imandra .input}
(* Employee E must do a dance
   if E is late for a meeting for n minutes
   and n is greater than 3*)

module Rule3 = struct

 let c1 st =
  is_late st

 let c2 st =
  st.emp.arrival_time - st.meeting_time > 3

 let cs st =
  c1 st && c2 st

 let s st =
  st.emp.obligations.do_a_dance

 let rule st =
  s st <== cs st

end
```





```{.imandra .input}
(* Employee E must NOT sing a song
   if E is late for a meeting for n minutes
   and n is greater than 1 *)

module Rule3 = struct

 let c1 st =
  is_late st

 let c2 st =
  st.emp.arrival_time - st.meeting_time > 1

 let cs st =
  c1 st && c2 st

 let s st =
  not (st.emp.obligations.sing_a_song)

 let rule st =
  s st <== cs st

end
```








```{.imandra .input}
(* Employee E must not sing a song
   if E is late for a meeting for n minutes
   and n is greater than 3 *)

module Rule4 = struct

 let c1 st =
  is_late st

 let c2 st =
  st.emp.arrival_time - st.meeting_time > 3

 let cs st =
  c1 st && c2 st

 let s st =
  not (st.emp.obligations.sing_a_song)

 let rule st =
  s st <== cs st

end
```





```{.imandra .input}
(* Employee E must do a dance
   if E is late for a meeting for n minutes
   and n is greater than 3 *)

module Rule5 = struct

 let c1 st =
  is_late st

 let c2 st =
  st.emp.arrival_time - st.meeting_time > 1

 let cs st =
  c1 st && c2 st

 let s st =
  st.emp.obligations.do_a_dance

 let rule st =
  s st <== cs st

end
```






```{.imandra .input}
(* Employee E must sing a song
   if E is late for a meeting for n minutes
   and n is less than 3 *)

module Rule6 = struct

 let c1 st =
  is_late st

 let c2 st =
  st.emp.arrival_time - st.meeting_time < 3

 let cs st =
  c1 st && c2 st

 let s st =
  st.emp.obligations.sing_a_song

 let rule st =
  s st <== cs st

end
```






```{.imandra .input}
(* Employee E must not sing a song
   if E is late for a meeting for n minutes
   and n is greater than 1 *)

module Rule7 = struct

 let c1 st =
  is_late st

 let c2 st =
  st.emp.arrival_time - st.meeting_time > 1

 let cs st =
  c1 st && c2 st

 let s st =
  not (st.emp.obligations.sing_a_song)

 let rule st =
  s st <== cs st

end
```






```{.imandra .input}
(* Employee E must not sing a song
   if E is late for a meeting for n minutes
   and n is less than 3 *)

module Rule8 = struct

 let c1 st =
  is_late st

 let c2 st =
  st.emp.arrival_time - st.meeting_time < 3

 let cs st =
  c1 st && c2 st

 let s st =
  not (st.emp.obligations.sing_a_song)

 let rule st =
  s st <== cs st

end
```







# Let's pose some queries about the relationships of these rules


```{.imandra .input}
(* Do the conditions of rules 0 and 1 overlap? *)

instance (fun st -> Rule0.cs st && Rule1.cs st)
```








```{.imandra .input}
(* Do the statements of rules 0 and 1 overlap? *)

instance (fun st -> Rule0.s st && Rule1.s st)
```













```{.imandra .input}
(* We can encode these as checks on rules.
   We prefix with `v` if `verify` should be used, else with `i` if `instance` should be used. *)

let v_check_1 r1_cs r1_s r2_cs r2_s st =
  r1_s st = r2_s st && r1_cs st = r2_cs st
```





```{.imandra .input}
(* For example, we can do check1 for Rule0 and Rule0 *)

verify (fun st -> v_check_1 Rule0.cs Rule0.s Rule0.cs Rule0.s st)
```






```{.imandra .input}
(* And similarly for Rule0 and Rule1 *)

verify (fun st -> v_check_1 Rule0.cs Rule0.s Rule1.cs Rule1.s st)
```





```{.imandra .input}
(* Now let's consider check2: statements the same but conditions different (overlapping) *)
(* We do this with two checks, one universal and one existential: *)

let v_check2 r1_cs r1_s r2_cs r2_s st =
 r1_s st = r2_s st

let i_check2 r1_cs r1_s r2_cs r2_s st =
 r1_cs st && r2_cs st
```







```{.imandra .input}
(* Let's check condition 2 for Rule0 and Rule1 -- we see it holds! *)

verify (fun st -> v_check2 Rule0.cs Rule0.s Rule1.cs Rule2.s st)
instance (fun st -> i_check2 Rule0.cs Rule0.s Rule1.cs Rule2.s st)
```





```{.imandra .input}
(* Let's check condition 2 for Rule0 and Rule2 -- we see it does not hold! *)

verify (fun st -> v_check2 Rule0.cs Rule0.s Rule2.cs Rule2.s st)
instance (fun st -> i_check2 Rule0.cs Rule0.s Rule2.cs Rule2.s st)
```





```{.imandra .input}
(* Now let's do check 7: contrary statements with same conditions *)

let v_check7 r1_cs r1_s r2_cs r2_s st =
 (r1_s st <==> not(r2_s st)) && (r1_cs st = r2_cs st)
```







```{.imandra .input}
(* We'll check this for Rule0 and Rule 4 *)

verify (fun st -> v_check7 Rule0.cs Rule0.s Rule4.cs Rule4.s st)
```




```{.imandra .input}
(* Now let's check it for Rule0 and Rule5 -- we see it's not true! *)

verify (fun st -> v_check7 Rule0.cs Rule0.s Rule5.cs Rule5.s st)
```












Let's look at a region decomp of a particular rule to get examples of its distinct behaviours.


```{.imandra .input}
let rule5 = Rule5.rule;;
```







```{.imandra .input}
Modular_decomp.top "rule5";;

```
