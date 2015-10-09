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
* SECTION 2 - SAS data sets and other data structures                        *;
******************************************************************************;

* define git_repo_dir macro variable; 
%let git_repo_dir = /folders/myshortcuts/SAS_GWU_examples; 

* set directory separator; 
%let dsep = /; /* comment line for windows (but not for unversity edition) */
* %let dsep = \; /* uncomment line for windows */

*** sas data sets ************************************************************;

* the sas data set is the primary data structure in the SAS language;
* now you will make one called scratch;

%let n_rows = 1000; /* define number of rows */
%let n_vars = 5;    /* define number of character and numeric variables */

* options mprint; /* to see the macro variables resolve uncomment this line */
data scratch;

	/* since you did not specify a permanent library on the data statement */
	/* the scratch set will be created in the temporary library work */
	/* it will be deleted when you leave SAS */

	/* SAS is strongly typed - it is safest to declare variables */
	/* using a length statement - especially for character variables */
	/* $ denotes a character variable */

	/* arrays are a data structure that can exist during the data step */
	/* they are a reference to a group of variables */
	/* horizontally across a data set */
	/* $ denotes a character array */
	/* do loops are often used in conjuction with arrays */
	/* SAS arrays are indexed from 1 */

	/* a key is a variable with a unique value for each row */

	/* mod() is the modulo function */
	/* the eval() macro function performs math operations */
	/* before text substitution */

	/* the drop statement removes variables from the output data set */

	/* since you are not reading from a pre-existing data set */
	/* you must output rows explicitly using the output statement */

	length key 8 char1-char&n_vars $ 8 numeric1-numeric&n_vars 8;
	text_draw = 'AAAAAAAA BBBBBBBB CCCCCCCC DDDDDDDD EEEEEEEE FFFFFFFF GGGGGGGG';
	array c $ char1-char&n_vars;
	array n numeric1-numeric&n_vars;
	do i=1 to &n_rows;
		key = i;
		do j=1 to %eval(&n_vars);
			/* assign a random value from text_draw */
			/* to each element of the array c */
			c[j] = scan(text_draw, floor(7*ranuni(12345)+1), ' ');
			/* assign a random numeric value to each element of the n array */
			/* ranuni() requires a seed value */
			n[j] = ranuni(%eval(&n_rows*&n_vars));
		end;
	  if mod(i, %eval(&n_rows/10)) = 0 then put 'Processing line ' i '...';
		drop i j text_draw;
		output;
	end;
	put 'Done.';
run;

*** basic data analysis ******************************************************;

* use proc contents to understand basic information about a data set;
proc contents data=scratch;
run;

* use proc freq to analyze categorical data;
proc freq
	/* nlevels counts the discreet levels in each variable */
	/* the colon operator expands to include variable names with prefix char */
	data=scratch nlevels;
	/* request frequency bar charts for each variable */
	tables char: / plots=freqplot(type=bar);
run;

* use proc univariate to analyze numeric data;
proc univariate
	data=scratch;
	/* request univariate statistics for variables names with prefix numeric */
	var numeric:;
	/* request histograms for the same variables */
	histogram numeric:;
	/* inset basic statistics on the histograms */
	inset min max mean / position=ne;
run;

*** basic data manipulation **************************************************;

* subsetting columns;
* create scratch2 set;
data scratch2;
	/* set statement reads from a pre-existing data set */
	/* no output statement is required */
	/* using data set options: keep, drop, etc. is often more efficient than */
	/* corresponding data step statements */
	/* there are MANY other ways to subset columns ... */
	set scratch(keep=key char1 numeric1);
run;

* subsetting and modifying columns;
* select two columns and modify them with data step functions;
* overwrite scratch2 set;
data scratch2;
	/* use length statement to ensure correct length of trans_char1 */
	/* the lag function saves the value from the row above */
	/* lag will create a numeric missing value in the first row */
	/* tranwrd finds and replaces character values */
	set scratch(keep=key char1 numeric1
		rename=(char1=new_char1 numeric1=new_numeric1));
 	length trans_char1 $8;
	lag_numeric1 = lag(new_numeric1);
	trans_char1 = tranwrd(new_char1, 'GGGGGGGG', 'foo');
run;

* subsetting rows;
* select only the first row and impute the missing value;
* create scratch3 set;
data scratch3;
	/* the where data set option can subset rows of data sets */
	/* there are MANY other ways to do this ... */
	set scratch2 (where=(key=1));
	lag_numeric1 = 0;
