```ocaml
type obligations = {
  sing_a_song: bool;
  do_a_dance: bool;
}

type employee = {
  name : string;
  arrival_time : int;
  obligations : obligations;
}

type state = {
  emp: employee;
  meeting_time: int;
}

let on_time st =
  st.emp.arrival_time <= st.meeting_time

let is_late st =
  not (on_time st)
```




    type obligations = { sing_a_song : bool; do_a_dance : bool; }
    type employee = {
      name : string;
      arrival_time : Z.t;
      obligations : obligations;
    }
    type state = { emp : employee; meeting_time : Z.t; }
    val on_time : state -> bool = <fun>
    val is_late : state -> bool = <fun>





```ocaml
(* Employee E must sing a song
   if E is late for a meeting for n minutes
   and n is greater than 3*)

module Rule0 = struct

 let c1 st =
  is_late st

 let c2 st =
  st.emp.arrival_time - st.meeting_time > 3
  
 let cs st =
  c1 st && c2 st
  
 let s st =
  st.emp.obligations.sing_a_song
  
 let rule st =
  s st <== cs st

end
```




    module Rule0 :
      sig
        val c1 : state -> bool
        val c2 : state -> bool
        val cs : state -> bool
        val s : state -> bool
        val rule : state -> bool
      end





```ocaml
(*
  Employee E must sing a song
  if E is late for a meeting for n minutes
  and n is greater than 1
*)

module Rule1 = struct

 let c1 st =
  is_late st

 let c2 st =
  st.emp.arrival_time - st.meeting_time > 1
   
 let cs st =
  c1 st && c2 st
  
 let s st =
  st.emp.obligations.sing_a_song
  
 let rule st =
  s st <== cs st

end
```




    module Rule1 :
      sig
        val c1 : state -> bool
        val c2 : state -> bool
        val cs : state -> bool
        val s : state -> bool
        val rule : state -> bool
      end





```ocaml
(* Do Rule0's and Rule1's conditions overlap? *)

instance (fun st -> (Rule0.c1 st) && (Rule1.c1 st))
```




    - : state -> bool = <fun>
    module CX : sig val st : state end





<div><pre>Instance (after 0 steps, 0.014s):
let st : state =
  {emp =
   {name = &quot;!0!&quot;; arrival_time = 0;
    obligations = {sing_a_song = false; do_a_dance = false}};
   meeting_time = (-1)}
</pre></div>




<div><div style="font-size: 1.2em; padding: 0.5em; border-top: 1px solid green; border-bottom: 1px solid green"><i class="fa fa-check-circle" style="margin-right: 0.5em; color: green"></i><span>Instance</span></div><div><div class="imandra-alternatives" id="alt-b9c2545c-de54-4602-a076-423d8e0474f1"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>call graph</a></li><li class="" data-toggle="tab"><a>proof</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-graphviz" id="graphviz-80906a01-fc99-45bc-ac5a-4d49d4e3b61b"><textarea style="display: none">digraph &quot;call graph&quot; {
goal [label=&quot;not (st.emp.arrival_time \&lt;= st.meeting_time)&quot;,shape=box,style=filled,color=&quot;cyan&quot;,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-80906a01-fc99-45bc-ac5a-4d49d4e3b61b';
  graphviz.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-proof-top"><div class="imandra-fold panel panel-default" id="fold-bc104909-edae-4d4d-98b8-a46c3105dcd0"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>proof attempt</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-e1b39794-031e-4915-8bf4-88fdef4a3c43"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li><li class="" data-toggle="tab"><a>graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-193ac051-c197-4ea3-9233-06ffd9a6370a"><table><tr><td>ground_instances:</td><td>0</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.014s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-5751f6dc-af6d-48b5-94a7-c5ef97f042d3"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-2d82e258-0add-48ec-901d-026300d352b9"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-54cb016c-bb9e-4e82-9f45-7bbc985e12ab"><table><tr><td>num checks:</td><td>1</td></tr><tr><td>arith assert lower:</td><td>1</td></tr><tr><td>arith tableau max rows:</td><td>1</td></tr><tr><td>arith tableau max columns:</td><td>4</td></tr><tr><td>arith pivots:</td><td>1</td></tr><tr><td>rlimit count:</td><td>331</td></tr><tr><td>mk clause:</td><td>16</td></tr><tr><td>datatype occurs check:</td><td>1</td></tr><tr><td>mk bool var:</td><td>22</td></tr><tr><td>decisions:</td><td>2</td></tr><tr><td>seq num reductions:</td><td>1</td></tr><tr><td>propagations:</td><td>2</td></tr><tr><td>datatype accessor ax:</td><td>4</td></tr><tr><td>arith num rows:</td><td>1</td></tr><tr><td>datatype constructor ax:</td><td>4</td></tr><tr><td>num allocs:</td><td>7241286</td></tr><tr><td>final checks:</td><td>1</td></tr><tr><td>added eqs:</td><td>23</td></tr><tr><td>del clause:</td><td>8</td></tr><tr><td>time:</td><td>0.007000</td></tr><tr><td>memory:</td><td>16.810000</td></tr><tr><td>max memory:</td><td>17.210000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-5751f6dc-af6d-48b5-94a7-c5ef97f042d3';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-d879ab16-56a1-438f-80f1-9ea5a4170385"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.014s]
  let (_x_0 : bool)
      = not (( :var_0: ).emp.arrival_time &lt;= ( :var_0: ).meeting_time)
  in _x_0 &amp;&amp; _x_0</pre></li><li><div><h4>simplify</h4><div class="imandra-table" id="table-ac95caa2-b0ae-4550-88ea-a80e789a2907"><table><tr><td>into:</td><td><pre>not (( :var_0: ).emp.arrival_time &lt;= ( :var_0: ).meeting_time)</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li>Sat (Some let st : state =
  {emp =
   {name = &quot;!0!&quot;; arrival_time = (Z.of_nativeint (0n));
    obligations = {sing_a_song = false; do_a_dance = false}};
   meeting_time = (Z.of_nativeint (-1n))}
)</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-d879ab16-56a1-438f-80f1-9ea5a4170385';
  fold.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-5d76cece-aaf8-451a-97bc-66b1f5665fa7"><textarea style="display: none">digraph &quot;proof&quot; {
p_2 [label=&quot;Start (let (_x_0 : bool)\l           = not (( :var_0: ).emp.arrival_time \&lt;= ( :var_0: ).meeting_time)\l       in _x_0 &amp;&amp; _x_0 :time 0.014s)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_2 -&gt; p_1 [label=&quot;&quot;];
p_1 [label=&quot;Simplify (not (( :var_0: ).emp.arrival_time \&lt;= ( :var_0: ).meeting_time)\l          :expansions [] :rw [] :fc [])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_1 -&gt; p_0 [label=&quot;&quot;];
p_0 [label=&quot;Sat (Some let st : state =\l  \{emp =\l   \{name = \&quot;!0!\&quot;; arrival_time = (Z.of_nativeint (0n));\l    obligations = \{sing_a_song = false; do_a_dance = false\}\};\l   meeting_time = (Z.of_nativeint (-1n))\}\l)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-5d76cece-aaf8-451a-97bc-66b1f5665fa7';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-e1b39794-031e-4915-8bf4-88fdef4a3c43';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-bc104909-edae-4d4d-98b8-a46c3105dcd0';
  fold.hydrate(target);
});
</script></div></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-b9c2545c-de54-4602-a076-423d8e0474f1';
  alternatives.hydrate(target);
});
</script></div></div></div>




```ocaml
(* Employee E must sing a song
   if E is late for a meeting for n minutes
   and n is less than 3*)

module Rule2 = struct

 let c1 st =
  is_late st
  
 let c2 st =
  st.emp.arrival_time - st.meeting_time < 3
  
 let cs st =
  c1 st && c2 st
  
 let s st =
  st.emp.obligations.sing_a_song
  
 let rule st =
  s st <== cs st

end
```




    module Rule2 :
      sig
        val c1 : state -> bool
        val c2 : state -> bool
        val cs : state -> bool
        val s : state -> bool
        val rule : state -> bool
      end





```ocaml
(* Employee E must do a dance
   if E is late for a meeting for n minutes
   and n is greater than 3*)

module Rule3 = struct

 let c1 st =
  is_late st

 let c2 st =
  st.emp.arrival_time - st.meeting_time > 3
  
 let cs st =
  c1 st && c2 st
  
 let s st =
  st.emp.obligations.do_a_dance
  
 let rule st =
  s st <== cs st

end
```




    module Rule3 :
      sig
        val c1 : state -> bool
        val c2 : state -> bool
        val cs : state -> bool
        val s : state -> bool
        val rule : state -> bool
      end





```ocaml
(* Employee E must NOT sing a song
   if E is late for a meeting for n minutes
   and n is greater than 1 *)

module Rule3 = struct
 
 let c1 st =
  is_late st

 let c2 st =
  st.emp.arrival_time - st.meeting_time > 1
  
 let cs st =
  c1 st && c2 st
  
 let s st =
  not (st.emp.obligations.sing_a_song)
  
 let rule st =
  s st <== cs st

end
```




    module Rule3 :
      sig
        val c1 : state -> bool
        val c2 : state -> bool
        val cs : state -> bool
        val s : state -> bool
        val rule : state -> bool
      end





