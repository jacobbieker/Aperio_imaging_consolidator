#!/usr/bin/env bash
  R --vanilla << "EOF"      #  Pipe all subsequent lines into R.
  ################ Put all your R code here  ###############
    
  # Designed and developed by Patrick Leyshock (leyshock@ohsu.edu) And Jacob Bieker (jacob@bieker.us)
  
  # Script consolidates multiple .xls files (generated by Aperio image-analysis software) into one .xlsx workbook
  #   Input to script is multiple .xls files.  There is one .xls file per slide, with one or more rows, each row
  #     corresponding to a region selected in the image
  #   Output is a single .xlsx worksheet
  #
  # Assumptions:
  #   1.  script is located in same directory as input files
  #   2.  directory containing input files contains only this script, plus .xls files to be consolidated
  #   3.  input .xls files follow this naming convention:
  #
  #             mouse_NN_slide_MM_stain_MM.xls
  #
  #       so for mouse 3, slide 2, stain 5, the file name should be:
  #
  #             mouse_3_slide_2_stain_5.xls
  #
  #       Note that the delimitator between each component of the file name can be 
  #       any of the following: "_"
  
  #-------------------------------------------------------------------------
  #-------------------------------------------------------------------------
  #   Configuration
  #-------------------------------------------------------------------------
  #-------------------------------------------------------------------------
  # Uncomment below if the JVM is running out of heap space
  # Default should be fine for most data sets, tested on > 6000 files w/o 
  # using this option
  # options(java.parameters = "-Xmx1024m")
  
  # Check if libraries are installed, if not, install them
  if(require("XLConnect") & require("yaml") & require("readxl")){
    print("XLConnect, yaml, and readxl are loaded correctly")
  } else {
    print("trying to install XLConnect, yaml, and readxl")
    install.packages("XLConnect")
    install.packages("yaml")
    install.packages("readxl")
    if(require("XLConnect") & require("yaml") & require("readxl")){
      print("XLConnect, yaml, and readxl are installed and loaded")
    } else {
      stop("could not install XLConnect, yaml, or readxl")
    }
  }
  
  #   load appropriate libraries
  library(readxl);
  library(XLConnect);
  library(yaml);
  
  #loads column names from config file config.yml
  predefined.column.headers <- yaml.load_file("config.yml");
  
  #-------------------------------------------------------------------------
  #-------------------------------------------------------------------------
  #   Utility functions
  #-------------------------------------------------------------------------
  #-------------------------------------------------------------------------
  
  #   utility functions for mouse_MM_slide_NN_stain_NN.xls
  get.mouse.id <- function(file.name) {
    #   remove file extension
    file.name <- strsplit(file.name, "\\.")[[1]][1];
    #   extract mouse number
    mouse.id <- strsplit(file.name, "_")[[1]][2];
    return(mouse.id);
  }   #   get.mouse.id()
  
  get.slide.num <- function(file.name)   {
    #   remove file extension
    file.name <- strsplit(file.name, "\\.")[[1]][1];
    #   extract mouse number
    slide.num <- strsplit(file.name, "_")[[1]][4];    
    return(slide.num);    
  }   #   get.slide.num()
  
  get.stain.name <- function(file.name)   {
    #   remove file extension
    file.name <- strsplit(file.name, "\\.")[[1]][1];
    #   extract stain number
    stain.name <- strsplit(file.name, "_")[[1]][6];
    #Checks if stain name does not exist, because the output will be messed up if so
    if (is.na(stain.name)) {
      noStainError <- paste0("Warning: File ", file.name, " does not have stain name included, please rename and rerun script")
      stop(noStainError)
    }
    return(stain.name);
  }   #   get.stain.name()
  #-------------------------------------------------------------------------
  #-------------------------------------------------------------------------
  #   Setup
  #-------------------------------------------------------------------------
  #-------------------------------------------------------------------------
  
  #Remove older consolidated_files file
  fn <- "consolidated_files.xlsx";
  if(file.exists(fn))
    file.remove(fn);
  
  #   identify all .xls files in the directory 
  files <- list.files(getwd(), pattern = ".xls$");
  
  #   create list to hold output data.frames
  output <- list();
  #   create vector for storing the different stain numbers so that diff sheets created
  stain.names <- c();
  #   create workbook to save the data to
  workbook <- loadWorkbook("consolidated_files.xlsx", create = TRUE);
  #   create vector to store the different mice id for use in the summary
  mouse.ids <- c();
  #-------------------------------------------------------------------------
  #-------------------------------------------------------------------------
  #   Read workbook contents into R
  #-------------------------------------------------------------------------
  #-------------------------------------------------------------------------
  
  #   for all files in the directory
  for(i in 1:length(files))   {
    
    #   get current file name
    file.name <- files[i];
    
    #   read in file content
    file.content <- read_excel(path=file.name,
                               sheet=1,     #   Workbook output by ImageScope always contains only one worksheet
                               col_names=TRUE);
    
    #   extract column headings, for output (and possibly QC), for the first file only
    if(i == 1)
      column.headings <- colnames(file.content);
    
    #   extract relevant metadata from file name
    mouse.idnum <- get.mouse.id(file.name);
    slide.number <- get.slide.num(file.name);
    stain.nameber <- get.stain.name(file.name);
    
    #Adds stain number to stain.names if it does not already exist in the vector
    if(!stain.nameber %in% stain.names) {
      stain.names <- c(stain.names, stain.nameber);
      #  Create a sheet in the master workbook for each stain
      createSheet(workbook, name = stain.nameber);
    }
    
    #Adds stain number to stain.names if it does not already exist in the vector
    if(!mouse.idnum %in% mouse.ids) {
      mouse.ids <- c(mouse.ids, mouse.idnum);
    }
    
    #   prepend metadata to file content
    file.content <- cbind(stain.nameber,mouse.idnum, slide.number, file.content);
    
    #   append file content to output data.frame
    output <- rbind(output, file.content);
    
    
  }   #   for i
  
  #-------------------------------------------------------------------------
  #-------------------------------------------------------------------------
  #   Export results
  #-------------------------------------------------------------------------
  #-------------------------------------------------------------------------
  
  
  #Assign the column names to the data.frame
  colnames(output) <- predefined.column.headers;
  
  #  get the current sheets in the master workbook, which is in the same order
  #  as stain.nameber
  currentSheets <- getSheets(workbook);
  
  for(i in 1:length(currentSheets)) {
    # Selects the subset of the output that has the same stain number
    output.subset <- output[output[,1]==stain.names[i],]
    #Drops the Stain number from the data.frame before writing it
    output.subset[,1] <- NULL
    #Get rid of stain number on columns, since that is stored in sheet name
    writeWorksheet(workbook, output.subset, sheet = currentSheets[i], 1, 1, header = TRUE)
  }
  
  #saves and actually writes the data to an Excel file
  saveWorkbook(workbook);
  
  
  #-------------------------------------------------------------------------
  #-------------------------------------------------------------------------
  #   Summary of Data
  #-------------------------------------------------------------------------
  #-------------------------------------------------------------------------
  
  #Subset output so that Stain Num are not converted and stay strings
  #Then add back in to data.frame 
  factor_to_numbers <- output
  factor_to_numbers$'Stain' <- NULL
  
  #   convert factors to numbers
  #       Not elegant, but needed so that the first three columns are converted
  #       to their numeric values and not factor level values
  factor_to_numbers<- sapply(factor_to_numbers, function(x) if(is.factor(x)) {
    as.numeric(as.character(x));
  } else {
    as.numeric(x);
  })
  
  factor_to_numbers <- data.frame(factor_to_numbers)
  #Reassign stain back to the temp data.frame
  factor_to_numbers$'Stain' <- output$'Stain'
  #Output is then given the modified data.frame for use in the rest of the script
  output <- factor_to_numbers
  
  #Reorder so that Stain is the first column, like it was originally
  output <- output[c(length(output), seq(1, length(output) - 1, by = 1))]
  
  #Reassign column names lost in above step
  colnames(output) <- predefined.column.headers;
  
  #Convert to numeric
  mouse.ids <- as.numeric(mouse.ids);
  
  #Create the sheet for the summary
  createSheet(workbook, name = "summary");
  
  #Write the data of the summary run in the top left corner
  writeWorksheet(workbook, date(), sheet = "summary", header = FALSE);
  
  #create summary data.frame to put all the summary info into
  mouse.summary.output <- data.frame();
  
  #subset data for each mouse and perform calulations on it
  for(i in 1:length(mouse.ids)) {
    #vector to store the data before putting into summary output
    current.summary <- NULL;
    #Add the mouse ID to the current.summary
    current.summary <- c(current.summary, mouse.ids[i])
    for(j in 1:length(stain.names)) {
      #subset output for current mouse and stain numbers
      mouse.data.current <- subset(output, output[,2]==mouse.ids[i] & output[,1]==stain.names[j])
      #Perform the calculations
      #   Averaging to get the number of cells per mm per stain and mouse
      average.size <- mean(mouse.data.current[,25]);
      average.cells <- mean(mouse.data.current[,20]);
      average.cellpermm <- average.cells/average.size;
      #Append average cell to current summary
      current.summary <- c(current.summary, average.cellpermm)
    }
    #End of inside for loop
    #save the current.summary to overall summary
    mouse.summary.output <- rbind(mouse.summary.output, current.summary)
  }
  
  #-------------------------------------------------------------------------
  #-------------------------------------------------------------------------
  #   Formatting Excel Document
  #-------------------------------------------------------------------------
  #-------------------------------------------------------------------------
  
  #  Create CellStyles to use later
  average.header <- createCellStyle(workbook, name = "AvgHeader")
  
  #Set foreground color for average.header
  setFillPattern(average.header, XLC$FILL.SOLID_FOREGROUND)
  setFillForegroundColor(average.header, XLC$COLOR.TURQUOISE)
  setBorder(average.header, side = "all", XLC$BORDER.MEDIUM, color = XLC$COLOR.BLACK)
  
  #    Create header for above the stain numbers
  #have reference to get correct number of columns
  reference <- paste0("B3:", LETTERS[length(stain.names)+1], "3")
  mergeCells(workbook, sheet = "summary", reference)
  mergedCellsIndex <- seq(2, length(stain.names)+1, 1)
  
  #Write to the worksheet
  writeWorksheet(workbook, "Average Cells/mm Per Stain", sheet = "summary", 3, 2, header = FALSE)
  #Set CellStyle to average.header
  setCellStyle(workbook, sheet = "summary", row = 3, col = mergedCellsIndex, cellstyle = average.header)
  
  #Create the columns for the data to go in
  summary.col.names <- c();
  
  for(i in 1:length(stain.names)) {
    stain.name <- paste0("Stain ", as.character(stain.names[i]));
    #put in the initial names
    if(i==1){
      summary.col.names <- c("Mouse ID", stain.name);
    } else {
      summary.col.names <- c(summary.col.names, stain.name);
    }
  }
  
  #Apply column names to the summary output
  colnames(mouse.summary.output) <- summary.col.names
  
  writeWorksheet(workbook, mouse.summary.output, sheet = "summary", startRow = 4)
  
  #Save to workbook after creating the summary
  saveWorkbook(workbook)
  ###########################end of R code #########################
EOF