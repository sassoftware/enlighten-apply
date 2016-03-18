******************************************************************************;
* Copyright (c) 2015 by SAS Institute Inc., Cary, NC 27513 USA               *;
*                                                                            *;
* Licensed under the Apache License, Version 2.0 (the "License")             *;
* you may not use this file except in compliance with the License.           *;
* You may obtain a copy of the License at                                    *;
*                                                                            *;
*   http://www.apache.org/licenses/LICENSE-2.0                               *;
*                                                                            *;
* Unless required by applicable law or agreed to in writing, software        *;
* distributed under the License is distributed on an "AS IS" BASIS,          *;
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   *;
* See the License for the specific language governing permissions and        *;
* limitations under the License.                                             *;
******************************************************************************;

******************************************************************************;
* script used to cluster image patches or a compressed representation of     *;
* image patches created by a stacked autoencoder                             *;
*   to be used:                                                              *;
*   - directly after threaded_tile.py or threaded_tile_r.py                  *;
*    OR                                                                      *;
*   - after make_dictionary.sas                                              *;
*                                                                            *;
* square images are imported from patches.csv                                *;
* random selection of images are displayed to check import                   *;
* OR a compressed representation from hidden_output.sas7bdat is used         *;
* (if hidden_output.sas7bdat is used, inputs are not displayed)              *;
* input images are clustered using the aligned box criterion (ABC) to        *;
*   automatically estimate the best number of clusters                       *;
* cluster labels are saved in OUT_DIR as cluster_labels.sas7bdat             *;
* clustering results are overlayed onto original images to visualize         *;
*   clusters                                                                 *;
*                                                                            *;
* CORE_COUNT - number of physical cores to use, int                          *;
* OUT_DIR - out (-o) directory created by Python script as unquoted string,  *;
*           must contain the generated csv files and is the directory in     *;
*           which to write the patches.sas7bdat file (if it does not exist), *;
*           and the cluster labels, cluster_labels.sas7bdat                  *;
* DIM - side length of square patches in IN_SET, probably (-d) value from    *;
*       Python script, int                                                   *;
* MAX_CLUSTERS - maximum number of clusters to test with ABC,                *;
*                int < 50 suggested                                          *;
* PLOT_RESULTS - plot the clustering results overlayed onto the original     *;
*                images, not suitable for many input images or extremely     *;
*                large input images, boolean int, 1 = true                   *;
******************************************************************************;

* TODO: user sets constants;
%let CORE_COUNT = 2;
%let OUT_DIR = ;
%let DIM = 25;
%let MAX_CLUSTERS = 20;
%let PLOT_RESULTS = 1;

* system options;
options threads;
ods html close;
ods listing;

options mprint;

*** plot_clusters ************************************************************;
* conditionally defines a graph template for each image;
* aligns patches in each cluster with the original image;
* plots results;
* label_var - name of variable containing cluster label;
%macro plot_clusters(label_var=_CLUSTER_ID_);

  * define a list of SAS/GRAPH colors;
  %let color_list = cream blue cyan gold green lilac lime magenta maroon
                    olive orange pink purple red rose salmon violet white
                    yellow;

  * place original image names into macro variable array;
  proc sql noprint;
    create table image_names as
    select distinct orig_name
    from l.originals;
  quit;
  data _null_;
    set image_names end=eof;
    call symput('image'||strip(put(_n_, best.)), strip(orig_name));
    if eof then call symput('n_images', strip(put(_n_, best.)));
  run;

  * loop for each original image;
  %do j=1 %to &n_images;

    proc sql;

      * determine max x value of image;
      select max(x) into: max_x
      from l.originals
      where orig_name = "&&image&j";

      * determine max y value of image;
      select max(y) into: max_y
      from l.originals
      where orig_name = "&&image&j";

      * determine number of clusters in image;
      select max(&label_var.) into: n_clus
      from l.cluster_labels
      where orig_name = "&&image&j";

    quit;

    * conditionally define gtl template based on image attributes;
    ods path show;
    ods path(prepend) work.templat(update);
    proc template;
      define statgraph contour;
        dynamic _title;
        begingraph;
          entrytitle _title;
          * assign consistent color to cluster labels across all images;
          discreteattrmap name="cluster_colors";
            %do i=1 %to &n_clus;
              %let color_index = %eval(%sysfunc(mod(%eval(&i-1), &n_clus))+1);
              %let _color = %scan(&color_list, &color_index, ' ');
              value "&i" / markerattrs=(color=&_color symbol=circlefilled);
            %end;
          enddiscreteattrmap;
          discreteattrvar attrvar=groupmarkers var=&label_var.
            attrmap="cluster_colors";
          * layout boundaries and axis attributes;
          layout overlay / aspectratio=1
            xaxisopts=(offsetmin=0 offsetmax=0 linearopts=(viewmin=0
              viewmax=%eval(&max_x.-1) tickvaluelist=(0 %eval(&max_x./2)
              %eval(&max_x.-1))))
            yaxisopts=(offsetmin=0 offsetmax=0 linearopts=(viewmin=0
              viewmax=%eval(&max_y.-1) tickvaluelist=(0 %eval(&max_y./2)
              %eval(&max_y.-1))));
            * contour plot of original image is bottom layer of layout;
            contourplotparm x=x y=y z=z /
              contourtype=gradient nlevels=255
              colormodel=twocolorramp;
            * a dense scatter plot of cluster patches is overlayed;
            * onto contour plot of original image;
            scatterplot x=scatter_x y=scatter_y /
              group=groupmarkers name="clus"
              /* transparency needs to be adjusted for different image sizes */
              markerattrs=(symbol=CircleFilled size=1px transparency=0.5);
          endlayout;
        endgraph;
      end;
    run;

    * loop for each cluster;
    %do k=1 %to &n_clus;

      * create x,y coordinates of clusters;
      * accounting for size and rotation;
      * sort into correct order to align with original image;
      data tiles_clus_expanded;
        set l.cluster_labels (where=(&label_var.=&k. and orig_name="&&image&j"));
        retain &label_var.;
        _x = x;
        _y = %eval(&max_y.-1) - y;
        do i=0 to size-1;
          do j=0 to size-1;
            y = _y - i;
            x = _x + j;
            if angle ne 0 then do;
              pi = constant("pi");
              _angle = (angle/180)*pi;
              x = floor(x*cos(_angle) - y*sin(_angle));
              y = floor(x*sin(_angle) + y*cos(_angle));
            end;
          output;
        end;
      end;
      keep x y orig_name &label_var.;
    run;
    proc sort nodupkey; by orig_name x y; run;

    * if no clusters for this label, continue;
    %let _rc = %sysfunc(open(tiles_clus_expanded));
    %let _nlobs = %sysfunc(attrn(&_rc, NLOBS));
    %let _rc = %sysfunc(close(&_rc));
    %if ^&_nlobs %then %goto continue;

    * align clusters with original image;
    data cluster_merge;
      merge l.originals (where=(orig_name="&&image&j"))
            tiles_clus_expanded;
      by orig_name x y;
      * gtl requires a different name for different layout layer attributes;
      if &label_var. ne . then do;
        scatter_x = x;
        scatter_y = y;
      end;
    run;

    * render image;
    proc sgrender data=cluster_merge template=contour;
      dynamic _title="&&image&j cluster &k";
    run;

    %continue:

    %end; /* end cluster loop */

  %end; /* end image loop */

