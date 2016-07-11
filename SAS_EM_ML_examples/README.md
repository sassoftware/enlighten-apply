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

SAS_ML_examples

===============

Code and materials for several machine learning tasks with SAS.

To accompany "An Overview of Machine Learning with SAS Enterprise Miner"

Paper available at:

http://support.sas.com/resources/papers/proceedings14/SAS313-2014.pdf

Be sure to unzip the data!

This repo contains samples. The original larger data sources should
be available on kaggle.com.

The claim prediction challenge example is completed using the SAS Enterprise
Miner GUI. Both a model package and diagram XML are provided to recreate
the workflow.

You can use the -MEMSIZE option to increase the amount of RAM availabe to a SAS
session.

These examples were tested in the following environment:

Windows Server 2008 R2 Enterprise

Dual Intel Xeon E5-2667 @ 2.9 GHz

128 GB RAM (Most the examples were also run on a laptop with 16 GB of RAM.)

SAS 9.4 (TS1M2)

SAS Enterprise Miner 13.2

R 2.15.3

===============

emc_israel_data_science_challenge.sas

===============

1.) Download (and unzip) or clone the SAS_ML_examples repository
to a directory referred to as {WORK_DIR}.

2.) Unzip example data file (data.zip) so that the following files are
extracted to {WORK_DIR}\data. 

3.) Open the emc_israel_data_science_challenge.sas file in a standard
DMS SAS Session.

4.) Set the git_repo_data_dir macro variable to the (unzipped!) data
subdirectory of the repository i.e., {WORK_DIR}\data.

5.) Set the cpu_count macro variable to an integer less than or equal to the
number of physical CPU cores on your system.

6.) Submit the entire file or in parts if interested in walking through
the steps.


===============

claim_prediction_challenge.xml

===============

This example is in the form of xml that can be imported into SAS Enterprise
Miner as a process flow. It also needs R (with cluster package) to be installed
alongside SAS.

1.) Install R and set RLANG option:

1a.) Install R (with cluster package)

SAS/IML Version: 13.1
  -> Recommended versions of R: 2.13.0-3.0.2
  -> Required Version of PMML Package: pmml_1.4.1

SAS/IML Version: 13.2
  -> Recommended versions of R: 2.15.3-3.0.3
  -> Required Version of PMML Package: pmml_1.4.1

SAS/IML Version: 14.1
  -> Recommended versions of R: 3.0.1-3.1.2
  -> Required Version of PMML Package: pmml_1.4.2

1b.) If it is not set, set the -RLANG SAS system option:

The –RLANG option is typically added to the main sasv9.cfg file of a given
SAS installation.

The main sasv9.cfg file is often located in a directory like

C:\Program Files\SASHome\SASFoundation\9.4\nls\en

Once you have found this file, add

-RLANG

to the bottom of the file.

2.) Download (and unzip) or clone the SAS_ML_examples repository
to a directory referred to as {WORK_DIR}.

3.) Unzip example data file (data.zip) so that the following files are
extracted to {WORK_DIR}\data.

4.) Create a new project in SAS Enterprise Miner.

5.) In top-left pane, right-click on "Diagrams" folder and select
"Import Diagram from XML...". In the Open window, browse to {WORK_DIR} and
select claim_prediction_challenge.xml file. This opens the flow diagram.

6.) The first node (CLAIMS_TRAIN_SAMPLE) in the flow represents input data
and needs to be re-created to point to the actual data. To do this:

6a.) Create a new library in Enterprise Miner using File->New->Library pointing
to {WORK_DIR}\data directory.

6b.) Create a new data source for claims_train_sample.sas7bdat. To do this
use File->New->Data Source and the library created in above step to locate
the dataset. In addition, select Advanced button for Metadata Advisor Options
on Step 4 of the Data Source Wizard creation.

6c.) After the data source is created, validate its metadata is accurate.
For that, on top-left pane, under Data Sources, right-click CLAIMS_TRAIN_SAMPLE
and select "Edit Variables".

IMPORTANT: Make sure the table metadata matches as below. If not, make
necessary changes.

Name            Role           Level

========        ========       ========

Blind_Make      Rejected       Nominal

Blind_Model     Rejected       Nominal

Blind_Submodel  Rejected       Nominal

Calendar_Year   Input          Nominal

Cat1            Input          Nominal

Cat10           Input          Nominal

Cat11           Input          Nominal

Cat12           Input          Nominal

Cat2            Input          Nominal

Cat3            Input          Nominal

Cat4            Input          Nominal

Cat5            Input          Nominal

Cat6            Input          Nominal

Cat7            Input          Nominal

Cat8            Input          Nominal

Cat9            Input          Binary

Household_ID    ID             Nominal

Model_Year      Input          Interval

NVCat           Input          Nominal

NVVar1          Input          Interval

NVVar2          Input          Interval

NVVar3          Input          Interval

NVVar4          Input          Interval

OrdCat          Input          Ordinal

Row_ID          ID             Interval

Var1            Input          Interval

Var2            Input          Interval

Var3            Input          Interval

Var4            Input          Interval

Var5            Input          Interval

Var6            Input          Interval

Var7            Input          Interval

Var8            Input          Interval

Vehicle         Input          Nominal

_dataobs_       ID             Interval


6d.) Delete existing CLAIMS_TRAIN_SAMPLE node in the flow and drag-drop
the newly created data source with same name on to the diagram and connect
it to the second node (Variable Selection) in the flow.

7.) Run the flow.

NOTE: The SAS program file claim_prediction_challenge.sas and the model
package file claim_prediction_challenge.spk are provided for
redunancy.


===============

digit_recognizer.sas

===============

1.) Download (and unzip) or clone the SAS_ML_examples repository
to a directory referred to as {WORK_DIR}.

2.) Unzip example data file (data.zip) so that the following files are
extracted to {WORK_DIR}\data

3.) Open the digit_recognizer.sas file in a standard DMS SAS Session.

4.) Set the git_repo_data_dir macro variable to the (unzipped!) data
subdirectory of the repository i.e., {WORK_DIR}\data.

5.) Set the cpu_count macro variable to an integer less than or equal to the
number of physical CPU cores on your system.

6.) Submit the entire file or in parts if interested in walking through
the steps.
