/******************************************************************************
Copyright (c) 2017 by SAS Institute Inc., Cary, NC 27513 USA
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
* SAS ROUTINES FOR TRAINING AND SCORING DATA THAT HAS MULTIPLE TARGET LEVELS *;
* USING THE ONE-VS-ALL APPROACH IN CONJUNCTION WITH SUPPORT VECTOR MACHINES  *;
*                                                                            *;
* STEPS:                                                                     *;
* CREATE A MACRO FOR TRAINING                                                *;
*     MODIFY INPUT DATA TO HAVE A TARGET COLUMN FOR EACH LEVEL OF THE TARGET *;
*     RUN AN SVM MODEL FOR EACH TARGET COLUMN AND SAVE THE SCORING CODE      *;
*     CREATE A TABLE THAT CONTAINS THE NAME OF THE SAVED SCORING CODE FILES  *;
* CREATE A MACRO FOR SCORING                                                 *;
*     RUN EACH SCORING CODE FILE ON THE SCORE DATA                           *;
*     ASSIGN THE TARGET BASED UPON THE HIGHEST PROBABILITY                   *;
*     CREATE A CONFUSION MATRIX FOR RESULTS VISUALIZATION                    *;
* SETUP TRAINING AND SCORING RUNS                                            *;
*     SETUP TRAINING AND SCORING DATA                                        *;
*     SETUP INPUT VARIABLES AND PARAMETERS                                   *;
*                                                                            *;
* FOR FURTHER INFORMATION ON ONE-VS-ALL AND OTHER MULTICLASS SVM APPROACHES: *;
* HSU, CHIH-WEI AND LIN, CHIH-JEN (2002). "A COMPARISON OF METHODS FOR       *;
* MULTICLASS SUPPORT VECTOR MACHINES." IEEE TRANSACTIONS OF NEURAL NETWORKS. *;
******************************************************************************;




******************************************************************************;
* BASIC SYSTEM AND METADATA SETUP *;
******************************************************************************; 
*** THE FOLLOWING CODE CREATES SEVERAL SAS DATA SETS AND SOME FILES;
*** TO ENSURE THAT NOTHING IS OVERWRITTEN, PLEASE CREATE A NEW DIRECTORY;
***     OR POINT TO AN EXISTING EMPTY DIRECTORY;
*** SET THE OUTPUT DIRECTORY BELOW;
%let OutputDir = U:\Demo\SGF2017\;

x cd "&OutputDir";
libname l "&OutputDir";



******************************************************************************;
* TRAINING MACRO                                                             *;
******************************************************************************; 
%macro SAS_SVM_ONE_VS_ALL_TRAIN();

*** SEPARATE OUT THE TARGET FOR INFORMATION GATHERING PURPOSES;
data l.TargetOnly;
    set &InputData;
    keep &Target;
    if MISSING(&Target) then delete;
run;

proc contents data = l.TargetOnly out=l.TType(keep = type);
run;

data _NULL_;
    set l.TType;
    call symput("TargetType", type);
run;

*** GET THE NUMBER OF LEVELS OF THE TARGET;
proc freq data=l.TargetOnly nlevels;
    ods output nlevels=l.TargetNLevels OneWayFreqs=l.TargetLevels;
run;

*** CREATE A VARIABLE, n, THAT IS THE NUMBER OF LEVELS OF THE TARGET;
data _NULL_;
    set l.TargetNLevels;
    call symput("n", left(trim(nlevels)));
run;

*** CREATE MACRO VARIABLES FOR EACH LEVEL OF THE TARGET;
data _NULL_;
    set l.TargetLevels;
    i = _N_;
    call symput("level"||left(trim(i)), trim(left(right(&Target.))));
run;

*** CREATE A COLUMN FOR EACH LEVEL OF THE TARGET;
*** THE VALUE OF THE COLUMN IS 1 IF THE TARGET IS THAT LEVEL, 0 OTHERWISE;
data l.ModifiedInput;
    set &InputData;
    _MY_ID_ = _N_;
    %do i=1 %to &n;
        %if (&TargetType = 1) %then %do;
		    if MISSING(&Target) then do;
			    &Target.&&level&i = .;
			end;
            else if (&Target = &&level&i) then do;
                &Target.&&level&i = 1;
            end;
            else do;
                &Target.&&level&i = 0;
            end;
        %end;
        %else %if (&TargetType = 2) %then %do;
            if MISSING(&Target) then do;
			    &Target.&&level&i = .;
			end;
            else if (&Target = "&&level&i") then do;
                &Target.&&level&i = 1;
            end;
            else do;
                &Target.&&level&i = 0;
            end;
        %end;
    %end;
run;

%let datetime_start = %sysfunc(TIME()) ;
%put START TIME: %sysfunc(datetime(),datetime14.);

*** RUN AN SVM FOR EACH TARGET. ALSO SAVE THE SCORING CODE FOR EACH SVM;
%do i=1 %to &n;
    %let Target&i = &Target.&&level&i;

    data _NULL_;
        length svmcode $2000;
        svmcode  = "&OutputDir"!!"svmcode"!!"&i"!!".sas";
        call symput("svmcode"||left(trim(&i)), trim(svmcode));
    run;

    proc hpsvm data = l.ModifiedInput tolerance = &Tolerance c = &C maxiter = &Maxiter nomiss;
        target &&Target&i;
        %if &INPUT_INT_NUM > 0 %then %do;
            input &INPUT_INT / level = interval;
        %end;
        %if &INPUT_NOM_NUM > 0 %then %do;
            input &INPUT_NOM / level = nominal;
        %end;
        *kernel linear;
        kernel polynomial / degree = 2;
        id _MY_ID_ &Target;
        code file = "&&svmcode&i";
    run;
%end;

*** THIS TABLE LISTS ALL OF THE SVM SCORING FILES;
data l.CodeInfoTable;
    length code $2000;
    %do i=1 %to &n;
        code = "&&svmcode&i";
        output;
    %end;
run;

%put END TIME: %sysfunc(datetime(),datetime14.);
%put ONE-VS-ALL TRAINING TIME:  %sysfunc(putn(%sysevalf(%sysfunc(TIME())-&datetime_start.),mmss.)) (mm:ss) ;

%mend SAS_SVM_ONE_VS_ALL_TRAIN;
******************************************************************************;
* END TRAINING MACRO                                                         *;
******************************************************************************;



******************************************************************************;
* SCORING MACRO                                                              *;
******************************************************************************;
*** THIS MACRO ALLOWS FOR SCORING NEW DATA (OR THE TRAINING DATA);
%macro SAS_SVM_ONE_VS_ALL_SCORE();

%let datetime_start = %sysfunc(TIME()) ;
%put START TIME: %sysfunc(datetime(),datetime14.);

*** RECORD THE TARGET TYPE: 1 = NUMERIC, 2 = CHARACTER;
data _NULL_;
    set l.TType;
    call symput("TargetType", type);
run;

*** CREATE A VARIABLE, n, THAT IS THE NUMBER OF LEVELS OF THE TARGET;
data _NULL_;
    set l.TargetNLevels;
    call symput("n", left(trim(nlevels)));
run;

*** CREATE MACRO VARIABLES FOR EACH LEVEL OF THE TARGET;
data _NULL_;
    set l.TargetLevels;
    i = _N_;
    call symput("level"||left(trim(i)), trim(left(right(&Target.))));
run;

*** READ THE CODE INFO TABLE AND CREATE MACRO VARIABLES FOR EACH CODE FILE;
data _NULL_;
    set l.CodeInfoTable;
    i = _N_;
    call symput("svmcode"||left(trim(i)), trim(left(right(code))));
run;

%do i=1 %to &n;
    %let Target&i = &Target.&&level&i;
%end;

*** SCORE THE DATA USING EACH SCORE CODE;
*** IN TOTAL, SCORE A NUMBER OF TIMES EQUAL TO THE NUMBER OF LEVELS OF THE TARGET;
*** FINALLY ASSIGN PREDICTED VALUE BASED UPON WHICH TARGET LEVEL HAS THE HIGHEST PROBABILITY;
%MakeScoredOneVsAll();

*** CREATE A CONFUSION MATRIX FOR RESULTS VIEWING PURPOSES;
%MakeConfusion();

%put END TIME: %sysfunc(datetime(),datetime14.);
%put ONE-VS-ALL SCORING TIME:  %sysfunc(putn(%sysevalf(%sysfunc(TIME())-&datetime_start.),mmss.)) (mm:ss) ;

%mend SAS_SVM_ONE_VS_ALL_SCORE;
******************************************************************************;
* END SCORING MACRO                                                          *;
******************************************************************************;



******************************************************************************;
* UTILITY MACROS                                                             *;
******************************************************************************;
*** MACRO TO MAKE THE SCORED OUTPUT FOR ONE_VS_ALL;
%macro MakeScoredOneVsAll();
data l.ScoredOutput;
    set &ScoreData;
    %if (&TargetType = 2) %then %do;
        length I_&Target $ &TargetLength;
    %end;
    %do i=1 %to &n;
        %inc "&&svmcode&i";
    %end;
    keep 
    %do i=1 %to &n;
        P_&&Target&i..1
    %end;    
    %if (&ID_NUM > 0) %then %do;
        &ID
    %end;    
    I_&Target &Target;
    _P_ = 0;
    %do i=1 %to &n;
        %if (&TargetType = 1) %then %do;
            if (P_&&Target&i..1 > _P_) then do;
                _P_ = P_&&Target&i..1;
                I_&Target = &&level&i;
            end;
        %end;
        %else %if (&TargetType = 2) %then %do;
            if (P_&&Target&i..1 > _P_) then do;
                _P_ = P_&&Target&i..1;
                I_&Target = "&&level&i";
            end;
        %end;
    %end;
run;
%mend MakeScoredOneVsAll;



*** MACRO TO MAKE THE CONFUSION MATRIX;
%macro MakeConfusion();
data l.ConfusionMatrix _NULL_;
    set l.ScoredOutput end=last;
	%if (&TargetType = 2) %then %do;
	    length From_&Target $ &TargetLength;
	%end;
    retain
    %do i=1 %to &n;
        %do j=1 %to &n;
            temp&i._&j 
        %end;
    %end;
    0;
    %if (&TargetType = 1) %then %do;
        %do i=1 %to &n;
            if (&Target = &&level&i) then do;
                %do j=1 %to &n;
                    if (I_&Target = &&level&j) then do;
                        temp&i._&j = temp&i._&j+1;
                    end;
                %end;
            end;
        %end;
        if (last) then do;
            %do i=1 %to &n;
                From_&Target = &&level&i;
                %do j=1 %to &n;
                    To_&Target._&&level&j = temp&i._&j;
                %end;
                keep From_&Target
                %do j=1 %to &n;
                    To_&Target._&&level&j 
                %end;
                ;
                output l.ConfusionMatrix;
            %end;
        end;
    %end;
    %else %if (&TargetType = 2) %then %do;
        %do i=1 %to &n;
            if (&Target = "&&level&i") then do;
                %do j=1 %to &n;
                    if (I_&Target = "&&level&j") then do;
                        temp&i._&j = temp&i._&j+1;
                    end;
                %end;
            end;
        %end;
        if (last) then do;
            %do i=1 %to &n;
                From_&Target = "&&level&i";
                %do j=1 %to &n;
                    To_&Target._&&level&j = temp&i._&j;
                %end;
                keep From_&Target
                %do j=1 %to &n;
                    To_&Target._&&level&j 
                %end;
                ;
                output l.ConfusionMatrix;
            %end;
        end;
    %end;
run;
%mend MakeConfusion;
******************************************************************************;
* END UTILITY MACROS                                                         *;
******************************************************************************;




******************************************************************************;
* RUN THE TRAINING AND SCORING MACROS                                        *;
******************************************************************************; 
*** DATA SETUP;

*** SET THE TARGET VARIABLE;
*** ALSO SET THE INPUT AND SCORE DATA SETS;
*** YOU CAN CHANGE THE SCORE DATA SET EVERY TIME YOU WANT TO SCORE A NEW DATA SET;
%let Target    = Species; *CASE SENSITIVE;
%let InputData = sashelp.iris;
%let ScoreData = sashelp.iris;

*** SHOW POSSIBLE INPUT VARIABLES FOR CONVENIENCE;
proc contents data =&InputData out=names (keep = name type length);
run;
data names;
    set names;
    if name = "&Target" then do;
        call symput("TargetLength", length);
        delete;
    end;
run;

*** MANUALLY ADD NAMES TO INTERVAL OR NOMINAL TYPE DEPENDING ON USE CASE ***;
*** ID VARIABLES ARE SAVED FROM THE INPUT DATA TO THE SCORED OUTPUT DATA ***;

%let ID        = PetalLength PetalWidth SepalLength SepalWidth;
%let INPUT_NOM = ;
%let INPUT_INT = PetalLength PetalWidth SepalLength SepalWidth;
%let ID_NUM        = 4;
%let INPUT_NOM_NUM = 0;
%let INPUT_INT_NUM = 4;

*** HPSVM OPTIONS FOR THE USER (OPTIONAL);
%let Maxiter   = 25;
%let Tolerance = 0.000001;
%let C         = 1;


%SAS_SVM_ONE_VS_ALL_TRAIN();


*** IF YOU HAVE ALREADY RUN TRAIN, YOU CAN RUN SCORING AS MANY TIMES AS YOU WANT;
*** WITH NEW DATA, PROVIDED THAT THE PROPER TRAINING FILES STILL EXIST IN THE OUTPUT DIRECTORY;

%SAS_SVM_ONE_VS_ALL_SCORE();