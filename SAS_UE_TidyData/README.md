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


### Tidy data examples

This repository contains three SAS programs which allow you to tidy your messy data. Tidying data is a structured process meant to address common analytical data quality problems. These SAS macros do not use all of Hadley Wickham's original terminology, but instead try to represent the Tidy Data process in a format most native to SAS programming.

Detailed information about Tidy Data is presented by Hadley Wickham in the article entitled “Tidy Data” from The Journal of Statistical Software, Vol. 59, Issue 10 (August 2014), https://www.jstatsoft.org/article/view/v059i10. 

Specifically, these SAS programs address Sections 3.1, 3.2, and 3.3 in that article.

This example will run in the free [SAS&reg; University Edition](http://www.sas.com/en_us/software/university-edition.html).

#### Messy Data Scenario 1: Dimension values stored as column names

This is data stored in a presentation style format, where multiple measure columns are described by the dimension values in their names.

![alt text](README_pics/TidyData1.png "Messy Data Scenario 1")

[Example SAS Code](https://github.com/sassoftware/enlighten-apply/blob/master/SAS_UE_TidyData/tidy1.sas)

#### Messy Data Scenario 2: Multiple dimension variables stored in one column

This is data where a column contains values for multiple dimension variables.

![alt text](README_pics/TidyData2.png "Messy Data Scenario 2")

[Example SAS Code](https://github.com/sassoftware/enlighten-apply/blob/master/SAS_UE_TidyData/tidy2.sas)

#### Messy Data Scenario 3: Dimension values stored as column names and measure variables stored in rows

This is data stored in a presentation style format, where multiple measure columns are described by the dimension values in their names, and multiple measure variables are stored in rows.

![alt text](README_pics/TidyData3.png "Messy Data Scenario 3")

[Example SAS Code](https://github.com/sassoftware/enlighten-apply/blob/master/SAS_UE_TidyData/tidy3.sas)

## Testing

This example was tested in the following environment:

* Windows 7 Enterprise
* Intel i7-5600U @ 2.60 GHz
* 16 GB RAM
* VMware Workstation 12 Player
* SAS University Edition