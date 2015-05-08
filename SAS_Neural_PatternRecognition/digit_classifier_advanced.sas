/******************************************************************************
Copyright (c) 2015 by SAS Institute Inc., Cary, NC 27513 USA

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

******************************************************************************/

*******************************************************************************;
* VARIOUS SAS AND PYTHON ROUTINES FOR MNIST DATA:                              ;
* CALL PYTHON TO NORMALIZE THE DIGITS                                          ;
* VISUALIZE INPUT DIGITS WITH TRANSFORMATIONS                                  ;
* CLASSIFY DIGITS WITH A DEEP NEURAL NET                                       ;
* CHECK PREDICTIONS                                                            ;
*******************************************************************************;

*** SET WORKING DIRECTORY TO REPO DOWNLOADED FROM GIT;
%let git_repo_dir= ;

*** SET SYSTEM DIRECTORY SEPARATOR;
%let _SYSSCP= %index(&SYSSCP, WIN);
data _null_;
	if &_SYSSCP then call symput('dsep', '\');
	else call symput('dsep', '/');
run;

*** SET CPU COUNT;
%let cpu_count= ;

*** SET THE PYTHON COMMAND;
%let python_exec_command= ;

*** SYSTEM OPTIONS ***********************************************************;
%let git_repo_data_dir= &git_repo_dir.&dsep.data;
libname l "&git_repo_data_dir";
%let train_set= Digits_train_sample;

*** OUTPUT OPTIONS;
ods listing close;
ods html close;
ods html;

*** IMAGE PREPROCESSING ******************************************************;

*** ESTABLISH FILENAME AND MACRO VAR FOR JAVA CONNECTION TO PYTHON;
filename pysubmit "&git_repo_dir.&dsep.digit_preprocess_py.py";

*** EXECUTE PYTHON PREPROCESSING;
data _null_;
	length rtn_val 8;
	python_script= "%sysfunc(pathname(pysubmit))";
	python_call= cat('"', trim(python_script), '" "', trim("&git_repo_data_dir"), '"');
	declare javaobj j("dev.SASJavaExec", "&python_exec_command", python_call);
	j.callIntMethod("executeProcess", rtn_val);
run;

*** IMPORT PYTHON PREPROCESSED DIGITS INTO SAS FORMAT;
proc import
	out= &train_set
	datafile= "&git_repo_data_dir.&dsep.digits_train_sample_processed.csv"
	dbms= csv
	replace;
	getnames= yes;
	datarow= 2;
run;

data &train_set.;
	set &train_set.;
	pic_ID= _n_;
run;

*** MACROS USED TO VIEW RANDOM DIGITS ****************************************;

*** GTL TEMPLATE;
ods path show;
ods path(prepend) work.templat(update);
proc template; /* DEFINE A GRAPH TEMPLATE */
      define statgraph contour;
            dynamic _title;
            begingraph;
                  entrytitle _title;
                  layout overlayequated / equatetype= square
                              commonaxisopts= (viewmin= 0 viewmax= 26
                                  tickvaluelist= (0 5 10 15 20 25))
                              xaxisopts= (offsetmin= 0 offsetmax= 0)
                              yaxisopts= (offsetmin= 0 offsetmax= 0);
                  contourplotparm x= x y= y z= z /
                              contourtype= gradient nlevels= 255
                                  colormodel= twocolorramp;
                  endlayout;
            endgraph;
      end;
run;

*** MACROS FOR VEIWING DIGITS;
%global _length _nobs _seed;
%let _length= 10;
%let _nobs= 2000;
%let _seed= %sysfunc(floor(%sysfunc(time())));
data _r;
	length r 8;
	do i= 1 to &_length;
		r= floor(&_nobs*ranuni(&_seed)+1);
		output;
	end;
run;
proc sort data= _r; by r; run;
data _null_;
	set _r;
	call symput(left(compress('rand'||_n_)), r);
run;

%macro random_digit_string(_length, _nobs);

	%sysfunc(compress(
	%do i= 1 %to %eval(&_length - 1);
		&&rand&i %str(,)
	%end;
	&&rand&i
	))

%mend random_digit_string;

%macro view_inputs(DS, DIM);

	%global _length;
	%global _nobs;

	data _xyz;
		do i= %random_digit_string(&_length, &_nobs);
			obs= i;
			set &DS point= obs;
			array pixels pixel: ;
			do i= 1 to %eval(&dim*&dim);
				x= (i-&dim*floor((i-1)/&dim))-1;
				y= (%eval(&dim+1)-ceil(i/&dim))-1;
				z= pixels[i];
				output;
				keep pic_ID x y z;
			end;
		end;
	stop;
	run;

	proc sgrender data= _xyz template= contour;
		dynamic _title= "Digit Image";
		by pic_ID;
	run;

%mend;
%view_inputs(&train_set., 27);
*********************************************************************;
* RUN TO HERE TO SEE PREPROCESSING RESULTS                          *;
*********************************************************************;

%macro view_results(DS, DIM);

	%global _length;
	%global _nobs;

	%let random_digit_string= %random_digit_string(&_length, &_nobs);
	%let random_digit_string= %sysfunc(tranwrd(%quote(&random_digit_string),%str(,), ));
	%do i= 1 %to &_length;
		%let j= %scan(&random_digit_string, &i);
		data _xyz;
			set &DS (where= (pic_ID= &j));
			array pixels pixel: ;
			do i= 1 to %eval(&dim*&dim);
				x= (i-&dim*floor((i-1)/&dim))-1;
				y= (%eval(&dim+1)-ceil(i/&dim))-1;
				z= pixels[i];
				output;
				keep pic_ID x y z;
			end;
		run;

		proc sgrender data= _xyz template= contour;
			dynamic _title= "Input Image";
		run;

		data _p;
			set &DS (where= (pic_ID= &j) keep= p_: pic_ID);
		run;
		proc transpose data= _p (keep= p_:) out= _pt (drop= _name_); run;
		proc sort data= _pt; by descending col1; run;
		data _pt;
			set _pt(obs= 1);
			label _LABEL_= 'Digit Value';
			keep _LABEL_;
		run;
		title 'Top Prediction';
		proc print data= _pt noobs label; run;
		title;

	%end;

%mend;

*** METADATA PREP FOR TRAINING ***********************************************;

*** CREATE MACROS FOR VAR NAMES;
*** DROP PIXELS THAT ARE ALWAYS ZERO;
proc means data= &train_set (keep= pixel:) noprint;
	var pixel:;
	output out= o (keep= _STAT_ pixel: where= (_STAT_= 'MAX'));
run;
proc transpose data= o out= ot; run;
proc sql noprint;
	select _NAME_ into :inputs separated by ' '
	from ot
	where col1 ne 0;
	select count(_NAME_) into :n_inputs
	from ot
	where col1 ne 0;
quit;
%let inputs= &inputs;
%put inputs= &inputs;
%put n_inputs= &n_inputs;

*** TRAIN DEEP NEURAL NETWORK ************************************************;

*** REQUIRED CATALOG FOR PROC NEURAL;
proc dmdb
	data= &train_set
	dmdbcat= work.cat_&train_set.;
	var &inputs;
	class label;
	id pic_ID;
run;

*** REDIRECT LONG LIST OF PARAMETERS;
ods html close;
ods listing;
filename out "%sysfunc(pathname(WORK))\clusterout%sysfunc(compress(%sysfunc(datetime(), datetime23.),:)).txt";
proc printto print= out; run;

*** TRAIN DENOISING AUTOENCODER;
proc neural

	data= &train_set
	dmdbcat= work.cat_&train_set.
	random= 12345;
	performance compile details cpucount= &cpu_count threads= yes;

	netoptions decay= 0.1; /* L2 PENALTY */

	archi MLP hidden= 3;
	hidden &n_inputs / id= h1;
	hidden %eval(&n_inputs/2) / id= h2;
	hidden 10 / id= h3;

	input &inputs / std= no id= i level= int;
	target label / std= no id= t level= nom;

	initial infan= 1;
	prelim 10 preiter= 10;

	/* TRAIN LAYERS SEPARATELY */
	freeze h1->h2;
	freeze h2->h3;
	train maxtime= 10000 maxiter= 5000;

	freeze i->h1;
	thaw h1->h2;
	train maxtime= 10000 maxiter= 5000;

	freeze h1->h2;
	thaw h2->h3;
	train maxtime= 10000 maxiter= 5000;

	/* RETRAIN ALL LAYERS SIMULTANEOUSLY */
	thaw i->h1;
	thaw h1->h2;
	train maxtime= 10000 maxiter= 5000;

	score
		data= &train_set.
		outfit= &train_set._fit
		out= &train_set._score
		role= TRAIN;

run;

*** RECAPTURE HTML OUTPUT;
proc printto; run;
ods listing close;
ods html;

*** PRINT FITTING RESULTS;
proc print
	data= &train_set._fit
	noobs;
run;

*** SEE A FEW PREDICTIONS ****************************************************;
data &train_set._samp;
	do i= %random_digit_string(&_length, &_nobs);
		obs= i;
		set &train_set._score point= obs;
		output;
	end;
	stop;
run;
options mprint;
%view_results(&train_set._samp, 27);
