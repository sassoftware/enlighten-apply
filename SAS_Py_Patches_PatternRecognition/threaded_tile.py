# -*- coding: utf-8 -*-

"""
Copyright (c) 2015 by SAS Institute

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
preprocessing tasks.

Images are copied into n_process seperate folders and converted to greyscale.
Original, full size images are coverted into x,y,z contours and written to csv.
These countours serve as the background over which to lie interesting patches.
Images are then tiled. Tiling can lead to the learning of translation-invariant
features. Patches can be conditionally downsampled using the -d switch or by
setting a value for downsample_size. Images are then flattened and collected
into a single csv file, called 'patches.csv'. Patches.csv is located in 
out_dir. Patches.csv will contain all pixel intensity values for each patch as
a row vector. Each row of patches.csv will also contain additional information
including the original image filename including the upper-lefthand x and y 
values of the patch in the original image. All pre-existing files from earlier 
runs of threaded_tile.py may be replaced or deleted by subsequent runs.

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

tile_size: (-t) Side length of square image patches measured in pixels. If
           downsample_size is set to None, this will be the final side length
           of the square image patches used for analysis and each row vector of
           patches.csv will contain tile_size*tile_size pixel intensity
           elements.

downsample_size: (-d) Side length of downsampled square image patches measured
                 in pixels. By default, image patches are downsampled before 
                 being flattened, resulting in each row vector of patches.csv
                 containing downsample_size*downsample_size pixels intensity
                 elements. (default=25)

stride_length: (-s) Number of pixels between each patch. Setting stride_length
               to 1 results in creating a number of patches that can be equal 
               to the number of pixels in the original image. The maximum value
               of stride_length is:

               min(orignal image height, original image width) - tile_size

               User-input values that exceed the maximum value will be reset to
               the maximum value. (default=tile_size/2)

variance_threshold: (-v) The standard deviation above which an image will be
                    flattened and saved to patches.csv. Used to prevent blank,
                    dark, or plain white images from being included in the
                    analysis. (default=tile_size/10)

Run threaded_tile.py from an IDE by setting constants in main OR by the command
line. Example command line usage:

$ python threaded_tile.py -i test_in -o test_out -g True -t 400

"""

# imports

import ast
import csv
import getopt
import multiprocessing
import numpy as np
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
                 patches.csv file.

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
                 patches.csv file.

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

def map_convert_originals(i, out_dir):

    """ Write original image file to csv as x,y,z contours. These countours are
    used as the background over which to lie interesting patches.

    Args:
        i: Process index.
        out_dir: Directory in which to create intermediate files and final
                 originals.csv file.

    Raises:
        EnvironemtError: Problem creating csv file.
    """

    # local constants

    process_name = multiprocessing.current_process().name
    chunk_dir = out_dir + os.sep + '_chunk_dir' + str(i)
    image_type_list = ['JPG', 'JPEG', 'PNG', 'BMP', 'TIFF']

    # cycle through original images in chunk_dir and convert to csv using
    # pandas

    file_list = [name for name in os.listdir(chunk_dir)\
                    if name.split('.')[-1].upper() in image_type_list]

    for name in file_list:

        print process_name + ': Converting ' + name + ' to csv ...'
        chunk_file = chunk_dir + os.sep + name

        out_csv_name = chunk_dir + os.sep + 'orig.' + name + '.csv'
        try:
            if os.path.exists(out_csv_name):
                os.remove(out_csv_name, ignore_errors=True)
            o = open(out_csv_name, 'wb')
        except EnvironmentError as exception_:
            print exception_
            print 'Failed to create ' + out_csv_name + '!'
            sys.exit(-1)

        im = Image.open(chunk_file).convert('L')
        w, h = im.size
        x = np.tile(np.arange(w), h).T + 1
        y = np.repeat(np.arange(h-1, -1, -1), w).T + 1
        z = 255-np.asarray(im.getdata()).T

        wr = csv.writer(o)
        for i in range(0, w*h):
            wr.writerow([x[i], y[i], z[i], name])

        o.close()

    print process_name + ': Done.'

def reduce_join_original_csv(n_process, out_dir, debug):

    """ Creates out_dir/originals.csv, writes csv header to originals.csv, and
    concatenates intermediate csv files into orginals.csv.

    Args:
        n_process: Number of processes specified by the user.
        out_dir: Directory in which to create intermediate files and final
                 originals.csv file.
        debug: If true, preserves intermediate working directories.

    Raises:
        EnvironemtError: Problem creating csv file.
    """

    # create out_dir/originals.csv

    out_csv_name = out_dir + os.sep + 'originals.csv'
    try:
        if os.path.exists(out_csv_name):
            shutil.rmtree(out_csv_name, ignore_errors=True)
        o = open(out_csv_name, 'wb')
    except EnvironmentError as exception_:
        print exception_
        print 'Failed to create ' + out_csv_name + '!'
        sys.exit(-1)

    # write csv header to patches.csv

    header = ['x', 'y', 'z', 'orig_name']

    csv.writer(o).writerow(header)

    # concatenate intermediate csv files into originals.csv

    for i in range(0, n_process):

        chunk_dir = out_dir + os.sep + '_chunk_dir' + str(i)

        file_list = [name for name in os.listdir(chunk_dir)\
                    if name.split('.')[0].upper() == 'ORIG']

        for name in file_list:

            in_csv_name = chunk_dir + os.sep + name
            with open(in_csv_name) as n:
                for line in n:
                    o.write(line)

    o.close()


