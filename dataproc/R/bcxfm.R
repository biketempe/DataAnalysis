#Bike Count Transform
#
#NOTE: This code is obsolete and not complete. It has been replaced by bcxfm.xlsx
#
#from count sheets to single file standard input for bcstat.R
#tasks: 
#  concatenate csv files' count and attribute data; combine team counts using Excel (133A, 133P)
#  correct date if misinterpreted as 2017
#  replicate LocID and Time for all rows
#  calculate Page, Segment, Direction; fill columns
#  extract recorder names
#  (optional) fill recorder column
# (optional) calculate Seg, SegSeq and fill columns
rm(list=ls())
rwd <- getwd() #assume working directory is set correctly
#assume subdirectories are already created
inPath <- paste0(rwd, "/DataIn/CompleteCSV/")
#outPath <- rwd & "/DataOut/"
outPath <- paste0(rwd, "/DataIn/") #output is input to next R program, bcstat.R
filenames <- list.files(path = inPath, pattern="*.csv", full.names=FALSE)
#example: "101_A.csv"
filenames <- as.character(substr(filenames, 1, nchar(filenames) - 4)) #strip ".csv"
nfiles <- length(filenames)
fin1 <- filenames[1]
bkdata <- read.csv(paste0(inPath, fin1, ".csv"),stringsAsFactors=FALSE) #model for columns; must have all columns that other files have
fsummary <- as.data.frame(filenames, stringsAsFactors=FALSE) #coerce filenames to data frame
fsummary[1,"nRowsDet"] <- nrow(bkdata) #add column, blank for now
#
for(i in 2:nfiles) {
  bcsheet <- read.csv(paste0(inPath, filenames[i], ".csv"))
  fsummary[i,2] <- nrow(bcsheet) #number of rows read from each BC sheet; should be 16 or 32
  MissingCol <- setdiff(names(bkdata), names(bcsheet))
  bcsheet[MissingCol] <- 0
  bkdata <- rbind(bkdata, bcsheet)
}
bkdata$Page <- as.Numeric(rownames(bkdata))
#To do:
# why not use a simple file concatenate function? Then do the time & Dir conversion in Excel
# some csv files are 1 page (22 files), some 2 pages, but all have 32 rows;
#   easiest fix is to combine split csv's manually
#   could add numbers, but this makes time stamp wrong, and doesn't work for duplicate counts
#   determining Page number: in the file name:
#    _7, _4 = Page 1
#    _8, _5 = Page 2
#  i.e., Page 2 data is in rows 1:16
# convert TimeSeg=:00, :15, ... to Segment=1,2,3,4; SegSeq=1,2,...8, Page=1,2
# convert Time=A,P to Time=AM,PM 
# convert Dir = NB, SB, EB, WB to Direction = 1:4
# add column "NotesTranscription" if it does not exist
# fill Recorder name into all rows for each bcsheet
# convert date formats
#
#needs work: what to do with extra columns (e.g. TimeSeg, Dir, LocEW, LocNS)
If (1==2) {
# order of column names for final csv output
colnamefinal <- c(
  "LocID",
  "Time",
  "Recorder",
  "Empty",
  "Page",
  "Segment",
  "Direction",
  "Count",
  "Gender",
  "Helmet",
  "Wrongway",
  "Sidewalk",
  "Notes")
bkdata <- bkdata[colnamefinal]
}
#don't need the rest of this
If (1==2) {
  nCols <- 15 #number of columns to be read in inpput csv files
  resultTable <- matrix(data = NA, nrow = 1, ncol = nCols) #for col headers
filenamedummy <- character(1)
results <- data.frame(filenamedummy, resultTable)
outF <- paste0(outPath, "BCdata.csv", collapse=NULL) #rename later to 2016_BCdata.csv
#this is the first line with column names
write.table(results, outF, append=FALSE, col.names = TRUE, sep=",", row.names=FALSE) 
#reset matrix size
resultTable <- matrix(data = NA, nrow = 32, ncol = nCols)
for(i in 1:length(filenames)) {
  read.csv()
  resultTable <- bcsheet(filenames[i]) #
}
}

