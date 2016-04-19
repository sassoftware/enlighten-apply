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
* - tidy data utility two: multiple dimension variables stored in one column *;
* - based on Hadley Wickham's "Tidy data"                                    *;
*   https://www.jstatsoft.org/article/view/v059i10/v59i10.pdf                *;
*                                                                            *;
* INSTRUCTIONS:                                                              *;
* - set global constants directly below                                      *;
* - run entire file                                                          *;
******************************************************************************;


*** simulate example data ****************************************************;
data samp;
  length year 8 dim $2 measure 8;
  input year dim $ measure;
  datalines4;
2005 x1 5
2005 x2 10
2005 y1 3
2005 y2 18
2006 x1 3
2006 x2 20
2006 y1 1
2006 y2 0
;;;; 
run;

*** TODO: user set global constants ******************************************;
* INDATA2 - name of the input dataset - must include the Libref if the;
*           dataset is not in WORK - required;
* OUTDATA2 - name of the generated output dataset - include a libref as;
*            needed - optional, if blank, WORK._TIDY2_ will be generated;
* DIMCOL - name of the column containing values for the dimension variables;
*          specify the column name within the single quotes - required;
* DIMNAMES - space or comma delimited list of the names of the dimension;
*            variables - required;
* DIMLENGTHS - space or comma delimited list of the character lengths of the;
*              dimension variables - specify integer values - required;
*              number of values specified must match the number of values;
*              specified for DIMNAMES above;
*              lengths are used to parse the column for the dimension variable;
*              values when DIMSTOREMETHOD=2 (below);
* DIMSTOREMETHOD - method for how the dimension variable values are stored in;;
*                  the column - required;
*                  1 = delimited by one or more specified characters;
*                  2 = fixed start character position, counting from the left;
*                  the start position for a dimension variable needs to be;
*                  the same on every column value;
* PARSEDELIM - delimiter character list for parsing the column values;
*              specify the characters within single quotes;
*              used if DIMSTOREMETHOD = 1;
*              the first delimited value is assigned to the
*              first dimension variable in DIMNAMES, the second delimited
*              value is assigned to second dimension var in DIMNAMES, etc;
*              if no characters are specified, the default SAS macro;
*              delimiters will be used;
* PARSEPOSITIONS - space or comma delimited list of the start character;
*                  position for each variable, counting from the left;
*                  specify integer values - required if DIMSTOREMETHOD = 2;
*                  the number of values specified must match the number;
*                  of values specified for DIMNAMES above;
*                  this list along with the DIMLENGTHS list above is used;
*                  to parse the column values;

%let INDATA2 = samp; /* example setting */
%let OUTDATA2 = outtidy2; /* example setting */
%let DIMCOL = 'dim'; /* example setting */ /* quoted string */
%let DIMNAMES = DIM1 DIM2; /* example setting */
%let DIMLENGTHS = 1 1; /* example setting */
%let DIMSTOREMETHOD = 2; /* example setting */ /* valid value: 1 or 2 */
%let PARSEDELIM = ''; /* quoted string */
%let PARSEPOSITIONS = 1 2; /* example setting */

*** tidy2 ********************************************************************;
* macro that corrects multiple dimension variables stored in one column;

options validvarname=ANY;