run;

* subsetting rows;
* remove the problematic first row containing the missing value;
* from scratch2 set;
data scratch2;
	set scratch2;
	if key > 1;
run;

* combining data sets top-to-bottom;
* add scratch3 to the bottom of scratch2;
proc append
	base=scratch2  /* proc append does not read the base set */
	data=scratch3; /* for performance reasons base set should be largest */
run;

* sorting data sets;
* sort scratch2 in place;
proc sort
	data=scratch2;
	by key; /* you must specificy a variables to sort by */
run;

* sorting data sets;
* create the new scratch4 set;
proc sort
	data=scratch2
	out=scratch4; /* specifying an out set creates a new data set */
	by new_char1 new_numeric1; /* you can sort by many variables */
run;

* combining data sets side-by-side;
* to create scratch5 set;
* create messy scratch5 set;
data scratch5;
	/* merge simply attaches two or more data sets together side-by-side*/
	/* it overwrites common variables - be careful */
	merge scratch scratch4;
run;

* combining data sets side-by-side;
* join columns to scratch from scratch2 when key variable matches;
* to create scratch6 correctly;
data scratch6;
	/* merging with a by variable is safer */
	/* it requires that both sets be sorted */
	/* then rows are matched when key values are equal */
	/* very similar to SQL join */
	merge scratch scratch2;
	by key;
run;

* don't forget PROC SQL;
* nearly all common SQL statements and functions are supported by PROC SQL;
* join columns to scratch from scratch2 when key variable matches;
* to create scratch7 correctly;
proc sql noprint; /* noprint suppresses procedure output */
	create table scratch7 as
	select *
	from scratch
	join scratch2
	on scratch.key = scratch2.key;
quit;

* comparing data sets;
* results from data step merge with by variable and PROC SQL join;
* should be equal;
proc compare base=scratch6 compare=scratch7;
run;

* export data set;
* to create a csv file;
proc export
	data=scratch7
	/* create scratch7.csv in working directory */
	/* . ends a macro variable name */
	outfile="&git_repo_dir.&dsep.scratch7.csv"
	/* create a csv */
	dbms=csv
	/* replace an existing file with that name */
	replace;
run;

* import data set;
* from the csv file;
* to overwrite scratch7 set;
proc import
	/* import from scratch7.csv */
	datafile="&git_repo_dir.&dsep.scratch7.csv"
	/* create a sas table in the work library */
	out=scratch7
	/* from a csv file */
	dbms=csv
	/* replace an existing data set with that name */
	replace;
run;

* results from export/import should match previously created scratch6 set;
proc compare
	base=scratch6
	compare=scratch7
	criterion=0.000001; /* we can except tiny differences */
run;

* by group processing;
* by variables can be used in the data step;
* the data set must be sorted;
* create scratch8 summary set;
data scratch8;
	set scratch4;
	by new_char1 new_numeric1;
	retain count 0; /* retained variables are remembered from row-to-row */
	if last.new_char1 then do; /* first. and last. are used with by vars */
		count + 1; /* shorthand to increment a retained variable */
		output; /* output the last row of a sorted by group */
	end;
run;

* by group processing;
* by variables can be used efficiently in most procedures;
* the data set must be sorted;
proc univariate
	data=scratch4;
	var lag_numeric1;
	histogram lag_numeric1;
	inset min max mean / position=ne;
	by new_char1;
run;

*** hashes in sas ************************************************************;

* hash objects are an in-memory data structure in SAS;
* they have keys and data;
* and several simple functions for data manipulation;
* one common use of hash objects is to join a very narrow data set;
* onto a wider data set;
data scratch9;

	/* declare a hash with the name h */
	/* define the key and data elements of h */
	/* use a do until loop to load */
	/* the narrower data set scratch2 into h */

	/* end creates a temporary variable that =1 at the last */
	/* row of a data set */

	/* use a do until loop to process the rows of scratch */
	/* when the key of h matches the key variable in scratch */
	/* output the data h and the variables in scratch */

	declare hash h();
	h.defineKey('key');
	h.defineData('new_char1', 'new_numeric1', 'trans_char1', 'lag_numeric1');
	h.defineDone();
	do until(eof1);
		set scratch2 end=eof1;
		_rc=h.add();
		if _rc then do;
			put 'ERROR: hash load on line ' _n_= '.';
			abort;
		end;
	end;
	do until(eof2);
		set scratch end=eof2;
		_rc = h.find();
		if _rc then do;
			put 'ERROR: Matching key not found for line ' _n_= '.';
			abort;
		end;
		output;
	end;
	drop _rc;
