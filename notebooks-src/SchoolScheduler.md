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

This data in this [school student csv file](data.csv) contains text of randomly generated sample school data which describes on each line families of students, and at the end of each comma separated student entry, a designated class is given. For example

```
Julie REYES P6A,Jenna REYES P1A,Siobhan REYES P2C
```


denotes a family of three students, Julie, Jenna and Siobhan Reyes, in classes `P6A`, `P1A` and `P2C`. We want to ensure that Julie, Jenna and Siobhan all go to school on the same day, and make sure this is the case for all families at the school. In this example there are 21 classes and 630 students, which 30 in each class ordinarily, but now this is restricted to 7.

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


let rec valid_alloc_by_list (alloc:(day*family_id) list) class_map families cnt families_class_list  = 
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
          valid_alloc_by_list alloc updated_map xs (cnt+1) families_class_list 
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
let parse_csv ~filename  = 
  let comma_separator = Str.regexp "," in
  let space_separator = Str.regexp " " in
  let student_names = ref [] in 
  let families = ref [] in 
  let families_class_list = ref [] in
  let families_student_names = ref [] in 
  let class_map = ref (Map.const []) in 
  let ic = open_in filename in
  let cnt = ref 0 in
  let fam_cnt = ref 0 in
  try 
    while true; do
      begin
        let line = input_line ic in
        let st_names = (Str.split comma_separator line) in 
        let these_students = ref [] in
        let these_classes = ref [] in
        Caml.List.iter (fun n -> 
            let st_name_class_name = Str.split space_separator n in 
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
        fam_cnt := !fam_cnt+1
      end;
    done;
    close_in ic;
    Map.of_list ~default:[] !families_class_list, !families,Map.of_list ~default:("anon") !student_names, Map.of_list ~default:[] !families_student_names
  with 
  | End_of_file -> 
    close_in ic; 
    Map.of_list  ~default:[] !families_class_list, !families,Map.of_list ~default:("anon") !student_names, Map.of_list ~default:[] !families_student_names
  | e -> 
    raise e [@@program]
;;

let solve_from_csv ~filename  = 
  let families_class_map, families, student_names, families_student_list = parse_csv ~filename in 
  let families_sorted = List.sort ~leq:(fun (_,a) (_,b) -> List.length a >= List.length b) families in
  let res = calc_alloc init_map (List.map fst families_sorted) [] families_class_map in
  if (fst res) then 
    print_res (List.map fst (snd res)) families_student_list student_names,families,families_class_map,snd res
  else 
    "No solution found",families,families_class_map,snd res
[@@program];;

let verify_alloc ~filename = 
  let print_value,families,fmap,ans = solve_from_csv ~filename in 
  if valid_alloc_by_list ans init_map (List.map fst families) 0 fmap 
  then print_endline (print_value^"\nSolution Verified") 
  else print_endline "Incorrect solution" [@@program]
;;
```
Now we can use imandra to solve using the data file above
```
solve_from_csv ~filename:"data.csv";;
``` 
which produces the output
```
Student Leanne PATEL goes on Monday
Student Katie GONZALES goes on Monday
Student Christopher GONZALES goes on Monday
Student Peter WALLACE goes on Tuesday
Student Gordon BUTLER goes on Monday
Student Craig KELLY goes on Tuesday
Student Stuart KELLY goes on Tuesday
Student Leanne KELLY goes on Tuesday
Student Deborah MORGAN goes on Tuesday
Student Martin MORGAN goes on Tuesday
Student Gary COOPER goes on Wednesday
Student Gary SIMMONS goes on Wednesday
Student Barry COLLINS goes on Thursday
Student Richard CHENG goes on Friday
Student Martin CHENG goes on Friday
Student Paul REYNOLDS goes on Tuesday
Student Robert HOWARD goes on Thursday
Student Michael HOWARD goes on Thursday
Student Kenneth HOWARD goes on Thursday
Student Paul SULLIVAN goes on Friday
Student William HUGHES goes on Wednesday
Student Jason HUGHES goes on Wednesday
Student Caroline HUGHES goes on Wednesday
Student Leanne HUGHES goes on Wednesday
Student Joanne ROSS goes on Thursday
Student Catherine BROOKS goes on Wednesday
Student Siobhan BROOKS goes on Wednesday
Student Richard EVANS goes on Monday
Student Kenneth EVANS goes on Monday
Student Alan EVANS goes on Monday
Student Alison EDWARDS goes on Friday
Student Kevin EDWARDS goes on Friday
Student Susan GRAHAM goes on Monday
Student Alexander GRAHAM goes on Monday
Student Rachael BAILEY goes on Wednesday
Student George ROSS goes on Friday
Student Stephen GRAY goes on Wednesday
Student Gary GRAY goes on Wednesday
Student Clare JORDAN goes on Monday
Student Alan MORGAN goes on Thursday
Student Hannah BAILEY goes on Tuesday
Student Deborah RICHARDSON goes on Tuesday
Student Brian PETERSON goes on Thursday
Student Kathryn PETERSON goes on Thursday
Student Jenna PETERSON goes on Thursday
Student Martin PETERSON goes on Thursday
Student Gary COX goes on Tuesday
Student Katie COX goes on Tuesday
Student Stephen GONZALES goes on Thursday
Student Scott GONZALES goes on Thursday
Student Suzanne GONZALES goes on Thursday
Student Caroline GONZALES goes on Thursday
Student Jade STEWART goes on Friday
Student Andrew STEWART goes on Friday
Student Hannah BAILEY goes on Friday
Student Pamela JORDAN goes on Friday
Student Natasha JORDAN goes on Friday
Student Colin JORDAN goes on Friday
Student Eilidh JORDAN goes on Friday
Student Iain GRAY goes on Monday
Student Jacqueline GRAY goes on Monday
Student Katie GUTIERREZ goes on Thursday
Student Brian GUTIERREZ goes on Thursday
Student Catherine GUTIERREZ goes on Thursday
Student Susan COLLINS goes on Wednesday
Student Stephen COLLINS goes on Wednesday
Student Neil TORRES goes on Monday
Student Rachael TORRES goes on Monday
Student Natasha KIM goes on Tuesday
Student Katie KIM goes on Tuesday
Student Jason EVANS goes on Monday
Student Darren KELLY goes on Friday
Student Alan KELLY goes on Friday
Student Pamela KELLY goes on Friday
Student Brian PERRY goes on Monday
Student Elizabeth MURPHY goes on Monday
Student Richard MURPHY goes on Monday
Student Richard MURPHY goes on Monday
Student Jason MURPHY goes on Monday
Student Kerry CHENG goes on Thursday
Student Gary CHENG goes on Thursday
Student Eilidh MORALES goes on Wednesday
Student Jenna MORALES goes on Wednesday
Student Colin MORALES goes on Wednesday
Student Catherine GOMEZ goes on Friday
Student Brian GOMEZ goes on Friday
Student Jason GOMEZ goes on Friday
Student Rachael ETOO goes on Tuesday
Student Martin ETOO goes on Tuesday
Student Rachael CARTER goes on Tuesday
Student Eilidh CARTER goes on Tuesday
Student Stephen MORGAN goes on Tuesday
Student Alison GOMEZ goes on Wednesday
Student Katie HAMILTON goes on Wednesday
Student Scott BROOKS goes on Thursday
Student Michael BROOKS goes on Thursday
Student Stephen BROOKS goes on Thursday
Student Kathryn REYNOLDS goes on Thursday
Student Mark TURNER goes on Wednesday
Student Kayleigh TURNER goes on Wednesday
Student Caroline WEST goes on Thursday
Student Kenneth WEST goes on Thursday
Student Michael WEST goes on Thursday
Student Rachael FLORES goes on Tuesday
Student Iain WATSON goes on Wednesday
Student Derek PATTERSON goes on Wednesday
Student Michael CARTER goes on Wednesday
Student Kerry CARTER goes on Wednesday
Student Alexander ETOO goes on Tuesday
Student Alison ETOO goes on Tuesday
Student Gary COLE goes on Friday
Student Mark COLE goes on Friday
Student Susan SULLIVAN goes on Thursday
Student Kathryn SULLIVAN goes on Thursday
Student Alexander SULLIVAN goes on Thursday
Student Alison FOSTER goes on Friday
Student Craig FOSTER goes on Friday
Student Robert FOSTER goes on Friday
Student Deborah MORALES goes on Thursday
Student Leanne COLE goes on Monday
Student Deborah COLE goes on Monday
Student Suzanne BARNES goes on Thursday
Student Caroline BARNES goes on Thursday
Student Stuart BARNES goes on Thursday
Student Kenneth SANDERS goes on Monday
Student Richard ROGERS goes on Friday
Student Kerry MURPHY goes on Thursday
Student Hayley MURPHY goes on Thursday
Student Barry EVANS goes on Friday
Student Kevin HENDERSON goes on Monday
Student Graham HENDERSON goes on Monday
Student Suzanne WEST goes on Monday
Student Alison LONG goes on Tuesday
Student Richard LONG goes on Tuesday
Student Craig LONG goes on Tuesday
Student Colin TORRES goes on Wednesday
Student Alexander CRUZ goes on Tuesday
Student Catherine CRUZ goes on Tuesday
Student Catherine PHILLIPS goes on Thursday
Student Kenneth HUGHES goes on Wednesday
Student Jenna PRICE goes on Monday
Student Rachael TURNER goes on Friday
Student Paul COLEMAN goes on Monday
Student Barry MORRIS goes on Monday
Student Iain MORRIS goes on Monday
Student Eilidh MORRIS goes on Monday
Student Karen JENKINS goes on Friday
Student Craig JENKINS goes on Friday
Student Scott KHAN goes on Wednesday
Student Richard ROGERS goes on Friday
Student Pamela ROGERS goes on Friday
Student Michael FLORES goes on Wednesday
Student Robert FLORES goes on Wednesday
Student Neil FLORES goes on Wednesday
Student Caroline REYNOLDS goes on Tuesday
Student Gordon HENDERSON goes on Thursday
Student Martin PARKER goes on Friday
Student George EDWARDS goes on Thursday
Student Rachael WEST goes on Tuesday
Student Barry WEST goes on Tuesday
Student Andrew WEST goes on Tuesday
Student Kenneth GRAY goes on Monday
Student Jacqueline STEWART goes on Thursday
Student Graeme STEWART goes on Thursday
Student Barry COOK goes on Tuesday
Student Brian COOK goes on Tuesday
Student Natasha COOK goes on Tuesday
Student Thomas KHAN goes on Wednesday
Student Joanne PARKER goes on Wednesday
Student Kayleigh EDWARDS goes on Tuesday
Student Kathryn EDWARDS goes on Tuesday
Student William EDWARDS goes on Tuesday
Student Barry EDWARDS goes on Tuesday
Student Paul COOPER goes on Monday
Student Kenneth PATTERSON goes on Friday
Student Craig PATTERSON goes on Friday
Student Joanne COOK goes on Friday
Student Susan CARTER goes on Thursday
Student Scott CARTER goes on Thursday
Student Caroline LONG goes on Monday
Student Craig LONG goes on Monday
Student Stuart LONG goes on Monday
Student Paul SIMMONS goes on Thursday
Student Darren JENKINS goes on Friday
Student Gary HAMILTON goes on Tuesday
Student Alexander COLE goes on Wednesday
Student Graeme MORGAN goes on Monday
Student Jade MORGAN goes on Monday
Student Barry MORGAN goes on Monday
Student Stuart HENDERSON goes on Friday
Student Joanne HENDERSON goes on Friday
Student Suzanne HENDERSON goes on Friday
Student Hayley BENNETT goes on Tuesday
Student Julie BENNETT goes on Tuesday
Student Jason BENNETT goes on Tuesday
Student Gordon STEWART goes on Thursday
Student Karen STEWART goes on Thursday
Student Gordon CARTER goes on Thursday
Student Joanne CARTER goes on Thursday
Student Richard CARTER goes on Thursday
Student Peter TURNER goes on Monday
Student Jason KIM goes on Wednesday
Student Andrew KIM goes on Wednesday
Student Brian KIM goes on Wednesday
Student Alison SANDERS goes on Friday
Student Caroline SANDERS goes on Friday
Student Peter WARD goes on Monday
Student Paul COLE goes on Friday
Student Darren COLE goes on Friday
Student Hayley COLE goes on Friday
Student Hannah GRAHAM goes on Monday
Student Andrew GRAHAM goes on Monday
Student Barry GRAHAM goes on Monday
Student Pamela GOMEZ goes on Tuesday
Student Katie CARTER goes on Wednesday
Student Julie CARTER goes on Wednesday
Student Deborah CARTER goes on Wednesday
Student Julie KIM goes on Tuesday
Student Ian LONG goes on Monday
Student Kenneth LONG goes on Monday
Student Pamela LONG goes on Monday
Student Catherine COX goes on Monday
Student Scott COX goes on Monday
Student Karen COX goes on Monday
Student Gary FISHER goes on Tuesday
Student James ETOO goes on Wednesday
Student Martin ETOO goes on Wednesday
Student Graham ETOO goes on Wednesday
Student Jade ETOO goes on Wednesday
Student Brian MORGAN goes on Monday
Student Kayleigh MORGAN goes on Monday
Student George REYES goes on Thursday
Student Neil REYES goes on Thursday
Student Iain REYES goes on Thursday
Student Natasha REYES goes on Thursday
Student Rachael RICHARDSON goes on Wednesday
Student Kenneth KELLY goes on Thursday
Student Derek SULLIVAN goes on Wednesday
Student Scott SULLIVAN goes on Wednesday
Student Barry KHAN goes on Tuesday
Student Clare TURNER goes on Tuesday
Student Hannah ALEXANDER goes on Monday
Student Deborah RIVERA goes on Friday
Student Susan SANDERS goes on Friday
Student Derek SANDERS goes on Friday
Student Hayley SANDERS goes on Friday
Student Kevin COOK goes on Thursday
Student Eilidh COOK goes on Thursday
Student Jenna COOK goes on Thursday
Student Julie COOK goes on Thursday
Student Susan COLLINS goes on Friday
Student Rachael COLLINS goes on Friday
Student Craig WOOD goes on Thursday
Student Brian WOOD goes on Thursday
Student Clare WOOD goes on Thursday
Student Steven SIMMONS goes on Monday
Student Hannah SIMMONS goes on Monday
Student Joanne SIMMONS goes on Monday
Student Mark SIMMONS goes on Monday
Student Craig PETERSON goes on Thursday
Student Andrew BARNES goes on Friday
Student Lynsey REED goes on Monday
Student Alan REED goes on Monday
Student Darren PRICE goes on Monday
Student Stuart PRICE goes on Monday
Student Jason BELL goes on Tuesday
Student Clare BELL goes on Tuesday
Student Deborah MORGAN goes on Friday
Student Jenna MORGAN goes on Friday
Student Steven MORGAN goes on Friday
Student Suzanne MORGAN goes on Friday
Student Richard ROGERS goes on Tuesday
Student Suzanne ROGERS goes on Tuesday
Student Joanne REYNOLDS goes on Friday
Student Colin REYNOLDS goes on Friday
Student Stuart WARD goes on Monday
Student Martin WARD goes on Monday
Student Christopher WOOD goes on Tuesday
Student Eilidh WOOD goes on Tuesday
Student Elizabeth CARTER goes on Tuesday
Student Jason CARTER goes on Tuesday
Student Stuart CARTER goes on Tuesday
Student Kayleigh WALLACE goes on Thursday
Student Hayley WALLACE goes on Thursday
Student Jason WALLACE goes on Thursday
Student Jade PHILLIPS goes on Tuesday
Student Elizabeth GRAY goes on Wednesday
Student Kevin COOK goes on Tuesday
Student Kenneth COOK goes on Tuesday
Student Richard COOK goes on Tuesday
Student Catherine COOK goes on Tuesday
Student Mark HENDERSON goes on Monday
Student Alan ROSS goes on Friday
Student James ROSS goes on Friday
Student Ian ROSS goes on Monday
Student Alan ROSS goes on Monday
Student Paul ORTIZ goes on Wednesday
Student William ORTIZ goes on Wednesday
Student Clare ORTIZ goes on Wednesday
Student Siobhan TURNER goes on Thursday
Student Steven CARTER goes on Thursday
Student Michael CARTER goes on Thursday
Student Craig CARTER goes on Thursday
Student Michael NGUYEN goes on Wednesday
Student Stuart BENNETT goes on Friday
Student Natasha SIMMONS goes on Tuesday
Student Karen SIMMONS goes on Tuesday
Student Deborah SIMMONS goes on Tuesday
Student Natasha SIMMONS goes on Tuesday
Student Craig POWELL goes on Monday
Student Ian POWELL goes on Monday
Student Suzanne LONG goes on Friday
Student Peter LONG goes on Friday
Student Alan LONG goes on Friday
Student Rachael COOK goes on Thursday
Student Brian FOSTER goes on Wednesday
Student Clare HENDERSON goes on Monday
Student Kevin HENDERSON goes on Wednesday
Student Stuart HENDERSON goes on Wednesday
Student Gary HENDERSON goes on Wednesday
Student Elizabeth LONG goes on Wednesday
Student Caroline REYNOLDS goes on Tuesday
Student Paul REYNOLDS goes on Tuesday
Student Mark REYNOLDS goes on Tuesday
Student Graeme ROGERS goes on Friday
Student Alexander ALEXANDER goes on Friday
Student Mark GRAY goes on Wednesday
Student Alexander GOMEZ goes on Monday
Student Julie REED goes on Tuesday
Student Robert WEST goes on Wednesday
Student Katie EDWARDS goes on Monday
Student Graham GONZALES goes on Thursday
Student Pamela GONZALES goes on Thursday
Student Clare PATTERSON goes on Friday
Student Rachael BELL goes on Friday
Student Barry BELL goes on Friday
Student Mark EDWARDS goes on Tuesday
Student Rachael EDWARDS goes on Tuesday
Student Lynsey EDWARDS goes on Tuesday
Student Paul EDWARDS goes on Tuesday
Student Graham WEST goes on Tuesday
Student Karen WEST goes on Tuesday
Student Kayleigh WEST goes on Tuesday
Student William WEST goes on Tuesday
Student Joanne PETERSON goes on Monday
Student George GUTIERREZ goes on Tuesday
Student Clare GUTIERREZ goes on Tuesday
Student Gary GUTIERREZ goes on Tuesday
Student Stephen KIM goes on Wednesday
Student Robert KIM goes on Wednesday
Student Joanne BROOKS goes on Monday
Student Alan BROOKS goes on Monday
Student Graham JAMES goes on Wednesday
Student George JAMES goes on Wednesday
Student Lynsey REYNOLDS goes on Thursday
Student Karen EDWARDS goes on Monday
Student Natasha TURNER goes on Thursday
Student Ian SULLIVAN goes on Wednesday
Student Steven SULLIVAN goes on Wednesday
Student Darren SULLIVAN goes on Wednesday
Student Kenneth CHENG goes on Monday
Student Kerry CHENG goes on Monday
Student Kayleigh LONG goes on Tuesday
Student Alexander GRAY goes on Tuesday
Student Mark GRAY goes on Tuesday
Student Hannah GRAY goes on Tuesday
Student Derek EDWARDS goes on Thursday
Student Kathryn PATEL goes on Wednesday
Student James SANDERS goes on Wednesday
Student Kerry SANDERS goes on Wednesday
Student Natasha SANDERS goes on Wednesday
Student Darren SULLIVAN goes on Monday
Student Colin GRAY goes on Wednesday
Student Julie GRAY goes on Wednesday
Student Ian GRAY goes on Wednesday
Student Graeme CARTER goes on Thursday
Student Peter CARTER goes on Thursday
Student Kenneth CARTER goes on Thursday
Student Kerry WARD goes on Friday
Student Robert SANDERS goes on Wednesday
Student Derek PARKER goes on Wednesday
Student Craig PARKER goes on Wednesday
Student Neil PARKER goes on Wednesday
Student Pamela TORRES goes on Thursday
Student Karen TORRES goes on Thursday
Student Hannah ROSS goes on Thursday
Student Gordon PATEL goes on Monday
Student Jade ETOO goes on Tuesday
Student William ETOO goes on Tuesday
Student Thomas RIVERA goes on Thursday
Student Graham EVANS goes on Friday
Student Kathryn BARNES goes on Monday
Student Siobhan BARNES goes on Monday
Student Mark BENNETT goes on Thursday
Student James BENNETT goes on Thursday
Student Iain BUTLER goes on Friday
Student Graham HENDERSON goes on Thursday
Student Siobhan ETOO goes on Monday
Student Rachael ETOO goes on Monday
Student Suzanne NGUYEN goes on Tuesday
Student Brian NGUYEN goes on Tuesday
Student Kerry NGUYEN goes on Tuesday
Student Jason NGUYEN goes on Tuesday
Student Elizabeth COLEMAN goes on Thursday
Student James MURPHY goes on Friday
Student Richard DIAZ goes on Tuesday
Student Graham DIAZ goes on Tuesday
Student Thomas DIAZ goes on Tuesday
Student Steven DIAZ goes on Tuesday
Student Kenneth GRAHAM goes on Friday
Student Eilidh HOWARD goes on Wednesday
Student Gordon HOWARD goes on Wednesday
Student Siobhan HOWARD goes on Wednesday
Student Craig HOWARD goes on Wednesday
Student Michael GONZALES goes on Wednesday
Student Kathryn GONZALES goes on Wednesday
Student Pamela GONZALES goes on Monday
Student Gordon GONZALES goes on Monday
Student Gary GONZALES goes on Monday
Student Deborah TORRES goes on Tuesday
Student Deborah TORRES goes on Tuesday
Student Gary BUTLER goes on Monday
Student Jacqueline BUTLER goes on Monday
Student Alexander BUTLER goes on Monday
Student Hannah BUTLER goes on Monday
Student Caroline COX goes on Tuesday
Student Iain HUGHES goes on Monday
Student Kevin HUGHES goes on Monday
Student Richard FOSTER goes on Monday
Student William KELLY goes on Wednesday
Student Andrew KELLY goes on Wednesday
Student Kenneth KELLY goes on Wednesday
Student Barry KELLY goes on Wednesday
Student Paul MURPHY goes on Friday
Student Suzanne MURPHY goes on Friday
Student Brian MURPHY goes on Friday
Student Karen MURPHY goes on Friday
Student Susan PATEL goes on Thursday
Student Leanne STEWART goes on Tuesday
Student Eilidh DIAZ goes on Friday
Student George DIAZ goes on Friday
Student Darren DIAZ goes on Friday
Student Ian DIAZ goes on Friday
Student Iain REYNOLDS goes on Tuesday
Student Robert REYNOLDS goes on Tuesday
Student William ROSS goes on Monday
Student Susan PATTERSON goes on Monday
Student Lynsey PATTERSON goes on Monday
Student Pamela PATTERSON goes on Monday
Student Alexander PATTERSON goes on Monday
Student Iain GOMEZ goes on Tuesday
Student Kevin GOMEZ goes on Tuesday
Student Hannah GOMEZ goes on Tuesday
Student Mark GOMEZ goes on Tuesday
Student George DIAZ goes on Thursday
Student Mark ROGERS goes on Monday
Student Christopher ROGERS goes on Monday
Student Eilidh BENNETT goes on Wednesday
Student Richard BENNETT goes on Wednesday
Student Robert MORGAN goes on Wednesday
Student Barry MORGAN goes on Wednesday
Student Neil MORGAN goes on Wednesday
Student Richard MORGAN goes on Wednesday
Student Steven PATTERSON goes on Tuesday
Student Robert CRUZ goes on Wednesday
Student Lynsey TORRES goes on Thursday
Student Karen TORRES goes on Thursday
Student Stephen POWELL goes on Thursday
Student Thomas COOK goes on Thursday
Student Alan WALLACE goes on Tuesday
Student Susan WALLACE goes on Tuesday
Student Alan REED goes on Thursday
Student Clare REED goes on Thursday
Student Rachael REED goes on Thursday
Student Karen REED goes on Thursday
Student Brian DIAZ goes on Monday
Student Hayley WALLACE goes on Thursday
Student Neil WALLACE goes on Thursday
Student Jason COOPER goes on Wednesday
Student Barry COOPER goes on Wednesday
Student Jacqueline COOPER goes on Wednesday
Student Leanne CRUZ goes on Friday
Student Hannah CRUZ goes on Friday
Student Deborah CRUZ goes on Friday
Student Siobhan FISHER goes on Friday
Student Kathryn HUGHES goes on Tuesday
Student Caroline JAMES goes on Tuesday
Student Barry PATTERSON goes on Monday
Student Stuart RICHARDSON goes on Wednesday
Student Lynsey RICHARDSON goes on Wednesday
Student Jenna KIM goes on Monday
Student Kayleigh HUGHES goes on Wednesday
Student Jason HUGHES goes on Wednesday
Student Gordon HUGHES goes on Wednesday
Student Leanne MYERS goes on Thursday
Student Barry MYERS goes on Thursday
Student Eilidh MYERS goes on Thursday
Student Natasha ROGERS goes on Monday
Student Christopher ROGERS goes on Monday
Student Stephen ROGERS goes on Monday
Student Susan BARNES goes on Wednesday
Student Barry BARNES goes on Wednesday
Student Martin EDWARDS goes on Monday
Student Natasha CARTER goes on Tuesday
Student Kenneth COX goes on Tuesday
Student Thomas COX goes on Tuesday
Student Alexander COX goes on Tuesday
Student Jacqueline COX goes on Tuesday
Student Jade TURNER goes on Tuesday
Student Alexander TURNER goes on Tuesday
Student Robert SULLIVAN goes on Wednesday
Student Paul ROGERS goes on Tuesday
Student Kevin ROGERS goes on Tuesday
Student Neil ROGERS goes on Tuesday
Student Christopher GOMEZ goes on Thursday
Student Jacqueline PATEL goes on Tuesday
Student Thomas FLORES goes on Tuesday
Student Leanne FLORES goes on Tuesday
Student Martin TURNER goes on Friday
Student Jacqueline GUTIERREZ goes on Tuesday
Student Julie RICHARDSON goes on Monday
Student Jade RICHARDSON goes on Monday
Student Elizabeth BELL goes on Thursday
Student Richard BELL goes on Thursday
Student William BELL goes on Thursday
Student Caroline BELL goes on Thursday
Student Mark ALEXANDER goes on Wednesday
Student Jenna ALEXANDER goes on Wednesday
Student Jade LONG goes on Wednesday
Student Kevin LONG goes on Wednesday
Student Eilidh LONG goes on Wednesday
Student Rachael BAILEY goes on Wednesday
Student Darren FISHER goes on Tuesday
Student Neil FISHER goes on Tuesday
Student Ian FISHER goes on Tuesday
Student Graham FISHER goes on Tuesday
Student Eilidh STEWART goes on Wednesday
Student Karen STEWART goes on Wednesday
Student Kevin SANDERS goes on Tuesday
Student Catherine ORTIZ goes on Wednesday
Student Christopher ORTIZ goes on Wednesday
Student Graham ORTIZ goes on Wednesday
Student Rachael REYES goes on Wednesday
Student Scott REYES goes on Wednesday
Student Catherine REYES goes on Wednesday
Student Kayleigh RAMOS goes on Friday
Student Joanne FLORES goes on Thursday
Student Stephen FLORES goes on Thursday
Student Ian FLORES goes on Thursday
Student Elizabeth GONZALES goes on Monday
Student Suzanne GONZALES goes on Monday
Student Stuart GONZALES goes on Monday
Student Leanne COOK goes on Thursday
Student Natasha PATEL goes on Wednesday
Student Susan ROGERS goes on Wednesday
Student Catherine PRICE goes on Thursday
Student Graeme PRICE goes on Thursday
Student Jacqueline PRICE goes on Thursday
Student Catherine EVANS goes on Friday
Student Siobhan ROGERS goes on Thursday
Student Kayleigh ROGERS goes on Thursday
Student Joanne RUSSELL goes on Friday
Student William RUSSELL goes on Friday
Student Rachael RUSSELL goes on Friday
Student Deborah RUSSELL goes on Friday
Student Susan ALEXANDER goes on Friday
Student Kayleigh MURPHY goes on Thursday
Student Kerry MURPHY goes on Thursday
Student Julie GONZALES goes on Monday
Student Jenna GONZALES goes on Monday
Student Ian HAMILTON goes on Wednesday
Student Elizabeth HAMILTON goes on Wednesday
Student Kevin COOK goes on Friday
Student Jason COOK goes on Friday
Student Caroline COOK goes on Friday
Student Richard COLLINS goes on Thursday
Student Robert COLLINS goes on Thursday
Student Mark COLLINS goes on Thursday
Student Stuart BAILEY goes on Tuesday
Student Kerry MORRIS goes on Friday
Student Joanne WOOD goes on Tuesday
Student Alison WOOD goes on Tuesday
Student Elizabeth WOOD goes on Tuesday
Student Kenneth NGUYEN goes on Friday
Student Michael NGUYEN goes on Friday
Student Stephen HAMILTON goes on Wednesday
Student Stephen COOK goes on Thursday
Student Leanne COOK goes on Thursday
Student Kayleigh RICHARDSON goes on Wednesday
Student George PERRY goes on Thursday
Student Kevin PERRY goes on Thursday
Student Darren DIAZ goes on Friday
Student Leanne REYES goes on Friday
Student Jason WOOD goes on Thursday
Student Mark BUTLER goes on Friday
Student Paul RIVERA goes on Friday
Student Peter WATSON goes on Thursday
Student Lynsey COLLINS goes on Thursday
Student Leanne COLLINS goes on Thursday
Student Eilidh ETOO goes on Thursday
Student Richard ETOO goes on Thursday
Student Leanne ETOO goes on Thursday
Student Neil PATTERSON goes on Friday
Student Gary WOOD goes on Friday
Student Robert RIVERA goes on Tuesday
Student George REYES goes on Friday
Student Mark REYES goes on Friday
Student Craig REYES goes on Friday
Student Kevin MORALES goes on Wednesday
Student Scott MORALES goes on Wednesday
Student Christopher SANDERS goes on Thursday
Student Alan ROGERS goes on Friday
Student Rachael ROGERS goes on Friday
Student Alison ALEXANDER goes on Friday
Student Christopher ALEXANDER goes on Friday
Student Elizabeth WATSON goes on Wednesday
Student Scott COLE goes on Friday
Student Graham REYNOLDS goes on Friday
Student Pamela REYNOLDS goes on Friday
Student Pamela REYNOLDS goes on Friday
Student Susan WOOD goes on Thursday
Student Natasha WARD goes on Thursday
Student Robert WARD goes on Thursday
Student Suzanne FISHER goes on Friday
Student Graham FISHER goes on Friday
Student Graham GRAY goes on Friday
Student Andrew GRAY goes on Friday
Student Kenneth GRAY goes on Friday
Student Jade RAMOS goes on Friday
Student Stuart POWELL goes on Friday

Solution Verified
- : unit = ()
```
