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
* - tidy data utility three: values of one or more dimensions are stored     *;
*   across multiple column names and measure variables are stored in rows    *;
* - based on Hadley Wickham's "Tidy data"                                    *;
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
  length year 8 type $1 w x y z 8;
  input year type $ w x y z;
  datalines4;
2005 A 3 6 2 4
2005 B 2 4 1 14
2006 A 1 12 0 0 
2006 B 2 8 1 0 
;;;; 
run;

*** TODO: user set global constants ******************************************;
* INDATA3 - name of the input dataset - must include the Libref if the;
*           dataset is not in WORK - required;
* OUTDATA3 - name of the generated output dataset - include a libref as;
*            needed - optional, if blank, WORK._TIDY3_ will be generated;
* DIMNAME - name of the dimension - specify one name - this could comprise;
*           multiple dimensions - if blank, _DIM_ will be used;
* MEASNAMESCOL - character column whose values are the names of the measure;
*                variables - specify one column name within the single quotes;
*                required - this column must be populated for every row;

%let INDATA3 = samp; /* example setting */ 
%let OUTDATA3 = outtidy3; /* example setting */
%let DIMNAME = DIM; /* example setting */
%let MEASNAMESCOL = 'TYPE'; /*  example setting */

*** TODO: user set identifier (fixed) variables *****************************;
* specify these variables by inserting them on lines immediately after the;
*   datalines4 statement below, one per line - required;
* do not include the column specified for MEASNAMESCOL (above) in this list;

/* example settings below */
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

/* example settings below */
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

data numcoldrop;
input @1 name $char32.;
datalines4;
;;;;
run;

*** tidy3 ********************************************************************;
* macro that corrects values of one or more dimensions that are stored across;
*   multiple column names and measure variables that are stored in rows;

options validvarname=ANY;

%macro tidy3 / minoperator;

  * macro variable validations;
  * INDATA3;
  %if %superq(INDATA3) = %then %do;
    %put ERROR: Variable 'INDATA3' cannot be blank. The source dataset must be specified.;
    %if (&syscc. in (0 4)) %then %let syscc = 5;
    %return;
  %end;
  %if not(%sysfunc(exist(%superq(INDATA3)))) or
      (%superq(INDATA3) = %str(*)) %then %do;
    %put ERROR: Source dataset %qupcase(%superq(INDATA3)) does not exist.;
    %if (&syscc. in (0 4)) %then %let syscc = 5;
    %return;
  %end;

  * OUTDATA3;
  %if %superq(OUTDATA3) = %then %let OUTDATA3 = _TIDY3_;

  * DIMNAME;
  %if %superq(DIMNAME) = %then %let DIMNAME = _DIM_;

  * MEASNAMESCOL;
  %if %qsysfunc(kcompress(%superq(MEASNAMESCOL),%str(%' ))) = %then %do;
    %put ERROR: Variable 'MEASNAMESCOL' cannot be blank. Specify a Column name within the single quotes.;
    %if (&syscc. in (0 4)) %then %let syscc = 5;
    %return;
  %end;
  %if (%qsysfunc(ksubstr(%superq(MEASNAMESCOL),1,1)) ne %str(%'))
      or (%qsysfunc(ksubstr(%qsysfunc(kreverse(%superq(MEASNAMESCOL))),1,1))
      ne %str(%')) %then %do;
    %put ERROR: The Column name specified for Variable 'MEASNAMESCOL' must be within single quotes.;
    %if (&syscc. in (0 4)) %then %let syscc = 5;
    %return;
  %end;

  * extract and write the dim measure columns to macro var array;
  * dimmeas1, dimmeas2, etc.;
  %local dimmeascnt;
  %let dimmeascnt = 0;
  data _null_;
    set dimMeasures end=last;
    call symput('dimmeas'||strip(put(_n_,10.)),"'"||
      tranwrd(ktrim(name),"'","''")||"'n");
    if last then call symputx('dimmeascnt',_n_,'F');
  run;

  * if DIMMEASURES is unpopulated, extract numeric variables from INDATA3;
  %if (&dimmeascnt. = 0) %then %do;

    proc contents data=&INDATA3. noprint out=_metaout (keep=name type);
    run;

    * extract numeric variables that are not in IDVARS and NUMCOLDROP;
    * write to numMeasures;
    proc sql;
      create table numMeasures as
      select name
      from _metaout
      where type=1
      and not(upcase(name) in
        (select upcase(name) from idvars))
        and not(upcase(name) in
        (select upcase(name) from numcoldrop));
      drop table _metaout;
    quit;

    * extract and write the dim measure columns to macro var array;
    * dimmeas1, dimmeas2, etc.;
    data _null_;
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
  %let idvarcnt = 0;
  data _null_;
    set idvars end=last;
    call symput('idvar'||strip(put(_n_,10.)),"'"||
      tranwrd(ktrim(name),"'","''")||"'n");
    if last then call symputx('idvarcnt',_n_,'F');
  run;

  * exit if there are no identifier variables;
  %if (&idvarcnt. = 0) %then %do;
    %put ERROR: Table IDVARS must be populated with the Identifier variables.;
    %if (&syscc. in (0 4)) %then %let syscc = 5;
    %return;
  %end;

  * clear-out any labels on the dimmeas columns;
  data _temp_INDATA3;
    set &INDATA3.;
    %do x=1 %to &dimmeascnt.;
      label &&dimmeas&x.=;
    %end;
  run;

  %local x;  /* counter variable */

  * sort by the identifier variables and MEASNAMESCOL;
  proc sort data=_temp_INDATA3;
    by %do x=1 %to &idvarcnt.;
      &&idvar&x.
    %end;;
  run;

  * transpose the input data to "stack" the dimension measure columns;
  * into one measure variable;
  proc transpose data=_temp_INDATA3 out=&OUTDATA3. name=&DIMNAME.;
    by %do x=1 %to &idvarcnt.;
      &&idvar&x.
    %end;;
    var %do x=1 %to &dimmeascnt.;
      &&dimmeas&x.
    %end;;
    id &MEASNAMESCOL.n;
  run;

  proc sql;
    drop table _temp_INDATA3;
  quit;

%mend;
%tidy3