run;

* hash join should match earlier join results;
proc compare base=scratch6 compare=scratch9; run;

*** lists in sas *************************************************************;

* PROC SQL is probably the easiest way to create a list;
* but the list is limited to the maximum length of a macro variable;
proc sql noprint;
	/* use separated by statements to define list delimiter */
	select name into: list1 separated by ' '
	from sashelp.class;
quit;
%put &list1;

* a macro variable array takes more effort to create;
* but is limited in length only by the amount RAM allocated to SAS;
data _null_;
	set sashelp.class(keep=name) end=eof;

	/* call symput creates macro variables */
	/* call symput('macro_var_name', 'macro_var_value') */
	/* _n_ is the system row count variable */
	/* the || operator concatenates strings */

	/* the line directly below creates a macro variable */
	/* with the name list_element<_n_> */
	/* and with the value of the variable name in the current row */
	/* strip() removes whitespace */
	call symput('list_element'||strip(put(_n_, best.)), name);
	/* it is also convenient to know the number of elements in the list */
	/* the variable eof will be true when the end of the data set is reached */
	if eof then call symput('list_length', strip(put(_n_, best.)));
run;
%put _user_; /* see all user-created macro variables */
%put &list_element3;
%put &list_length;
* macro functions are defined using the macro statements: macro and mend;
* other macro statements define the flow of the macro function;
* a macro function using double amperstand notation (&&):
* can be used to cycle through the list elements created above;
%macro resolve_list;
	%do i=1 %to &list_length;
		%put &&list_element&i;
	%end;
%mend;
%resolve_list;

* you can use dynamic programming techniques;
* to create a macro that stores a list as a macro;
* this allows you to store lists of massive lengths;
* macro functions can have keyword or locational parameters;
%macro make_list(name=list2, metadata=, key=name, nummacro=list_length2);

	/* name - name of the macro to contain the list of variables */
	/* metadata - name of the data set containing the key variable */
	/* key - name of the variable containing the list elements */
	/* nummacro - name of a global macro variable that resolves to */
	/*            the length of the list */

	/* define a binary file known as a macro source file */
	/* use a _null_ data step to write the text that defines a macro */
	/* to this macro source file */
	/* the defined macro will simply resolve to the values of the key variable */

	filename lstmacro catalog 'work.emutil.macro.source';
	data _null_;
		length _line $80;
		retain _line;
		set &metadata end=eof;
		file lstmacro;
		if _n_=1 then do;
			/* start defining the macro */
			_string = "%"!!"macro &name;";
			put _string;
		end;
		/* check that the line of list elements has not become too long */
		if (length(_line) + length(trim(&key))+ 1 < 80) then do;
			/* if not, add key to the list elements */
			_line = trim(_line)!!' '!!trim(&key);
			/* if at the end of the data set */
			if eof then do;
				/* write any remaining list elements */
				put _line;
				/* end the macro */
				_string = "%"!!"mend &name;";
				put _string;
				/* define a macro variable holding the list length */
				%if (&nummacro ne ) %then %do;
					_string = strip(put(_N_, best.));
					put "%" "global &nummacro;";
					put "%" "let &nummacro = " _string ";";
				%end;
				/* exit data step if end of set is reached */
				stop;
			end;
		end;
		else do;
			/* the line is too long, write all list elements to the macro */
			put _line;
			/* there is at least one more row in the data set */
			_line = trim(&key);
			/* if at the end of the data set */
			if eof then do;
				/* write any remaining list elements */
				put _line;
				/* end the macro */
				_string = "%"!!"mend &name;";
				put _string;
			end;
		end;
		/* define a macro variable holding the list length */
		if eof then do;
			_string = strip(put(_N_, best.));
			%if (&nummacro ne ) %then %do;
				put "%" "global &nummacro;";
				put "%" "let &nummacro = " _string ";";
			%end;
		end;
	run;

	/* compile the generated macro */
	%inc lstmacro;
	filename lstmacro;

%mend make_list;

* define a list and write it to the log;
%make_list(metadata=sashelp.class);
%put %list2;
%put &list_length2;
