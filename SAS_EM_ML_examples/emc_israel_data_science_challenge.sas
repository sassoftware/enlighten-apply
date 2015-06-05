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
* VARIOUS SAS ROUTINES FOR EMC ISRAEL CHALLENGE DATA:                        *;
* READ IN DATA FROM CSR FORMAT TO SAS COO FORMAT                             *;
* EXPAND SAS COO TO TRADITIONAL SAS SET                                      *;
* RANDOM FOREST CLASSIFIER                                                   *;
* MULTICLASS LOGARITHMIC LOSS                                                *;
* GENERATE SVD FEATURES                                                      *;
******************************************************************************;

*** SET WORKING DIRECTORY TO REPO DOWNLOADED FROM GIT;
%let git_repo_data_dir= ;
x "cd &git_repo_data_dir";

*** SET CPU COUNT;
%let cpu_count= ;

*** IMPORT TRAINING DATA TO CREATE COO FORMAT SAS DATA SET *******************;
*** FILL IN PATH;
%let train_file= 'emc_train_data.csv'; /* CSR FILE */
data values columns row_offsets;
	 infile "&train_file" recfm= f lrecl= 1 end= eof;
	 length accum $32;
	 retain accum ' ';                         *** TEXT VARIABLE FOR INPUT VALUES;
	 retain recnum 1;                          *** LINE OF INPUT FILE;
	 input x $char1.;                          *** PLACEHOLDER FOR ALL INPUT VALUES;
	 if x='0d'x then return;
	 delim= x in (',' '0a'x);
	 if not delim then accum= trimn(accum)||x; *** IF IT’S NOT A DELIMITER IT'S A VALUE;
	 if not delim and not eof then return;     *** IF IT'S NOT EOF OR A DELIMITER, CONTINUE;
	 nvalues+1;                                *** INCREMENT NUMBER OF NON-ZERO VALUES;
	 value= input(accum,best32.);              *** CONVERT ACCUM TO NUMERIC VALUE;
	 accum= ' ';                               *** RESET TEXT VARIABLE FOR NEXT VALUE OF X;
	 if nvalues<10 then put recnum= value=;    *** OUTPUT A SMALL SAMPLE OF VALUES FOR LOG;
	 if recnum= 1 then do;                     *** SPECIAL CASE FOR FIRST ROW OF INPUT FILE;
	    if nvalues= 1 then call symputx('nrows',value);
	    if nvalues= 2 then call symputx('ncols',value);
	 end;
	 else if recnum= 2 then output values;     *** SAS DATA SET FOR NON-ZERO VALUES;
	 else if recnum= 3 then output columns;    *** SAS DATA SET FOR COLUMN INDEX;
	 else if recnum= 4 then output row_offsets;*** SAS DATA SET FOR ROW POINTER;
	 if x='0a'x or eof then do;                *** TRUE CARRIAGE RETURN OR EOF, PRINT TO LOG;
	    put recnum= nvalues=;
	    recnum+1;                              *** INCREMENT TO NEXT INPUT LINE;
	    nvalues= 0;                            *** RESET NVALUES;
	 end;
	 keep value;                               *** KEEP VALUES, NOT TEMP VARS;
run;

*** CREATE A COO FORMAT TABLE;
*** CONTAINS THE ROW NUMBER, COLUMN NUMBER AND VALUE;
*** ALL INFORMATION NECESSARY TO BUILD FULL TRAINING MATRIX OR JUST SELECTED FEATURES;
data final_coo(keep= rownum colnum value);
    set row_offsets(firstobs= 2) end= eof;        *** 2ND OBS IN ROW_OFFSETS TELLS WHERE ...;
    retain prev 0;                                *** TO STOP THE FIRST ROW IN FINAL;
    retain min_colnum 1e50 max_colnum 0;
    rownum+1;                                     *** INITIALIZE ROWNUM TO ONE;
    count= value-prev;                            *** INDEX FOR END OF ROW;
    prev = value;                                 *** INDEX FOR START OF ROW;
    do i=1 to count;
       set values;                                *** GET MATRIX VALUE;
       set columns (rename= (value= colnum));     *** GET COLUMN NUMBER;
       min_colnum= min(min_colnum, colnum);
       max_colnum= max(max_colnum, colnum);
       output;
    end;
    if eof then put _n_= min_colnum= max_colnum= "nrows=&nrows. ncols=&ncols.";
run;

*** EXPAND TO FULL (OR PARTIAL) TRAINING SET *********************************;

