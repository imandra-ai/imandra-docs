---
title: "Aside: Voronoi diagrams"
description: "An aside on Voronoi diagrams for decomposition"
kernel: imandra
slug: aside-voronoi
key-phrases:
  - decomposition
  - side-condition
  - target function
  - uninterpreted function
  - state space enumeration
  - region of behaviour
---

# Aside: Voronoi diagrams

When performing a region decomposition in a Jupyter notebook, the Imandra plugin will render the result as a Voronoi diagram.

To render a Voronoi diagram from the REPL, use `Imandra_voronoi.Voronoi.print`:

```
# let target x = if x > 0 then 1 else -1;;
val target : int -> int = <fun>

# let d = Modular_decomp.top "target" [@@program];;
- Beginning modular decomposition of target.
* Computing fresh modular decomposition for target
- Computed 2 regions.
- Target modular decomposition of target complete (2 regions).
- Integration complete in 0 rounds (2 regions).
val d : Top_result.modular_decomposition =
  {Imandra_interactive.Modular_decomp.MD.md_session = 1i;
   md_f =
    {Imandra_surface.Uid.name = "target"; id = <abstr>;
     special_tag = <abstr>; namespace = <abstr>;
     chash = Some IJllFgjXGBXdmGllO51yKe2dFt1V0i4n85B2RT8f5B0;
     depth = (3i, 1i)};
   md_args = [(x : int)]; md_regions = <abstr>}

# Imandra_voronoi.Voronoi.print () Format.std_formatter d;;
Open: file:////var/folders/y2/bzjbz5bj0s91lz0mx42q_jd80000gn/T/voronoi_822f8d.html
- : unit = ()
```

Then open the temporary file in your browser.

Alternatively, you can install the Voronoi printer to generate a diagram for every decomposition:

```
# let pp_voronoi = Imandra_voronoi.Voronoi.print () [@@program];;
val pp_voronoi : Format.formatter -> Top_result.modular_decomposition -> unit =
  <fun>

# #install_printer pp_voronoi;;

# let target x = if x > 0 then 1 else -1;;
val target : int -> int = <fun>

# Modular_decomp.top "target";;
- Beginning modular decomposition of target.
* Computing fresh modular decomposition for target
- Computed 2 regions.
- Target modular decomposition of target complete (2 regions).
- Integration complete in 0 rounds (2 regions).
- : Top_result.modular_decomposition =
Open: file:////var/folders/y2/bzjbz5bj0s91lz0mx42q_jd80000gn/T/voronoi_8710d3.html
```
