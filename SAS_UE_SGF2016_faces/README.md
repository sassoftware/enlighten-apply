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

#### Preprocessing

![alt text](README_pics/Slide1.PNG "Preprocessing")

#### Principal component analysis

##### Creating the covariance matrix

![alt text](README_pics/Slide2.PNG "Creating the covariance matrix")

##### Decomposition of the covariance matrix to create eigenfaces

![alt text](README_pics/Slide3.PNG "Decomposition of the covariance matrix to create eigenfaces")

##### Using eigenvector loadings to represent face images

![alt text](README_pics/Slide4.PNG "Using eigenvector loadings to represent face images")

#### Results

![alt text](README_pics/results_table.png "Matching new faces to known faces")

#### Testing

This example was tested in the following environment:

* Windows 7 Enterprise
* Intel i7-5600U @ 2.60 GHz
* 16 GB RAM
* SAS University Edition