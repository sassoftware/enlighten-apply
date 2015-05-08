# -*- coding: utf-8 -*-
"""

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

-------------------------------------------------------------------------------

Simple Python routines for preprocessing MNIST digits

"""

import os
import sys
import cv2
import numpy

# global magic numbers for images ... sorry
INPUT_SIZE = (28, 28)    # size of input image, 2-tuple
OUT_SIZE = (27, 27)      # size of output image, 2-tuple
IN_OBS = 2000            # number of input file records

# final bounding box size for normalized images,
# 2-tuple, < out_size
NORM_SIZE = (21, 21)
NORM_EXPAND_SIZE = int((27-NORM_SIZE[0])/2)

# more complicated ...
# turning a 1, 7 or other skinny number into a square during normalization is
# dumb do avoid doing so, don't resize numbers whose left most pixel is located
# at a index >= to skinny_threshold
SKINNY_THRESHOLD = 10

# difficult to see (and therefore test) the bounding box without this, 0-255
# set higher for debugging
TO_BLACK_THRESHOLD = 0

def normalize_scale(src, out_size=OUT_SIZE, norm_size=NORM_SIZE,
                    norm_expand_size=NORM_EXPAND_SIZE,
                    skinny_threshold=SKINNY_THRESHOLD,
                    to_black_threshold=TO_BLACK_THRESHOLD):

    """ Normalizes image scale

        Args:
            src: images as 2-D numpy array
            out_size: desired size of output image (square)
            norm_size: desired size of image within out_size (square)
            norm_expand_size: how much norm size needs to be expanded to fill
                              out_size
            skinny_threshold: prevents narrow numbers from being stretched
                              horizontally
            to_black_threshold: a value below which pixel intensities are
                                thresholded


        Returns:
            A normalized image as a 2-D numpy array

    """

    src[src < to_black_threshold] = 0
    bottom, top = numpy.min(numpy.nonzero(src)[0]),\
                 numpy.max(numpy.nonzero(src)[0])
    left, right = numpy.min(numpy.nonzero(src.T)[0]),\
                 numpy.max(numpy.nonzero(src.T)[0])
    bounding_box = src[bottom:top+1, left:right+1]
    if left >= skinny_threshold:
        skinny = True
    else:
        skinny = False
    if skinny:
        return cv2.resize(src, (out_size))
    else:
        norm = cv2.resize(bounding_box, (norm_size))
        return cv2.copyMakeBorder(norm, norm_expand_size, norm_expand_size,
                                  norm_expand_size, norm_expand_size, 0)

def main():

    """ Driver method

        Opens input data, cycles through each row, normalizes each row as an
        image, and writes to an output file

    """

    # io
    github_data_dir = sys.argv[1]

    file_in_loc = github_data_dir + os.sep + 'digits_train_sample.csv'
    file_out = open(github_data_dir + os.sep +
                    'digits_train_sample_processed.csv', 'w+')
    file_in = open(file_in_loc, 'rb')

    # cycle through all images
    for i, row in enumerate(file_in):

        row = row.split(',')

        if i == 0: # row 0 is column names
            header = ','.join(row[0:OUT_SIZE[0]**2 + 1])
            file_out.write(header + '\n')

        if i > 0:

            if i % 100 == 0:
                print 'Processing image ' + str(i) + ' ...'

            # read row into image
            row_array = numpy.asarray(row)
            row_array = row_array.astype(numpy.float32)
            img = numpy.reshape(row_array[1:], (INPUT_SIZE))

            # normalize scale
            norm = normalize_scale(img)

            # flatten
            out_row = numpy.array(norm).flatten()

            # add to output
            out_row = out_row.reshape((1, OUT_SIZE[0]**2))
            out_row = numpy.insert(out_row, 0, row_array[0])
            file_out.write(str(out_row.tolist())[1:-1] + '\n')

    file_in.close()
    file_out.close()

    print 'Done.'

if __name__ == '__main__':
    main()