*** IMPORT TRAINING LABELS;
*** FILL IN PATH;
%let label_file= 'emc_train_labels.csv';
data target;
	length hkey 8;
	hkey= _n_;
	infile "&label_file" delimiter= ',' missover dsd lrecl= 32767 firstobs= 1;
	informat target best32. ;
	format target best12. ;
	input target;
	if _n_ <= 10 then put hkey= target=;
run;

*** EXPAND SUMMARY SET INTO FULL TRAINING MATRIX;
*** THIS WILL TAKE SOME TIME (LIKE MAYBE DAYS ... );
*** AND DISK SPACE (~800 GB ...);
*** BUILD THE FIRST 1000 LINES AND DO SOME BENCHMARKING WITH DIFFERENT ...;
*** BUFNO, BUFSIZE, CATCACHE, AND COMPRESS OPTIONS;
*** DO NOT ATTEMPT TO VIEW THE FULL (~800 GB, ~600K COLUMNS) TABLE IN THE GUI!!;

*** DATA STEP TO EXPAND ALL DATA;
*** (SLIGHTLY DIFFERENT);
*** CAN BE BUILT FROM COO AND TARGET SET WITHOUT INTERMEDIATE STEPS BELOW;
/*data emcIsrael&ncols; */
/*	set final_coo; */
/*	by rownum; */
/*	array tokens {&ncols} token1-token&ncols;      *** CREATE FULL NUMBER OF COLUMNS;  */
/*	retain tokens;				     */
/*	do i= 1 to &ncols;                             *** POPULATE ARRAY WITH EXPANDED VALUES; */
/*   		if i= (colnum+1) then tokens{i}= value;*** COLNUM STARTS AT 0; */
/*   		if tokens{i}= . then tokens{i}= 0; */
/*	end;*/
/*	keep rownum token1-token&ncols;  */
/*	if last.rownum then do;  */
/*	   output;                                     *** OUTPUT ONE ROW FOR EACH SET OF ROWNUMS; */
/*	   if mod(rownum, 1000)= 0 then putlog 'NOTE: currently processing record ' rownum;  */
/*	   do j = 1 to &ncols;                         *** REINITIALIZE ARRAY; */
/*	      tokens{j}= .;*/
/*	   end;*/
/*	end; */
/*run; */

*** REMEMBER, IN THE PAPER THIS WAS JUST AN EXAMPLE ABOUT A BIG CHUNK OF DATA ...;
*** TO AVOID HAVING TO EXPAND THAT ENTIRE BIG CHUNK OF DATA ...;
*** YOU CAN USE THE COO SET TO FIND THE COLUMNS YOU LIKE BEST ...;
*** SOMETHING LIKE ...;

*** RESET NCOLS;
%let ncols= 25;

proc sort
	data= final_coo
	out= _&ncols.highestTokenCount
	sortsize= MAX;
	by colnum;
run;
data _&ncols.highestTokenCount (keep= colnum count);
	set _&ncols.highestTokenCount (keep= colnum);
	by colnum;
	retain count 0;
	count+1;
	if last.colnum then do;
		output;
		count= 0;
	end;
run;
proc sort
	data= _&ncols.highestTokenCount
	out= _&ncols.highestTokenCount
	sortsize= MAX;
	by descending count;
run;
data _&ncols.highestTokenCount;
	set _&ncols.highestTokenCount(obs= &ncols);
run;
proc sql noprint;
	select colnum into :selected_feature_names separated by ' token'
	from _&ncols.highestTokenCount
	order by colnum;
	select colnum into :selected_feature_values separated by ', '
	from _&ncols.highestTokenCount
	order by colnum;
quit;
%let selected_feature_names= token&selected_feature_names;
%put &selected_feature_names;
%put &selected_feature_values;

*** EXPAND INTO FLAT SAS TABLE;
data emcIsrael&ncols.;
	set final_coo;
	by rownum;
	array tokens {&ncols} &selected_feature_names;	*** CREATE FULL NUMBER OF COLUMNS;
	array lookup {&ncols} (&selected_feature_values);
	retain tokens;
	do i= 1 to &ncols;				*** POPULATE ARRAY WITH EXPANDED VALUES;
			if lookup{i}= colnum then tokens{i}= value;
			if tokens{i}= . then tokens{i}= 0;
	end;
	keep rownum &selected_feature_names;
	if last.rownum then do;
		output;					*** OUTPUT ONE ROW FOR EACH SET OF ROWNUMS;
		if mod(rownum, 10000)= 0 then putlog 'NOTE: currently processing record ' rownum ' ...';
		do j= 1 to &ncols;
			tokens{j}=.;			*** REINITIALIZE ARRAY;
		end;
	end;
run;

