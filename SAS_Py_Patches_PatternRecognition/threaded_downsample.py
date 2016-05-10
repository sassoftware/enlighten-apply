# -*- coding: utf-8 -*-

"""

Copyright (c) 2016 by SAS Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

-------------------------------------------------------------------------------

@author: patrick.hall@sas.com

Script using Python multiprocessing and PIL to complete independent image
preprocessing tasks in parallel. 

Images are copied into n_process seperate folders, converted to greyscale, and 
downsampled to square tiles (default: 25x25). Images are downsampled using
the -d switch or by setting a value for downsample_size. Images are then 
flattened and collected into a single csv file, called 'images.csv'. Images.csv
is located in out_dir. Images.csv will contain all pixel intensity values for
each downsampled image as a row vector. Each row of images.csv will also 
contain the original image filename. All pre-existing files from earlier 
runs of threaded_downsample.py may be replaced or deleted by subsequent runs.

Important constants:

n_process: (-p) Number of processes to use; the script will create this many
           chunks of image files and place them into working sub-directores,
           with names like out_dir/_chunk_dir<n>. (default=2)

in_dir: (-i) Directory in which input images are located. This directory should
        contain only image files of type JPG, PNG, BMP or TIFF. The files must
        also have standard file extensions to be recognized by the script.
        Files will be copied into their respective chunk directories before
        being tiled, (and/or downsampled,) flattened, and converted to csv.

out_dir: (-o) Parent directory in which the sub-directories for each chunk of
         image files will be created. A large number temporary files will be
         created in out_dir.

debug: (-g) Leaves temporary files in out_dir. (default=False)

downsample_size: (-d) Side length of downsampled square image tiles measured
                 in pixels. Images are downsampled before being flattened, 
                 resulting in each row vector of images.csv containing 
                 downsample_size*downsample_size pixels intensity elements. 
                 (default=25)

Run threaded_downsample.csv from an IDE by setting constants in main OR by the 
command line. Example command line usage:

$ python threaded_downsample.csv -i test_in -o test_out -g True -d 50

"""

# imports

import ast
import csv
import getopt
import multiprocessing
import os
import shutil
import sys
import time
from multiprocessing import Process
from PIL import Image

def create_out_dirs(n_process, out_dir):

    """ Creates n_process number of output directories.

    Args:
        n_process: Number of processes specified by the user.
        out_dir: Directory in which to create intermediate files and final
                 images.csv file.

    Raises:
        EnvironemtError: Problem creating directories.
    """

    print '-------------------------------------------------------------------'
    print 'Creating working directory structure ... '

    # create dir structure

    for i in range(0, int(n_process)):

        chunk_outdir = out_dir + os.sep + '_chunk_dir' + str(i)
        try:
            if os.path.exists(chunk_outdir):
                shutil.rmtree(chunk_outdir, ignore_errors=True)
            os.mkdir(chunk_outdir)
            print 'Created ' + chunk_outdir + ' ...'
        except EnvironmentError as exception_:
            print exception_
            print 'Failed to locate or create ' + chunk_outdir + '!'
            sys.exit(-1)

    print 'Done.'

def chunk_files(n_process, in_dir, out_dir):

    """ Separates the image in in_dir into n_process roughly equal chunks of
    files, each in a separate directory created by create_out_dirs.

    Args:
        n_process: Number of processes specified by the user.
        in_dir: Directory in which original image files are located.
        out_dir: Directory in which to create intermediate files and final
                 images.csv file.

    Raises:
        EnvironemtError: Problem copying image files.
    """

    print '-------------------------------------------------------------------'
    print 'Chunking ' + in_dir + ' ...'

    # local constants

    check_point_value = 1000
    image_type_list = ['JPG', 'JPEG', 'PNG', 'BMP', 'TIFF']

     # copy files

    file_list = [name for name in os.listdir(in_dir)\
                    if name.split('.')[-1].upper() in image_type_list]

    for i, name in enumerate(file_list):

        source_file = in_dir + os.sep + name
        chunk_outdir = out_dir + os.sep + '_chunk_dir' +\
            str(int(i % n_process))
        chunk_file = chunk_outdir + os.sep + name

        try:
            if os.path.isfile(chunk_file):
                shutil.rmtree(chunk_file, ignore_errors=True)
            else:
                shutil.copy(source_file, chunk_file)
        except EnvironmentError as exception_:
            print exception_
            print 'Failed to copy' + name + '!'
            sys.exit(-1)

        if i % check_point_value == 0 and i != 0:
            print 'Processing file %i ...' % (i)

    print 'Done.'
    
def map_downsample(i, out_dir, debug, downsample_size):

    """ In each process: convert images to greyscale, conditionally
    downsamples images, flatten images into row vector of pixel intensities,
    and save row vector to intermediate csv.

    Args:
        i: Process index.
        out_dir: Directory in which to create intermediate files and final
                 images.csv file.
        debug: If true, preserves intermediate image tiles.
        downsample_size: Side length of downsampled square images measured in
                         pixels. If set, images are downsampled before being
                         flattened.

    Raises:
        EnvironemtError: Problem creating csv file.
    """

    # local constants
    process_name = multiprocessing.current_process().name
    chunk_dir = out_dir + os.sep + '_chunk_dir' + str(i)
    image_type_list = ['JPG', 'JPEG', 'PNG', 'BMP', 'TIFF']

    # open intermediate csv for writing flattened images
    out_csv_name = chunk_dir + os.sep + 'images' + str(i) + '.csv'
    try:
        if os.path.exists(out_csv_name):
            shutil.rmtree(out_csv_name, ignore_errors=True)
        o = open(out_csv_name, 'wb')
        wr = csv.writer(o)
    except EnvironmentError as exception_:
        print exception_
        print 'Failed to create ' + out_csv_name + '!'
        sys.exit(-1)


    # loop through images in chunk dir
    file_list = [name for name in os.listdir(chunk_dir)\
                    if name.split('.')[-1].upper() in image_type_list]

    for name in file_list:

        print process_name + ': processing ' + name + ' ...'
        chunk_file = chunk_dir + os.sep + name
        
        # convert to greyscale        
        im = Image.open(chunk_file).convert('L')

        # conditionally downsample
        if downsample_size != None:
            tile = im.resize((downsample_size, downsample_size),\
                              Image.ANTIALIAS)

        # conditionally save tiles                                
        if debug:
            tile_fname = os.path.join(chunk_dir, 'tile.%s.png' % (name))
            tile.save(tile_fname, "PNG")

        # flatten tiles into row vector of pixel intensities
        tile_list = list(tile.getdata())
        tile_list.extend([name])

        # save row vector to intermediate csv
        wr.writerow(tile_list)

    o.close()
    print process_name + ': Done.'
    
