---
title: "Scheduling smaller class sizes during Covid"
description: "This notebook demonstrates how to encode and solve a constraint problem of making sure all children from the same family go to school on the same day, when days at school are restricted due to Covid."
kernel: imandra
slug: school-scheduler
key-phrases:
  - OCaml
  - proof
  - instance
---

# Stating the problem

During the Covid pandemic of 2019/2020 it became apparent that due to social distancing, children going to school in the Scotland and elsewhere would only be able to attend for a restricted number of days per week. One of the primary concerns for families was that siblings should attend on the same day. This problem is a classic scheduling problem which can become very tricky due to a combinatorial explosion. This notebook demonstrates how it is possible to encode such a problem and use imandra to write a solver to find a solution.

# Representation of classes, families and students

For the purposes of this demonstration, we assume (without loss of generality) that there are seven years of a primary school, each with 3 classes of 30 students. We randomly populate the school with students and families in such a way as to mimic realistic data. The school is full and is comprised of families of 1,2,3 and 4 students. We encode each student as a unique identifier `S0` to `S629` and each family as an identifier `F0` to `F308`. Each student is mapped to each of 21 classes - `P1A` through to `P7C`.

# Initial data
The initial data for this school is represented by various function on the students and families to denote the distribution of families and students to classes. We also introduce days `M,T,W,Th,F` to represent days. In this instance we solve for the problem of students going one day a week - this is also generalisable according to the specifics of the problem. At the time of writing this was realistic according to the social distancing guidelines in schools meaning a class which ordinarily would accommodate 30 children would now accommodate 6 or 7.

This csv format data held in the variable `csv_data` copies the format  in which schools already encapsulate their data:

