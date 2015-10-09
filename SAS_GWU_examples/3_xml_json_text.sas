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
* SECTION 3 - XML, JSON, and text                                            *;
******************************************************************************;

* define git_repo_dir macro variable;
%let git_repo_dir = /folders/myshortcuts/SAS_GWU_examples;

* set directory separator;
%let dsep = /; /* comment line for windows (but not for unversity edition) */
* %let dsep = \; /* uncomment line for windows */

*** XML **********************************************************************;

* one way to process semi-structured XML data using sas;
* is the SAS XML libname;

* define a library reference to the example.xml file;
* then you can treat it like a SAS data set;
libname x xml92 "&git_repo_dir";

* read data into SAS work;
* usually a good idea;
data scratch;
	set x.example;
run;

* data cleaning exercise;
* fix variable1 to have 2 decimal points;
* fix variable2 to be a numeric variable;
* converting a character variable to a numeric variable (and vise versa);
* is common data cleaning operation in SAS;
* formatted variables are also common in SAS;
* create scratch set;
data scratch;

	/* rename variable2 before it is read */
	/* use length statement before set statement */
	/* to enforce order of variables in the new set */
	/* define new variable2 as numeric explicitly */
	/* input() function converts a character value into a numeric value */
	/* ?? prevents an error when an invalid value is encountered */
	/* best. is a SAS informat */
	/* it determines the best format for reading variable2c */
	/* compress() removes white space from characters */
	/* account for invalid data */
	/* 10.2 format limits variable1 to 10 digits with 2 decimal points */
	/* 2. format limits variable 2 to 2 digits */
	/* drop variable2c in data step */

	length variable1 variable2 8 variable3 $6;
	set scratch (rename=(variable2=variable2c));
	variable2 = input(compress(variable2c), ?? best.);
	/* convert numeric missing to code: 99 */
	if variable2 = . then variable2 = 99;
	format variable1 10.2;
	format variable2 2.;
	drop variable2c;
run;

* write the clean temp data back to XML;
data x.clean_example;
	set scratch;
run;

* design libref x;
libname x;

*** JSON *********************************************************************;

* create a file reference to the example.json file;
filename json "&git_repo_dir.&dsep.example.json";

* use a data step strategy to ingest the JSON file;
* read desired JSON elements as character strings;
* create scratch2 set;
data scratch2;

	/* infile statement reads from an external file */
	/* infile and data step provide A LOT of flexibility */
	/* lrecl is how long a single record in the external file can be */
	/* truncover allows records to be shorter than expected */
	/* scanover scans for the @'character-string' expression */
	/* input statement creates new SAS variables */

	infile json lrecl = 1000 truncover scanover;
	input @'"variable1": ' c_variable1 $255.
		@'"variable2": ' c_variable2 $255.
		@'"variable3": "' c_variable3 $255.;
run;

* use data step functions and SAS formats;
* to tidy up JSON input;
data scratch2;
	length variable1 variable2 8 variable3 $6;
	infile json lrecl=32767 truncover scanover;
	input @'"variable1": ' c_variable1 $255.
		@'"variable2": ' c_variable2 $255.
		@'"variable3": "' c_variable3 $255.;
	/* substr() returns a segment of a string */
	/* SAS strings are indexed from 1 */
	/* indexc() returns the position of a character */
	variable1 = input(substr(c_variable1, 1, indexc(c_variable1, ',"')-1), best.);
	variable2 = input(substr(c_variable2, 1, indexc(c_variable2, ',"')-1), best.);
	variable3 = strip(substr(c_variable3, 1, indexc(c_variable3, ',"')-1));
	format variable1 10.2;
	format variable2 2.;
	drop c_:;
run;

* PROC GROOVY provides another method to ingest JSON using SAS;

*** text *********************************************************************;

* create a file reference to the example.txt file;
filename txt "&git_repo_dir.&dsep.example.txt";

* create scratch3 set;
* each tweet will be one line of the data set;
data scratch3;
	length line $140.;		/* tweets are 140 characters */
	infile txt dlm='0a'x;	/* hex character for line return */
	informat line $140.;
	input line $;
run;

* basic text normalization;
* use SAS PRX functions;
data scratch3;

	/* regular expression our a flexible tool for manipulating test */
	/* SAS surfaces them through the prx functions */

	/* compile regular expression */
	regex = prxparse('s/http.*( |)/ /');
	length line $140.;
	infile txt dlm='0a'x;
	informat line $140.;
	input line $;
	/* all text to lower case */
	line = lowcase(line);
	/* use perl regular expression to remove urls */
	call prxchange(regex, -1, line);
	/* remove non-alphabetical characters */
	line = compress(line, '?@#:&!".');
	drop regex;
run;

*** create a term by document matrix *****************************************;

* tranpose wide data into long data;
data scratch4;
	set scratch3;
	/* give each tweet a numeric ID */
	retain tweet_id 1;
	/* use a do loop to put each term into its own row */
	n_terms = countw(line);
	do i=1 to n_terms;
		term = scan(line, i);
		/* short terms usually not informative */
		if length(term) > 2 then output;
	end;
	tweet + 1;
	drop line n_terms i;
run;

* create a dictionary of unique terms;
proc sort
	data=scratch4(keep=term)
	out=dictionary;
	by term;
run;
* which terms appear frequently?;
proc sort
	data=scratch4(keep=term)
	out=dictionary
	/* remove duplicate terms this time */
	nodupkey;
	by term;
run;
* add term ID number to dictionary;
data dictionary;
	set dictionary;
	term_id = _n_;
run;

* sort transposed set by term to join term IDs;
proc sort
	data=scratch4;
	by term;
run;
data scratch4;
	merge scratch4 dictionary;
	by term;
run;

* create term by document matrix;
* term by document matrix is often represent by rows of 3-tuples;
* (document ID, term ID, term count);
proc sort
	data=scratch4;
	by tweet_id term_id;
run;
data tbd;
	set scratch4;
	by tweet term_id;
	retain count 0;
	if first.term_id then count = 0;
	count + 1;
	keep tweet_id term_id count;
run;
* a term by document matrix in this format is suitable for text mining;