%mend;

*** main macro ***************************************************************;
* drive execution conditionally;
* based on the presence of hidden_output.sas7bdat;
%macro main;

  * start timer;
  %let start = %sysfunc(datetime());

  *** import necessary data;

  * libref to OUT_DIR;
  libname l "&OUT_DIR.";

  * working dir to OUT_DIR;
  x "cd &OUT_DIR";

  * if l.hidden_output does not exist;
  * import raw patches;
  * and check visually;
  %let ds = l.patches;
  %if ^%sysfunc(exist(l.hidden_output)) %then %do;
    %if ^%sysfunc(exist(l.patches)) %then %do;

      proc import
        datafile="&OUT_DIR./patches.csv"
        out=&ds
        dbms=csv
        replace;
      run;

    %end;
  %end;
  %else %let ds = l.hidden_output;

  * import original images;
  proc import
    datafile="&OUT_DIR./originals.csv"
    out=l.originals
    dbms=csv
    replace;
  run;
  proc sort
    data=l.originals
    sortsize=MAX;
    by orig_name x y;
  run;

  *** view random patches;
  * if clustering l.patches;

  %if "&ds" = "l.patches" %then %do;

    * define gtl template;
    ods path show;
    ods path(prepend) work.templat(update);
    proc template;
      define statgraph contour;
        dynamic _title;
        begingraph;
          entrytitle _title;
          layout overlayequated / equatetype=square
            commonaxisopts=(viewmin=0 viewmax=%eval(&DIM.-1)
                            tickvaluelist=(0 %eval(&DIM./2) &DIM.-1))
            xaxisopts=(offsetmin=0 offsetmax=0)
            yaxisopts=(offsetmin=0 offsetmax=0);
            contourplotparm x=x y=y z=z /
              contourtype=gradient nlevels=255
              colormodel=twocolorramp;
           endlayout;
       endgraph;
      end;
    run;

    * create random sample of patches;
    proc surveyselect
      data=l.patches
      out=samp
      method=srs
      n=20; 
    run;

    * convert random patches to contours;
    data _xyz;
      set samp;	
      array pixels pixel_:;
      pic_ID = _n_;
      do j=1 to %eval(&DIM*&DIM);
        x = (j-&DIM*floor((j-1)/&DIM))-1;
        y = (%eval(&DIM+1)-ceil(j/&DIM))-1;
        z = 255-pixels[j];
        output;
        keep pic_ID x y z;
      end;
    run;

    * render selected patches;
    proc sgrender data=_xyz template=contour;
      dynamic _title="Input Image";
      by pic_ID;
    run;

  %end;

  *** cluster inputs;

  * cluster patches using ABC to determine best number of clusters;
  proc hpclus
    data=&ds
    maxclusters=&MAX_CLUSTERS
    noc=abc(b=10 minclusters=2 align=PCA criterion=all)
    maxiter=1000
    seed=44444;
    %if "&ds" = "l.patches" %then %do;
      input pixel_: / level=interval;
    %end;
    %else %do;
      input h: / level=interval;
    %end;
    id x y orig_name size angle;
    performance threads=&CORE_COUNT;
    score out=l.cluster_labels;
	code file="&OUT_DIR./cluster_score.sas";
    ods output
      abcstats=_abcstats
      abcresults=_abcresults;
  run;

  * ABC plot;
  data _null_;
    set _abcresults;
    call symput('best_k', strip(put(K, best.)));
  run;
  title "ABC Plot for Image Patches";
  proc sgplot data=_abcstats;;
    xaxis type=discrete;
    series x=K y=Gap;
    refline &best_k. / axis=x label="Selected Number of Clusters";
  run;
  title;

  *** conditionally plot results;
  %if &PLOT_RESULTS %then %do;
    %plot_clusters;
  %end;

  * end timer;
  %put NOTE: Total elapsed time: %sysfunc(putn(%sysevalf(%sysfunc(datetime())-&start), 10.2)) seconds.;

%mend;
%main;
