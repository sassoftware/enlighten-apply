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
* simple random projections example:                                         *;
* determine conservative number of random vectors to generate                *;
* generate random uniform i.i.d. vectors                                     *;
* execute original_features*transpose(random_generated_vectors) dot product  *;
*    to complete projection                                                  *;
******************************************************************************;

* set working directory;
%let git_repo_dir = ;
libname l "&git_repo_dir";

* conservatively determine the number of needed random vectors;
* choose epsilon, distance distortion introduced by a random projection is;
* factor of (1 +- epsilon);
%let epsilon = 0.1;
%macro determine_n_features(ds, epsilon);

	%global n_features;

	%let dsid = %sysfunc(open(&ds));
	%let nobs = %sysfunc(attrn(&dsid, NLOBS));
	%let _rc = %sysfunc(close(&dsid));

	data _null_;
		n_features = 4*log(&nobs)/(((&epsilon**2)/2)
			- ((&epsilon**3)/3));
		call symput('n_features', strip(put(ceil(n_features), best.)));
	run;

	%put n_features=&n_features.;

%mend; 
%determine_n_features(l.original_features, &epsilon);

* create Gaussian i.i.d. random features with data step;
%macro create_random_vectors(ds, k, out=random_generated_vectors, seed=12345);

	* create a macro array of input names in the training data;
	* necessary for using PROC SCORE;
	proc contents
		data=&ds.(drop=id) /* do not use id variable in calculation */
		out=names(keep=name)
		noprint;
	run;
	data _null_;
		set names end=eof;
		call symput('name'||strip(put(_n_, best.)), name);
		if eof then call symput('n_names', strip(put(_n_, best.)));
	run;

	* generate random row vectors for PROC SCORE;
	data &out;
		call streaminit(&seed);
		do i=1 to &k;
			_TYPE_='SCORE';
			_NAME_=compress('random_feature'||strip(put(i, best.)));
			%do j=1 %to &n_names;
				&&name&j = 2*rand('NORMAL')-1;
			%end;
 			output;
		end;
		drop i;
	run;

%mend;
%create_random_vectors(l.original_features, &n_features);

* project data onto random features with PROC SCORE;
* executes original_features*transpose(random_vectors) dot product;
proc score
	data=l.original_features
	type='SCORE' /* requests dot product multiplication */
	score=random_generated_vectors
	out=random_features(keep=random_feature:)
	nostd;
	var BE_: STD_:; /* do not use id variable in calculation */
	id id;
run;
