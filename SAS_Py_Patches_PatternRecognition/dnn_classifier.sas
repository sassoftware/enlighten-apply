******************************************************************************;
* Copyright (c) 2015 by SAS Institute Inc., Cary, NC 27513 USA               *;
*                                                                            *;
* Licensed under the Apache License, Version 2.0 (the "License");            *;
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
* script used to create classify image patches using a deep neural network - *;
*   to be used after threaded_tile.py or threaded_tile_r.py                  *;
*                                                                            *;
* square images are imported from patches.csv                                *;
* random selection of patches are displayed to check import                  *;
* 3 layer neural network is trained on all imported images                   *;
* input patches are scored with predicted values or labels                   *;
*   and saved to OUT_DIR                                                     *;
* score code with network weights is saved to OUT_DIR                        *;
* conditionally plots classified patches over original images                *;
*                                                                            *;
* CORE_COUNT - number of physical cores to use, int                          *;
* OUT_DIR - out (-o) directory created by Python script as unquoted string,  *;
*           must contain the generated csv files and is the directory in     *;
*           which to write the patches.sas7bdat set, the label file,         *;
*           DNN_labels.sas7bdat, and score code file, DNN_score.sas          *;
* LABEL_FILE - csv file name as unquoted string, containing original image   *;
*              names and labels - must contain 2 columns with headers:       *;
*              orig_name, label                                              *;
* DIM - side length of square patches in IN_SET, probably (-d) value from    *;
*       Python script, int                                                   *;
* HIDDEN_UNIT_LIST - number units in each layer, space separated list of     *;
*                    3 integers                                              *;
* VALID_PROPORTION - proportion of patches to assign to a validation set for *;
*                    training neural network, float (0,1)                    *;
* STAT - error measure used to assess neural network                         *;
*        unquoted string string: ASE or MISC                                 *;
******************************************************************************;

* TODO: user sets constants;
%let CORE_COUNT = 2;
%let OUT_DIR = ;
%let LABEL_FILE = ;
%let DIM = 25;
%let HIDDEN_UNIT_LIST = 100 50 10;
%let VALID_PROPORTION = 0.3;
%let STAT = MISC;

* system options;
options threads;
ods html;
ods listing;

*** import csv ***************************************************************;

* libref to OUT_DIR;
libname l "&OUT_DIR.";

* import csv;
proc import
  datafile="&OUT_DIR./patches.csv"
  out=l.patches
  dbms=csv
  replace;
run;
proc sort; by orig_name; run;

*** view random patches *******************************************************;

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
                        tickvaluelist=(0 %eval(&DIM./2) &DIM.))
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

*** add labels ***************************************************************;

* import csv;
proc import
  datafile="&LABEL_FILE"
  out=labels
  dbms=csv
  replace;
run;
proc sort; by orig_name; run;

* join labels to patches;
data l.patches;
  merge l.patches(in=_x) labels;
  by orig_name;
  if _x;
run;

*** create validation set ****************************************************;

data train valid;
  set l.patches;
  if ranuni(12345) < 1-&VALID_PROPORTION then output train;
  else output valid;
run;

*** train 3-layer DNN ********************************************************;

* create necessary dmdb catalog;
proc dmdb
  data=train
  out=_
  dmdbcat=work.patches_cat;
  var pixel_:;
  class label;
  target label;
run;

* train a deep neural net classifier with 3 layers;
proc neural

  data=train
  validdata=valid
  dmdbcat=work.patches_cat
  random=44444;
  performance compile details cpucount=&CORE_COUNT threads=yes;

  nloptions noprint; /* noprint=do not show weight values */
  netoptions decay=0.25; /* decay=L2 penalty */

  archi MLP hidden=3; /* 5-layer network architecture */
  hidden %scan(&HIDDEN_UNIT_LIST, 1, ' ') / id=h1;
  hidden %scan(&HIDDEN_UNIT_LIST, 2, ' ') / id=h2;
  hidden %scan(&HIDDEN_UNIT_LIST, 3, ' ') / id=h3;
  input pixel_0-pixel_%eval(&DIM*&DIM-1) / std=no id=i level=int;
  target label / std=no id=t level=nom;

  /* initialize network */
  /* infan reduces chances of neurons being saturated by random init */
  initial infan=0.1;

  /* pretrain layers seperately */

  /* layer 1 */
  freeze h1->h2;
  freeze h2->h3;
  train maxtime=3600 maxiter=100;

  /* layer 2 */
  freeze i->h1;
  thaw h1->h2;
  train maxtime=3600 maxiter=1000;

  /* layer 3 */
  freeze h1->h2;
  thaw h2->h3;
  train maxtime=3600 maxiter=1000;

  /* retrain all layers together */

  thaw i->h1;
  thaw h1->h2;
  thaw h2->h3;
  train
    tech=congra
    maxtime=7200
    maxiter=2000
    outest=weights_all
    outfit=_fit
    estiter=1;

  save network=work._net.architecture;

