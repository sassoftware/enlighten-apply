******************************************************************************;
* Copyright (c) 2016 by SAS Institute Inc., Cary, NC 27513 USA               *;
*                                                                            *;
* Licensed under the Apache License, Version 2.0 (the "License")             *;
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

%let GIT_REPO_DIR = ;

*** system options;

%let NUM_EIGENFACES = 310;
libname faces "&git_repo_dir";

options casuser=ruzhan cashost='<host>' casport=<port>;
options casinstall='/opt/vb005/laxno/TKGrid';

cas mysess1 host="rdcgrd001" port=xxxxx user=xxxxx;

libname mycas sasioca sessref=mysess1 ;

data mycas.allfaces;
    set faces.allfaces;
run;

proc partition data=mycas.allfaces samppct = 10 partind ;
    by id;
    output out=mycas.allfacespart ;
run;

proc pca data=mycas.allfacespart(where=(_PartInd_=1))
              n=&NUM_EIGENFACES method=NIPALS (noscale);
    var feature1-feature4096;
    display /excludeall;
    displayout Loadings=loadings;
    output out=mycas.normalizedfaces STD SCORE COPYVARS=ID;
    code file = 'pcaCode.sas'
run;

data mycas.pcaScore;
    set mycas.allfacespart(where=(_PartInd_=0));
    %include pcaCode;
run;

data mycas.normalizedfaces;
    set mycas.normalizedfaces mycas.pcaScore;
run;

proc logselect data=mycas.normalizedfaces;
    model ID=feature1-feature4096;
    output out=mycas.pred COPYVARS=ID;
run;

