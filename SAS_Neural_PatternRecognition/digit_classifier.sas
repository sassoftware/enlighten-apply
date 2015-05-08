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

******************************************************************************;
* VARIOUS SAS ROUTINES FOR MNIST DATA:                                       *;
* CALCULATE PIXEL DENSITY                                                    *;
* RESIZE GRID ON WHICH PIXELS CAN BE CENTERED (ODD# X ODD#)                  *;
* VISUALIZE INPUT DIGITS WITH TRANSFORMATIONS                                *;
* CLASSIFY DIGITS WITH A SINGLE LAYER NEURAL NET                             *;
* CHECK PREDICTIONS                                                          *;
******************************************************************************;

*** SET WORKING DIRECTORY TO REPO DOWNLOADED FROM GIT;
%let git_repo_data_dir= ;
libname l "&git_repo_data_dir";
%let train_set= Digits_train_sample;

*** SET CPU COUNT;
%let cpu_count= ;

*** OUTPUT OPTIONS;
ods listing close;
ods html close;
ods html;

*** ADD PRIMARY KEY TO TRAINING DATA *****************************************;
*** MAKE TEMP COPY - DO NOT ALTER ORIGINAL DATA ******************************;

data &train_set;
	length pic_ID 8;
	set l.&train_set;
	pic_ID= _n_;
run;

*** TRANSFORM PIXELS INTO XY PLANE WITH Z CONTOURS ***************************;

data _xyz;
    set &train_set;
    array pixels pixel0-pixel783;
    do j= 1 to 784;
        pic_ID= pic_ID;
        label= label;
        x= j-28*floor((j-1)/28);
        y= 29-ceil(j/28);
        z= pixels(j);
        output;
    end;
    drop j pixel0-pixel783;
run;

*** CALCULATE PIXEL DENSITY IN XY SPACE **************************************;
*** DENSITY ~ INTENSITY;

data _d;
    set _xyz;
    by pic_ID;
    retain _sum 0;
    _sum= _sum + z;
    if last.pic_ID then do;
        density= _sum/(28*28);
        output;
        _sum= 0;
    end;
    keep pic_ID density;
run;

*** MERGE RESULTS ONTO TRAINING SET;
data &train_set._dn;
	length pic_ID label density pixel0-pixel783 8;
	merge &train_set _d;
	by pic_ID;
run;


*** CENTER *******************************************************************;

*** DIFFICULT TO CENTER DIGITAL IMAGE/CANNOT BE CENTERED ON EVEN BY EVEN GRID;
*** (ORIGIN= 14.5, 14.5)
*** CREATE ODD BY ODD GRID;
*** (ORIGIN= 14, 14);

*** REMOVE OUTER PIXELS;
data &train_set._dn;
	set &train_set._dn;
	drop pixel0-pixel27 pixel28 pixel56 pixel84 pixel112 pixel140 pixel168
	pixel196 pixel224 pixel252 pixel280 pixel308 pixel336 pixel364 pixel392
	pixel420 pixel448 pixel476 pixel504 pixel532 pixel560 pixel588 pixel616
	pixel644 pixel672 pixel700 pixel728 pixel756;
run;

*** REMAP PIXEL NAMES TO 27 BY 27 GRID;
data _new;
    do new= 0 to ((27*27)-1);
        output;
    end;
run;
data _new;
    set _new;
    match= _n_;
run;

data _old;
    do i=0 to 755;
        if mod((i+28),28)^= 0 then do;
            old= i+28;
            output;
        end;
        else continue;
        drop i;
    end;
run;
data _old;
    set _old;
    match= _n_;
run;

filename rnm_stmt "%sysfunc(pathname(WORK))\rnm_stmt.sas";
data _null_;
    merge _new _old;
    by match;
    file rnm_stmt;
    if _n_= 1 then put "proc datasets nolist noprint lib=WORK; modify &train_set._dn; rename";
    line= 'pixel'||trim(left(old))||' = pixel'||trim(left(new));
    put line;
    if _n_= 27*27 then put '; run; quit;';
run;
%include rnm_stmt;
filename rnm_stmt;

*** CALCULATE COORDINATES OF BOX SURROUNDING EACH DIGIT **********************;

*** RE-TRANSFORM PIXELS INTO XY PLANE WITH Z CONTOURS;
data _xyz;
    set &train_set._dn;
    array pixels pixel0-pixel728;
    do j= 1 to 729;
        pic_ID= pic_ID;
        label= label;
        x= j-27*floor((j-1)/27);
        y= 28-ceil(j/27);
        z= pixels(j);
        output;
    end;
    drop j pixel0-pixel728;
run;

*** CALCULATE COORDINATES OF BOX SURROUNDING EACH DIGIT;
proc sort
	data= _xyz(keep= pic_ID x z where=(z^= 0))
	out=_max_x
	sortsize= MAX
	threads;
	by pic_ID descending x;
run;
data _max_x;
    set _max_x;
    retain max_x;
    by pic_ID;
    if first.pic_ID then max_x= x;
    if last.pic_ID then do;
        min_x= x;
        output;
    end;
    drop x z;
run;

proc sort
	data= _xyz(keep= pic_ID y z where=(z^= 0))
	out=_max_y
	sortsize= MAX
	threads;
	by pic_ID descending y;
run;
data _max_y;
    set _max_y;
    retain max_y;
    by pic_ID;
    if first.pic_ID then max_y= y;
    if last.pic_ID then do;
        min_y= y;
        output;
    end;
    drop y z;
run;

*** CENTER DIGITS;
data _xyz;
    merge _xyz _max_x _max_y;
    by pic_ID;
    x_mid= round((max_x - min_x)/2 + min_x,1);
    y_mid= round((max_y - min_y)/2 + min_y,1);
    if x_mid^= 14 then do;
        x_offset= x_mid - 14; /* x offset is units RIGHT of the origin */
        x= x-x_offset;
        if x > 27 then x= 27;
        if x < 1 then x= 1;
    end;
    if y_mid^= 14 then do;
        y_offset= y_mid - 14; /* y offset is units ABOVE the origin */
        y= y-y_offset;
        if y > 27 then y= 27;
        if y < 1 then y= 1;
    end;
    if z^= 0;
run;

*** TRANSFORM FROM XY SPACE TO PIXEL SPACE;
filename rnm_stmt "%sysfunc(pathname(WORK))\rnm_stmt2.sas";
data _null_;
    file rnm_stmt;
    put "data &train_set._dn_cn;";
    put 'set _xyz;';
    put 'by pic_ID;';
    put 'array pixels pixel0-pixel728;';
    put 'retain pixels;';
    do y= 1 to 27;
        do x= 1 to 27;
            _y= 28-y;
            i= (y-1)*27 + x;
            put 'if x= ' x' and y= ' _y' then pixels[' i']= z;';
            put 'if pixels[' i']= . then pixels[' i']= 0;';
            output;
        end;
    end;
    put 'if last.pic_ID then do;';
    put 'output;';
    put 'do i= 1 to 729;';
    put 'pixels[i]= 0;';
    put 'end;';
    put 'end;';
    put 'drop x y z max_x min_x max_y min_y x_offset y_offset i x_mid y_mid;';
    put 'run;';
run;
%include rnm_stmt;
filename rnm_stmt;
/* THIS SET IS NOW SUITABLE FOR SUPERVISED TRAINING IN ENTEPRISE MINER */

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
		r= floor(&_nobs*ranuni(&_seed));
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
%view_inputs(&train_set._dn_cn, 27);

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
		proc transpose
			data= _p (keep= p_:)
			out= _pt (drop= _name_);
		run;
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
proc means data= &train_set._dn_cn (keep= density pixel:) noprint;
	var density pixel:;
	output out= o (keep= _STAT_ density pixel: where= (_STAT_= 'MAX'));
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

*** TRAIN NEURAL NETWORK *****************************************************;

proc hpneural
	data= &train_set._dn_cn;
	input &inputs;
	hidden &n_inputs; /* THIS IS THE NUMBER OF NON-CONSTANT INPUTS */
	target label / level= nom;
	id pic_ID;
	train numtries= 1 maxiter= 50 opt= lbfgs valid= none;
	performance nthreads= &cpu_count details;
	score out= &train_set._dn_cn_score;
run;
/* SEE OUTPUT FOR DETAILED FIT STATISCTICS */

*** SEE A FEW PREDICTIONS ****************************************************;
data &train_set._dn_cn_score;
	merge &train_set._dn_cn &train_set._dn_cn_score;
	by pic_ID;
	keep pic_ID label density pixel: p_:;
run;
data &train_set._dn_cn_samp;
	do i= %random_digit_string(&_length, &_nobs);
		obs= i;
		set &train_set._dn_cn_score point= obs;
		output;
	end;
	stop;
run;
options mprint;
%view_results(&train_set._dn_cn_samp, 27);
