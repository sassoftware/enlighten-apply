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
* - tidy data utility one: dimension values are stored across multiple       *;
*   column names                                                             *;
* - based on Hadley Wickham's "Tidy Data"                                    *;
*   https://www.jstatsoft.org/article/view/v059i10/v59i10.pdf                *;
*                                                                            *;
* INSTRUCTIONS:                                                              *;
* - set global constants directly below                                      *;
* - set identifier (fixed) variables                                         *;
* - set measurement columns                                                  *;
* - set numeric columns not in DIMNAME                                       *;
* - run entire file                                                          *;
******************************************************************************;

*** simulate example data ****************************************************;
data samp;
  length year w x y z 8;
  input year w x y z;
  datalines4;
2005 5 10 3 18
2006 3 20 1 0  
;;;; 
run;

*** TODO: user set global constants ******************************************;
* INDATA1 - name of the input dataset - must include the Libref if the;
*           dataset is not in WORK - required;
* OUTDATA1 - name of the generated output dataset - include a libref as;
*            needed - optional, if blank, WORK._TIDY1_ will be generated;
* DIMNAME - name of the dimension - specify one name - this could comprise;
*           multiple dimensions - if blank, _DIM_ will be used;
* MEASNAME - name of the Mmeasure described by the dimension(s);
*            (e.g. freq, rank, etc.);
*            specify one name, if blank, _MEASURE_ will be used;

%let INDATA1 = samp; /* example setting */
%let OUTDATA1 = outtidy1; /*example setting */
%let DIMNAME = DIM; /* example setting */
%let MEASNAME = MEASURE; /* example setting */

*** TODO: user set identifier (fixed) variables *****************************;
* specify these variables by inserting them on lines immediately after the;
*   datalines4 statement below, one per line;
* if none is specified, the id variable _CASE_ will be generated containing;
*   the _n_ value from the source dataset.;

/* example setting below */
data idvars;
input @1 name $char32.;
datalines4;
year
;;;;
run;

*** TODO: user set measurement variables *************************************;
* measure columns whose names contain the dimension (DIMNAME) values;
* these columns should all be of the same type (numeric or character) and;
*   must contain the measures described by MEASNAME above;
* if none is specified, all numeric columns will be used excluding any;
*   numeric columns specified in the idvars set above, and excluding numeric;
*   columns specified in the numcoldrop set below;
* specify these columns by inserting them on lines immediately after the
*   datalines4 statement below, one per line;

/* example setting below */
data dimMeasures;
input @1 name $char32.;
datalines4;
w
x
y
z
;;;;
run;

*** TODO: user set numeric columns not in DIMNAME ****************************;
* numeric columns whose names are not in the dimension (DIMNAME);
* this will be used if DIMMEASURES is empty;
* specify these columns by inserting them on lines immediately after the
*   datalines4 statement below, one per line;
* optional;

data  numcoldrop;
input @1 name $char32.;
datalines4;
;;;;
run;

*** tidy1 ********************************************************************;
* macro that corrects dimension values stored across multiple column names;

options validvarname=ANY;

%macro tidy1 /  minoperator;

  * macro variable validations;
  * INDATA1;
  %if %superq(INDATA1) = %then %do;
    %put ERROR: Variable 'INDATA1' cannot be blank. The source dataset must be specified.;
    %if (&syscc. in (0 4)) %then %let syscc = 5;
    %return;
  %end;
  %if not(%sysfunc(exist(%superq(INDATA1)))) or
      (%superq(INDATA1)=%str(*)) %then %do;
    %put ERROR: Source dataset %qupcase(%superq(INDATA1)) does not exist.;
    %if (&syscc. in (0 4)) %then %let syscc = 5;
    %return;
  %end;

  * OUTDATA1;
  %if %superq(OUTDATA1)= %then %let OUTDATA1=_TIDY1_;

  * DIMNAME;
  %if %superq(DIMNAME)= %then %let DIMNAME=_DIM_;

  * MEASNAME;
  %if %superq(MEASNAME)= %then %let MEASNAME=_MEASURE_;

  * extract and write the dim measure columns to macro var array;
  * dimmeas1, dimmeas2, etc.;
  %local dimmeascnt;
  %let dimmeascnt = 0;
  data  _null_;
    set dimMeasures end=last;
    call symput('dimmeas'||strip(put(_n_,10.)),"'"||
      tranwrd(ktrim(name),"'","''")||"'n");
    if last then call symputx('dimmeascnt',_n_,'F');
  run;

  *if DIMMEASURES is unpopulated, extract numeric variables from INDATA1;
  %if (&dimmeascnt. = 0) %then %do;

    proc contents data=&INDATA1. noprint out=_metaout (keep=name type);
    run;

    * extract numeric variables that are not in IDVARS and NUMCOLDROP;
    * write to NUMMEASURES;
    proc sql;
      create table numMeasures as
      select name
      from _metaout
      where type = 1
        and not(upcase(name) in
        (select upcase(name) from idvars))
        and not(upcase(name) in
        (select upcase(name) from numcoldrop));
      drop table _metaout;
    quit;

    * extract and write the dim measure columns to macro var array;
    * dimmeas1, dimmeas2, etc.;
    data  _null_;
      set numMeasures end=last;
      call symput('dimmeas'||strip(put(_n_,10.)),"'"||
        tranwrd(ktrim(name),"'","''")||"'n");
      if last then call symputx('dimmeascnt',_n_,'F');
    run;

    * exit if there are no numeric variables to be transposed ("stacked");
    %if (&dimmeascnt. = 0) %then %do;
      %put ERROR: Numeric variables are unavailable for further processing.;
      %if (&syscc. in (0 4)) %then %let syscc = 5;
      %return;
    %end;

  %end;

  * extract and write the identifier variables to macro var array;
  * idvar1, idvar2, etc.;
  %local idvarcnt;
  %let idvarcnt=0;
  data  _null_;
    set idvars end=last;
    call symput('idvar'||strip(put(_n_,10.)),"'"||
      tranwrd(ktrim(name),"'","''")||"'n");
    if last then call symputx('idvarcnt',_n_,'F');
  run;

  * generate the _CASE_ column;
  * clear-out any labels on the dimmeas columns;
  data  _temp_indata / view=_temp_indata;
    set &INDATA1.;
    _CASE_=_n_;
    %do x=1 %to &dimmeascnt.;
      label &&dimmeas&x.=;
    %end;
  run;

  %local x;
  * transpose the input data to "stack";
  * the dimension measure columns into one measure variable;
  proc transpose
    data=_temp_indata
    out=&OUTDATA1. (rename=(col1=&MEASNAME.)
    %if (&idvarcnt.) %then drop=_CASE_;) name=&DIMNAME.;
    by _CASE_
    %if (&idvarcnt.) %then %do;
      %do x=1 %to &idvarcnt.;
        &&idvar&x.
      %end;
      NOTSORTED
    %end;;
    var %do x=1 %to &dimmeascnt.;
      &&dimmeas&x.
    %end;;
  run;

  proc sql;
    drop view _temp_indata;
  quit;

%mend;
%tidy1