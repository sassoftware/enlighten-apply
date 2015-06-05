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
* THIS CODE WILL NOT RUN OUTSIDE OF ENTERPRISE MINER !!!                     *;
*                                                                            *;
* VARIOUS SAS ROUTINES FOR CLAIMS PREDICTION DATA:                           *;
* GENERATE BINARY DUMMIES IN CODE NODE                                       *;
* CONVERT GENERATED BINARY DUMMIES TO INTERVAL ROLE                          *;
* CALCULATE CCC IN CODE NODE                                                 *;
* CALCULATE GAP STATISTIC IN OPEN SOURCE NODE                                *;
* CALCULATE ABC IN CODE NODE (SINGLE-MACHINE/SMP)                            *;
* CALCULATE ABC IN BASE SAS (DISTRIBUTED/MPP)                                *;
*                                                                            *;
* THE k-ESTIMATION CALCULATIONS FOLLOWED THIS WORKFLOW IN EM:                *;
* VARIABLE SELECTION -> IMPUTE NUMERIC AND CLASS ->                          *;
* REPLACE NUMERIC OUTLIERS -> BIN CLASS OUTLIERS -> STANDARDIZE INTERVAL ->  *;
* CREATE BINNARY DUMMIES FOR CLASS VARS IN CODE NODE (USE CODE BELOW) ->     *;
* REJECT CORRELATED WITH METADATA NODE ->                                    *;
* CONVERT ALL REMAINING INPUTS TO INTERVAL MEASUREMENT LEVEL                 *;
*                                                                            *;
* FOR GAP, ALL VARIABLES THAT ARE NOT INPUTS MUST BE PHYSICALLY DROPPED      *;
* YOU MAY ALSO NEED TO SAMPLE ... GAP WILL PROBABLY RUN BETTER ON *NIX       *;
*                                                                            *;
******************************************************************************;

*** GENERATES BINARY DUMMY VARIABLES FOR AN ENTERPRISE MINER INPUT SET *******;
*** ATTEMPTS TO USE VARIABLE LEVEL IN NEW NAME;

*** CONSTRUCT A SET CONTAINING BINARY VARIABLE METADATA;
proc dmdb data=&EM_IMPORT_DATA classout= &EM_NODEID._bin;
	class %EM_BINARY_INPUT;
run;

*** CREATE IF STATMENTS FOR NEW VARIABLES;
data &EM_NODEID._bin;
	set &EM_NODEID._bin end= eof;
	/* TAKES CARE OF NAME LENGHT RESTRICTIONS */
	length line $255 short_name clean_level $16 new_name $32;
	file "%sysfunc(pathname(WORK))&EM_DSEP.if_stmt_bin.sas";
	short_name= name;
	/* DO NOT MAKE PERFECTLY CORRELATED PAIRS OF BINARY VARS! */
	if mod(_n_,2)= 0 then do;
		if TYPE= 'N' then do;
			/* NEGATIVE NUMERICAL VARS */
			if level ge 0 then clean_level= strip(level);
			else clean_level= strip('m'||compress(level, ' -'));
			new_name= strip(compress(
				short_name||clean_level, ' '));
			line= 'if '||strip(name)||'= '||strip(level)||' then '
				||strip(new_name)||'= 1; else '
				||strip(new_name)||'= -1;';
			put line;
		end;
		else do;
			clean_level= translate(translate(strip(level),
				'_______________________________',
				' <,>.?/:;{}[]|\~%"!@#$%^&*()-+='), '_', "'");
			new_name= strip(compress(
				short_name||clean_level, ' '));
			line= 'if upcase('||strip(name)||")= '"||strip(level)
				||"' then "||strip(new_name)||'= 1; else '
				||strip(new_name)||'= -1;';
			put line;
		end;
	end;
run;

*** CONSTRUCT A SET CONTAINING CLASS VARIABLE METADATA;
proc dmdb data=&EM_IMPORT_DATA classout= &EM_NODEID._nom;
	class %EM_NOMINAL_INPUT %EM_ORDINAL_INPUT;
run;

*** CREATE IF STATMENTS FOR NEW VARIABLES;
data &EM_NODEID._nom;
	set &EM_NODEID._nom end= eof;
	length line $255 short_name clean_level $16 new_name $32;
	file "%sysfunc(pathname(WORK))&EM_DSEP.if_stmt_nom.sas";
	short_name= name;
	if TYPE= 'N' then do;
		if level ge 0 then clean_level= strip(level);
		else clean_level= strip('m'||compress(level, ' -'));
		new_name= strip(compress(short_name||clean_level, ' '));
		line= 'if '||strip(name)||'= '||strip(level)||' then '||
			strip(new_name)||'= 1; else '||strip(new_name)||
			'= -1;';
		put line;
	end;
	else do;
		clean_level= translate(translate(strip(level),
			'_______________________________',
			' <,>.?/:;{}[]|\~%"!@#$%^&*()-+='), '_', "'");
		new_name= strip(compress(short_name||clean_level, ' '));
		line= 'if '||strip(name)||"= '"||strip(level)||"' then "||
			strip(new_name)||'= 1; else '||strip(new_name)||
			'= -1;';
		put line;
	end;
