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

This is example will run in the free [SAS&reg; University Edition](http://www.sas.com/en_us/software/university-edition.html). If you are using the SAS University Edition to run this example, a convenient way to setup the example is to direct a shared folder of your virtual machine to the SAS_UE_SGF2016_faces folder. If you do so, you will likely set the GIT_REPO_DIR macro variable to the /folders/myshortcuts/SAS_UE_SGF2016_faces folder.

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

The eigenfaces approach uses principal components analysis to create a small number of representative faces in the train data, i.e. the eigenfaces. These representative faces are used as a lower-dimensional model of the train faces. Both the train faces and any new faces can be represented in the low-dimensional space a linear combination of the eigenfaces.

##### Creating the covariance matrix

![alt text](README_pics/Slide2.PNG "Creating the covariance matrix")

The IML procedure is used to create the covariance matrix from the train data.

```sas
M = A * A`;
```

##### Decomposition of the covariance matrix to create eigenfaces

![alt text](README_pics/Slide3.PNG "Decomposition of the covariance matrix to create eigenfaces")

```sas
call eigen(eigenvalues, eigenvectors, M);
pc = A`*eigenvectors[,1:&NUM_EIGENFACES.];
```

The IML procedure is then used to complete the eigendecomposition of the covariance matrix. 

In this simple example, only 6 eigenfaces are used to represent the train data due to the small size of train data. In a more realistic scenario where the train data might contain many more faces, a higher number of eigenfaces would be more appropriate. There are also many other ways to perform principal component analysis using SAS, including the PRINCOMP and HPPRINCOMP procedures.

##### Using eigenvector loadings to represent faces

![alt text](README_pics/Slide4.PNG "Using eigenvector loadings to represent faces")

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

To learn how to represent each train face as a low-dimsional linear combination of the eigenfaces, the REG procedure is used to regress each face in the train data against the 6 eigenfaces. The noint option in the model statement prevents the REG procedure from fitting an intercept (or bias) term, resulting in a vector of 6 regression parameters that can be used as low-dimensional representation of each face in the train data. The ods select stament is used to collect the parameter estimates. A SAS macro is used to run the REG procedure for each train face and to collect the resulting regression parameters in a single SAS data set.

#### Results

To test the accuracy of this simple eigenface model, the test data set is normalized and the REG procedure is used to find the low-dimensional representation of the test faces. The IML procedure is used to calculate the Euclidean distance between the train faces and the test faces, to find the closest test face for each train face, and to calculate the distance to the closest test face. The Euclidean distance in the low-dimensional space between a test face and a train face is used as a measure of similarity between the known train faces and new test faces. The DISTANCE procedure can also be used to caluclate distances in SAS.

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

We can see that the model is very successful at matching some of the train faces to some of the test faces. For the first 3 faces in the train data, it can be seen that the value of the closest_test_image variable matches the value of the train_image_index variable, indicating the corresponding faces from the train and test data are placed closest to one another in the low-dimensional eigenface space. The distance_to_test image variable indicates the Euclidean distance between the corresponding train and test faces. The distance_to_closest_test_image variable will be 0 in the case of an exact match between train and test faces. In the case where train and test faces are not matched exactly, the value of the distance_to_closest_test_image will be greater than 0 indicating that some other face in test data was closest to the train face.

![alt text](README_pics/results_table.png "Matching new faces to known faces")

A close inspection of the results will reveal that most test faces are not matched exactly to the corresponding face in the train data. However, the simple eigenfaces model does generally place corresponding train and test faces very close to one another in the low-dimensional eigenface space. Increasing the amount of train data and the number of eigenfaces would likely increase the classification accuracy of this simple model.

#### Testing

This example was tested in the following environment:

* Windows 7 Enterprise
* Intel i7-5600U @ 2.60 GHz
* 16 GB RAM
* SAS University Edition