%macro tidy2 / minoperator;

  * macro variable validations;
  * INDATA2;
  %if %superq(INDATA2) = %then %do;
    %put ERROR: Variable 'INDATA2' cannot be blank. The source dataset must be specified.;
    %if (&syscc. in (0 4)) %then %let syscc = 5;
    %return;
  %end;
  %if not(%sysfunc(exist(%superq(INDATA2)))) or (%superq(INDATA2)=%str(*)) %then %do;
    %put ERROR: Source dataset %qupcase(%superq(INDATA2)) does not exist.;
    %if (&syscc. in (0 4)) %then %let syscc = 5;
    %return;
  %end;

  * OUTDATA2;
  %if %superq(OUTDATA2)= %then %let OUTDATA2=_TIDY2_;

  * DIMCOL;
  %if %qsysfunc(kcompress(%superq(DIMCOL),%str(%' )))= %then %do;
    %put ERROR: Variable 'DIMCOL' cannot be blank. Specify a Column name within the single quotes.;
    %if (&syscc. in (0 4)) %then %let syscc = 5;
    %return;
  %end;
  %if (%qsysfunc(ksubstr(%superq(DIMCOL),1,1)) ne %str(%'))
      or (%qsysfunc(ksubstr(%qsysfunc(kreverse(%superq(DIMCOL))),1,1))
      ne %str(%')) %then %do;
    %put ERROR: The Column name specified for Variable 'DIMCOL' must be within single quotes.;
    %if (&syscc. in (0 4)) %then %let syscc = 5;
    %return;
  %end;

  * DIMNAMES;
  %if %superq(DIMNAMES) = %then %do;
    %put ERROR: Variable 'DIMNAMES' cannot be blank. Specify a space delimited list of two or more Dimension names.;
    %if (&syscc. in (0 4)) %then %let syscc = 5;
    %return;
  %end;

  %local dimcount;
  %let dimcount = %sysfunc(countw(%superq(DIMNAMES),%str( ,)));
  %if (&dimcount. lt 2) %then %do;
    %put ERROR: Variable 'DIMNAMES' must contain a space delimited list of two or more Dimension names.;
    %if (&syscc. in (0 4)) %then %let syscc = 5;
    %return;
  %end;

  * DIMLENGTHS;
  %if %superq(DIMLENGTHS) = %then %do;
    %put ERROR: Variable 'DIMLENGTHS' cannot be blank. Specify a space delimited list of the lengths of the Dimension Variables.;
    %if (&syscc. in (0 4)) %then %let syscc = 5;
    %return;
  %end;
  %if (%sysfunc(countw(%superq(DIMLENGTHS),%str( ,))) ne &dimcount.) %then %do;
    %put ERROR: Variable 'DIMLENGTHS' must contain the same number of lengths as the number of specified Dimension names.;
    %if (&syscc. in (0 4)) %then %let syscc = 5;
    %return;
  %end;
  data _null_;
    length val $10 message $200;
    l_error = 0;
    do x=1 to &dimcount.;
    val = scan(symget('DIMLENGTHS'),x,' ,');
    len = input(val,10.);
    if len lt 1 then do;
      message = "ERROR: Invalid value '"||strip(val)||"' specified within Variable 'DIMLENGTHS'. Specify an integer value greater than 0.";
      put message;
      message = '';
      l_error = 1;
    end;
    else call symputx('len'||strip(put(x,10.)),int(len),'L');
    end;
    call symputx('l_error',l_error,'L');
  run;
  %if (&l_error.) %then %do;
    %if (&syscc. in (0 4)) %then %let syscc = 5;
    %return;
  %end;

  * DIMSTOREMETHOD;
  %if %superq(DIMSTOREMETHOD) = %then %do;
    %put ERROR: Variable 'DIMSTOREMETHOD' cannot be blank. Valid values: 1 or 2.;
    %if (&syscc. in (0 4)) %then %let syscc = 5;
    %return;
  %end;
  %if not(%superq(DIMSTOREMETHOD) in (1 2)) %then %do;
    %put ERROR: Invalid value specified for Variable 'DIMSTOREMETHOD'. Valid values:  1 or 2.;
    %if (&syscc. in (0 4)) %then %let syscc = 5;
    %return;
  %end;

  * PARSEDELIM;
  %if (&DIMSTOREMETHOD. = 1) %then %do;
    %if (%superq(PARSEDELIM) ne %str() and %superq(PARSEDELIM) ne '') %then %do;
      %if (%qsysfunc(ksubstr(%superq(PARSEDELIM),1,1)) ne %str(%')) or
          (%qsysfunc(ksubstr(%qsysfunc(kreverse(%superq(PARSEDELIM))),1,1)) ne
           %str(%')) %then %do;
        %put ERROR: The delimiter characters populated for Variable 'PARSEDELIM' must be within single quotes.;
        %if (&syscc. in (0 4)) %then %let syscc = 5;
        %return;
      %end;
    %end;
    %else %let PARSEDELIM=;
  %end;

  * PARSEPOSITIONS;
  %if (&DIMSTOREMETHOD. = 2) %then %do;

    %if %superq(PARSEPOSITIONS)= %then %do;
      %put ERROR: Variable 'PARSEPOSITIONS' cannot be blank. Specify a space delimited list of the parsing start positions for the Dimension Variables.;
      %if (&syscc. in (0 4)) %then %let syscc = 5;
      %return;
    %end;
    %if (%sysfunc(countw(%superq(PARSEPOSITIONS),%str( ,))) ne &dimcount.)
        %then %do;
      %put ERROR: Variable 'PARSEPOSITIONS' must contain the same number of start positions as the number of specified Dimension names.;
      %if (&syscc. in (0 4)) %then %let syscc = 5;
      %return;
    %end;
    data _null_;
      length val $10 message $200;
      l_error = 0;
      do x=1 to &dimcount.;
      val = scan(symget('PARSEPOSITIONS'),x,' ,');
      pos = input(val,10.);
      if pos lt 1 then do;
        message = "ERROR: Invalid value '"||strip(val)||"' specified within Variable 'PARSEPOSITIONS'. Specify an integer value greater than 0.";
        put message;
        message = '';
        l_error = 1;
      end;
      else call symputx('pos'||strip(put(x,10.)),int(pos),'L');
      end;
      call symputx('l_error',l_error,'L');
    run;
    %if (&l_error.) %then %do;
      %if (&syscc. in (0 4)) %then %let syscc = 5;
      %return;
    %end;

  %end;

  * extract the dimension names, writing to macro var arrray;
  * dim1, dim2, etc.;
  %local x;
  %do x=1 %to &dimcount.;
    %local dim&x.;
    %let dim&x. = %scan(%superq(DIMNAMES),&x.,%str( ,));
  %end;

  * data step to generate the dimension variables;
  data &OUTDATA2.;
    set &INDATA2.;
    length
    %do x=1 %to &dimcount.;
      &&dim&x. $&&len&x.
    %end;;
    %if (&DIMSTOREMETHOD. = 1) %then %do;
      %do x=1 %to &dimcount.;
        &&dim&x. = kscan(&DIMCOL.n,&x.%if %superq(PARSEDELIM) ne %then,&PARSEDELIM.;);
      %end;
    %end;
    %else %do;   /* DIMSTOREMETHOD. = 2 */
      %do x=1 %to &dimcount.;
        &&dim&x. = ksubstr(&DIMCOL.n,&&pos&x.,&&len&x.);
      %end;
    %end;
    drop &DIMCOL.n;
  run;

%mend;
%tidy2