```ocaml
(* Employee E must not sing a song
   if E is late for a meeting for n minutes
   and n is greater than 3 *)
   
module Rule4 = struct

 let c1 st =
  is_late st

 let c2 st =
  st.emp.arrival_time - st.meeting_time > 3
  
 let cs st =
  c1 st && c2 st
  
 let s st =
  not (st.emp.obligations.sing_a_song)
  
 let rule st =
  s st <== cs st

end
```




    module Rule4 :
      sig
        val c1 : state -> bool
        val c2 : state -> bool
        val cs : state -> bool
        val s : state -> bool
        val rule : state -> bool
      end





```ocaml
(* Employee E must do a dance
   if E is late for a meeting for n minutes
   and n is greater than 3 *)
   
module Rule5 = struct

 let c1 st =
  is_late st

 let c2 st =
  st.emp.arrival_time - st.meeting_time > 1
  
 let cs st =
  c1 st && c2 st
  
 let s st =
  st.emp.obligations.do_a_dance
  
 let rule st =
  s st <== cs st

end
```




    module Rule5 :
      sig
        val c1 : state -> bool
        val c2 : state -> bool
        val cs : state -> bool
        val s : state -> bool
        val rule : state -> bool
      end





```ocaml
(* Employee E must sing a song
   if E is late for a meeting for n minutes
   and n is less than 3 *)
   
module Rule6 = struct

 let c1 st =
  is_late st

 let c2 st =
  st.emp.arrival_time - st.meeting_time < 3
  
 let cs st =
  c1 st && c2 st
  
 let s st =
  st.emp.obligations.sing_a_song
  
 let rule st =
  s st <== cs st

end
```




    module Rule6 :
      sig
        val c1 : state -> bool
        val c2 : state -> bool
        val cs : state -> bool
        val s : state -> bool
        val rule : state -> bool
      end





```ocaml
(* Employee E must not sing a song
   if E is late for a meeting for n minutes
   and n is greater than 1 *)
   
module Rule7 = struct

 let c1 st =
  is_late st

 let c2 st =
  st.emp.arrival_time - st.meeting_time > 1
  
 let cs st =
  c1 st && c2 st
  
 let s st =
  not (st.emp.obligations.sing_a_song)
  
 let rule st =
  s st <== cs st

end
```




    module Rule7 :
      sig
        val c1 : state -> bool
        val c2 : state -> bool
        val cs : state -> bool
        val s : state -> bool
        val rule : state -> bool
      end





```ocaml
(* Employee E must not sing a song
   if E is late for a meeting for n minutes
   and n is less than 3 *)
   
module Rule8 = struct

 let c1 st =
  is_late st

 let c2 st =
  st.emp.arrival_time - st.meeting_time < 3
  
 let cs st =
  c1 st && c2 st
  
 let s st =
  not (st.emp.obligations.sing_a_song)
  
 let rule st =
  s st <== cs st

end
```




    module Rule8 :
      sig
        val c1 : state -> bool
        val c2 : state -> bool
        val cs : state -> bool
        val s : state -> bool
        val rule : state -> bool
      end




# Let's pose some queries about the relationships of these rules


```ocaml
(* Do the conditions of rules 0 and 1 overlap? *)

instance (fun st -> Rule0.cs st && Rule1.cs st)
```




    - : state -> bool = <fun>
    module CX : sig val st : state end





<div><pre>Instance (after 0 steps, 0.015s):
let st : state =
  {emp =
   {name = &quot;!0!&quot;; arrival_time = 0;
    obligations = {sing_a_song = false; do_a_dance = false}};
   meeting_time = (-4)}
</pre></div>




<div><div style="font-size: 1.2em; padding: 0.5em; border-top: 1px solid green; border-bottom: 1px solid green"><i class="fa fa-check-circle" style="margin-right: 0.5em; color: green"></i><span>Instance</span></div><div><div class="imandra-alternatives" id="alt-8ab7bc5b-26d1-40f1-ac31-b2bbd8bee1c3"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>call graph</a></li><li class="" data-toggle="tab"><a>proof</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-graphviz" id="graphviz-af706738-30b4-4249-b119-79dd4e34e4a7"><textarea style="display: none">digraph &quot;call graph&quot; {
goal [label=&quot;let (_x_0 : int) = st.emp.arrival_time in\llet (_x_1 : int) = st.meeting_time in\llet (_x_2 : int) = _x_0 + (-1) * _x_1 in\l(not (_x_0 \&lt;= _x_1) &amp;&amp; not (_x_2 \&lt;= 3)) &amp;&amp; not (_x_2 \&lt;= 1)&quot;,shape=box,style=filled,color=&quot;cyan&quot;,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-af706738-30b4-4249-b119-79dd4e34e4a7';
  graphviz.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-proof-top"><div class="imandra-fold panel panel-default" id="fold-bc766c68-badc-4bf4-955e-d83e5c248c6f"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>proof attempt</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-b62a294a-1155-43ce-8ffb-9a9890ce2b7f"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li><li class="" data-toggle="tab"><a>graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-a25fff2c-3e4c-4124-b7c8-c4f2b3826d2b"><table><tr><td>ground_instances:</td><td>0</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.015s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-f3cfc96f-1633-4d6f-b710-833bdc9abddf"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-5e0f5fed-af2b-4747-b9df-7f13801ab59d"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-76edc9f1-4218-4d31-9557-454b5785dd4d"><table><tr><td>num checks:</td><td>1</td></tr><tr><td>arith assert lower:</td><td>3</td></tr><tr><td>arith tableau max rows:</td><td>1</td></tr><tr><td>arith tableau max columns:</td><td>4</td></tr><tr><td>arith pivots:</td><td>1</td></tr><tr><td>rlimit count:</td><td>577</td></tr><tr><td>mk clause:</td><td>16</td></tr><tr><td>datatype occurs check:</td><td>1</td></tr><tr><td>mk bool var:</td><td>24</td></tr><tr><td>decisions:</td><td>2</td></tr><tr><td>seq num reductions:</td><td>1</td></tr><tr><td>propagations:</td><td>2</td></tr><tr><td>datatype accessor ax:</td><td>4</td></tr><tr><td>arith num rows:</td><td>1</td></tr><tr><td>datatype constructor ax:</td><td>4</td></tr><tr><td>num allocs:</td><td>15333776</td></tr><tr><td>final checks:</td><td>1</td></tr><tr><td>added eqs:</td><td>23</td></tr><tr><td>del clause:</td><td>8</td></tr><tr><td>time:</td><td>0.007000</td></tr><tr><td>memory:</td><td>18.390000</td></tr><tr><td>max memory:</td><td>18.780000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-f3cfc96f-1633-4d6f-b710-833bdc9abddf';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-1b98d447-c13e-4ec0-8dab-40af05b6c103"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.015s]
  let (_x_0 : int) = ( :var_0: ).emp.arrival_time in
  let (_x_1 : int) = ( :var_0: ).meeting_time in
  let (_x_2 : bool) = not (_x_0 &lt;= _x_1) in
  let (_x_3 : int) = _x_0 - _x_1 in (_x_2 &amp;&amp; _x_3 &gt; 3) &amp;&amp; _x_2 &amp;&amp; _x_3 &gt; 1</pre></li><li><div><h4>simplify</h4><div class="imandra-table" id="table-29d179aa-66ad-40cb-8aa0-4d6ede6aa69a"><table><tr><td>into:</td><td><pre>let (_x_0 : int) = ( :var_0: ).emp.arrival_time in
let (_x_1 : int) = ( :var_0: ).meeting_time in
let (_x_2 : int) = _x_0 + (-1) * _x_1 in
(not (_x_0 &lt;= _x_1) &amp;&amp; not (_x_2 &lt;= 3)) &amp;&amp; not (_x_2 &lt;= 1)</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li>Sat (Some let st : state =
  {emp =
   {name = &quot;!0!&quot;; arrival_time = (Z.of_nativeint (0n));
    obligations = {sing_a_song = false; do_a_dance = false}};
   meeting_time = (Z.of_nativeint (-4n))}
)</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-1b98d447-c13e-4ec0-8dab-40af05b6c103';
  fold.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-cb4a503e-b7f5-4f77-a2c4-be07da2d7911"><textarea style="display: none">digraph &quot;proof&quot; {
p_5 [label=&quot;Start (let (_x_0 : int) = ( :var_0: ).emp.arrival_time in\l       let (_x_1 : int) = ( :var_0: ).meeting_time in\l       let (_x_2 : bool) = not (_x_0 \&lt;= _x_1) in\l       let (_x_3 : int) = _x_0 - _x_1 in\l       (_x_2 &amp;&amp; _x_3 \&gt; 3) &amp;&amp; _x_2 &amp;&amp; _x_3 \&gt; 1 :time 0.015s)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_5 -&gt; p_4 [label=&quot;&quot;];
p_4 [label=&quot;Simplify (let (_x_0 : int) = ( :var_0: ).emp.arrival_time in\l          let (_x_1 : int) = ( :var_0: ).meeting_time in\l          let (_x_2 : int) = _x_0 + (-1) * _x_1 in\l          (not (_x_0 \&lt;= _x_1) &amp;&amp; not (_x_2 \&lt;= 3)) &amp;&amp; not (_x_2 \&lt;= 1)\l          :expansions [] :rw [] :fc [])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_4 -&gt; p_3 [label=&quot;&quot;];
p_3 [label=&quot;Sat (Some let st : state =\l  \{emp =\l   \{name = \&quot;!0!\&quot;; arrival_time = (Z.of_nativeint (0n));\l    obligations = \{sing_a_song = false; do_a_dance = false\}\};\l   meeting_time = (Z.of_nativeint (-4n))\}\l)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-cb4a503e-b7f5-4f77-a2c4-be07da2d7911';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-b62a294a-1155-43ce-8ffb-9a9890ce2b7f';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-bc766c68-badc-4bf4-955e-d83e5c248c6f';
  fold.hydrate(target);
});
</script></div></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-8ab7bc5b-26d1-40f1-ac31-b2bbd8bee1c3';
  alternatives.hydrate(target);
});
</script></div></div></div>




