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
%let CORE_COUNT = 12;
%let OUT_DIR = ;
%let LABEL_FILE = ;
%let DIM = 25;
%let HIDDEN_UNIT_LIST = 50 25 10;
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
  initial infan=0.25;

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
    out=l.DNN_labels (keep=P_: orig_name x y)
    role=test;

  * save score code;
  code file="&OUT_DIR/DNN_score.sas";

quit;