```{.imandra .input}
let csv_data = 
"Leanne PATEL P1C
Katie GONZALES P3C,Christopher GONZALES P4B
Peter WALLACE P3C
Gordon BUTLER P4B
Craig KELLY P5B,Stuart KELLY P4B,Leanne KELLY P4B
Deborah MORGAN P7C,Martin MORGAN P7C
Gary COOPER P4A
Gary SIMMONS P2A
Barry COLLINS P2A
Richard CHENG P3C,Martin CHENG P1A
Paul REYNOLDS P2A
Robert HOWARD P1A,Michael HOWARD P6C,Kenneth HOWARD P3C
Paul SULLIVAN P2B
William HUGHES P1C,Jason HUGHES P6C,Caroline HUGHES P7C,Leanne HUGHES P5A
Joanne ROSS P6C
Catherine BROOKS P6B,Siobhan BROOKS P5B
Richard EVANS P1B,Kenneth EVANS P1A,Alan EVANS P4A
Alison EDWARDS P6B,Kevin EDWARDS P1A
Susan GRAHAM P6A,Alexander GRAHAM P1C
Rachael BAILEY P7C
George ROSS P7A
Stephen GRAY P2C,Gary GRAY P1A
Clare JORDAN P2C
Alan MORGAN P6A
Hannah BAILEY P5C
Deborah RICHARDSON P1B
Brian PETERSON P5B,Kathryn PETERSON P2B,Jenna PETERSON P1B,Martin PETERSON P5C
Gary COX P7B,Katie COX P2A
Stephen GONZALES P7B,Scott GONZALES P5B,Suzanne GONZALES P7A,Caroline GONZALES P4C
Jade STEWART P2A,Andrew STEWART P5C
Hannah BAILEY P7B
Pamela JORDAN P6A,Natasha JORDAN P4B,Colin JORDAN P2C,Eilidh JORDAN P3A
Iain GRAY P4C,Jacqueline GRAY P6C
Katie GUTIERREZ P5C,Brian GUTIERREZ P1C,Catherine GUTIERREZ P7B
Susan COLLINS P6A,Stephen COLLINS P6B
Neil TORRES P2B,Rachael TORRES P4A
Natasha KIM P5C,Katie KIM P2C
Jason EVANS P5A
Darren KELLY P6C,Alan KELLY P2C,Pamela KELLY P5A
Brian PERRY P4C
Elizabeth MURPHY P3A,Richard MURPHY P6B,Richard MURPHY P4A,Jason MURPHY P7C
Kerry CHENG P3C,Gary CHENG P5B
Eilidh MORALES P2C,Jenna MORALES P4B,Colin MORALES P6B
Catherine GOMEZ P5A,Brian GOMEZ P6A,Jason GOMEZ P7A
Rachael ETOO P3A,Martin ETOO P3A
Rachael CARTER P4C,Eilidh CARTER P3B
Stephen MORGAN P6A
Alison GOMEZ P5C
Katie HAMILTON P1C
Scott BROOKS P4A,Michael BROOKS P1A,Stephen BROOKS P7B
Kathryn REYNOLDS P5B
Mark TURNER P3B,Kayleigh TURNER P2A
Caroline WEST P1B,Kenneth WEST P3A,Michael WEST P7C
Rachael FLORES P4A
Iain WATSON P4C
Derek PATTERSON P3B
Michael CARTER P1B,Kerry CARTER P7A
Alexander ETOO P2B,Alison ETOO P7A
Gary COLE P5A,Mark COLE P1C
Susan SULLIVAN P6B,Kathryn SULLIVAN P2B,Alexander SULLIVAN P4C
Alison FOSTER P3A,Craig FOSTER P2B,Robert FOSTER P7A
Deborah MORALES P3B
Leanne COLE P3C,Deborah COLE P6C
Suzanne BARNES P5A,Caroline BARNES P3B,Stuart BARNES P3B
Kenneth SANDERS P7B
Richard ROGERS P1B
Kerry MURPHY P6A,Hayley MURPHY P7A
Barry EVANS P7A
Kevin HENDERSON P1C,Graham HENDERSON P1C
Suzanne WEST P1C
Alison LONG P6A,Richard LONG P4B,Craig LONG P7A
Colin TORRES P6A
Alexander CRUZ P4A,Catherine CRUZ P4A
Catherine PHILLIPS P1A
Kenneth HUGHES P1C
Jenna PRICE P1A
Rachael TURNER P2B
Paul COLEMAN P4A
Barry MORRIS P5A,Iain MORRIS P7A,Eilidh MORRIS P1A
Karen JENKINS P2A,Craig JENKINS P3C
Scott KHAN P1C
Richard ROGERS P2C,Pamela ROGERS P2A
Michael FLORES P3C,Robert FLORES P7B,Neil FLORES P5B
Caroline REYNOLDS P2A
Gordon HENDERSON P4B
Martin PARKER P1C
George EDWARDS P6A
Rachael WEST P3A,Barry WEST P3C,Andrew WEST P2B
Kenneth GRAY P5A
Jacqueline STEWART P2B,Graeme STEWART P3C
Barry COOK P2C,Brian COOK P2C,Natasha COOK P4C
Thomas KHAN P5C
Joanne PARKER P3A
Kayleigh EDWARDS P2C,Kathryn EDWARDS P6C,William EDWARDS P6C,Barry EDWARDS P5C
Paul COOPER P7B
Kenneth PATTERSON P4C,Craig PATTERSON P7C
Joanne COOK P2A
Susan CARTER P3A,Scott CARTER P3C
Caroline LONG P7B,Craig LONG P2B,Stuart LONG P3A
Paul SIMMONS P3B
Darren JENKINS P2B
Gary HAMILTON P7C
Alexander COLE P5C
Graeme MORGAN P2C,Jade MORGAN P7A,Barry MORGAN P2B
Stuart HENDERSON P4B,Joanne HENDERSON P4C,Suzanne HENDERSON P2A
Hayley BENNETT P5A,Julie BENNETT P6B,Jason BENNETT P5B
Gordon STEWART P4C,Karen STEWART P6B
Gordon CARTER P4A,Joanne CARTER P6C,Richard CARTER P7B
Peter TURNER P7C
Jason KIM P1B,Andrew KIM P4A,Brian KIM P6C
Alison SANDERS P6B,Caroline SANDERS P7A
Peter WARD P6B
Paul COLE P1B,Darren COLE P3A,Hayley COLE P3B
Hannah GRAHAM P5C,Andrew GRAHAM P3B,Barry GRAHAM P3B
Pamela GOMEZ P6C
Katie CARTER P6A,Julie CARTER P2A,Deborah CARTER P3C
Julie KIM P1B
Ian LONG P3A,Kenneth LONG P1B,Pamela LONG P5B
Catherine COX P7C,Scott COX P5A,Karen COX P1A
Gary FISHER P1B
James ETOO P7C,Martin ETOO P7C,Graham ETOO P3B,Jade ETOO P4C
Brian MORGAN P6B,Kayleigh MORGAN P2C
George REYES P7B,Neil REYES P6C,Iain REYES P1B,Natasha REYES P4B
Rachael RICHARDSON P4B
Kenneth KELLY P5B
Derek SULLIVAN P5C,Scott SULLIVAN P4C
Barry KHAN P5C
Clare TURNER P1A
Hannah ALEXANDER P5B
Deborah RIVERA P5A
Susan SANDERS P4A,Derek SANDERS P3B,Hayley SANDERS P4B
Kevin COOK P7B,Eilidh COOK P5B,Jenna COOK P1A,Julie COOK P6A
Susan COLLINS P6B,Rachael COLLINS P5A
Craig WOOD P7B,Brian WOOD P1A,Clare WOOD P1A
Steven SIMMONS P5A,Hannah SIMMONS P7B,Joanne SIMMONS P7B,Mark SIMMONS P1A
Craig PETERSON P1A
Andrew BARNES P5A
Lynsey REED P4B,Alan REED P4B
Darren PRICE P5A,Stuart PRICE P1C
Jason BELL P7B,Clare BELL P6A
Deborah MORGAN P1A,Jenna MORGAN P5B,Steven MORGAN P4B,Suzanne MORGAN P4B
Richard ROGERS P5B,Suzanne ROGERS P1C
Joanne REYNOLDS P6C,Colin REYNOLDS P4C
Stuart WARD P4C,Martin WARD P6A
Christopher WOOD P7C,Eilidh WOOD P6A
Elizabeth CARTER P5C,Jason CARTER P1C,Stuart CARTER P6B
Kayleigh WALLACE P2B,Hayley WALLACE P2C,Jason WALLACE P5A
Jade PHILLIPS P5C
Elizabeth GRAY P6A
Kevin COOK P7A,Kenneth COOK P4C,Richard COOK P4A,Catherine COOK P2C
Mark HENDERSON P1C
Alan ROSS P2C,James ROSS P7C
Ian ROSS P5B,Alan ROSS P7B
Paul ORTIZ P6C,William ORTIZ P3A,Clare ORTIZ P2A
Siobhan TURNER P3A
Steven CARTER P6B,Michael CARTER P3C,Craig CARTER P2A
Michael NGUYEN P3B
Stuart BENNETT P6A
Natasha SIMMONS P6C,Karen SIMMONS P1B,Deborah SIMMONS P4C,Natasha SIMMONS P4A
Craig POWELL P6B,Ian POWELL P3B
Suzanne LONG P3B,Peter LONG P5B,Alan LONG P1C
Rachael COOK P4C
Brian FOSTER P3B
Clare HENDERSON P2A
Kevin HENDERSON P7C,Stuart HENDERSON P3C,Gary HENDERSON P2C
Elizabeth LONG P6C
Caroline REYNOLDS P4B,Paul REYNOLDS P4B,Mark REYNOLDS P1B
Graeme ROGERS P2B
Alexander ALEXANDER P2A
Mark GRAY P4A
Alexander GOMEZ P1B
Julie REED P2A
Robert WEST P3B
Katie EDWARDS P6C
Graham GONZALES P7A,Pamela GONZALES P4C
Clare PATTERSON P5A
Rachael BELL P2C,Barry BELL P7A
Mark EDWARDS P5C,Rachael EDWARDS P4A,Lynsey EDWARDS P5A,Paul EDWARDS P2B
Graham WEST P7A,Karen WEST P1B,Kayleigh WEST P5C,William WEST P3C
Joanne PETERSON P4A
George GUTIERREZ P5B,Clare GUTIERREZ P6B,Gary GUTIERREZ P2B
Stephen KIM P3C,Robert KIM P2C
Joanne BROOKS P2B,Alan BROOKS P3A
Graham JAMES P6A,George JAMES P3A
Lynsey REYNOLDS P3A
Karen EDWARDS P7A
Natasha TURNER P3A
Ian SULLIVAN P4A,Steven SULLIVAN P1B,Darren SULLIVAN P7C
Kenneth CHENG P1A,Kerry CHENG P1C
Kayleigh LONG P7C
Alexander GRAY P6B,Mark GRAY P2A,Hannah GRAY P3C
Derek EDWARDS P6C
Kathryn PATEL P3C
James SANDERS P7A,Kerry SANDERS P7C,Natasha SANDERS P2B
Darren SULLIVAN P7B
Colin GRAY P5C,Julie GRAY P5B,Ian GRAY P6B
Graeme CARTER P1B,Peter CARTER P5C,Kenneth CARTER P3B
Kerry WARD P4B
Robert SANDERS P2B
Derek PARKER P6A,Craig PARKER P2B,Neil PARKER P2B
Pamela TORRES P3B,Karen TORRES P4B
Hannah ROSS P4B
Gordon PATEL P6A
Jade ETOO P6A,William ETOO P4C
Thomas RIVERA P6B
Graham EVANS P2B
Kathryn BARNES P4C,Siobhan BARNES P6B
Mark BENNETT P5B,James BENNETT P1B
Iain BUTLER P7B
Graham HENDERSON P4B
Siobhan ETOO P7B,Rachael ETOO P4C
Suzanne NGUYEN P5B,Brian NGUYEN P1A,Kerry NGUYEN P1A,Jason NGUYEN P1A
Elizabeth COLEMAN P5B
James MURPHY P5A
Richard DIAZ P7B,Graham DIAZ P7C,Thomas DIAZ P3B,Steven DIAZ P1B
Kenneth GRAHAM P4B
Eilidh HOWARD P5C,Gordon HOWARD P5C,Siobhan HOWARD P3B,Craig HOWARD P6A
Michael GONZALES P7C,Kathryn GONZALES P5A
Pamela GONZALES P7C,Gordon GONZALES P7C,Gary GONZALES P3C
Deborah TORRES P7B,Deborah TORRES P7C
Gary BUTLER P3C,Jacqueline BUTLER P7B,Alexander BUTLER P3B,Hannah BUTLER P1A
Caroline COX P3C
Iain HUGHES P7B,Kevin HUGHES P6B
Richard FOSTER P3C
William KELLY P1C,Andrew KELLY P6B,Kenneth KELLY P1C,Barry KELLY P2A
Paul MURPHY P2C,Suzanne MURPHY P2A,Brian MURPHY P3A,Karen MURPHY P1B
Susan PATEL P3A
Leanne STEWART P4C
Eilidh DIAZ P1B,George DIAZ P3A,Darren DIAZ P3A,Ian DIAZ P3C
Iain REYNOLDS P5A,Robert REYNOLDS P6A
William ROSS P6B
Susan PATTERSON P5B,Lynsey PATTERSON P5C,Pamela PATTERSON P6A,Alexander PATTERSON P2A
Iain GOMEZ P6C,Kevin GOMEZ P6C,Hannah GOMEZ P2B,Mark GOMEZ P5A
George DIAZ P4A
Mark ROGERS P3A,Christopher ROGERS P2C
Eilidh BENNETT P7A,Richard BENNETT P3B
Robert MORGAN P1C,Barry MORGAN P2A,Neil MORGAN P5C,Richard MORGAN P1A
Steven PATTERSON P7A
Robert CRUZ P4B
Lynsey TORRES P3A,Karen TORRES P1C
Stephen POWELL P6C
Thomas COOK P7A
Alan WALLACE P1C,Susan WALLACE P4A
Alan REED P1B,Clare REED P4A,Rachael REED P7C,Karen REED P4A
Brian DIAZ P7A
Hayley WALLACE P3B,Neil WALLACE P7A
Jason COOPER P5B,Barry COOPER P5C,Jacqueline COOPER P5C
Leanne CRUZ P4C,Hannah CRUZ P2A,Deborah CRUZ P6C
Siobhan FISHER P2A
Kathryn HUGHES P1B
Caroline JAMES P3C
Barry PATTERSON P5A
Stuart RICHARDSON P6C,Lynsey RICHARDSON P6C
Jenna KIM P6B
Kayleigh HUGHES P2C,Jason HUGHES P2B,Gordon HUGHES P2C
Leanne MYERS P5B,Barry MYERS P7A,Eilidh MYERS P5A
Natasha ROGERS P1C,Christopher ROGERS P4A,Stephen ROGERS P4A
Susan BARNES P2C,Barry BARNES P1A
Martin EDWARDS P2C
Natasha CARTER P4C
Kenneth COX P7C,Thomas COX P3A,Alexander COX P3A,Jacqueline COX P3A
Jade TURNER P3A,Alexander TURNER P5A
Robert SULLIVAN P3A
Paul ROGERS P5A,Kevin ROGERS P5A,Neil ROGERS P1B
Christopher GOMEZ P3C
Jacqueline PATEL P6A
Thomas FLORES P1B,Leanne FLORES P1B
Martin TURNER P3C
Jacqueline GUTIERREZ P2B
Julie RICHARDSON P4B,Jade RICHARDSON P2A
Elizabeth BELL P1B,Richard BELL P6A,William BELL P3B,Caroline BELL P6B
Mark ALEXANDER P7B,Jenna ALEXANDER P2C
Jade LONG P6B,Kevin LONG P1B,Eilidh LONG P3A
Rachael BAILEY P7C
Darren FISHER P4B,Neil FISHER P4A,Ian FISHER P7C,Graham FISHER P5C
Eilidh STEWART P5C,Karen STEWART P7A
Kevin SANDERS P3C
Catherine ORTIZ P2C,Christopher ORTIZ P6B,Graham ORTIZ P7A
Rachael REYES P5C,Scott REYES P3C,Catherine REYES P7B
Kayleigh RAMOS P2C
Joanne FLORES P2A,Stephen FLORES P7C,Ian FLORES P4A
Elizabeth GONZALES P2A,Suzanne GONZALES P7A,Stuart GONZALES P5C
Leanne COOK P2B
Natasha PATEL P7B
Susan ROGERS P1B
Catherine PRICE P7A,Graeme PRICE P3B,Jacqueline PRICE P7B
Catherine EVANS P1C
Siobhan ROGERS P2C,Kayleigh ROGERS P6A
Joanne RUSSELL P7A,William RUSSELL P5B,Rachael RUSSELL P2B,Deborah RUSSELL P2B
Susan ALEXANDER P5B
Kayleigh MURPHY P7B,Kerry MURPHY P4A
Julie GONZALES P5B,Jenna GONZALES P1C
Ian HAMILTON P1C,Elizabeth HAMILTON P2C
Kevin COOK P1C,Jason COOK P1A,Caroline COOK P6B
Richard COLLINS P5C,Robert COLLINS P6C,Mark COLLINS P6A
Stuart BAILEY P5A
Kerry MORRIS P7C
Joanne WOOD P6C,Alison WOOD P1A,Elizabeth WOOD P2C
Kenneth NGUYEN P6C,Michael NGUYEN P6A
Stephen HAMILTON P1A
Stephen COOK P6B,Leanne COOK P6C
Kayleigh RICHARDSON P5A
George PERRY P5B,Kevin PERRY P2A
Darren DIAZ P3B
Leanne REYES P5C
Jason WOOD P3B
Mark BUTLER P3B
Paul RIVERA P7B
Peter WATSON P7C
Lynsey COLLINS P1A,Leanne COLLINS P6C
Eilidh ETOO P1A,Richard ETOO P2B,Leanne ETOO P4B
Neil PATTERSON P4C
Gary WOOD P4B
Robert RIVERA P3C
George REYES P4A,Mark REYES P5B,Craig REYES P1C
Kevin MORALES P4C,Scott MORALES P1C
Christopher SANDERS P4A
Alan ROGERS P2A,Rachael ROGERS P3C
Alison ALEXANDER P6C,Christopher ALEXANDER P4C
Elizabeth WATSON P4C
Scott COLE P5B
Graham REYNOLDS P2B,Pamela REYNOLDS P4B,Pamela REYNOLDS P1A
Susan WOOD P3B
Natasha WARD P5A,Robert WARD P4B
Suzanne FISHER P7A,Graham FISHER P4C
Graham GRAY P6B,Andrew GRAY P2A,Kenneth GRAY P6A
Jade RAMOS P4C
Stuart POWELL P4A";;
```