```ocaml
(* Do the statements of rules 0 and 1 overlap? *)

instance (fun st -> Rule0.s st && Rule1.s st)
```




    - : state -> bool = <fun>
    module CX : sig val st : state end





<div><pre>Instance (after 0 steps, 0.012s):
let st : state =
  {emp =
   {name = &quot;&quot;; arrival_time = 0;
    obligations = {sing_a_song = true; do_a_dance = false}};
   meeting_time = 0}
</pre></div>




<div><div style="font-size: 1.2em; padding: 0.5em; border-top: 1px solid green; border-bottom: 1px solid green"><i class="fa fa-check-circle" style="margin-right: 0.5em; color: green"></i><span>Instance</span></div><div><div class="imandra-alternatives" id="alt-d59b9d72-0c56-493e-b8aa-b563aa497a20"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>call graph</a></li><li class="" data-toggle="tab"><a>proof</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-graphviz" id="graphviz-142dd4cc-08de-415e-a0f3-feabfe8189a2"><textarea style="display: none">digraph &quot;call graph&quot; {
goal [label=&quot;st.emp.obligations.sing_a_song&quot;,shape=box,style=filled,color=&quot;cyan&quot;,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-142dd4cc-08de-415e-a0f3-feabfe8189a2';
  graphviz.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-proof-top"><div class="imandra-fold panel panel-default" id="fold-0fc003ea-8aee-4d00-89ac-6b37515e548e"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>proof attempt</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-d9796039-d5e6-47bb-ac35-ac7ff23b8dcd"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li><li class="" data-toggle="tab"><a>graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-38a6b392-ae8f-4e04-b0f0-e571435965d2"><table><tr><td>ground_instances:</td><td>0</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.012s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-c9e89b62-9988-4583-bc89-03ff9e09089b"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-c73c87a6-6ec1-443a-a84d-ceb7058fb841"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-6cdfdd1d-4716-4483-8b0c-075ac993d93f"><table><tr><td>num checks:</td><td>1</td></tr><tr><td>rlimit count:</td><td>119</td></tr><tr><td>mk bool var:</td><td>1</td></tr><tr><td>eliminated applications:</td><td>3</td></tr><tr><td>num allocs:</td><td>23655505</td></tr><tr><td>final checks:</td><td>1</td></tr><tr><td>time:</td><td>0.005000</td></tr><tr><td>memory:</td><td>18.540000</td></tr><tr><td>max memory:</td><td>18.790000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-c9e89b62-9988-4583-bc89-03ff9e09089b';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-79ee209d-1481-46de-ba7f-0e5170e7c2bc"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.012s]
  let (_x_0 : bool) = ( :var_0: ).emp.obligations.sing_a_song in _x_0 &amp;&amp; _x_0</pre></li><li><div><h4>simplify</h4><div class="imandra-table" id="table-a72a02bb-4d6c-474d-8399-29d0c7af1179"><table><tr><td>into:</td><td><pre>( :var_0: ).emp.obligations.sing_a_song</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li>Sat (Some let st : state =
  {emp =
   {name = &quot;&quot;; arrival_time = (Z.of_nativeint (0n));
    obligations = {sing_a_song = true; do_a_dance = false}};
   meeting_time = (Z.of_nativeint (0n))}
)</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-79ee209d-1481-46de-ba7f-0e5170e7c2bc';
  fold.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-17af135c-c3f0-4c0d-b28a-5d5f05b952cd"><textarea style="display: none">digraph &quot;proof&quot; {
p_8 [label=&quot;Start (let (_x_0 : bool) = ( :var_0: ).emp.obligations.sing_a_song in\l       _x_0 &amp;&amp; _x_0 :time 0.012s)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_8 -&gt; p_7 [label=&quot;&quot;];
p_7 [label=&quot;Simplify (( :var_0: ).emp.obligations.sing_a_song :expansions [] :rw []\l          :fc [])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_7 -&gt; p_6 [label=&quot;&quot;];
p_6 [label=&quot;Sat (Some let st : state =\l  \{emp =\l   \{name = \&quot;\&quot;; arrival_time = (Z.of_nativeint (0n));\l    obligations = \{sing_a_song = true; do_a_dance = false\}\};\l   meeting_time = (Z.of_nativeint (0n))\}\l)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-17af135c-c3f0-4c0d-b28a-5d5f05b952cd';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-d9796039-d5e6-47bb-ac35-ac7ff23b8dcd';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-0fc003ea-8aee-4d00-89ac-6b37515e548e';
  fold.hydrate(target);
});
</script></div></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-d59b9d72-0c56-493e-b8aa-b563aa497a20';
  alternatives.hydrate(target);
});
</script></div></div></div>




```ocaml
(* We can encode these as checks on rules.
   We prefix with `v` if `verify` should be used, else with `i` if `instance` should be used. *)

let v_check_1 r1_cs r1_s r2_cs r2_s st =
  r1_s st = r2_s st && r1_cs st = r2_cs st
```




    val v_check_1 :
      ('a -> 'b) -> ('a -> 'c) -> ('a -> 'b) -> ('a -> 'c) -> 'a -> bool = <fun>





```ocaml
(* For example, we can do check1 for Rule0 and Rule0 *)

verify (fun st -> v_check_1 Rule0.cs Rule0.s Rule0.cs Rule0.s st)
```




    - : state -> bool = <fun>





<div><div style="font-size: 1.2em; padding: 0.5em; border-top: 1px solid green; border-bottom: 1px solid green"><i class="fa fa-check-circle" style="margin-right: 0.5em; color: green"></i><span>Proved</span></div><div><div class="imandra-alternatives" id="alt-c802b71c-269a-4bfe-a357-5cda1cf81fc3"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>proof</a></li><li class="" data-toggle="tab"><a>call graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-proof-top"><div class="imandra-fold panel panel-default" id="fold-490fab55-88e7-43ff-9c43-d1f3ff0cac10"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>proof</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-69bef5ec-b96e-47e0-ac22-9d0d94377750"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li><li class="" data-toggle="tab"><a>graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-af94d251-2b43-481c-b113-1a6180e6aa49"><table><tr><td>ground_instances:</td><td>0</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.018s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-2651edbd-d4b4-4a68-9fb7-0ed94a6c58eb"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-9a0fbc4b-c584-4916-bb50-f93c67117ef6"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-88a249e9-a3f3-41d3-b038-7969a1d9e421"><table><tr><td>rlimit count:</td><td>7</td></tr><tr><td>num allocs:</td><td>33563801</td></tr><tr><td>time:</td><td>0.007000</td></tr><tr><td>memory:</td><td>18.940000</td></tr><tr><td>max memory:</td><td>18.940000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-2651edbd-d4b4-4a68-9fb7-0ed94a6c58eb';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-da6aca19-2613-45a0-a451-fc7afe31b496"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.018s] true</pre></li><li>Unsat</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-da6aca19-2613-45a0-a451-fc7afe31b496';
  fold.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-5ee4604b-ef49-4f0e-b59b-2060cc6dfe49"><textarea style="display: none">digraph &quot;proof&quot; {
p_10 [label=&quot;Start (true :time 0.018s)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_10 -&gt; p_9 [label=&quot;&quot;];
p_9 [label=&quot;Unsat&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-5ee4604b-ef49-4f0e-b59b-2060cc6dfe49';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-69bef5ec-b96e-47e0-ac22-9d0d94377750';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-490fab55-88e7-43ff-9c43-d1f3ff0cac10';
  fold.hydrate(target);
});
</script></div></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-02c8013a-d08d-4ec5-80cf-c930fbac63c2"><textarea style="display: none">digraph &quot;call graph&quot; {
goal [label=&quot;false&quot;,shape=box,style=filled,color=&quot;cyan&quot;,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-02c8013a-d08d-4ec5-80cf-c930fbac63c2';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-c802b71c-269a-4bfe-a357-5cda1cf81fc3';
  alternatives.hydrate(target);
});
</script></div></div></div>




```ocaml
(* And similarly for Rule0 and Rule1 *)

verify (fun st -> v_check_1 Rule0.cs Rule0.s Rule1.cs Rule1.s st)
```




    - : state -> bool = <fun>
    module CX : sig val st : state end





