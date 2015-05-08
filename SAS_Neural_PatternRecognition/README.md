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

SAS_Pattern_Recognition_Examples

===============

Code and materials for pattern recognition with SAS.

Be sure to unzip the data!

These examples where tested in the following environment:

Windows Server 2008 R2 Enterprise

Dual Intel Xeon E5-2667 @ 2.9 GHz 

128 GB RAM 

SAS 9.4 (TS1M2)

SAS Enterprise Miner 13.2

Python 2.7 (with OpenCV and NumPy)

Oracle JDK 1.7.0_25

===============

digit_classifier.sas

===============

1.) Download (and unzip) or clone the SAS_Deep_Learning_Examples repository 
to a directory referred to as {WORK_DIR}.

2.) Unzip example data file (data.zip) so that the following files are 
extracted to {WORK_DIR}\data

digits_train_sample.csv
digits_train_sample.sas7bdat

3.) Open the digit_classifier.sas file in a standard DMS SAS Session. 

4.) Set the git_repo_data_dir macro variable to the (unzipped!) data 
subdirectory of the repository i.e., {WORK_DIR}\data

5.) Set the cpu_count macro variable to an integer less than or equal to the
number of physical CPU cores on your system. 

6.) Submit the entire file. 

Discussion of Results:

This is a basic example of pattern recognition using an easy data set and 
a traditional neural network model. 

The sample MNIST data is part of a famous data set that contains thousands of 
handwritten digit images with labels from 0 through 9. Correctly labeling
these digit images is a classic problem in machine learning research. (The 
full MNIST data are widely available.) 

In this demo, pixel density, or intensity, is calculated and added to the model
inputs. The digits are also centered and the outer pixels that always have
an intensity of 0 are dropped from the analysis. The digit images are then fed
to a 1-layer MLP neural network to be classified. 

It is very typical for a neural network to achieve 100% training accuracy as 
should occur here. After being correctly tuned SAS technologies, especially
PROC NEURAL and HPNEURAL, should achieve 98-99% correct classification for 
hold-out sets on this and other popular pattern recognition problems. Also, 
convolutional neural networks are the state-of-the-art in pattern recognition. 
PROCs NEURAL and HPNEURAL do not support this architecture. 

===============

digit_classifier_advanced.sas

===============

0.) This example assumes that Python is installed on the same machine as SAS 
with the following packages:
- OpenCV
- NumPy

1.) Download (and unzip) or clone the SAS_Deep_Learning_Examples repository 
to a directory referred to as {WORK_DIR}.

2.) Compile provided Java class in {WORK_DIR}\src\dev directory. To do that, 
change directories to {WORK_DIR} and issue the following javac command. 
This operation assumes JDK is part of the PATH environment variable.

cd {WORK_DIR}
javac src/dev/* -d bin

3.) Add the line

-SET CLASSPATH "{WORK_DIR}\bin" to the command you use to invoke SAS

OR 

-SET CLASSPATH "{WORK_DIR}\bin" to the main SASv9.CFG file for the SAS install 
(SASHome\SASFoundation\9.4\nls\en\SASV9.CFG)

See http://support.sas.com/resources/papers/proceedings12/008-2012.pdf pages 
3-4 for more examples of setting your CLASSPATH for SAS on Windows. 
	
4.) Open the digit_classifier_advanced.sas file in a standard DMS SAS Session. 

5.) Set the git_repo_dir macro variable to the (unzipped!) directory of the 
downloaded repository {WORK_DIR}.

6.) Set the cpu_count macro variable to an integer less than or equal to the
number of physical CPU cores on your system. 

7.) Set the python_exec_command macro variable to your systems Python 
executable, for instance

C:\Python27\python
/usr/bin/python

8.) Submit the file until the %view_inputs(&train_set., 27) call at line 160 
to see the results of the preprocessing. 

9.) Run the remainder of the file to train a deep neural network for digit
classification. This step might take a while depending on the hardware used
- with the above mentioned configuration (Dual Intel Xeon E5-2667 @ 2.9 GHz,
128G RAM) and cpu_count=12, it completed in approximately 2.5 hours.

NOTE: On Windows running Anaconda Python 2.7, OpenCV is not installable 
through conda. Use the following instructions to install OpenCV in that 
scenario:

a.) From http://opencv.org/downloads.html, download OpenCV for Windows 
(say version 2.4.10)

b.) Extract opencv-2.4.10.exe to a directory and copy file under
{extracted_dir}\build\python\2.7\x64\cv2.pyd to 
{anaconda_install_dir}\Lib\site-packages 

Discussion of Results:

This is an advanced example of pattern recognition using an easy data set of 
digit images, using Python to preprocess the digit images, and a 3 layer 
(i.e. "deep") neural network to classify the digit images. 

The sample MNIST data is part of a famous data set that contains thousands of 
handwritten digit images with labels from 0 through 9. Correctly labeling
these digit images is a classic problem in machine learning research. (The 
full MNIST data are widely available.) 

In this demo, a Python script is used to scale and center the digits so that 
they are all the same size and are all located in the same position within the
27 x 27 grid of pixels. The base SAS Java Object is used along with some simple
Java classes to kick-off the Python process. The Python process creates an 
output file with a name that SAS expects. After the Python process finishes, 
SAS is then used to drop all pixels with a constant intensity of 0 from the
analysis. The digit images are then fed to a 3-layer MLP neural network to be
classified. This neural network uses a training approach in which the single
layers of the neural network are trained seperately then retrained together. 
This approach helps avoid the vanishing gradient problem that is common in deep
neural networks and often prevents all the layers of deep neural networks from
being trained together simultaneously.

It is very typical for a neural network to achieve 100% training accuracy as 
should occur here. After being correctly tuned SAS technologies, especially
PROC NEURAL and HPNEURAL, should achieve 98-99% correct classification for 
hold-out sets on this and other popular pattern recognition problems. Also, 
convolutional neural networks are the state-of-the-art in pattern recognition. 
PROCs NEURAL and HPNEURAL do not support this architecture.