and contains text of randomly generated sample school data which describes on each line families of students, and at the end of each comma separated student entry, a designated class is given. For example

```
Katie GONZALES P3C,Christopher GONZALES P4B
```

denotes a family of two students, Katie and Christopher Gonzales, in classes `P3C` and `P4B`. We want to ensure that Katie and Christopher both go to school on the same day, and make sure this is the case for all families at the school. In this example there are 21 classes and 630 students, which 30 in each class ordinarily, but now this is restricted to 7.

We can now encode a simple solver to determine how to find a solution. This simply gives back a list of days corresponding to a day allocation per family.


```{.imandra .input}
type day = M | T | W | Th | Fr
;;

let class_day_alloc = fun _ -> 20;;

let string_of_day = function
  | M -> "Monday"
  | T -> "Tuesday"
  | W -> "Wednesday"
  | Th -> "Thursday"
  | Fr -> "Friday"
;;

type student_id = S of int;;
type family_id = F of int;;
type class_id = C of string;;

type alloc = student_id -> day
let init_map : (class_id*day,int) Map.t =
  Map.const 0;;

let init_map : (class_id*day,int) Map.t =
  Map.const 0;;


let rec update_map classes map day =
  match classes with
  | [] -> map
  | h::t ->
    let res = Map.get (h,day) map in
    let new_map = Map.add (h,day) (res+1) map in
    update_map t new_map day
;;


let rec valid_alloc_by_list (alloc:(day*family_id) list) class_map families families_class_list  = 
  match families with
  | x :: xs ->
    begin
      match List.find (fun (_d,f)-> f = x) alloc with 
      | None -> false 
      | Some (d,_) -> 
        (* Check class size is within bounds *)
        let classes = Map.get x families_class_list in
        if List.exists (fun x -> Map.get (x,d) class_map = class_day_alloc x) classes then false else
          let updated_map = update_map classes class_map d in
          valid_alloc_by_list alloc updated_map xs families_class_list 
    end
  | _ -> true [@@measure (Ordinal.of_int (List.length families))]
;;

let solver_sort classes class_map = 
  let rec fold_cut num_in classes day = 
    match classes with 
    | [] -> true, num_in
    | h::t -> 
      let num_used = Map.get (h,day) class_map in 
      if num_used<class_day_alloc h then fold_cut (num_in+num_used) t day else 
        false,0
  in
  let nums_days = List.fold_left (fun acc day -> 
      let res = fold_cut 0 classes day in 
      if (fst res) then (day,snd res)::acc else acc
    ) [] [M;T;W;Th;Fr] in 
  List.sort ~leq:(fun (_,y) (_,z) -> y<=z) nums_days |>
  List.map fst
[@@program]
;;

let rec calc_alloc class_map families alloc families_class_map = 
  let rec try_all_days days_list t classes class_map orig_class_map alloc orig_alloc fam = 
    match days_list with 
    | [] -> false,orig_alloc
    | h::t_days -> 
      let updated_map = 
        List.fold_left (fun acc_map el -> 
            let ans = Map.get (el,h) acc_map in
            Map.add (el,h) (ans+1) acc_map) class_map classes in
      let res = (calc_alloc  updated_map t ((h,fam)::alloc) families_class_map)  in 
      if (fst res) then res else 
        try_all_days t_days t classes orig_class_map orig_class_map alloc orig_alloc fam in
  match families with 
  | [] -> true,alloc 
  | h::t -> 
    begin
      let classes = Map.get h families_class_map  in 
      let days_list = solver_sort (Map.get h families_class_map) class_map in 
      try_all_days days_list t classes class_map class_map alloc alloc h
    end 
[@@program];;



let print_res r families_student_list student_names = 
  snd @@ List.fold_left (fun (cnt,acc) el -> 
      cnt+1,(
        let stds =Map.get (F cnt) families_student_list in 
        acc^List.fold_left (fun inner_acc st -> 
            let nm = Map.get st student_names in
            "Student "^nm^" goes on "^(string_of_day el)^"\n"^inner_acc) "" stds
      ))
    (0,"")  (List.rev r) [@@program];;

```

