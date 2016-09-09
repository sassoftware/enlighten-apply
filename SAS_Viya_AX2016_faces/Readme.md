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

## Discussion

**Note:** SAS Cloud Analytic Services (CAS) is the engine and associated cloud services in SAS Viya. To run the code in the following examples, you need to have a CAS server readily available.

### The ORL Database of Faces 

http://www.cl.cam.ac.uk/research/dtg/attarchive/facesataglance.html

There are ten different images of each of 40 distinct subjects. For some subjects, the images were taken at different times, varying the lighting, facial expressions (open / closed eyes, smiling / not smiling) and facial details (glasses / no glasses). All the images were taken against a dark homogeneous background with the subjects in an upright, frontal position (with tolerance for some side movement). The files are in PGM format.

### NNET1_origData.ipynb

To get started you need to set the path variable to the location of the image files. 

`path = "/path/to/att_faces"`

In this model there are five major steps:

1. Read in image files in PGM format and downsize the images to 90x90 pixels. Divide each image into 25 blocks, where each block is 16x16 pixels. You can save the blocks to JPG files for visulization. Covert each block to a 1x256 vector and concatenate all the blocks in an image into a 1x6400 vector.
2. Load the data into your CAS session.
3. Partition the data into train and validation sets. 9 out of 10 images from each person are used as training data through a random draw, and the remaining image is used as validation. 
4. Train a neural network individually on the blocks for all the images and predict the personID. Take majority voting from all the blocks for a given personID and make final decisions.
5. Calculate the misclassification rate in validation set.

### Eigenfaces.sas

To get started you must set the location of the face data at the top of the Eigenfaces.sas file. The `GIT_REPO_DIR` macro variable should be set to the directory containing allfaces.sas7bdat.

`%let GIT_REPO_DIR = /path/to/allfaces;`

This example uses principle component analysis (PCA) to represent the faces in a lower-dimensional space and then builds a regression based classifier to identify a person. There are four major steps.

1. Convert each image (64x64) into a 1x4096 vector and load the data to your CAS session.
2. Partition the data into train and validation sets. 9 out of 10 images from each person are used as training data through a random draw, and the remaining image is used as validation.
3. Calculate the PCs and the weights on the top 310 PCs for each image in the training set. Score the validation set by projecting the validation data onto the selected PCs. The images are represented in a lower-dimensional space.
4. Build a regression based classifier with the reduced dimensions and predict the personID.

### NNET2_LBP.ipynb:
To get started you need to set the path variable to the location of the image files. 

`path = "/path/to/att_faces"`

This example is similar to the example in NNET1_origData.ipynb. Instead of working on the original images, this example makes a LBP transformation on the raw pixels and obtains LBP features. It then repeats the five major steps as shown in NNET1_origData.ipynb.



