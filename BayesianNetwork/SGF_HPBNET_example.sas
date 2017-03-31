
proc hpbnet data=sampsio.hmeq nbin=5 structure=Naive TAN PC MB bestmodel  
missingint=IMPUTE missingnom=LEVEL;
target Bad;
input Reason Job Delinq Derog Ninq/level=NOM;
input Loan Mortdue Value Yoj Clage Clno Debtinc/level=INT;
output pred=pred network=net parameter=parameter varinfo=varinfo varlevel=varlevel varorder=varorder varselect=varselect validinfo=vi;
code file="U:\SGF_hpbnet_scorecode.sas";
run;

%macro createBNCdiagram(target=Bad, outnetwork=net);

   data outstruct;
        set &outnetwork;
        if strip(upcase(_TYPE_)) eq 'STRUCTURE' then output;
        keep _nodeid_   _childnode_  _parentnode_;
   run;

   data networklink;
       set outstruct;
        linkid = _N_;
        label linkid ="Link ID";
   run;

   proc sql;
      create table work._node1 as
         select distinct  _CHILDNODE_ as  node
         from networklink;
      create table work._node2  as
         select distinct _PARENTNODE_  as node
         from networklink;
   quit;

   proc sql;
      create table work._node as
         select node
         from work._node1
         UNION
         select node
         from work._node2;
   quit;

   data bnc_networknode;
       length NodeType $32.;
       set work._node;
       if strip(upcase(node)) eq strip(upcase("&target")) then do;
         NodeType = "TARGET";
         NodeColor=2;
       end;
       else  do;
         NodeType = "INPUT";
         NodeColor = 1;
       end;
       label NodeType ="Node Type" ;
       label NodeColor ="Node Color" ;

   run;

   data parents(rename=(_parentnode_ = _node_)) children(rename=(_childnode_ = _node_)) links;
       length _parentnode_ _childnode_ $ 32;
       set networklink;
       keep _parentnode_ _childnode_ ;
   run;

   *get list of all unique nodes;
   data nodes;
       set parents children;
   run;

   proc sort data=nodes;
       by _node_;
   run;

   data nodes;
       set nodes;
       by _node_;
       if first._node_;
      _Parentnode_ = _node_;
      _childnode_ = "";
   run;

   /*merge node color and type */
   data nodes;
       merge nodes bnc_networknode (rename=(node=_node_ nodeColor=_nodeColor_ nodeType=_nodeType_));
       by _node_;
   run;

   /*sort color values to ensure a consistent color mapping across networks */
   /*note that the color mapping is HTML style dependent though */
   proc sort data=nodes;
       by  _nodeType_;
   run;

   *combine nodes and links;
   * need outsummaryall for model report;
   data bnc_networksummary(drop=_shape_ _nodecolor_ _nodepriority_ _shape_ _nodeID_ _nodetype_ _linkdirection_) bnc_networksummaryall;
       length _parentnode_ _childnode_ $ 32;
       set nodes links;
       drop _node_;
       if _childnode_ EQ "" then
           do;
               _nodeID_ = _parentnode_;
               _nodepriority_ = 1;
               _shape_= "OVAL";
           end;
       else do;
         _linkdirection_ = "TO";
         output bnc_networksummary;
       end;
       output bnc_networksummaryall;
       label _linkdirection_="Link Direction";
   run;

    proc datasets lib=work nolist nowarn;
         delete _node _node1 _node2 nodes links parents children;
   run;

   quit;

   proc template;
      define statgraph bpath;
         begingraph / DesignHeight=720 DesignWidth=720;
            entrytitle "Bayesian Network Diagram";
            layout region;
              pathdiagram fromid=_parentnode_ toid=_childnode_ /
              arrangement=GRIP
              nodeid=_nodeid_
              nodelabel=_nodeID_
              nodeshape=_shape_
              nodepriority=_nodepriority_
              linkdirection=_linkdirection_
              nodeColorGroup=_NodeColor_
                        textSizeMin = 10
               ;
            endlayout;
         endgraph;
      end;
   run;

   ods graphics;
   proc sgrender data=bnc_networksummaryall template=bpath;
   run;

%mend;

%createBNCdiagram;