def map_make_tiles(i, out_dir, debug, tile_size, downsample_size,
                   stride_length, variance_threshold):

    """ In each process: creates patches from each file, conditionally
    downsamples patches, flattens patches into row vector of pixel intensities,
    and saves row vector to intermediate csv.

    Args:
        i: Process index.
        out_dir: Directory in which to create intermediate files and final
                 patches.csv file.
        debug: If true, preserves intermediate image patches.
        tile_size: Side length of square image patches measured in pixels.
        downsample_size: Side length of downsampled square image patches
                         measured in pixels. If set, image patches are 
                         downsampled before being flattened.
        stride_length: Number of pixels between each patch.
        variance_threshold: The standard deviation above which an image will be
                            flattened and saved to patches.csv.

    Raises:
        EnvironemtError: Problem creating csv file.
    """

    # local constants

    process_name = multiprocessing.current_process().name
    chunk_dir = out_dir + os.sep + '_chunk_dir' + str(i)
    image_type_list = ['JPG', 'JPEG', 'PNG', 'BMP', 'TIFF']

    # open intermediate csv for writing flattened images

    out_csv_name = chunk_dir + os.sep + 'patches' + str(i) + '.csv'
    try:
        if os.path.exists(out_csv_name):
            shutil.rmtree(out_csv_name, ignore_errors=True)
        o = open(out_csv_name, 'wb')
        wr = csv.writer(o)
    except EnvironmentError as exception_:
        print exception_
        print 'Failed to create ' + out_csv_name + '!'
        sys.exit(-1)

    file_list = [name for name in os.listdir(chunk_dir)\
                    if name.split('.')[-1].upper() in image_type_list]

    for name in file_list:

        print process_name + ': tiling ' + name + ' ...'

        chunk_file = chunk_dir + os.sep + name
        im = Image.open(chunk_file).convert('L')
        w, h = im.size

        # check stride_length

        if stride_length > min(w, h) - tile_size:
            stride_length = min(w, h) - tile_size

        # create patches from each file

        reached_y_edge = False
        for y in range(0, h, stride_length):

            y_ = y
            if reached_y_edge:
                continue
            else:
                my = min(y + tile_size, h)
                if my == h:
                    y_ = h - tile_size
                    reached_y_edge = True

            reached_x_edge = False
            for x in range(0, w, stride_length):

                x_ = x
                if reached_x_edge:
                    continue
                else:
                    mx = min(x + tile_size, w)
                    if mx == w:
                        x_ = w - tile_size
                        reached_x_edge = True

                tile = im.crop((x_, y_, mx, my))
                std = np.std(np.array(tile))

                if std > variance_threshold:

                    # conditionally downsample patches

                    if downsample_size != None:
                        tile = tile.resize((downsample_size, downsample_size),\
                                            Image.ANTIALIAS)

                    if debug:
                        tile_fname = os.path.join(chunk_dir,\
                            'patch.%s.%d.%d.png' % (name, x_, y_))
                        tile.save(tile_fname, "PNG")

                    # flatten patches into row vector of pixel intensities

                    tile_list = list(tile.getdata())
                    tile_list.extend([name, x_, y_, tile_size, 0])

                    # save row vector to intermediate csv

                    wr.writerow(tile_list)

    o.close()
    print process_name + ': Done.'

