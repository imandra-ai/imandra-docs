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

For the purposes of this demonstration, we assume (without loss of generality) that there are seven years of a primary school, each with 3 classes of between 30 and 40 students. We randomly populate the school with students and families in such a way as to mimic realistic data. The school is full and is comprised of families of 1,2,3 and 4 students. Each student is mapped to each of 21 classes - `P1A` through to `P7C`.

# Initial data
The initial data for this school is represented by various function on the students and families to denote the distribution of families and students to classes. We also introduce days `M,T,W,Th,F` to represent days. In this instance we solve for the problem of students going one day a week - this is also generalisable according to the specifics of the problem. At the time of writing this was realistic according to the social distancing guidelines in schools meaning a class which ordinarily would accommodate 30 children would now accommodate between 6 and 9 depending on the class.

This csv format data held in [this csv file](https://gist.github.com/ewenmaclean/3040c39c424d7d2f1e43c82f9fff2f06) is stored in the variable `students_csv` and copies the format in which schools already encapsulate their data:

```{.imandra .input}
#use_gist "ewenmaclean/43bad29da72962019180bbc21f9f7574";;
```

and contains text of randomly generated sample school data which describes on each line families of students, and at the end of each comma separated student entry, a designated class is given. For example

```
Katie GONZALES P3C,Christopher GONZALES P4B
```

denotes a family of two students, Katie and Christopher Gonzales, in classes `P3C` and `P4B`. We want to ensure that Katie and Christopher both go to school on the same day, and make sure this is the case for all families at the school. 

In this example there are 21 classes and 720 students, which 30 in each class ordinarily, but now this is restricted to between 6 and 9 depending on the class.

This class allocation size data with the names of classes and the number of students allowed to be in each showed by [this csv file](https://gist.github.com/ewenmaclean/4cf1c29402e63426f32c312a14ca86df)
```{.imandra .input}
#use_gist "ewenmaclean/4cf1c29402e63426f32c312a14ca86df";;
```

We can now exploit the `Imandra Scheduler` to find a solution to the problem. This simply gives back a list of days corresponding to a day allocation per family.

```{.imandra .input}
Imandra_scheduler.Solve.top ~lines:student_csv_data ~classes:class_csv_data
```

What is shown here is an example of dealing with the problem of students going on one day with a given restricted class size of 6 per day for a class with ordinarily 30 students. This is fully configurable and can be adapted with variable classes and allocations and number of days according to the restrictions that exist, and will be as efficient at finding a solution.
