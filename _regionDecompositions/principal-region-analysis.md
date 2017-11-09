---
title: "Region Decompositions"
excerpt: ""
layout: pageSbar
permalink: /regionPrinters/
colName: Region Printers
---
Imandra has a first-class notion of state-space decompositions which we call principal region decompositions. These allow one to compute a symbolic representation of the possible unique behaviours of a program subject to a given query constraint. 

For example: “Compute all regions of the venue state-space in which the price of the next trade will be the venue’s reference price,” or “Compute all regions of the state-space that will cause the venue to transition into volatility auction.”

These region descriptions are subject to a given basis, a collection of functions whose definitions will not be expanded and may carry lemmata exposing facts about their behaviour. We compute these decompositions through a special form of symbolic execution. Decompositions play a key role in how we generate certified documentation and high-coverage test suites. We often represent them as interactive hierarchical voronoi diagrams.
