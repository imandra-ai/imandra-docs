---
title: "Scheduling smaller class sizes during Covid"
description: "This notebook demonstrates how to encode and solve a constraint problem of making sure all children from the same family go to school on the same day, when days at school are restricted due to COVID-19."
kernel: imandra
slug: school-scheduler
key-phrases:
  - OCaml
  - proof
  - instance
---

# Get in touch

Is your school facing tough scheduling problems in order to facilitate social distancing?
We'd love to help! We're offering free Imandra licenses and pro bono consulting to help
schools solve their COVID-19 scheduling challenges.

Please contact us at <contact@imandra.ai> and we'll help you get started.

# Stating the problem

During the COVID-19 pandemic of 2020, it's become apparent that due to social
distancing, children going to school in Scotland and elsewhere will only be
able to attend for a restricted number of days per week. One of the primary
concerns for families is that siblings should attend on the same day. This
problem is a classical scheduling problem which can become very tricky due to a
combinatorial explosion. This notebook demonstrates how it is possible to encode
such a problem and use Imandra to find a solution.

# Representation of classes, families and students

In this notebook, we present a realistic case study of how our
`Imandra_scheduler` tool can be used to automatically solve tough school
scheduling problems. Due to privacy restrictions, we do this demonstration using
synthetic (i.e., randomly generated) student data for a primary school with 720
students and social distancing restrictions limiting the number of students per
class per day to between 6 and 9 students in the same group. The school is full
and is comprised of families of 1,2,3 and 4 students. Each student is mapped to
each of 21 classes - `P1A` through to `P7C`.

We import the student information from "Comma Separated Value (csv)" files such as the one shown below (click for full version)
[![Imandrabot](https://storage.googleapis.com/imandra-notebook-assets/studentscsv.png)](https://gist.github.com/ewenmaclean/3040c39c424d7d2f1e43c82f9fff2f06)

```{.imandra .input}
#use_gist "ewenmaclean/43bad29da72962019180bbc21f9f7574";;
```

and contains data which describes students, families and their classes. For example

```
Katie GONZALES,P3C,Christopher GONZALES,P4B
```


denotes a family of two students, Katie and Christopher Gonzales, in classes
`P3C` and `P4B`, respectively. We want to ensure that Katie and Christopher both
go to school on the same day, and make sure this "siblings attend on the same
day" property holds for all families at the school.

This class allocation size data with the names of classes and the number of
students allowed to be in each is also encapsulated in a csv file (click for
full version):

[![Imandrabot](https://storage.googleapis.com/imandra-notebook-assets/classescsv.png)](https://gist.github.com/ewenmaclean/4cf1c29402e63426f32c312a14ca86df)

```{.imandra .input}
#use_gist "ewenmaclean/4cf1c29402e63426f32c312a14ca86df";;
```

# Solution using the Imandra Scheduler

We can now exploit the `Imandra Scheduler` to find a solution to the problem.

```{.imandra .input}
Imandra_scheduler.Solve.top ~lines:student_csv_data ~classes:class_csv_data
```

What is shown here is an example of dealing with the problem of students in a
school of 720 students going on one day with a given restricted class size of
between 6 and 9 per day for a class with ordinarily between 30 and 40 students.
This is fully configurable and can be adapted with variable classes and
allocations and number of days according to the restrictions that exist.

Please get in touch with us at <contact@imandra.ai> and we'd be happy to help you get started!