<div><pre>Counterexample (after 0 steps, 0.014s):
let st : state =
  {emp =
   {name = &quot;!0!&quot;; arrival_time = 0;
    obligations = {sing_a_song = false; do_a_dance = false}};
   meeting_time = (-2)}
</pre></div>




<div><div style="font-size: 1.2em; padding: 0.5em; border-top: 1px dashed #D84315; border-bottom: 1px dashed #D84315"><i class="fa fa-times-circle-o" style="margin-right: 0.5em; color: #D84315"></i><span>Refuted</span></div><div><div class="imandra-alternatives" id="alt-e9dd0ce2-e689-4746-8bbf-aac5bd25a7a3"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>call graph</a></li><li class="" data-toggle="tab"><a>proof</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-graphviz" id="graphviz-f62dce57-bf40-4223-a209-2b1316310695"><textarea style="display: none">digraph &quot;call graph&quot; {
goal [label=&quot;let (_x_0 : int) = st.emp.arrival_time in\llet (_x_1 : int) = st.meeting_time in\llet (_x_2 : bool) = not (_x_0 \&lt;= _x_1) in\llet (_x_3 : int) = _x_0 + (-1) * _x_1 in\lnot ((_x_2 &amp;&amp; not (_x_3 \&lt;= 3)) = (_x_2 &amp;&amp; not (_x_3 \&lt;= 1)))&quot;,shape=box,style=filled,color=&quot;cyan&quot;,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-f62dce57-bf40-4223-a209-2b1316310695';
  graphviz.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-proof-top"><div class="imandra-fold panel panel-default" id="fold-79387e46-486c-4932-b48e-d26f3652949b"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>proof attempt</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-5e96891b-0d95-41fc-b2dc-572e698e70df"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li><li class="" data-toggle="tab"><a>graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-f68ad972-0ee3-4ad3-a945-f9783772a12c"><table><tr><td>ground_instances:</td><td>0</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.014s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-84cd53e4-a15c-4afc-a5db-b2bd3a905036"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-c5b88f18-86f6-4e50-aee5-e2083d7f15fa"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-b77f0ebc-bcd0-4727-aa32-b3d8ed94dc86"><table><tr><td>num checks:</td><td>1</td></tr><tr><td>arith assert lower:</td><td>2</td></tr><tr><td>arith tableau max rows:</td><td>1</td></tr><tr><td>arith tableau max columns:</td><td>4</td></tr><tr><td>arith pivots:</td><td>1</td></tr><tr><td>rlimit count:</td><td>733</td></tr><tr><td>mk clause:</td><td>26</td></tr><tr><td>datatype occurs check:</td><td>1</td></tr><tr><td>mk bool var:</td><td>26</td></tr><tr><td>arith assert upper:</td><td>1</td></tr><tr><td>decisions:</td><td>3</td></tr><tr><td>seq num reductions:</td><td>1</td></tr><tr><td>propagations:</td><td>10</td></tr><tr><td>conflicts:</td><td>1</td></tr><tr><td>datatype accessor ax:</td><td>4</td></tr><tr><td>arith num rows:</td><td>1</td></tr><tr><td>datatype constructor ax:</td><td>4</td></tr><tr><td>num allocs:</td><td>46687450</td></tr><tr><td>final checks:</td><td>1</td></tr><tr><td>added eqs:</td><td>23</td></tr><tr><td>del clause:</td><td>8</td></tr><tr><td>time:</td><td>0.007000</td></tr><tr><td>memory:</td><td>19.170000</td></tr><tr><td>max memory:</td><td>19.530000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-84cd53e4-a15c-4afc-a5db-b2bd3a905036';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-9abf91f7-2080-4069-8429-25a85a342025"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.014s]
  let (_x_0 : int) = ( :var_0: ).emp.arrival_time in
  let (_x_1 : int) = ( :var_0: ).meeting_time in
  let (_x_2 : bool) = not (_x_0 &lt;= _x_1) in
  let (_x_3 : int) = _x_0 - _x_1 in (_x_2 &amp;&amp; _x_3 &gt; 3) = (_x_2 &amp;&amp; _x_3 &gt; 1)</pre></li><li><div><h4>simplify</h4><div class="imandra-table" id="table-ea7cac93-f193-46f3-87ee-c428745f15ee"><table><tr><td>into:</td><td><pre>let (_x_0 : int) = ( :var_0: ).emp.arrival_time in
let (_x_1 : int) = ( :var_0: ).meeting_time in
let (_x_2 : bool) = not (_x_0 &lt;= _x_1) in
let (_x_3 : int) = _x_0 + (-1) * _x_1 in
(_x_2 &amp;&amp; not (_x_3 &lt;= 3)) = (_x_2 &amp;&amp; not (_x_3 &lt;= 1))</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li>Sat (Some let st : state =
  {emp =
   {name = &quot;!0!&quot;; arrival_time = (Z.of_nativeint (0n));
    obligations = {sing_a_song = false; do_a_dance = false}};
   meeting_time = (Z.of_nativeint (-2n))}
)</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-9abf91f7-2080-4069-8429-25a85a342025';
  fold.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-078845fa-2f3d-41a0-8294-444ea029b4f0"><textarea style="display: none">digraph &quot;proof&quot; {
p_13 [label=&quot;Start (let (_x_0 : int) = ( :var_0: ).emp.arrival_time in\l       let (_x_1 : int) = ( :var_0: ).meeting_time in\l       let (_x_2 : bool) = not (_x_0 \&lt;= _x_1) in\l       let (_x_3 : int) = _x_0 - _x_1 in\l       (_x_2 &amp;&amp; _x_3 \&gt; 3) = (_x_2 &amp;&amp; _x_3 \&gt; 1) :time 0.014s)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_13 -&gt; p_12 [label=&quot;&quot;];
p_12 [label=&quot;Simplify (let (_x_0 : int) = ( :var_0: ).emp.arrival_time in\l          let (_x_1 : int) = ( :var_0: ).meeting_time in\l          let (_x_2 : bool) = not (_x_0 \&lt;= _x_1) in\l          let (_x_3 : int) = _x_0 + (-1) * _x_1 in\l          (_x_2 &amp;&amp; not (_x_3 \&lt;= 3)) = (_x_2 &amp;&amp; not (_x_3 \&lt;= 1))\l          :expansions [] :rw [] :fc [])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_12 -&gt; p_11 [label=&quot;&quot;];
p_11 [label=&quot;Sat (Some let st : state =\l  \{emp =\l   \{name = \&quot;!0!\&quot;; arrival_time = (Z.of_nativeint (0n));\l    obligations = \{sing_a_song = false; do_a_dance = false\}\};\l   meeting_time = (Z.of_nativeint (-2n))\}\l)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-078845fa-2f3d-41a0-8294-444ea029b4f0';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-5e96891b-0d95-41fc-b2dc-572e698e70df';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-79387e46-486c-4932-b48e-d26f3652949b';
  fold.hydrate(target);
});
</script></div></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-e9dd0ce2-e689-4746-8bbf-aac5bd25a7a3';
  alternatives.hydrate(target);
});
</script></div></div></div>




