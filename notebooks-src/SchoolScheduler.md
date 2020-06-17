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

![Imandra Scheduling](https://storage.googleapis.com/imandra-notebook-assets/scheduler__general-diagram.svg)

# Stating the problem

During the COVID-19 pandemic of 2020, it's become apparent that due to social
distancing, children going to school in Scotland and elsewhere will only be
able to attend for a restricted number of days per week. One of the primary
concerns for families is that siblings should attend on the same day. This
problem is a classical scheduling problem which can become very tricky due to a
combinatorial explosion. This notebook demonstrates how it is possible to encode
such a problem and use Imandra to find a solution.

The schools in Edinburgh, Scotland, adopted an "ABC" approach where children would attend 1/3 of the time during a shortened 4 day week. This meant that students would attend one day a week, with two days every third week. Each subdivision of a class A, B or C would always attend school on the same days in order to minimise the spread of infection but restricting contact for students to "bubbles". 

The challenge is to organise this so families go on the same days, but with the added complication that some children already have days on which they can attend pre-determined. This may be on account of their parents being "keyworkers" - in which case they attend "Hub Schools" which determine which days they can attend, or it may be that they are vulnerable children with particular needs. 

# Representation of classes, families and students

In this notebook, we present a realistic case study of how our
`Imandra_scheduler` tool can be used to automatically solve tough school
scheduling problems. Due to privacy restrictions, we do this demonstration using
synthetic (i.e., randomly generated) student data for a primary school with 720
students and social distancing restrictions limiting the number of students per
class per day to a third of the normal class size. The school is full
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

[![Imandrabot](https://storage.googleapis.com/imandra-notebook-assets/full_classes.png)](https://gist.github.com/ewenmaclean/4cf1c29402e63426f32c312a14ca86df)

```{.imandra .input}
#use_gist "ewenmaclean/4cf1c29402e63426f32c312a14ca86df";;
```

In addition to this data we import a file of keyworker families - those where the  parents are both classed as keyworkers. These families are assumed to have the days on which they can attend normal school (not Hub school) predetermined, and hence their "bubble" (A, B or C) of their class for this school already decided. 

[![Imandrabot](https://storage.googleapis.com/imandra-notebook-assets/keyworkers.png)](https://gist.github.com/ewenmaclean/cc15cef4fd563404e3152d7b3e40c4a5)

```{.imandra .input}
#use_gist "ewenmaclean/cc15cef4fd563404e3152d7b3e40c4a5";;
```


# Solution using the Imandra Scheduler

We can now exploit the `Imandra Scheduler` to find a solution to the problem.

```{.imandra .input}
Imandra_scheduler.Solve.top ~lines:student_csv_data ~classes:class_csv_data ~keyworkers:keyworkers_csv_data
```

The resulting csv can be loaded into a spreadsheet program and manipulated directly (click to view full version). 

[![Imandrabot](https://storage.googleapis.com/imandra-notebook-assets/out.png)](https://storage.googleapis.com/imandra-notebook-assets/out.csv)

What is shown here is an example of dealing with the problem of students in a
school of 720 students going on for 4 days a week over 3 weeks of a 4-day school week.
between 10 and 15 per day for a class with ordinarily between 30 and 40 students.
This is fully configurable and can be adapted with variable classes and
allocations and number of days according to the restrictions that exist.

Please get in touch with us at <contact@imandra.ai> and we'd be happy to help you get started!

```{.imandra .input}

```
