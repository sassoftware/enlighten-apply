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
* script used to create a dictionary of representative images                *;
*   using a stacked autoencoder - to be used after threaded_tile.py or       *;
*   threaded_tile_r.py                                                       *;
*                                                                            *;
* square images are imported from patches.csv                                *;
* random selection of images are displayed to check import                   *;
* 5 layer stacked autoencoder network is trained on all imported images      *;
* weights from top level of trained network create a dictionary of           *;
*    representative images                                                   *;
* dictionary is saved to OUT_DIR as dictionary.sas7bdat                      *;
* hidden_output.sas7bdat is written to OUT_DIR                               *;
* hidden_output.sas7bdat can be used as input to make_clusters.sas           *;
*                                                                            *;
* CORE_COUNT - number of physical cores to use, int                          *;
* OUT_DIR - out (-o) directory created by Python script as unquoted string,  *;
*           must contain the generated csv files and is the directory in     *;
*           which to write the patches.sas7bdat and dictionary file,         *;
*           dictionary.sas7bdat                                              *;
* DIM - side length of square patches in IN_SET, probably (-d) value from    *;
*       Python script, int                                                   *;
* HIDDEN_UNIT_LIST - number units in each layer, space separated list of     *;
*                    5 integers                                              *;
******************************************************************************;

* TODO: user sets constants;
%let CORE_COUNT = 2;
%let OUT_DIR = ;
%let DIM = 25;
%let HIDDEN_UNIT_LIST = 50 25 2 25 50;

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
        commonaxisopts=(viewmin=0 viewmax=%eval(&dim.-1)
                        tickvaluelist=(0 %eval(&dim./2) &dim.))
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

*** train autoencoder network ************************************************;

* create necessary dmdb catalog;
proc dmdb
  data=l.patches
  out=_
  dmdbcat=work.patches_cat;
  var pixel_:;
  target pixel_:;
run;

* train a simple stacked autoencoder with 5 layers;
proc neural

  data=l.patches
  dmdbcat=work.patches_cat
  random=44444;
  performance compile details cpucount=&CORE_COUNT threads=yes;

  nloptions noprint; /* noprint=do not show weight values */
  netoptions decay=0.1; /* decay=L2 penalty */

  archi MLP hidden=5; /* 5-layer network architecture */
  hidden %scan(&HIDDEN_UNIT_LIST, 1, ' ') / id=h1;
  hidden %scan(&HIDDEN_UNIT_LIST, 2, ' ') / id=h2;
  hidden %scan(&HIDDEN_UNIT_LIST, 3, ' ') / id=h3 act=linear;
  hidden %scan(&HIDDEN_UNIT_LIST, 4, ' ') / id=h4;
  hidden %scan(&HIDDEN_UNIT_LIST, 5, ' ') / id=h5;
  input pixel_0-pixel_%eval(&DIM*&DIM-1) / std=no id=i level=int;
  target pixel_0-pixel_%eval(&DIM*&DIM-1) / std=no id=t level=int;

  /* initialize network */
  /* infan reduces chances of neurons being saturated by random init */
  initial infan=0.1;

  /* pretrain layers seperately */

  /* layer 1 */
  freeze h1->h2;
  freeze h2->h3;
  freeze h3->h4;
  freeze h4->h5;
  train maxtime=10000 maxiter=5000;

  /* layer 2 */
  freeze i->h1;
  thaw h1->h2;
  train maxtime=10000 maxiter=5000;

  /* layer 3 */
  freeze h1->h2;
  thaw h2->h3;
  train maxtime=10000 maxiter=5000;

  /* layer 4 */
  freeze h2->h3;
  thaw h3->h4;
  train maxtime=10000 maxiter=5000;

  /* layer 5 */
  freeze h3->h4;
  thaw h4->h5;
  train maxtime=10000 maxiter=5000;

  /* retrain all layers together */

  thaw i->h1;
  thaw h1->h2;
  thaw h2->h3;
  thaw h3->h4;
  train
    tech=congra
    maxtime=10000
    maxiter=5000
    outest=weights_all
    outfit=_fit
    estiter=1;

  code file="%sysfunc(pathname(WORK))/autoencoder.sas";

run;

* plot training error;
proc sgplot
  data=_fit (where=(_NAME_='OVERALL'));
  series x=_ITER_ y=_RASE_;
  xaxis label='Iteration';
  title 'Iteration Plot';
run;
title;

*** save and visualize dictionary ********************************************;

* extract filters from network weights;
data _h5_weights;
  set weights_all(where=(_TYPE_='PARMS' and _NAME_='_LAST_')
    keep=_TYPE_ _NAME_ h5:);
    drop _TYPE_ _NAME_;
run;
proc transpose out=filters_t(drop=_LABEL_); run;
proc sort
  sortseq=linguistic(numeric_collation=on);
  by _NAME_;
run;
proc transpose out=filters_tt(drop=_NAME_); run;

* arrange filters into dictionary and save to OUT_DIR;
data l.dictionary;
  set filters_tt;
  array h h5:;
  array pixels pixel_0-pixel_%eval(&DIM.*&DIM.-1);
  do i=1 to %scan(&HIDDEN_UNIT_LIST, 5, ' ');
    do j=1 to %eval(&DIM.*&DIM.);
      pixels[j] = h[(i-1)*%eval(&DIM.*&DIM.) + j];
    end;
    filter_id = i;
    output;
  end;
  drop i j h5:;
run;

* convert dictionary to contours;
data _xyz;
  set l.dictionary;
  array pixels pixel_0-pixel_%eval(&DIM.*&DIM.);
  do i=1 to %eval(&DIM.*&DIM.);
    x = (i-&DIM.*floor((i-1)/&DIM.))-1;
    y = ((&DIM.+1)-ceil(i/&DIM.))-1;
    z = pixels[i];
    output;
    keep filter_ID x y z;
  end;
run;

* visualize dictionary;
proc sgrender data= _xyz template=contour;
dynamic _title='Dictionary Image';
  by filter_ID;
run;

*** create hidden layer output ***********************************************;
* can be clustered instead of raw pacthes using make_clusters.sas;
data l.hidden_output;
  set l.patches;
  %include "%sysfunc(pathname(WORK))/autoencoder.sas" / nosource;
  drop h1: h2: h4: h5: pixel_: _WARN_ P_:;
run;
