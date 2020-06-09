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


```ocaml
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


```ocaml
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


```ocaml
solve_from_csv ~filename:"data.csv";;
```
