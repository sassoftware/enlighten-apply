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

This example uses a sample of faces from the famous [AT&T face database](http://www.cl.cam.ac.uk/research/dtg/attarchive/facesataglance.html) to illustrate the eigenfaces facial recognition approach using Base SAS&reg;, SAS/STAT&reg;, and SAS/IML&reg;. In the original face database there are 10 pictures of 40 people, for a total of 400 faces. In this example, one image of each person is used as the train set and one different image of each person is used as the test data. A simple model of the train data is created using 6 eigenfaces. An eigenface is a representative face constructed from the principal components of the train data. This simple model is then used to match the faces in the test data to the most similar face in the train data.


To get started you must set the location of the face data at the top of the faces.sas file. The GIT_REPO_DIR macro variable should be set to the directory containing the faces.sas and faces.sas7bdat file.

```sas
%let GIT_REPO_DIR = /path/to/enlighten-apply/SAS_UE_SGF2016_faces;
```

This example will run in the free [SAS&reg; University Edition](http://www.sas.com/en_us/software/university-edition.html). If you are using the SAS University Edition to run this example, a convenient way to setup the example is to direct a shared folder of your virtual machine to the SAS_UE_SGF2016_faces folder. If you do so, you will likely set the GIT_REPO_DIR macro variable to the /folders/myshortcuts/SAS_UE_SGF2016_faces folder.

```sas
%let GIT_REPO_DIR = /folders/myshortcuts/SAS_UE_SGF2016_faces;
```

#### Preprocessing

![alt text](README_pics/Slide1.PNG "Preprocessing")

As a preprocessing step, the mean face in the train data is subtracted from all the faces in the train data. The MEANS procedure is used to determine the average face.

```sas
proc means data=trainfaces noprint nway;
  var feature1-feature4096;
  output out=averageface(drop=_TYPE_ _FREQ_) mean=;
run;
```

A SAS DATA step is then used to perform the subtraction.

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

The eigenfaces approach uses principal components analysis (PCA) to create a small number of representative faces in the train data, i.e. the eigenfaces. These representative faces are used as a lower-dimensional model of the train faces. Both the train faces and any new faces can be represented in the low-dimensional space by a linear combination of the eigenfaces.

##### Creating the covariance matrix

![alt text](README_pics/Slide2.PNG "Creating the covariance matrix")

The IML procedure is used to create the covariance matrix from the train data.

```sas
M = A * A`;
```

##### Decomposition of the covariance matrix to create eigenfaces

![alt text](README_pics/Slide3.PNG "Decomposition of the covariance matrix to create eigenfaces")

The IML procedure is then used to complete the eigendecomposition of the covariance matrix. 

```sas
call eigen(eigenvalues, eigenvectors, M);
pc = A`*eigenvectors[,1:&NUM_EIGENFACES.];
```

In this simple example, only 6 eigenfaces are used to represent the train data due to the small size of train data. In a more realistic scenario where the train data might contain many more faces, a higher number of eigenfaces would be more appropriate. There are also many other ways to perform PCA using SAS, including the PRINCOMP and HPPRINCOMP procedures.

## Testing

This example was tested in the following environment:

* Windows 7 Enterprise
* Intel i7-5600U @ 2.60 GHz
* 16 GB RAM
* VMware Workstation 12 Player
* SAS University Edition