run;

*** EXECUTE EXPANSION OF DUMMY VARIABLES;

data &EM_EXPORT_TRAIN; /* FINAL OUTPUT WITH ALL NEW VARIABLES */
	set &EM_IMPORT_DATA; /* INPUT DATA */
	%include "%sysfunc(pathname(WORK))&EM_DSEP.if_stmt_bin.sas";
	%include "%sysfunc(pathname(WORK))&EM_DSEP.if_stmt_nom.sas";
run;

*** CHANGE METADATA;
%macro update_metadata;

	*** REJECT BINARY;
	%if (&EM_NUM_BINARY_INPUT) %then %do;
		%do m= 1 %to &EM_NUM_BINARY_INPUT;
		%EM_METACHANGE(
			NAME= %scan(%EM_BINARY_INPUT, &m),
			ROLE= REJECTED
		);
		%end;
	%end;

	*** REJECT NOMINAL;
	%if (%eval(&EM_NUM_NOMINAL_INPUT + &EM_NUM_ORDINAL_INPUT)) %then %do;
		%do m= 1 %to %eval(&EM_NUM_NOMINAL_INPUT + &EM_NUM_ORDINAL_INPUT);
			%EM_METACHANGE(
				NAME= %scan(%EM_NOMINAL_INPUT %EM_ORDINAL_INPUT, &m),
				ROLE= REJECTED
			);
		%end;
	%end;

	data &EM_NODEID._newclass;
		set &EM_NODEID._bin;
		if mod(_n_,2)= 0 then output;
	run;
	proc append
		base= &EM_NODEID._newclass
		data= &EM_NODEID._nom
		force;
	run;

	*** UPDATE NEW VARIABLES;
	%EM_VARMACRO(
		NAME= EM_NEW_BIN_VAR,
		METADATA= &EM_NODEID._newclass,
		KEY= NEW_NAME,
		NUMMACRO= EM_NUM_NEW_BIN_VAR
	);

	%if (&EM_NUM_NEW_BIN_VAR) %then %do;
		%do m= 1 %to &EM_NUM_NEW_BIN_VAR;
			%EM_METACHANGE(
				NAME= %scan(%EM_NEW_BIN_VAR, &m),
				ROLE= INPUT,
				LEVEL= BINARY
			);
		%end;
	%end;

%mend;
%update_metadata;


*** AUTOMATICALLY CONVERT NEW, NUMERIC BINARIES TO INTERVAL ROLE *************;
*** FOR USE IN CLUSTERING;

%macro binary_to_interval;

	%if (&EM_NUM_BINARY_INPUT) %then %do;
		%do i= 1 %to &EM_NUM_BINARY_INPUT;
			%EM_METACHANGE(
				NAME= %scan(%EM_BINARY_INPUT, &i),
				LEVEL= INTERVAL
			);
		%end;
	%end;

%mend;
%binary_to_interval;

*** CALCULATE CCC ************************************************************;
*** TO BE RUN IN EM SAS CODE NODE;

%macro getCCC(maxK= 20);
	%do i= 1 %to &maxK;
		proc fastclus
			noprint
			data= &EM_IMPORT_DATA
			maxclusters= &i
			outstat= o(where= (_TYPE_= 'CCC')
				keep= _TYPE_ OVER_ALL);
			var %EM_INTERVAL_INPUT;
		run;
		proc append base= CCCOut data= o; run;
	%end;
	proc print data= CCCOut; run;
%mend;
%getCCC;

### CALCULATE GAP #############################################################
### TO BE RUN IN EM OPEN SOURCE INTEGRATION NODE
### INSTALL R CLUSTER PACKAGE IF NOT PREVIOUSLY INSTALLED
### RUN IN NONE OUTPUT MODE

library('cluster')
set.seed(12345)
gskmn <- clusGap(&EMR_IMPORT_DATA, FUN= kmeans, K.max= 20, B= 10)
gskmn

*** CALCULATE ABC (SINGLE-MACHINE/SMP) ***************************************;
*** TO BE RUN IN EM SAS CODE NODE;

proc hpclus
	data= &EM_IMPORT_DATA maxclusters= 20 maxiter= 15
		noc= abc(b= 25 minclusters= 1 align= none criterion= all);
	input %EM_INTERVAL_INPUT;
	/* FILL IN THREADS */
	performance nthreads= ;
run;

*** CALCULATE ABC (DISTRIBUTED/MPP) ******************************************;
*** TO BE RUN IN SAS;
*** ON PREPROCESSED DATA FROM EM FLOW;
*** GRIDLIB REFERS TO A DISTRIBUTED SAS LIBRARY;

proc hpclus
	data= gridlib.kaggleClaimPrediction maxclusters= 20 maxiter= 15
		noc= abc(b= 25 minclusters= 1 align= none criterion= all);
	input _ALL_;
	/* FILL IN GRID OPTIONS */
	performance nodes= ;
run;
