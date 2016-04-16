## License

Copyright (c) 2016 by SAS Institute Inc., Cary, NC 27513 USA

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied
See the License for the specific language governing permissions and 
limitations under the License.

## Instructions

### Install required software 

Git client: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git

Git lfs client https://git-lfs.github.com/

SAS University Edition: http://www.sas.com/en_us/software/university-edition.html

### Fork and pull materials

Fork the enlighten-apply repository from: https://github.com/sassoftware/enlighten-apply

![alt text](README_pics/fork.png "Fork this repo!")

Enter the following statements on the git bash command line:

`$ mkdir enlighten-apply`


`$ cd enlighten-apply`


`$ git init`


`$ git remote add origin https://github.com/<your username>/enlighten-apply.git`


`$ git remote add upstream https://github.com/sassoftware/enlighten-apply.git`


`$ git pull origin master`


`$ git lfs install`


`$ git lfs track "*.jpg"`


`$ git lfs track "*.png"`


### Educational eigenfaces example

```sas
%let GIT_REPO_DIR = /path/to/enlighten-apply/SAS_UE_SGF2016_faces;
```

#### Preprocessing

![alt text](README_pics/Slide1.PNG "Preprocessing")

```sas
proc means data=trainfaces noprint nway;
  var feature1-feature4096;
  output out=averageface(drop=_TYPE_ _FREQ_) mean=;
run;
```

```sas
data normalizedtrain;
  set averageface trainfaces;
  array feature feature1-feature4096;
  array normalface normalface1-normalface4096;
  retain normalface;
  if id = 0 then do;
    do i=1 to 4096;
      normalface[i] = feature[i];
    end;
  end;
  do i=1 to 4096;
    normalface[i] = feature[i]-normalface[i];
  end;
  drop feature1-feature4096 i;
  if id = 0 then delete;
  drop id;
run;
```

#### Principal component analysis

##### Creating the covariance matrix

![alt text](README_pics/Slide2.PNG "Creating the covariance matrix")

```sas
M = A * A`;
```

##### Decomposition of the covariance matrix to create eigenfaces

![alt text](README_pics/Slide3.PNG "Decomposition of the covariance matrix to create eigenfaces")

```sas
call eigen(eigenvalues, eigenvectors, M);
```

##### Using eigenvector loadings to represent face images

![alt text](README_pics/Slide4.PNG "Using eigenvector loadings to represent face images")

```sas
ods select parameterestimates;
proc reg data=&_ds plots=none;
  model face&id = pc1-pc&NUM_EIGENFACES. / noint;
  ods output parameterestimates=paramests(keep=variable estimate);
run;
```

```sas
%do i=1 %to &n;

  %regression_model(id=&i, _ds=&ds, _role=&role);

%end;
```

#### Results

![alt text](README_pics/results_table.png "Matching new faces to known faces")

```sas
do i=1 to 40 by 1;

  D = Tr-Ts[,i];
  distance[,i] = vecdiag(D`*D);
  _output[i,2] = distance[i,i];

  minindex = distance[>:<,i];
  _output[i,3] = minindex;

  _output[i,4] = _output[i,2] - distance[minindex,i];

end;
```

#### Testing

This example was tested in the following environment:

* Windows 7 Enterprise
* Intel i7-5600U @ 2.60 GHz
* 16 GB RAM
* SAS University Edition