```ocaml
(* Now let's consider check2: statements the same but conditions different (overlapping) *)
(* We do this with two checks, one universal and one existential: *)

let v_check2 r1_cs r1_s r2_cs r2_s st =
 r1_s st = r2_s st
 
let i_check2 r1_cs r1_s r2_cs r2_s st =
 r1_cs st && r2_cs st
```




    val v_check2 : 'a -> ('b -> 'c) -> 'd -> ('b -> 'c) -> 'b -> bool = <fun>
    val i_check2 : ('a -> bool) -> 'b -> ('a -> bool) -> 'c -> 'a -> bool = <fun>





```ocaml
(* Let's check condition 2 for Rule0 and Rule1 -- we see it holds! *)

verify (fun st -> v_check2 Rule0.cs Rule0.s Rule1.cs Rule2.s st)
instance (fun st -> i_check2 Rule0.cs Rule0.s Rule1.cs Rule2.s st)
```




    - : state -> bool = <fun>
    - : state -> bool = <fun>
    module CX : sig val st : state end





<div><div style="font-size: 1.2em; padding: 0.5em; border-top: 1px solid green; border-bottom: 1px solid green"><i class="fa fa-check-circle" style="margin-right: 0.5em; color: green"></i><span>Proved</span></div><div><div class="imandra-alternatives" id="alt-bdb906e5-8069-4e94-adf5-7c9d45b37c95"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>proof</a></li><li class="" data-toggle="tab"><a>call graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-proof-top"><div class="imandra-fold panel panel-default" id="fold-b84f64fc-6a7e-47ff-abf7-7f99d3b67d68"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>proof</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-550e5549-3646-4f7e-afe4-002e508fcd97"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li><li class="" data-toggle="tab"><a>graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-38cc3470-f17e-4f0c-98bd-0558d247a99a"><table><tr><td>ground_instances:</td><td>0</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.013s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-c9739c54-68e6-4f47-ae24-b96e2018b2cd"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-d8c3b631-5d96-482e-b86d-7aa03b45992e"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-99bb43fd-c292-4ad2-9484-10f73527e194"><table><tr><td>rlimit count:</td><td>32</td></tr><tr><td>num allocs:</td><td>60860192</td></tr><tr><td>time:</td><td>0.006000</td></tr><tr><td>memory:</td><td>19.690000</td></tr><tr><td>max memory:</td><td>19.690000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-c9739c54-68e6-4f47-ae24-b96e2018b2cd';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-0d21462f-d447-4b6d-be28-74697640ad09"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.013s] true</pre></li><li><div><h4>simplify</h4><div class="imandra-table" id="table-d70c2b69-a6d6-4ad2-bc61-41431b328821"><table><tr><td>into:</td><td><pre>true</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li>Unsat</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-0d21462f-d447-4b6d-be28-74697640ad09';
  fold.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-d7e6f576-96bc-48c2-b51b-34209229e43a"><textarea style="display: none">digraph &quot;proof&quot; {
p_16 [label=&quot;Start (true :time 0.013s)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_16 -&gt; p_15 [label=&quot;&quot;];
p_15 [label=&quot;Simplify (true :expansions [] :rw [] :fc [])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_15 -&gt; p_14 [label=&quot;&quot;];
p_14 [label=&quot;Unsat&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-d7e6f576-96bc-48c2-b51b-34209229e43a';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-550e5549-3646-4f7e-afe4-002e508fcd97';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-b84f64fc-6a7e-47ff-abf7-7f99d3b67d68';
  fold.hydrate(target);
});
</script></div></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-f8998120-5439-40dd-9138-c1611d187df9"><textarea style="display: none">digraph &quot;call graph&quot; {
goal [label=&quot;false&quot;,shape=box,style=filled,color=&quot;cyan&quot;,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-f8998120-5439-40dd-9138-c1611d187df9';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-bdb906e5-8069-4e94-adf5-7c9d45b37c95';
  alternatives.hydrate(target);
});
</script></div></div></div>




<div><pre>Instance (after 0 steps, 0.014s):
let st : state =
  {emp =
   {name = &quot;!0!&quot;; arrival_time = 0;
    obligations = {sing_a_song = false; do_a_dance = false}};
   meeting_time = (-4)}
</pre></div>




<div><div style="font-size: 1.2em; padding: 0.5em; border-top: 1px solid green; border-bottom: 1px solid green"><i class="fa fa-check-circle" style="margin-right: 0.5em; color: green"></i><span>Instance</span></div><div><div class="imandra-alternatives" id="alt-693882fd-e4df-4ff9-a080-7da456f2b2a0"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>call graph</a></li><li class="" data-toggle="tab"><a>proof</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-graphviz" id="graphviz-65ea870c-8cc4-4819-a6cc-c704fc2acade"><textarea style="display: none">digraph &quot;call graph&quot; {
goal [label=&quot;let (_x_0 : int) = st.emp.arrival_time in\llet (_x_1 : int) = st.meeting_time in\llet (_x_2 : int) = _x_0 + (-1) * _x_1 in\l(not (_x_0 \&lt;= _x_1) &amp;&amp; not (_x_2 \&lt;= 3)) &amp;&amp; not (_x_2 \&lt;= 1)&quot;,shape=box,style=filled,color=&quot;cyan&quot;,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-65ea870c-8cc4-4819-a6cc-c704fc2acade';
  graphviz.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-proof-top"><div class="imandra-fold panel panel-default" id="fold-767d032a-7511-4bb9-b9ca-8f3f8259f6e8"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>proof attempt</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-f4c09df8-52c6-4b67-98a4-acf5c0d8a819"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li><li class="" data-toggle="tab"><a>graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-8a1a51ef-8d4e-4657-aca9-dd116cbd544f"><table><tr><td>ground_instances:</td><td>0</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.014s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-12ddd0b7-a988-4b4e-9c1b-cda8515b0327"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-0b647677-8b00-4320-8811-3f360b090db8"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-c0fe8c92-6beb-467b-b7a3-c0302046b97e"><table><tr><td>num checks:</td><td>1</td></tr><tr><td>arith assert lower:</td><td>3</td></tr><tr><td>arith tableau max rows:</td><td>1</td></tr><tr><td>arith tableau max columns:</td><td>4</td></tr><tr><td>arith pivots:</td><td>1</td></tr><tr><td>rlimit count:</td><td>583</td></tr><tr><td>mk clause:</td><td>16</td></tr><tr><td>datatype occurs check:</td><td>1</td></tr><tr><td>mk bool var:</td><td>24</td></tr><tr><td>decisions:</td><td>2</td></tr><tr><td>seq num reductions:</td><td>1</td></tr><tr><td>propagations:</td><td>2</td></tr><tr><td>datatype accessor ax:</td><td>4</td></tr><tr><td>arith num rows:</td><td>1</td></tr><tr><td>datatype constructor ax:</td><td>4</td></tr><tr><td>num allocs:</td><td>78731569</td></tr><tr><td>final checks:</td><td>1</td></tr><tr><td>added eqs:</td><td>23</td></tr><tr><td>del clause:</td><td>8</td></tr><tr><td>time:</td><td>0.007000</td></tr><tr><td>memory:</td><td>19.890000</td></tr><tr><td>max memory:</td><td>20.280000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-12ddd0b7-a988-4b4e-9c1b-cda8515b0327';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-3ea2c0d1-905e-4ed8-85ed-055be7f98a1d"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.014s]
  let (_x_0 : int) = ( :var_0: ).emp.arrival_time in
  let (_x_1 : int) = ( :var_0: ).meeting_time in
  let (_x_2 : bool) = not (_x_0 &lt;= _x_1) in
  let (_x_3 : int) = _x_0 - _x_1 in (_x_2 &amp;&amp; _x_3 &gt; 3) &amp;&amp; _x_2 &amp;&amp; _x_3 &gt; 1</pre></li><li><div><h4>simplify</h4><div class="imandra-table" id="table-99c5afe8-13c0-4e02-b091-45e65cb93bbd"><table><tr><td>into:</td><td><pre>let (_x_0 : int) = ( :var_0: ).emp.arrival_time in
let (_x_1 : int) = ( :var_0: ).meeting_time in
let (_x_2 : int) = _x_0 + (-1) * _x_1 in
(not (_x_0 &lt;= _x_1) &amp;&amp; not (_x_2 &lt;= 3)) &amp;&amp; not (_x_2 &lt;= 1)</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li>Sat (Some let st : state =
  {emp =
   {name = &quot;!0!&quot;; arrival_time = (Z.of_nativeint (0n));
    obligations = {sing_a_song = false; do_a_dance = false}};
   meeting_time = (Z.of_nativeint (-4n))}
)</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-3ea2c0d1-905e-4ed8-85ed-055be7f98a1d';
  fold.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-38f7c568-1317-4420-9a8e-89716b5c87e9"><textarea style="display: none">digraph &quot;proof&quot; {
p_19 [label=&quot;Start (let (_x_0 : int) = ( :var_0: ).emp.arrival_time in\l       let (_x_1 : int) = ( :var_0: ).meeting_time in\l       let (_x_2 : bool) = not (_x_0 \&lt;= _x_1) in\l       let (_x_3 : int) = _x_0 - _x_1 in\l       (_x_2 &amp;&amp; _x_3 \&gt; 3) &amp;&amp; _x_2 &amp;&amp; _x_3 \&gt; 1 :time 0.014s)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_19 -&gt; p_18 [label=&quot;&quot;];
p_18 [label=&quot;Simplify (let (_x_0 : int) = ( :var_0: ).emp.arrival_time in\l          let (_x_1 : int) = ( :var_0: ).meeting_time in\l          let (_x_2 : int) = _x_0 + (-1) * _x_1 in\l          (not (_x_0 \&lt;= _x_1) &amp;&amp; not (_x_2 \&lt;= 3)) &amp;&amp; not (_x_2 \&lt;= 1)\l          :expansions [] :rw [] :fc [])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_18 -&gt; p_17 [label=&quot;&quot;];
p_17 [label=&quot;Sat (Some let st : state =\l  \{emp =\l   \{name = \&quot;!0!\&quot;; arrival_time = (Z.of_nativeint (0n));\l    obligations = \{sing_a_song = false; do_a_dance = false\}\};\l   meeting_time = (Z.of_nativeint (-4n))\}\l)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-38f7c568-1317-4420-9a8e-89716b5c87e9';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-f4c09df8-52c6-4b67-98a4-acf5c0d8a819';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-767d032a-7511-4bb9-b9ca-8f3f8259f6e8';
  fold.hydrate(target);
});
</script></div></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-693882fd-e4df-4ff9-a080-7da456f2b2a0';
  alternatives.hydrate(target);
});
</script></div></div></div>




```ocaml
(* Let's check condition 2 for Rule0 and Rule2 -- we see it does not hold! *)

verify (fun st -> v_check2 Rule0.cs Rule0.s Rule2.cs Rule2.s st)
instance (fun st -> i_check2 Rule0.cs Rule0.s Rule2.cs Rule2.s st)
```




    - : state -> bool = <fun>
    - : state -> bool = <fun>





<div><div style="font-size: 1.2em; padding: 0.5em; border-top: 1px solid green; border-bottom: 1px solid green"><i class="fa fa-check-circle" style="margin-right: 0.5em; color: green"></i><span>Proved</span></div><div><div class="imandra-alternatives" id="alt-7c48d968-5308-42c3-8302-494847b8a731"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>proof</a></li><li class="" data-toggle="tab"><a>call graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-proof-top"><div class="imandra-fold panel panel-default" id="fold-70c73004-0ea0-4168-97fd-c1929ae93fcc"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>proof</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-21fcc2e3-e82a-45c4-9bc0-b05aba56cb60"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li><li class="" data-toggle="tab"><a>graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-b2722a40-5a31-4bd4-8c8e-107e047ba011"><table><tr><td>ground_instances:</td><td>0</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.012s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-e6447305-0f83-4c34-9307-5eaa77b000c8"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-741bd8cc-dab7-4f34-ae20-e7a233c60438"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-8e225a8c-32f3-4e4b-87cd-1bd5baf75c50"><table><tr><td>rlimit count:</td><td>32</td></tr><tr><td>num allocs:</td><td>95948293</td></tr><tr><td>time:</td><td>0.005000</td></tr><tr><td>memory:</td><td>20.080000</td></tr><tr><td>max memory:</td><td>20.280000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-e6447305-0f83-4c34-9307-5eaa77b000c8';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-7abd49a1-7f5f-45dd-b90f-6b318bb8453c"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.012s] true</pre></li><li><div><h4>simplify</h4><div class="imandra-table" id="table-37e94b44-2ae2-4cd9-bdc4-77b7ab91c384"><table><tr><td>into:</td><td><pre>true</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li>Unsat</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-7abd49a1-7f5f-45dd-b90f-6b318bb8453c';
  fold.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-cc195157-9111-4f0b-9073-88e9b613c3f0"><textarea style="display: none">digraph &quot;proof&quot; {
p_22 [label=&quot;Start (true :time 0.012s)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_22 -&gt; p_21 [label=&quot;&quot;];
p_21 [label=&quot;Simplify (true :expansions [] :rw [] :fc [])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_21 -&gt; p_20 [label=&quot;&quot;];
p_20 [label=&quot;Unsat&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-cc195157-9111-4f0b-9073-88e9b613c3f0';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-21fcc2e3-e82a-45c4-9bc0-b05aba56cb60';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-70c73004-0ea0-4168-97fd-c1929ae93fcc';
  fold.hydrate(target);
});
</script></div></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-3793b3c1-4efa-4a2d-996f-d38f61f798f6"><textarea style="display: none">digraph &quot;call graph&quot; {
goal [label=&quot;false&quot;,shape=box,style=filled,color=&quot;cyan&quot;,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-3793b3c1-4efa-4a2d-996f-d38f61f798f6';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-7c48d968-5308-42c3-8302-494847b8a731';
  alternatives.hydrate(target);
});
</script></div></div></div>




<div><div style="font-size: 1.2em; padding: 0.5em; border-top: 1px dashed #D84315; border-bottom: 1px dashed #D84315"><i class="fa fa-times-circle-o" style="margin-right: 0.5em; color: #D84315"></i><span>Unsatisfiable</span></div><div><div class="imandra-alternatives" id="alt-d23ae2f4-2637-4b4e-b6f0-2de724c353a5"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>proof</a></li><li class="" data-toggle="tab"><a>call graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-proof-top"><div class="imandra-fold panel panel-default" id="fold-01d9ab7e-cbe9-4f04-9d7d-2178aa546d57"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>proof</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-f76f752b-9046-4320-9f0d-f5e318848e8e"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li><li class="" data-toggle="tab"><a>graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-7bd32e8c-ede4-4293-87dd-0a9c734e3973"><table><tr><td>ground_instances:</td><td>0</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.014s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-3781f042-f8ce-4a81-b031-40983c28bd73"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-3a0c9df4-d67a-4606-b409-126cf4766cf2"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-4aa71b57-4c44-449f-965e-2dcd2d804707"><table><tr><td>num checks:</td><td>1</td></tr><tr><td>arith assert lower:</td><td>2</td></tr><tr><td>arith tableau max rows:</td><td>1</td></tr><tr><td>arith tableau max columns:</td><td>4</td></tr><tr><td>rlimit count:</td><td>508</td></tr><tr><td>mk clause:</td><td>16</td></tr><tr><td>mk bool var:</td><td>24</td></tr><tr><td>arith assert upper:</td><td>1</td></tr><tr><td>seq num reductions:</td><td>1</td></tr><tr><td>conflicts:</td><td>1</td></tr><tr><td>datatype accessor ax:</td><td>4</td></tr><tr><td>arith conflicts:</td><td>1</td></tr><tr><td>arith num rows:</td><td>1</td></tr><tr><td>datatype constructor ax:</td><td>4</td></tr><tr><td>num allocs:</td><td>118217010</td></tr><tr><td>added eqs:</td><td>15</td></tr><tr><td>time:</td><td>0.006000</td></tr><tr><td>memory:</td><td>20.260000</td></tr><tr><td>max memory:</td><td>20.680000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-3781f042-f8ce-4a81-b031-40983c28bd73';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-fdb3d01f-c838-4a29-9b63-73e48d019d83"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.014s]
  let (_x_0 : int) = ( :var_0: ).emp.arrival_time in
  let (_x_1 : int) = ( :var_0: ).meeting_time in
  let (_x_2 : bool) = not (_x_0 &lt;= _x_1) in
  let (_x_3 : int) = _x_0 - _x_1 in (_x_2 &amp;&amp; _x_3 &gt; 3) &amp;&amp; _x_2 &amp;&amp; _x_3 &lt; 3</pre></li><li><div><h4>simplify</h4><div class="imandra-table" id="table-c71a564b-038e-4345-bd90-61b928b33e2f"><table><tr><td>into:</td><td><pre>let (_x_0 : int) = ( :var_0: ).emp.arrival_time in
let (_x_1 : int) = ( :var_0: ).meeting_time in
let (_x_2 : int) = _x_0 + (-1) * _x_1 in
(not (_x_0 &lt;= _x_1) &amp;&amp; not (_x_2 &lt;= 3)) &amp;&amp; not (3 &lt;= _x_2)</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li>Unsat</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-fdb3d01f-c838-4a29-9b63-73e48d019d83';
  fold.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-43714787-1202-4945-9b6b-576ae853662d"><textarea style="display: none">digraph &quot;proof&quot; {
p_25 [label=&quot;Start (let (_x_0 : int) = ( :var_0: ).emp.arrival_time in\l       let (_x_1 : int) = ( :var_0: ).meeting_time in\l       let (_x_2 : bool) = not (_x_0 \&lt;= _x_1) in\l       let (_x_3 : int) = _x_0 - _x_1 in\l       (_x_2 &amp;&amp; _x_3 \&gt; 3) &amp;&amp; _x_2 &amp;&amp; _x_3 \&lt; 3 :time 0.014s)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_25 -&gt; p_24 [label=&quot;&quot;];
p_24 [label=&quot;Simplify (let (_x_0 : int) = ( :var_0: ).emp.arrival_time in\l          let (_x_1 : int) = ( :var_0: ).meeting_time in\l          let (_x_2 : int) = _x_0 + (-1) * _x_1 in\l          (not (_x_0 \&lt;= _x_1) &amp;&amp; not (_x_2 \&lt;= 3)) &amp;&amp; not (3 \&lt;= _x_2)\l          :expansions [] :rw [] :fc [])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_24 -&gt; p_23 [label=&quot;&quot;];
p_23 [label=&quot;Unsat&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-43714787-1202-4945-9b6b-576ae853662d';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-f76f752b-9046-4320-9f0d-f5e318848e8e';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-01d9ab7e-cbe9-4f04-9d7d-2178aa546d57';
  fold.hydrate(target);
});
</script></div></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-7b9a1b16-5b97-4d15-9046-4e8b6a09feea"><textarea style="display: none">digraph &quot;call graph&quot; {
goal [label=&quot;let (_x_0 : int) = st.emp.arrival_time in\llet (_x_1 : int) = st.meeting_time in\llet (_x_2 : int) = _x_0 + (-1) * _x_1 in\l(not (_x_0 \&lt;= _x_1) &amp;&amp; not (_x_2 \&lt;= 3)) &amp;&amp; not (3 \&lt;= _x_2)&quot;,shape=box,style=filled,color=&quot;cyan&quot;,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-7b9a1b16-5b97-4d15-9046-4e8b6a09feea';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-d23ae2f4-2637-4b4e-b6f0-2de724c353a5';
  alternatives.hydrate(target);
});
</script></div></div></div>




```ocaml
(* Now let's do check 7: contrary statements with same conditions *)

let v_check7 r1_cs r1_s r2_cs r2_s st =
 (r1_s st <==> not(r2_s st)) && (r1_cs st = r2_cs st)
```




    val v_check7 :
      ('a -> 'b) -> ('a -> bool) -> ('a -> 'b) -> ('a -> bool) -> 'a -> bool =
      <fun>





```ocaml
(* We'll check this for Rule0 and Rule 4 *)

verify (fun st -> v_check7 Rule0.cs Rule0.s Rule4.cs Rule4.s st)
```




    - : state -> bool = <fun>





<div><div style="font-size: 1.2em; padding: 0.5em; border-top: 1px solid green; border-bottom: 1px solid green"><i class="fa fa-check-circle" style="margin-right: 0.5em; color: green"></i><span>Proved</span></div><div><div class="imandra-alternatives" id="alt-690b78ed-a9c1-4dff-a590-ffd4aa07675a"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>proof</a></li><li class="" data-toggle="tab"><a>call graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-proof-top"><div class="imandra-fold panel panel-default" id="fold-39ad1e15-d3d3-437a-b784-7a7cdca5450a"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>proof</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-3797b565-c822-445e-8be0-09cf0333feb8"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li><li class="" data-toggle="tab"><a>graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-8e8b3811-498a-4501-8013-95aef65d1906"><table><tr><td>ground_instances:</td><td>0</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.013s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-75131037-14cb-4767-ac88-577517540a0d"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-a8890f3c-12d8-435d-a8cd-c39446db77e1"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-ba33015a-53cb-4b09-af00-d163ccec4795"><table><tr><td>rlimit count:</td><td>126</td></tr><tr><td>num allocs:</td><td>140064525</td></tr><tr><td>time:</td><td>0.006000</td></tr><tr><td>memory:</td><td>20.640000</td></tr><tr><td>max memory:</td><td>20.680000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-75131037-14cb-4767-ac88-577517540a0d';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-fa1ea487-7946-46fa-be2d-a5c2b5828fd4"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.013s] true</pre></li><li><div><h4>simplify</h4><div class="imandra-table" id="table-67ba667e-c446-4b61-b851-50c6a19ca8d6"><table><tr><td>into:</td><td><pre>true</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li>Unsat</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-fa1ea487-7946-46fa-be2d-a5c2b5828fd4';
  fold.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-c4164e26-7a88-4cfe-88de-4b6b120b033f"><textarea style="display: none">digraph &quot;proof&quot; {
p_28 [label=&quot;Start (true :time 0.013s)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_28 -&gt; p_27 [label=&quot;&quot;];
p_27 [label=&quot;Simplify (true :expansions [] :rw [] :fc [])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_27 -&gt; p_26 [label=&quot;&quot;];
p_26 [label=&quot;Unsat&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-c4164e26-7a88-4cfe-88de-4b6b120b033f';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-3797b565-c822-445e-8be0-09cf0333feb8';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-39ad1e15-d3d3-437a-b784-7a7cdca5450a';
  fold.hydrate(target);
});
</script></div></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-7edbafa2-12fa-49ba-ba8a-06e92a2974a5"><textarea style="display: none">digraph &quot;call graph&quot; {
goal [label=&quot;false&quot;,shape=box,style=filled,color=&quot;cyan&quot;,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-7edbafa2-12fa-49ba-ba8a-06e92a2974a5';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-690b78ed-a9c1-4dff-a590-ffd4aa07675a';
  alternatives.hydrate(target);
});
</script></div></div></div>




```ocaml
(* Now let's check it for Rule0 and Rule5 -- we see it's not true! *)

verify (fun st -> v_check7 Rule0.cs Rule0.s Rule5.cs Rule5.s st)
```




    - : state -> bool = <fun>
    module CX : sig val st : state end





<div><pre>Counterexample (after 0 steps, 0.013s):
let st : state =
  {emp =
   {name = &quot;!0!&quot;; arrival_time = 0;
    obligations = {sing_a_song = false; do_a_dance = false}};
   meeting_time = 38}
</pre></div>




<div><div style="font-size: 1.2em; padding: 0.5em; border-top: 1px dashed #D84315; border-bottom: 1px dashed #D84315"><i class="fa fa-times-circle-o" style="margin-right: 0.5em; color: #D84315"></i><span>Refuted</span></div><div><div class="imandra-alternatives" id="alt-d8902ac0-7547-4453-91c6-b754fcbbe94f"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>call graph</a></li><li class="" data-toggle="tab"><a>proof</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-graphviz" id="graphviz-c814eca2-77c3-478b-8f43-c8b89f5d19e1"><textarea style="display: none">digraph &quot;call graph&quot; {
goal [label=&quot;let (_x_0 : employee) = st.emp in\llet (_x_1 : obligations) = _x_0.obligations in\llet (_x_2 : int) = _x_0.arrival_time in\llet (_x_3 : int) = st.meeting_time in\llet (_x_4 : bool) = not (_x_2 \&lt;= _x_3) in\llet (_x_5 : int) = _x_2 + (-1) * _x_3 in\lnot\l(_x_1.sing_a_song = not _x_1.do_a_dance\l &amp;&amp; (_x_4 &amp;&amp; not (_x_5 \&lt;= 3)) = (_x_4 &amp;&amp; not (_x_5 \&lt;= 1)))&quot;,shape=box,style=filled,color=&quot;cyan&quot;,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-c814eca2-77c3-478b-8f43-c8b89f5d19e1';
  graphviz.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-proof-top"><div class="imandra-fold panel panel-default" id="fold-e5d6431e-62e9-4d95-9cad-7d6b5fa9e1a7"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>proof attempt</span></div></div><div class="panel-body collapse"><div class="imandra-proof"><div class="imandra-alternatives" id="alt-f5a81ea2-a735-4e07-b601-4980b5f887f1"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>summary</a></li><li class="" data-toggle="tab"><a>full</a></li><li class="" data-toggle="tab"><a>graph</a></li></ul><div class="tab-content"><div class="tab-pane active"><div class="imandra-table" id="table-10e4036c-b6ec-4fe3-a982-7f4de2b1ee06"><table><tr><td>ground_instances:</td><td>0</td></tr><tr><td>definitions:</td><td>0</td></tr><tr><td>inductions:</td><td>0</td></tr><tr><td>search_time:</td><td><pre>0.013s</pre></td></tr><tr><td>details:</td><td><div class="imandra-fold panel panel-default" id="fold-054630c9-d240-4466-b24a-230b7e8c5664"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><div class="imandra-table" id="table-c8f08877-ee50-4576-b8b5-396ed096dddb"><table><tr><td>smt_stats:</td><td><div class="imandra-table" id="table-2283fb61-dbb9-4b1b-ad34-949dc00f6dcc"><table><tr><td>num checks:</td><td>1</td></tr><tr><td>arith tableau max rows:</td><td>1</td></tr><tr><td>arith tableau max columns:</td><td>4</td></tr><tr><td>rlimit count:</td><td>989</td></tr><tr><td>mk clause:</td><td>33</td></tr><tr><td>datatype occurs check:</td><td>1</td></tr><tr><td>mk bool var:</td><td>28</td></tr><tr><td>decisions:</td><td>3</td></tr><tr><td>seq num reductions:</td><td>1</td></tr><tr><td>propagations:</td><td>8</td></tr><tr><td>datatype accessor ax:</td><td>4</td></tr><tr><td>arith num rows:</td><td>1</td></tr><tr><td>datatype constructor ax:</td><td>4</td></tr><tr><td>num allocs:</td><td>166287010</td></tr><tr><td>final checks:</td><td>1</td></tr><tr><td>added eqs:</td><td>23</td></tr><tr><td>del clause:</td><td>8</td></tr><tr><td>time:</td><td>0.006000</td></tr><tr><td>memory:</td><td>20.870000</td></tr><tr><td>max memory:</td><td>21.230000</td></tr></table></div></td></tr></table></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-054630c9-d240-4466-b24a-230b7e8c5664';
  fold.hydrate(target);
});
</script></div></td></tr></table></div></div><div class="tab-pane"><div class="imandra-fold panel panel-default" id="fold-4b67b959-e31d-469e-9fc4-6165ac6ca14e"><div class="panel-heading"><div><i class="fa fa-chevron-down hidden"></i><i class="fa fa-chevron-right"></i><span>Expand</span></div></div><div class="panel-body collapse"><ul><li><pre>start[0.013s]
  let (_x_0 : employee) = ( :var_0: ).emp in
  let (_x_1 : obligations) = _x_0.obligations in
  let (_x_2 : int) = _x_0.arrival_time in
  let (_x_3 : int) = ( :var_0: ).meeting_time in
  let (_x_4 : bool) = not (_x_2 &lt;= _x_3) in
  let (_x_5 : int) = _x_2 - _x_3 in
  _x_1.sing_a_song = not _x_1.do_a_dance
  &amp;&amp; (_x_4 &amp;&amp; _x_5 &gt; 3) = (_x_4 &amp;&amp; _x_5 &gt; 1)</pre></li><li><div><h4>simplify</h4><div class="imandra-table" id="table-5beb85fd-405d-4b78-badc-42fa58b61007"><table><tr><td>into:</td><td><pre>let (_x_0 : employee) = ( :var_0: ).emp in
let (_x_1 : obligations) = _x_0.obligations in
let (_x_2 : int) = _x_0.arrival_time in
let (_x_3 : int) = ( :var_0: ).meeting_time in
let (_x_4 : bool) = not (_x_2 &lt;= _x_3) in
let (_x_5 : int) = _x_2 + (-1) * _x_3 in
_x_1.sing_a_song = not _x_1.do_a_dance
&amp;&amp; (_x_4 &amp;&amp; not (_x_5 &lt;= 3)) = (_x_4 &amp;&amp; not (_x_5 &lt;= 1))</pre></td></tr><tr><td>expansions:</td><td><pre>[]</pre></td></tr><tr><td>rewrite_steps:</td><td><ul></ul></td></tr><tr><td>forward_chaining:</td><td><ul></ul></td></tr></table></div></div></li><li>Sat (Some let st : state =
  {emp =
   {name = &quot;!0!&quot;; arrival_time = (Z.of_nativeint (0n));
    obligations = {sing_a_song = false; do_a_dance = false}};
   meeting_time = (Z.of_nativeint (38n))}
)</li></ul></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-4b67b959-e31d-469e-9fc4-6165ac6ca14e';
  fold.hydrate(target);
});
</script></div></div><div class="tab-pane"><div class="imandra-graphviz" id="graphviz-8c701472-efbd-4b79-8168-274a71086763"><textarea style="display: none">digraph &quot;proof&quot; {
p_31 [label=&quot;Start (let (_x_0 : employee) = ( :var_0: ).emp in\l       let (_x_1 : obligations) = _x_0.obligations in\l       let (_x_2 : int) = _x_0.arrival_time in\l       let (_x_3 : int) = ( :var_0: ).meeting_time in\l       let (_x_4 : bool) = not (_x_2 \&lt;= _x_3) in\l       let (_x_5 : int) = _x_2 - _x_3 in\l       _x_1.sing_a_song = not _x_1.do_a_dance\l       &amp;&amp; (_x_4 &amp;&amp; _x_5 \&gt; 3) = (_x_4 &amp;&amp; _x_5 \&gt; 1) :time 0.013s)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_31 -&gt; p_30 [label=&quot;&quot;];
p_30 [label=&quot;Simplify (let (_x_0 : employee) = ( :var_0: ).emp in\l          let (_x_1 : obligations) = _x_0.obligations in\l          let (_x_2 : int) = _x_0.arrival_time in\l          let (_x_3 : int) = ( :var_0: ).meeting_time in\l          let (_x_4 : bool) = not (_x_2 \&lt;= _x_3) in\l          let (_x_5 : int) = _x_2 + (-1) * _x_3 in\l          _x_1.sing_a_song = not _x_1.do_a_dance\l          &amp;&amp; (_x_4 &amp;&amp; not (_x_5 \&lt;= 3)) = (_x_4 &amp;&amp; not (_x_5 \&lt;= 1))\l          :expansions [] :rw [] :fc [])&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
p_30 -&gt; p_29 [label=&quot;&quot;];
p_29 [label=&quot;Sat (Some let st : state =\l  \{emp =\l   \{name = \&quot;!0!\&quot;; arrival_time = (Z.of_nativeint (0n));\l    obligations = \{sing_a_song = false; do_a_dance = false\}\};\l   meeting_time = (Z.of_nativeint (38n))\}\l)&quot;,shape=box,style=filled,fontname=&quot;courier&quot;,fontsize=14];
}
</textarea><button class="btn btn-primary">Load graph</button><div class="imandra-graphviz-loading display-none">Loading..</div><div class="imandra-graphviz-target"></div><script>
require(['nbextensions/nbimandra/graphviz'], function (graphviz) {
  var target = '#graphviz-8c701472-efbd-4b79-8168-274a71086763';
  graphviz.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-f5a81ea2-a735-4e07-b601-4980b5f887f1';
  alternatives.hydrate(target);
});
</script></div></div></div><script>
require(['nbextensions/nbimandra/fold'], function (fold) {
  var target = '#fold-e5d6431e-62e9-4d95-9cad-7d6b5fa9e1a7';
  fold.hydrate(target);
});
</script></div></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-d8902ac0-7547-4453-91c6-b754fcbbe94f';
  alternatives.hydrate(target);
});
</script></div></div></div>



