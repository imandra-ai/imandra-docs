---
title: "Reflection"
description: "Reflection"
kernel: imandra
slug: imandravs
---
# Boyer-Moore

Like ACL2, Imandra’s logic is based on a mechanized formal semantics for an efficiently executable programming language (for ACL2, this is a first-order fragment of Lisp; for Imandra, this is a higher-order fragment of OCaml/ReasonML). This means that Imandra models are simultaneously executable programs (i.e., valid OCaml/ReasonML) and mathematical artifacts which may be subjected to rigorous formal analysis by Imandra’s reasoning engine. In Imandra, we have “lifted” many core Boyer-Moore ideas powering their remarkable successes in automating induction and simplification to our typed, higher-order setting.

# HOL, Isabelle/HOL, Coq, Agda and Lean

Like provers in the HOL family (as well as those based on dependent types such as Coq, Agda and Lean), Imandra’s logic is strongly typed. Like HOL systems, Imandra is built upon a higher-order polymorphic type theory (a variant of Hindley-Milner corresponding to pure OCaml). Imandra supports a rich executable fragment of HOL, with automation including efficient higher-order rewriting and induction through first-order specialization.

# SAT and SMT

Like SMT solvers, Imandra contains orchestrated combinations of high-performance CDCL-based SAT solving and decision procedures for theories relevant to program analysis. Crucially, Imandra’s proof procedures support the synthesis of reflected executable counterexamples (even of higher-order goals requiring function synthesis). All counterexamples constructed by Imandra are “first-class,” i.e., executable and available in the same runtime environment as the formal models themselves. This allows rapid prototyping iteration and model diagnostics, as counterexamples can be directly run through models. Imandra lifts SMT from (non-executable, monomorphic) first-order logic without recursion and induction to a rich executable, polymorphic higher-order logic with recursion and induction.

# Integration of Model Checking and Theorem Proving

Imandra seamlessly integrates bounded model checking (lifted to operate modulo higher-order recursive functions over algebraic datatypes, integers, reals, etc.) and “full-fledged” interactive theorem proving. Every verification goal in Imandra may be analyzed in “bounded” and “unbounded” fashions, and bounded results may be turned into actual theorems (e.g., incorporating bounds on the datatypes involved explicitly in theorem hypotheses) automatically. This allows for powerful incremental approaches to verification, utilizing bounded verification to rapidly eliminate design flaws,“completing” the results to their unbounded form as necessary only after all flaws corresponding to counterexamples found by bounded verification attempts have been eliminated.

# Nonlinear Decision Procedures for Hybrid Systems

 Imandra has deep support for datatypes and decision procedures relevant to the analysis of hybrid systems. This includes model-producing decision procedures for the existential theory of real closed fields (nonlinear real arithmetic w.r.t. systems of many-variable nonlinear polynomial equations and inequalities) integrated with Imandra’s inductive “waterfall” proof procedure. Moreover, Imandra can natively compute with and reason about real algebraic numbers. Through our experience working with (and in many cases contributing to) hybrid systems verification tools such as KeYmaera, Flow*, dReal and dReach and HybridSAL, we recognize scalable nonlinear real decision procedures as one of the most important bottlenecks in hybrid systems verification. The derivation of computable counterexamples (dually, instances in the case of test-case generation) satisfying constraints on both the discrete and continuous components of the models is crucial to efficient V&V.