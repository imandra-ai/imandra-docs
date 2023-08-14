---
title: "Introduction"
description: "An introduction to formal verification of your software with Imandra."
kernel: imandra
slug: introduction
---

# Introduction

*This introduction is designed to give you a brief overview of Imandra and some example use cases. If you'd prefer to get on with some concrete examples, take a look at [A Quick Tour of Imandra](A%20Quick%20Tour%20of%20Imandra.md).*

Imandra is a programming language and reasoning engine which you can use to analyse and verify properties of your programs.

With Imandra, you write your code and verification goals in the same language, and pursue programming and reasoning together.

This process is in some ways similar to writing tests, but happens through symbolic mathematical analysis of your code rather than simply through concrete test-case execution. It is also much more powerful, allowing you to prove mathematically that an assertion holds for all possible inputs (of which there may be infinitely many), rather than only for a handful of unit tests or randomly generated inputs.

If your assertions don’t hold, Imandra can be used to synthesize concrete counterexamples to help you understand and fix the problem.

We can also ask Imandra to decompose our programs to get a symbolic representation of their state-spaces. This representation can be used to explore the complexity of a program, understand the states covered by existing test suites and to automatically generate test-suites with precise state-space coverage metrics.

Traditionally these kinds of tools have their own language with which you write your statements. However, Imandra understands a subset of the functional language OCaml (and its sibling ReasonML). We call this subset of OCaml “IML” or “ImandraML” (for “Imandra Modelling Language”). This means you can write your programs and execute them as you would in any language, but also benefit from Imandra’s powerful reasoning tools.

If you’ve never written OCaml before, don’t worry! We’ll introduce you to some of the key concepts as you learn Imandra (but you may find it helpful to get more familiar with OCaml itself as you progress).

## Who Imandra is for

![Imandra scope](https://storage.googleapis.com/imandra-notebook-assets/imandra-scope.svg)

### Developers

Developers can use Imandra to help them test and prove properties about their code. Rather than having to come up with concrete test cases for the various edge cases of a function themselves, developers can express a logical property of their system and Imandra can be used to prove whether it holds mathematically, generate test-cases, and more.

Imandra’s test-case generation capabilities can also be used to generate example inputs and outputs for functions that can be used as verified documentation, derived from the function definitions themselves.

OCaml (and ReasonML) developers can benefit from these features with their existing code bases, but developers who use other languages can interface with Imandra in many ways, from writing IML models of mission critical parts of their existing system to aid their understanding and generate test-suites, to building powerful verification-enabled DSLs which use Imandra's powerful reasoning engine as a back-end.

### People who value correct software

For systems where the costs of bugs are measured in millions of dollars (or even in people’s lives), scalable rigorous approaches to software correctness and safety are needed now more than ever. In these settings, classical "testing" is typically wildly insufficient: the state-spaces are too large, the edge-cases too numerous and subtle, and the risks associated with failure too high. Formal verification tools are already relied upon in many safety-critical industries, but are typically baroque and niche, dedicated to restricted domains (i.e., microprocessor design) and requiring rare and expensive expertise. With Imandra, we aim to democratise these techniques, making them scalable, accessible and applicable to software development at large. Along the way, we're making deep contributions to the science of formal verification and automated reasoning.

It’s important to keep in mind that Imandra (and formal verification in general) is not a silver bullet. For example, you may prove properties about your code and later realise those properties did not express all of your informal intentions. This issue arises in any form of mathematical modelling of the real world. However, including Imandra as another net in your design and QA process can help to dramatically reduce risks (and time to market!).

### Computer scientists, Mathematicians and Logicians

Imandra is a world class proof assistant that has many advanced features, including first-class computable counterexamples, symbolic model checking, support for polymorphic higher-order recursive functions, automated induction, a powerful simplifier and symbolic execution engine with lemma-based conditional rewriting and forward-chaining, first-class state-space decompositions, decision procedures for algebraic data types, floating point arithmetic, and much more.

### Students

Learn and practice logic, formal verification and a functional language (OCaml), while also experimenting with an automated proof assistant!
