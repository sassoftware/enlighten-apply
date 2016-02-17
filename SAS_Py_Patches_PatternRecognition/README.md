/******************************************************************************

Copyright (c) 2015 by SAS Institute Inc., Cary, NC 27513 USA

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied
See the License for the specific language governing permissions and 
limitations under the License.

******************************************************************************/

SAS_Py_Patches_PatternRecognition

===============

Python and SAS scripts used for pattern recognition in image patches.

===============

SUGGESTED USAGE:

1.) Create patches.

    Create uniform patches by running:

    $ python threaded_tile.py -i test_in -o test_out -g True -t 400

    OR

    Create randomized patches by running:

    $ python threaded_tile_r.py -i test_in -o test_out_r -g True

For *unsupervised* learning ...

2.) Create a dictionary by running make_dictionary.sas.

3.) Make clusters of patches or, for more efficient processing, make clusters
    of the features extracted by the stacked autoencoder in 
    make_dictionary.sas. If the SAS data set hidden_output.sas7bdat exists in
    the OUT_DIR specified in make_clusters.sas, then clusters will
    automatically be made in the extracted feature space.

    The graphical output of make_clusters.sas may require very large amounts of
    JVM heapspace to be allocated, > 20 GB in some test cases. This can be 
    achieved by editing the -Xms and -Xmx JRE options in sasv9.cfg to allow
    for larger amounts of memory to be allocated.

OR for *supervised* learning ...

2.) Perform supervised learning tasks with a deep neural network (DNN) using
    dnn_classifier.sas. To use dnn_classifier.sas, you must supply a label
    file in CSV format with column headers 'orig_name', 'label'.

===============

GIT LFS NOTICE: Test images are supplied, however the test image files are
stored using git lfs.

===============

TESTING:

This example was tested in the following environment:

Windows 7 Enterprise

Intel i7-5600U @ 2.60 GHz

16 GB RAM

SAS 9.4 (TS1M2)

SAS Enterprise Miner 13.2