run;

*** model selection **********************************************************;

* find best iteration;
proc sort
  data=_fit(where=(_NAME_='OVERALL'));
  by _V&STAT._;
run;
data _null_;
  set _fit(obs=1);
  call symput('_best_iter', _ITER_);
run;

* plot training error;
proc sort
  data=_fit;
  by _ITER_;
run;
proc sgplot
  data=_fit (where=(_NAME_='OVERALL'));
  series x=_ITER_ y=_&STAT._;
  series x=_ITER_ y=_V&STAT._;
  refline &_best_iter. / axis=x label="Best Validation Error";
  xaxis label='Iteration';
  title 'Iteration Plot';
run;
title;

* score l.patches and generate score code;
proc neural

  data=l.patches
  dmdbcat=work.patches_cat
  network=work._net.architecture
  random=44444;

  * read best weights;
  nloptions noprint;
  initial inest=weights_all(where=(_ITER_=&_best_iter));
  train tech=none;

  * score l.patches;
  score
    data=l.patches
    out=l.DNN_labels (keep=I_label orig_name x y size angle)
    role=test;

  * save score code;
  code file="&OUT_DIR/DNN_score.sas";

quit;

*** conditionally plot classification results ********************************;

*** plot_labels ************************************************************;
* conditionally defines a graph template for each image;
* aligns patches in each class with the original image;
* plots results;
* label_var - name of variable containing class label;
%macro plot_labels(label_var=I_label);

  * define a list of SAS/GRAPH colors;
  %let color_list = red blue cream cyan gold green lilac lime magenta maroon
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

      * determine number of classes in image;
      select max(&label_var.) into: n_label
      from l.dnn_labels
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
          * assign consistent color to class labels across all images;
          discreteattrmap name="class_colors";
            %do i=1 %to &n_label;
              %let color_index = %eval(%sysfunc(mod(%eval(&i-1), &n_label))+1);
              %let _color = %scan(&color_list, &color_index, ' ');
              value "&i" / markerattrs=(color=&_color symbol=circlefilled);
            %end;
          enddiscreteattrmap;
          discreteattrvar attrvar=groupmarkers var=&label_var.
            attrmap="class_colors";
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
            * a dense scatter plot of class patches is overlayed;
            * onto contour plot of original image;
            scatterplot x=scatter_x y=scatter_y /
              group=groupmarkers name="class"
              /* transparency needs to be adjusted for different image sizes */
              markerattrs=(symbol=CircleFilled size=1px transparency=0.35);
          endlayout;
        endgraph;
      end;
    run;

    * loop for each class;
    %do k=1 %to &n_label;

      * create x,y coordinates of class;
      * accounting for size and rotation;
      * sort into correct order to align with original image;
      data tiles_label_expanded;
        set l.dnn_labels (where=(&label_var.="&k." and orig_name="&&image&j"));
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

    * if no class for this label, continue;
    %let _rc = %sysfunc(open(tiles_label_expanded));
    %let _nlobs = %sysfunc(attrn(&_rc, NLOBS));
    %let _rc = %sysfunc(close(&_rc));
    %if ^&_nlobs %then %goto continue;

    * align labeled patches with original image;
    data label_merge;
      merge l.originals (where=(orig_name="&&image&j"))
            tiles_label_expanded;
      by orig_name x y;
      * gtl requires a different name for different layout layer attributes;
      if &label_var. ne . then do;
        scatter_x = x;
        scatter_y = y;
      end;
    run;

    * render image;
    proc sgrender data=label_merge template=contour;
      dynamic _title="&&image&j label &k";
    run;

    %continue:

    %end; /* end class loop */

  %end; /* end image loop */

%mend;

*** plot *********************************************************************;
* simple utility macro to load originals.csv and conditionally execute; 
* ploting if a classification task was performed;
%macro plot(_stat=&STAT);

  %if "&_stat" = "MISC" %then %do;

    * import original images;
    proc import
      datafile="&OUT_DIR.\originals.csv"
      out=l.originals
      dbms=csv
      replace;
    run;
    proc sort
      data=l.originals
      sortsize=MAX;
      by orig_name x y;
    run;

	%plot_labels;

  %end;

%mend; 
%plot;