Let's look at a region decomp of a particular rule to get examples of its distinct behaviours.


```ocaml
let rule5 = Rule5.rule;;
```




    val rule5 : state -> bool = <fun>





```ocaml
Modular_decomp.top "rule5";;

```




    - : Modular_decomp_intf.decomp_ref = <abstr>





<div class="imandra-alternatives" id="alt-6cd7762c-7c27-4125-b176-fc157d0ef8d3"><ul class="nav nav-tabs"><li class="active" data-toggle="tab"><a>Voronoi (3 of 3)</a></li><li class="" data-toggle="tab"><a>Table</a></li></ul><div class="tab-content"><div class="tab-pane active"><div id="decompose-bfea9989-acb5-4c4f-8366-cb5f5e6d76bc" class="decompose"><textarea class="display-none">{
  &quot;regions&quot;: [
    {
      &quot;constraints&quot;: [ &quot;st.meeting_time &gt;= st.emp.arrival_time&quot; ],
      &quot;region&quot;: {
        &quot;constraints&quot;: [ &quot;st.meeting_time &gt;= st.emp.arrival_time&quot; ],
        &quot;invariant&quot;: &quot;F = true&quot;
      },
      &quot;groups&quot;: [],
      &quot;label&quot;: &quot;2&quot;,
      &quot;weight&quot;: 1
    },
    {
      &quot;constraints&quot;: [ &quot;st.emp.arrival_time &gt; st.meeting_time&quot; ],
      &quot;region&quot;: null,
      &quot;groups&quot;: [
        {
          &quot;constraints&quot;: [
            &quot;st.emp.arrival_time &gt; st.meeting_time&quot;,
            &quot;(st.emp.arrival_time - st.meeting_time) &gt; 1&quot;
          ],
          &quot;region&quot;: {
            &quot;constraints&quot;: [
              &quot;st.emp.arrival_time &gt; st.meeting_time&quot;,
              &quot;(st.emp.arrival_time - st.meeting_time) &gt; 1&quot;
            ],
            &quot;invariant&quot;: &quot;F = st.emp.obligations.do_a_dance&quot;
          },
          &quot;groups&quot;: [],
          &quot;label&quot;: &quot;1.2&quot;,
          &quot;weight&quot;: 1
        },
        {
          &quot;constraints&quot;: [
            &quot;st.emp.arrival_time &gt; st.meeting_time&quot;,
            &quot;(st.emp.arrival_time - st.meeting_time) &lt;= 1&quot;
          ],
          &quot;region&quot;: {
            &quot;constraints&quot;: [
              &quot;st.emp.arrival_time &gt; st.meeting_time&quot;,
              &quot;(st.emp.arrival_time - st.meeting_time) &lt;= 1&quot;
            ],
            &quot;invariant&quot;: &quot;F = true&quot;
          },
          &quot;groups&quot;: [],
          &quot;label&quot;: &quot;1.1&quot;,
          &quot;weight&quot;: 1
        }
      ],
      &quot;label&quot;: &quot;&quot;,
      &quot;weight&quot;: 2
    }
  ]
}</textarea><div class="decompose-foamtree"></div><div class="decompose-details"><div class="decompose-details-header">Regions details</div><div class="decompose-details-no-selection"><p>No group selected.</p><ul><li>Concrete regions are numbered</li><li>Unnumbered regions are groups whose children share a particular constraint</li><li>Click on a region to view its details</li><li>Double click on a region to zoom in on it</li><li>Shift+double click to zoom out</li><li>Hit escape to reset back to the top</li></ul></div><div class="decompose-details-selection hidden"><div><span class="decompose-details-label">Direct sub-regions: </span><span class="decompose-details-direct-sub-regions-text">-</span></div><div><span class="decompose-details-label">Contained regions: </span><span class="decompose-details-contained-regions-text">-</span></div><div class="decompose-details-section-header">Constraints</div><div class="decompose-details-constraints"><pre class="decompose-details-constraint">&lt;constraint&gt;</pre></div><div class="decompose-details-invariant"><div class="decompose-details-section-header">Invariant</div><pre class="decompose-details-invariant-text">&lt;invariant&gt;</pre></div></div></div><script>
(function () {
  require(['nbextensions/nbimandra/regions'], function (regions) {
    var target = '#decompose-bfea9989-acb5-4c4f-8366-cb5f5e6d76bc';
    regions.hydrate(target);
  });
})();
</script></div></div><div class="tab-pane"><div><div>decomp of (rule5 st<div class="imandra-table" id="table-2f0375ea-0b3c-4dad-a52e-18dbb100874d"><table><thead><tr><th>Reg_id</th><th>Constraints</th><th>Invariant</th></tr></thead><tr><td>2</td><td><ul><li><pre>st.emp.arrival_time &lt;= st.meeting_time</pre></li></ul></td><td><pre>true</pre></td></tr><tr><td>1</td><td><ul><li><pre>not (st.emp.arrival_time &lt;= st.meeting_time)</pre></li><li><pre>not ((st.emp.arrival_time - st.meeting_time) &gt; 1)</pre></li></ul></td><td><pre>true</pre></td></tr><tr><td>0</td><td><ul><li><pre>not (st.emp.arrival_time &lt;= st.meeting_time)</pre></li><li><pre>(st.emp.arrival_time - st.meeting_time) &gt; 1</pre></li></ul></td><td><pre>st.emp.obligations.do_a_dance</pre></td></tr></table></div></div></div></div></div><script>
require(['nbextensions/nbimandra/alternatives'], function (alternatives) {
  var target = '#alt-6cd7762c-7c27-4125-b176-fc157d0ef8d3';
  alternatives.hydrate(target);
});
</script></div>




```ocaml

```
