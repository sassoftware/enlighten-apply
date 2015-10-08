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
* SECTION 1: Hello World! - Standard SAS Output                              *;
******************************************************************************;

* the _null_ data step allows you to execute commands;
* or read a data set without creating a new data set;
data _null_;
	put 'Hello world!';
run;

* print the value of a variable to the log;
* VERY useful for debugging;
data _null_;
	x = 'Hello world!';
	put x;
	put x=;
run;

* file print writes to the open standard output;
* usually html or listing;
data _null_;
	file print;
	put 'Hello world!';
run;

* logging information levels;
* use these prefixes to print important information to the log;
data _null_;
	put 'NOTE: Hello world!';
	put 'WARNING: Hello world!';
	put 'ERROR: Hello world!';
run;

* you can also use the put macro statement;
%put Hello world!;
%put NOTE: Hello world!;
%put WARNING: Hello world!;
%put ERROR: Hello world!;

%put 'Hello world!'; /* macro variables are ALWAYS strings */

* the macro preprocessor resolves macro variables as text literals;
* before data step code is executed;
%let x = Hello world!;
%put &x;
%put '&x'; /* single quotes PREVENT macro resolution */
%put "&x"; /* double quotes ALLOW macro resolution */