******************************************************************************;
* Copyright (c) 2016 by SAS Institute Inc., Cary, NC 27513 USA               *;
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
* example data is the AT&T face database (formerly ORL face database)        *;
* by AT&T Laboratories Cambridge                                             *;
* http://www.cl.cam.ac.uk/research/dtg/attarchive/facedatabase.html          *;
******************************************************************************;

******************************************************************************;
* an educational facial recognition example using eigenfaces:                *;
* - the AT&T face database is split into train and test sets                 *;
* - one face from each person is assigned to the train set and to the        *;
*   test set                                                                 *;
* - the train set is normalized and projected onto NUM_EIGENFACES            *;
*   eigenvectors to create eigenfaces                                        *;
* - linear regression is then used to represented the train set as a linear  *;
*   combination of the eigenfaces                                            *;
* - the test set is normalized and projected into NUM_EIGENFACES             *;
*   eigenvectors to create eigenfaces                                        *;
* - linear regression is then used to represented the test set as a linear   *;
*   combination of the eigenfaces                                            *;
* - to test the performance of the model the distance is calculated between  *;
*   each corresponding train and test face using in reduced space of the     *;
*   eigenfaces                                                               *;
*                                                                            *;
* instructions:                                                              *;
* - user set GIT_REPO_DIR to downloaded or cloned SAS_UE_SGF2016_faces       *;
*   directory containg faces.sas7bdat                                        *;
******************************************************************************;

*** TODO: user set global constants ******************************************;

%let GIT_REPO_DIR = C:\workspace\enlighten-apply\SAS_UE_SGF2016_faces;

*** system options;

%let NUM_EIGENFACES = 6;
libname faces "&git_repo_dir";

*** veiw_faces ***************************************************************;
* a macro used to veiw face images;
* dim - the square side length of the input image;
* ds - SAS data set containing square images as row vectors;
* n - number of images to render;
* prefix - prefix name for variables containing pixel intensities;
* title - title for all rendered images;

%macro view_faces(dim=, ds=, n=, prefix=, title=);

  ods listing;
  ods listing gpath="&git_repo_dir";

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

  * create random sample of images;
  proc surveyselect
    data=&ds
    out=_samp
    method=srs
    n=&n
    noprint;
  run;

  * convert sample images to contours;
  data _xyz;
    set _samp;
    array pixels &prefix.:;
    pic_ID = _n_;
    do j=1 to %eval(&dim*&dim);
      x = (j-&dim*floor((j-1)/&dim))-1;
      y = (%eval(&dim+1)-ceil(j/&dim))-1;
      z = 255-pixels[j];
      output;
      keep pic_ID x y z;
    end;
  run;

  * render sample images;
  proc sgrender data=_xyz template=contour;
    dynamic _title="&title";
    by pic_ID;
  run;

%mend;

*** show a few input faces ***************************************************;

%view_faces(
  dim=64,
  ds=faces.faces,
  n=3,
  prefix=feature,
  title=Input Face Image
);

*** data preparation *********************************************************;

* create a train and test set;
* there are 10 images of each face in the example data;
* take the first 9 images as the train data;
* and the last image as the test data;
data allfaces;
  length id 8;
  set faces.faces;
  id = ceil(_n_/10);
run;
data trainfaces testfaces;
  set allfaces;
  by id;
  if first.id then output trainfaces;
  if last.id then output testfaces;
run;

* normalize each row vector (e.g. face vector);
* by subtracting the average of all rows;
proc means data=trainfaces noprint nway;
  var feature1-feature4096;
  output out=averageface(drop=_TYPE_ _FREQ_) mean=; /* average values */
run;
data averageface;
  length id 8;
  set averageface;
  id = 0;
run;
data normalizedtrain;
  set averageface trainfaces;
  array aveface avefeature1-avefeature4096;
  array normalface normalface1-normalface4096;
  array feature feature1-feature4096;
  retain aveface;
  if id = 0 then do;
    do i=1 to 4096;
      aveface[i] = feature[i];
    end;
  end;
  do i=1 to 4096;
    normalface[i] = feature[i]-aveface[i];
  end;
  drop feature1-feature4096 avefeature1-avefeature4096 i;
  if id = 0 then delete;
  drop id;
run;

* show the average face;
%view_faces(
  dim=64,
  ds=averageface,
  n=1,
  prefix=feature,
  title=Average Face Image
);

*** calculate principal components *******************************************;

proc iml;

  * read train data from SAS data set into a PROC IML matrix;
  use normalizedtrain;
  read all var _ALL_ into A [colname=varnames];
  close normalizedtrain;

  * find eigenvectors of the A matrix;
  M = A * A`;
  call eigen(eigenvalues, eigenvectors, M);

  * project train faces onto the first NUM_EIGENFACES eigenvectors;
  * these vectors are known as eigenfaces;
  * eigenfaces can be thought of as representative faces;
  pc = A`*eigenvectors[,1:&NUM_EIGENFACES.];

  * create a SAS data set named princomps that contains;
  * the projection onto the eigenfaces;
  pcnames = "pc1":"pc&NUM_EIGENFACES.";
  create princomps from pc[colname=pcnames];
  append from pc;
  close princomps;

  * create a SAS data set named _pct that contains;
  * the eigenfaces for display as row vectors;
  _pct = pc`;
  featurenames = "feature1":"feature4096";
  create _pct from _pct[colname=featurenames];
  append from _pct;
  close _pct;

  * create a SAS data set named facecolvecs from the A-transpose matrix;
  * that contains the train faces as column vectors;
  facenames = "face1":"face360";
  atranpose = A`;
  create facecolvecs from atranpose[colname=facenames];
  append from Atranpose;
  close facecolvecs;

quit;

* show a few eigenfaces;
%view_faces(
  dim=64,
  ds=_pct,
  n=6,
  prefix=feature,
  title=Eigenface Image
);