Now we can read in this csv file and ask the solver to find an allocation for each student, maintaining the requirement that all students from each family must go to school on the same day.


```{.imandra .input}

let parse_csv ~lines  = 
  let student_names = ref [] in 
  let families = ref [] in 
  let families_class_list = ref [] in
  let families_student_names = ref [] in 
  let class_map = ref (Map.const []) in 
  let cnt = ref 0 in
  let fam_cnt = ref 0 in
        Caml.List.iter (fun line -> 
        let st_names = Caml.String.split_on_char ',' line in 
        let these_students = ref [] in
        let these_classes = ref [] in
        Caml.List.iter (fun n -> 
            let st_name_class_name = Caml.String.split_on_char ' ' n in 
            match st_name_class_name with 
            | [fn;sn;cn] -> 
              begin
                these_students := (S !cnt)::!these_students;
                these_classes := (C cn)::!these_classes;           
                student_names := (S !cnt,(fn^" "^sn))::!student_names;
                let clstds = Map.get (C cn) !class_map in
                class_map := Map.add (C cn) ((S !cnt)::clstds) !class_map;
                cnt := !cnt+1
              end
            | _ -> ()) st_names;
        families_class_list := (F !fam_cnt,!these_classes)::!families_class_list;
        families_student_names := (F !fam_cnt,!these_students)::!families_student_names;
        families := (F !fam_cnt,!these_students)::!families;
        fam_cnt := !fam_cnt+1) lines; 
    Map.of_list ~default:[] !families_class_list, !families,Map.of_list ~default:("anon") !student_names, Map.of_list ~default:[] !families_student_names
   [@@program]
;;

let solve_from_csv s = 
  let lines = Caml.String.split_on_char '\n' s in 
  let families_class_map, families, student_names, families_student_list = parse_csv ~lines in 
  let families_sorted = List.sort ~leq:(fun (_,a) (_,b) -> List.length a >= List.length b) families in
  let res = calc_alloc init_map (List.map fst families_sorted) [] families_class_map in
  if (fst res) then 
    print_res (List.map fst (snd res)) families_student_list student_names,families,families_class_map,snd res
  else 
    "No solution found",families,families_class_map,snd res
[@@program];;

let verify_alloc s = 
  let print_value,families,fmap,ans = solve_from_csv s in 
  if valid_alloc_by_list ans init_map (List.map fst families)fmap 
  then print_endline (print_value^"\nSolution Verified") 
  else print_endline "Incorrect solution" [@@program]
;;
```
Now we can use imandra to solve the problem using
```{.imandra .input}
verify_alloc csv_data;;
```
