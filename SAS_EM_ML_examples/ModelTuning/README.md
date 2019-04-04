Examples for tuning models in Enterprise Miner

This folder contains a zip file with 2 Enterprise Miner diagram xmls you can import into a project and 2 of the data sets (the ones for the SVM diagram)…you will have to define the data sources and hook the data nodes back up of course.  The RF diagram uses the very common MNIST digits set (Mixed National Institute of Standards and Technology)…read more here https://en.wikipedia.org/wiki/MNIST_database.  Here’s some code that shows where/how to go get it from a public location:

filename traincsv url 'http://pjreddie.com/media/files/mnist_train.csv';

proc import 
  datafile=traincsv
  out=train
  dbms=csv
  replace;
  getnames=no;
run;

filename validcsv url 'http://pjreddie.com/media/files/mnist_test.csv';

proc import 
  datafile=validcsv
  out=valid
  dbms=csv
  replace;
  getnames=no;
run;