def reduce_join_csv(n_process, out_dir, debug, tile_size):

    """ Creates out_dir/patches.csv, writes csv header to patches.csv, and
    concatenates intermediate csv files into patches.csv.

    Args:
        n_process: Number of processes specified by the user.
        out_dir: Directory in which to create intermediate files and final
                 patches.csv file.
        debug: If true, preserves intermediate working directories.
        tile_size: Side length of square image patches measured in pixels - 
                   used to create csv header here.

    Raises:
        EnvironemtError: Problem creating csv file.
    """

    # create out_dir/patches.csv

    out_csv_name = out_dir + os.sep + 'patches.csv'
    try:
        if os.path.exists(out_csv_name):
            shutil.rmtree(out_csv_name, ignore_errors=True)
        o = open(out_csv_name, 'wb')
    except EnvironmentError as exception_:
        print exception_
        print 'Failed to create ' + out_csv_name + '!'
        sys.exit(-1)

    # write csv header to patches.csv

    header = ['pixel_' + str(j) for j in range(0, tile_size*tile_size)]
    header.extend(['orig_name', 'x', 'y', 'size', 'angle'])
    csv.writer(o).writerow(header)

    # concatenate intermediate csv files into patches.csv

    for i in range(0, n_process):
        chunk_dir = out_dir + os.sep + '_chunk_dir' + str(i)
        in_csv_name = chunk_dir + os.sep + 'patches' + str(i) + '.csv'
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
    in_dir = None
    out_dir = None
    debug = False
    tile_size = None
    downsample_size = 25
    stride_length = None
    variance_threshold = None

    # parse command line args and update dependent args

    try:
        opts, _ = getopt.getopt(argv, "p:i:o:g:t:d:s:v:h")
        for opt, arg in opts:
            if opt == '-p':
                n_process = int(arg)
            elif opt == '-i':
                in_dir = arg
            elif opt == '-o':
                out_dir = arg
            elif opt == '-g':
                debug = ast.literal_eval(arg)
            elif opt == '-t':
                tile_size = int(arg)
            elif opt == '-d':
                downsample_size = int(arg)
            elif opt == '-s':
                stride_length = int(arg)
            elif opt == '-v':
                variance_threshold = int(arg)
            elif opt == '-h':
                print 'Example usage: python threaded_tile.py -i <input directory> -o <output directory> -t <tile size>'
                sys.exit(0)
    except getopt.GetoptError as exception_:
        print exception_
        print 'Example usage: python threaded_tile.py -i <input directory> -o <output directory> -t <tile size>'
        sys.exit(-1)

    if in_dir == None:
        print 'Error: enter value for input directory (-i).'
        raise Exception

    if out_dir == None:
        print 'Error: enter value for output directory (-o).'
        raise Exception

    if tile_size == None:
        print 'Error: enter value for tile_size (-t).'
        raise Exception

    if stride_length == None:
        stride_length = int(tile_size/2)

    if variance_threshold == None:
        variance_threshold = int(tile_size/10)

    print '-------------------------------------------------------------------'
    print 'Proceeding with options: '
    print 'Processes (-p)           = %s' % (n_process)
    print 'Input directory (i)      = %s' % (in_dir)
    print 'Output directory (-o)    = %s' % (out_dir)
    print 'Debug (-g)               = %s' % (debug)
    print 'Tile size (-t)           = %s' % (tile_size)
    print 'Downsample size (-d)     = %s' % (downsample_size)
    print 'Stride length (-s)       = %s' % (stride_length)
    print 'Variance (-v)            = %s' % (variance_threshold)

    # start execution timer

    bigtic = time.time()

    # init chunk directory structure and copy chunks of files

    create_out_dirs(n_process, out_dir)
    chunk_files(n_process, in_dir, out_dir)

    # multiprocessing map/reduce scheme to execute image manipulation tasks on
    # chunks of image files in parallel

    # convert original images to contours in a csv file using multiprocessing
    # store in temporary files

    print '-------------------------------------------------------------------'
    print 'Converting original images to csv ... '
    tic = time.time()
    processes = []
    try:
        for i in range(0, int(n_process)):
            process_name = 'Process_' + str(i)
            process = Process(target=map_convert_originals, name=process_name,\
            args=(i, out_dir))
            process.start()
            processes.append(process)
        for process_ in processes:
            process_.join()
        print 'Images converted in %.2f s.' % (time.time()-tic)
    except BaseException as exception_:
        print exception_
        print 'ERROR: Could not convert original images to csv.'
        print sys.exc_info()
        exit(-1)

    # reduce temporary contour csv files into a single large csv

    print '-------------------------------------------------------------------'
    print 'Combining original csv files ... '
    reduce_join_original_csv(n_process, out_dir, debug)
    print 'Done.'
    print 'Csv files combined in %.2f s.' % (time.time()-tic)

    # tile images using multiprocessing
    # store in temporary files

    print '-------------------------------------------------------------------'
    print 'Tiling images ... '
    tic = time.time()
    processes = []
    try:
        for i in range(0, int(n_process)):
            process_name = 'Process_' + str(i)
            process = Process(target=map_make_tiles, name=process_name,\
            args=(i, out_dir, debug, tile_size, downsample_size,\
                  stride_length, variance_threshold))
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
    size_ = tile_size
    if downsample_size != None:
        size_ = downsample_size
    reduce_join_csv(n_process, out_dir, debug, size_)
    print 'Done.'
    print 'Csv files combined in %.2f s.' % (time.time()-tic)

    print '-------------------------------------------------------------------'
    print 'All tasks completed in %.2f s.' % (time.time()-bigtic)

if __name__ == '__main__':
    main(sys.argv[1:])
