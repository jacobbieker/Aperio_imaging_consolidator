__author__ = 'Jacob Bieker'
import os
import yaml
import xlutils
from xlutils.copy import copy
from xlrd import open_workbook
'''
Testing script for the aperio_consolidator R script, mostly designed for creating large sets of data
'''

#Authentication with Instagram
with open("config.yml", 'r') as access:
    config = yaml.load(access)

#Load the stain names, mice numbers, and slide numbers to put in the dummy data
list_of_stains = config['stains']
num_mice = config['mice']
num_slides = config['slides']

#Directory to the location of the script and input files
rootdir = 'C:\Development\SU2C_pancreatic_cancer'

#Open workbook that has two regions on it, so dataset is even larger
rb = open_workbook(os.path.join(rootdir,'mouse_2_slide_5_stain_CC3.xls'), formatting_info=True, on_demand=True)
workbook = copy(rb)
#create lots of dummy files for testing on large data sets
for mouse in range(0, num_mice):
    for slide in range(0, num_slides):
        for stain in list_of_stains:
            workbook.save(os.path.join(rootdir, "_" + str(mouse) + "__" + str(slide) + "_" + "_" + str(stain) + ".xls"))