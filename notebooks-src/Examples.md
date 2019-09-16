---
title: "Examples"
description: "Example notebooks"
kernel: imandra
slug: examples
---

# Examples

Our main Imandra documentation (browsable from the menu on the left) contains examples, but is intended as more of a full walkthrough / reference.

If you prefer investigating a particular topic in a bit more depth, take a look at these worked example notebooks:

- [Recursion, Induction and Rewriting](Recursion,%20Induction%20and%20Rewriting.md): In this notebook, we're going to use Imandra to prove some interesting properties of functional programs. We'll learn a bit about induction, lemmas and rewrite rules along the way.
- [Verifying Merge Sort in Imandra](Verifying%20Merge%20Sort%20in%20Imandra.md): Merge sort is a widely used efficient general purpose sorting algorithm, and a prototypical divide and conquer algorithm. It forms the basis of standard library sorting functions in languages like OCaml, Java and Python. Let's verify it with Imandra!
- [Analysing the UBS ATS dark pool](Analysing%20the%20UBS%20ATS%20Dark%20Pool.md): In this notebook, we model the order priority logic of the UBS ATS dark pool as described in UBS's June 1st 2015 Form ATS submission to the SEC and analyse it using Imandra. We observe that as described, the order priority logic suffers from a fundamental flaw: the order ranking function is not transitive.
- [Region Decomposition - Exchange Pricing](Region%20Decomposition%20-%20Exchange%20Pricing.md): In this notebook we'll use imandra to model a fragment of the SIX Swiss trading logic and decompose its state space using region decomposition
- [Analysing Web-app Authentication Logic](Analysing%20Web-app%20Authentication%20Logic.md): In this notebook, we look at some typical authentication logic that might be found in a standard web application, and analyse it with Imandra to make sure it's doing what we expect.
- [Simple Vehicle Controller](Simple%20Vehicle%20Controller.md): In this notebook, we'll design and verify a simple autonomous vehicle controller in Imandra. The controller we analyse is due to Boyer, Green and Moore, and is described and analysed in their article The Use of a Formal Simulator to Verify a Simple Real Time Control Program.
- [Simple Car Intersection Model](Simple%20Stoplight%20Model.md): In this notebook, we'll implement a simple model of a road interseciton with a car approaching, we'll then use Imandra's Principal Region Decomposition to explore its state space and define custom printers in order to explore the behavior of the car approaching the intersaction using english prose.
- [Verifying a Ripple Carry Adder](Verifying%20a%20Ripple%20Carry%20Adder.md): In this notebook, we'll verify a simple hardware design in Imandra, that of a full (arbitrary width) ripple-carry adder. We'll express this simple piece of hardware at the gate level. The theorem we'll prove expresses that our (arbitrary width) adder circuit is correct for all possible bit sequences.
- [Creating and Verifying a ROS Node](Creating%20and%20Verifying%20a%20ROS%20Node.md): At AI, we've been working on an IML (Imandra Modelling Language) interface to ROS, allowing one to develop ROS nodes and use Imandra to verify their properties. In this notebook, we will go through creation and verification of a Robotic Operating System (ROS) node in Imandra. We will make a robot control node that controls the motion of a simple 2-wheeler bot.
- [Tic Tac Toe with ReasonML](Tic%20Tac%20Toe%20with%20ReasonML.md): ReasonML provides an alternative syntax for OCaml, which Imandra can read. Let's walk through an example ReasonML model of Tic Tac Toe and use Imandra to understand and verify some properties of it.
- [Probabilistic reasoning in ReasonML](Probabilistic%20Reasoning%20in%20ReasonML.md): In this ReasonML notebook, we employ Imandra ability to reason about functional values to analyse probabilistic scenarios following the example of the Monty Hall problem ( there is also an [OCaml](Probabilistic%20Reasoning%20in%20OCaml.md) of this notebook )
- [Exploring The Apple FaceTime Bug with ReasonML State Machines](Exploring%20the%20FaceTime%20Bug%20With%20ReasonML%20State%20Machines.md): In this notebook we explore the Apple FaceTime bug and different ways of modelling our applications as state machines.
- [Key Pair Security in Imandra](KeyPairSecurity.md): In this ReasonML notebook, we use imandra to very quickly discover the 'man in the middle' attack for protocols with private/public key exchance protocols.
- [A comparison with TLA+](TLA+.md): In this notebook we encode examples from the Learn TLA+ book in Imandra.
- [Calculating Region Probabilities](Region%20Probabilities.md): In this notebook we provide an introduction to a small probabilistic programmining library that allows users reason about Imandra Modelling Language (IML) models probabilistically.
- [Analysing Machine Learning Models With Imandra](Supervised%20Learning.md): In this notebook we show how Imandra can be used to analyse and reason about models that have been learnt from data, an important and exciting topic bridging the gap between formal methods and machine learning.