*** MERGE LABELS WITH HASH;
data emcIsrael&ncols;
	declare hash h();
	length hkey target 8;                      	*** DEFINE HASH;
	h.defineKey("hkey");
	h.defineData("target");
	h.defineDone();
	do until(eof1);                            	*** FILL WITH TARGET SET;
	   set target end= eof1;
	   rc1= h.add();
	   if rc1 then do;
	      putlog 'ERROR: Target not found for line ' _n_=;
	      abort;
	   end;
	end;
	do until(eof2);                            	*** EXECUTE MERGE;
	   set emcIsrael&ncols (rename= (rownum= hkey)) end= eof2;
	   rc2= h.find();
	   if rc2 then do;
	      putlog 'ERROR: Target not found for line ' _n_=;
	      abort;
	   end;
	   output;
	end;
/*	keep hkey target token1-token&ncols; *** FOR FULL MATRIX; */
	keep hkey target &selected_feature_names; 	*** FOR SUBSET OF COLUMNS;
run;

*** APPEND TRAINING EXAMPLES THAT ARE ALL ZEROS;
data missing;
	merge target(rename= (hkey= rownum) in= a) final_coo(in= b);
	by rownum;
	if a and ^b;
	keep rownum target;
run;
data missing;
	set missing;
/*	array tokens token1-token&ncols (&ncols*0); 	*** FOR FULL MATRIX; */
	array tokens &selected_feature_names (&ncols*0);*** FOR SUBSET OF COLUMNS;
	do i= 1 to dim(tokens);
		if tokens{i}= . then abort;
	end;
	drop i;
run;
proc append base= emcIsrael&ncols data= missing (rename= (rownum= hkey)); run;

*** BUILD A RANDOM FOREST CLASSIFIER *****************************************;

*** TRAIN FOREST;
*** SCORE TRAINING DATA;
*** FILL IN GRID INFO IF NECESSARY;
proc hpforest
	data= emcIsrael&ncols
	maxtrees= 50						/* LARGER NUMBER OF TREES FOR HIGHER ACCURACY */
	leafsize= 1;						/* LOWER LEAFSIZE FOR HIGHER ACCURACY */
	input token: / level= interval;
	target target / level= nominal;
	id target hkey;
	ods output FitStatistics= fitstats(rename= (Ntrees= Trees));
	performance nthreads= &cpu_count.;					/* FILL IN CORE INFO */
	score out= emcIsrael&ncols.Pred;
*	performance commit= 10000 nodes=  host= "" install= "";	/* FILL IN GRID INFO */
run;

*** PLOT FIT STATISTICS;
data fitstats;
	set fitstats;
	label Trees= 'Number of Trees';
	label MiscAll= 'Full Data';
	label Miscoob= 'OOB';
run;
proc sgplot data= fitstats;
	title "OOB vs Training";
	series x= Trees y= MiscAll;
	series x= Trees y= MiscOob / lineattrs= (pattern= shortdash thickness= 2);
	yaxis label= 'Misclassification Rate';
run;

*** OUTPUT MULTI-CLASS LOGARITHMIC LOSS TO LOG *******************************;
data ll;
	set emcIsrael&ncols.Pred end= eof;
	array posteriorProbs p_:;
	retain logloss 0;
	vname= 'P_target'||strip(put(target, best.));
	do i= 1 to dim(posteriorProbs);
		if vname(posteriorProbs[i])= vname then
			logloss + log(posteriorProbs[i]);
	end;
	if eof then do;
		logloss= (-1*logloss)/_n_;
		put logloss= ;
	end;
run;

******************************************************************************;

*** ANOTHER APPROACH IS TO USE PROC SPSVD (OR HPTMINE) TO GENERATE ROTATED SVD;
*** FEATURES DIRECTLY FROM THE COO DATA;

*** FOR PROC SPSVD ALL INDICES MUST GREATER THAN ONE;
data final_coo_gt1;
	set final_coo;
	colnum= colnum+1;
run;

*** GENERATE SVD FEATURES;
proc spsvd
	data= final_coo_gt1
	k= &ncols
	p= 50
	;
	row rownum;
	col colnum;
	entry value;
	output rowpro= emcisreal&ncols.svd;
run;

*** CREATE THE MODELING DATA SET BY MERGING WITH THE TARGET SET;
*** THIS SET COULD ALSO BE USED WITH A CLASSIFIER LIKE;
*** HPFOREST, HPNEURAL, HPBNET, ETC.;
data emcisreal&ncols.svd;
	merge target emcisreal&ncols.svd(rename= (INDEX= hkey));
	by hkey;
run;