def reduce_join_csv(n_process, out_dir, debug, downsample_size):

    """ Creates out_dir/images.csv, writes csv header to images.csv, and
    concatenates intermediate csv files into images.csv.

    Args:
        n_process: Number of processes specified by the user.
        out_dir: Directory in which to create intermediate files and final
                 images.csv file.
        debug: If true, preserves intermediate working directories.
        downsample_size: Side length of square image tile measured in pixels
                         - used to create csv header here.

    Raises:
        EnvironemtError: Problem creating csv file.
    """

    # create out_dir/images.csv
    out_csv_name = out_dir + os.sep + 'images.csv'
    try:
        if os.path.exists(out_csv_name):
            shutil.rmtree(out_csv_name, ignore_errors=True)
        o = open(out_csv_name, 'wb')
    except EnvironmentError as exception_:
        print exception_
        print 'Failed to create ' + out_csv_name + '!'
        sys.exit(-1)

    # write csv header to images.csv
    header = ['pixel_' + str(j) for j in range(0, downsample_size**2)]
    header.extend(['orig_name'])
    csv.writer(o).writerow(header)

    # concatenate intermediate csv files into images.csv
    for i in range(0, n_process):
        chunk_dir = out_dir + os.sep + '_chunk_dir' + str(i)
        in_csv_name = chunk_dir + os.sep + 'images' + str(i) + '.csv'
        with open(in_csv_name) as n:
            for line in n:
                o.write(line)
        if not debug:
            shutil.rmtree(chunk_dir, ignore_errors=True)

    o.close()

def main(argv):

    """ For running standalone.
    Args:
        argv: Command line args.
    Raises:
        GetoptError: Problem parsing command line options.
        BaseException: Some problem from a multiprocessing task.
    """

    # TODO: user set constants if running from IDE
    # init local vars to defaults

    n_process = 2
    in_dir = ''
    out_dir = ''
    debug = False
    downsample_size = 25

    # parse command line args and update dependent args

    try:
        opts, _ = getopt.getopt(argv, "p:i:o:g:d:h")
        for opt, arg in opts:
            if opt == '-p':
                n_process = int(arg)
            elif opt == '-i':
                in_dir = arg
            elif opt == '-o':
                out_dir = arg
            elif opt == '-g':
                debug = ast.literal_eval(arg)
            elif opt == '-d':
                downsample_size = int(arg)
            elif opt == '-h':
                print 'Example usage: python threaded_tile.py -i <input directory> -o <output directory> -d <downsample size>'
                sys.exit(0)
    except getopt.GetoptError as exception_:
        print exception_
        print 'Example usage: python threaded_tile.py -i <input directory> -o <output directory> -d <downsample size>'
        sys.exit(-1)

    if in_dir == None:
        print 'Error: enter value for input directory (-i).'
        raise Exception

    if out_dir == None:
        print 'Error: enter value for output directory (-o).'
        raise Exception

    print '-------------------------------------------------------------------'
    print 'Proceeding with options: '
    print 'Processes (-p)           = %s' % (n_process)
    print 'Input directory (i)      = %s' % (in_dir)
    print 'Output directory (-o)    = %s' % (out_dir)
    print 'Debug (-g)               = %s' % (debug)
    print 'Downsample size (-d)     = %s' % (downsample_size)

    # start execution timer

    bigtic = time.time()

    # init chunk directory structure and copy chunks of files

    create_out_dirs(n_process, out_dir)
    chunk_files(n_process, in_dir, out_dir)

    # multiprocessing map/reduce scheme to execute image manipulation tasks on
    # chunks of image files in parallel

    # tile images using multiprocessing
    # store in temporary files

    print '-------------------------------------------------------------------'
    print 'Tiling images ... '
    tic = time.time()
    processes = []
    try:
        for i in range(0, int(n_process)):
            process_name = 'Process_' + str(i)
            process = Process(target=map_downsample, name=process_name,\
            args=(i, out_dir, debug, downsample_size,))
            process.start()
            processes.append(process)
        for process_ in processes:
            process_.join()
        print 'Completed tiling images in %.2f s.' % (time.time()-tic)
    except BaseException as exception_:
        print exception_
        print 'ERROR: Could not tile images.'
        print sys.exc_info()
        exit(-1)

    # reduce temporary files into a single large csv

    print '-------------------------------------------------------------------'
    print 'Combining tile csv files ... '
    reduce_join_csv(n_process, out_dir, debug, downsample_size)
    print 'Done.'
    print 'Csv files combined in %.2f s.' % (time.time()-tic)

    print '-------------------------------------------------------------------'
    print 'All tasks completed in %.2f s.' % (time.time()-bigtic)

if __name__ == '__main__':
    main(sys.argv[1:])
