#bike count R script 
#to analyze data, report stats and generate plots
#assumes data errors have been corrected
require(graphics)
library(stringr) # interface to common string operations
library(plyr)
#Note: start R in the correct directory
#setwd("C:/DataAnalysis/dataproc/R") #better to avoid setwd; not robust to different users
source("recorders.R")
dataPrefix <- readline("Enter the file prefix to be analyzed, e.g., 2014 for input file 2014_bcdata.csv: ") 
inPath <- "DataIn/"
outPath <- "DataOut/"
#input files
rawfile <- paste0(inPath, dataPrefix, "_BCdata.csv", collapse="") #e.g., "2014_BCdata.csv"
locfile <- paste0(inPath, dataPrefix, "_LocID.csv", collapse="") #e.g., "2014_LocID.csv"
divbyfile <- paste0(inPath, dataPrefix, "_DivBy.csv", collapse="") #e.g., "2014_DivBy.csv"
#CHECK IF FILE EXISTS
stopifnot(file.exists(rawfile) & file.exists(locfile))
#
#output files
repsummfile <- paste0(outPath, dataPrefix, "_repsumm.csv", collapse="") #e.g., "2014_repsumm.csv"
#
rawdata <- read.csv(rawfile)
#rawdata fields: LocID	Time	Recorder  Page	Segment	Direction	Count	Gender 	Helmet	Wrongway	Sidewalk Seg SegSeq
#locdata has a row for every location ever counted, but not all locations are counted every year.
locdata <- read.csv(locfile)
#locdata fields: LocID	LocEW	LocNS	Cordon	NS_Lane	EW_Lane	DistToASU	Traffic	latitude	longitude	Crash_2009_2013
#divby contains data on duplicate recorders for the same location
#DivBy should be 
# 1 for a single recorder
# 1 for multiple recorders who split a count (no overlap)
# n for n recorders taking complete data for the same location and time (same or different day)
#divby can be a partial list; default value of DivBy is 1
if(file.exists(divbyfile)) {
#divby fields: LocID	Time	Invalid	DivBy
  divby <- read.csv(divbyfile)
  bdivby = TRUE
} else bdivby <- FALSE

#Stats
nCountRaw <- sum(rawdata$Count)
nLoc <- length(unique(rawdata$LocID))
#
#Merge rawdata with locdata; coerces cordon, traffic, collisions, etc. into rawdata sequence
bkdata <- merge(rawdata,locdata,by="LocID")
#divby is the vector of duplicate divide-by numbers
# CAUTION: a partial divby list will eliminate rows not in divby
#needs work: allow a partial divby list
if (bdivby) {
# missing LocId's from divby list will be assigned DivBy=1, Invalid=FALSE
# all.x=TRUE keeps missing LocID's from divby from eliminating data; get NA
  bkdata <- merge(bkdata, divby, by=c("LocID","Time"), all.x=TRUE, sort=FALSE)
  bkdata$DivBy[is.na(bkdata$DivBy)] <- 1 #change from NA to 1
  bkdata$Invalid[is.na(bkdata$Invalid)] <- FALSE #change from NA to FALSE
} else {
  bkdata$DivBy <- 1 #no divby file; set divby=1, i.e., assume there are no duplicates
  bkdata$Invalid <- FALSE #note: Invalid is not currently used
}
#FLAG MISSING DATA IN Count and attributes
bkdata$naDetect <- FALSE
bkdata$naDetect[is.na(bkdata$Count) | 
                  is.na(bkdata$Gender) |
                  is.na(bkdata$Helmet) |
                  is.na(bkdata$Wrongway) |
                  is.na(bkdata$Sidewalk)] <- TRUE
# replace NA with 0
bkdata$Count[is.na(bkdata$Count)] <- 0
bkdata$Gender[is.na(bkdata$Gender)] <- 0
bkdata$Helmet[is.na(bkdata$Helmet)] <- 0
bkdata$Wrongway[is.na(bkdata$Wrongway)] <- 0
bkdata$Sidewalk[is.na(bkdata$Sidewalk)] <- 0
#
#print("NA detected in input data; replaced with 0")
print("NA replaced with 0 for the following LocID")
print(bkdata$LocID[bkdata$naDetect == TRUE])
#
#account for duplicates (t for transformed, e.g., corrected for duplicates)
bkdata$tCount<-bkdata$Count/bkdata$DivBy
bkdata$tGender<-bkdata$Gender/bkdata$DivBy
bkdata$tHelmet<-bkdata$Helmet/bkdata$DivBy
bkdata$tWrongway<-bkdata$Wrongway/bkdata$DivBy
bkdata$tSidewalk<-bkdata$Sidewalk/bkdata$DivBy
# Define directions; combine north & south as NS; combine east and west as EW
bkdata$Dir <- ifelse(bkdata$Direction == 1 | bkdata$Direction == 2, "NS", "EW")
# create sums by location, split by NS and EW directions (Table in Appendix)
summdir <- aggregate(cbind(tCount,tGender,tHelmet,tWrongway,tSidewalk) ~ LocID + Dir, sum, data = bkdata)
#total transformed count by location and time of day (AM or PM)
timeTot <- aggregate(tCount ~ LocID + Dir + Time, sum, data = bkdata)
#
AMcount <- timeTot[timeTot$Time == "AM",]
PMcount <- timeTot[timeTot$Time == "PM",]
colnames(AMcount)[4] <- "AMtot" #was tCount; set name for upcoming merge
colnames(PMcount)[4] <- "PMtot" #was tCount; set name for upcoming merge
# all=TRUE keeps LocIDs from getting culled (e.g., AM but not PM); sort is not in final form
summdir <- merge(summdir, AMcount, by=c("LocID", "Dir"), all=TRUE)
summdir <- summdir[ , !(names(summdir) %in% "Time")] #remove unwanted "Time" column
summdir <- merge(summdir, PMcount, by=c("LocID", "Dir"), all=TRUE)
summdir <- summdir[ , !(names(summdir) %in% "Time")] #remove unwanted "Time" column
#
summdir$Count <- summdir$tCount
summdir$Female <- summdir$tGender/summdir$tCount
summdir$Helmet <- summdir$tHelmet/summdir$tCount
summdir$Wrongway <- summdir$tWrongway/summdir$tCount
summdir$Sidewalk <- summdir$tSidewalk/summdir$tCount
#note: if tCount==0 then result is NaN which is fine, e.g., LocID 112 EW
#Corrected total count, used for fractional attribute calc
nCount <- round(sum(bkdata$tCount),0) #R rounds half to even
#fractional attributes, corrected for duplicates
FemaleF <- sum(bkdata$tGender)/nCount
HelmetF <- sum(bkdata$tHelmet)/nCount
WrongwayF <- sum(bkdata$tWrongway)/nCount
SidewalkF <- sum(bkdata$tSidewalk)/nCount

#count tally by location, divided by nTime to get "per hour"
#attribute tallies by location
LocCounted <- with(bkdata,aggregate(bkdata$LocID, by=list(LocID,Time), FUN=sum)[,1:2]) #FUN=sum is meaningless
#this gives a data frame with column names Group.1, Group.2
colnames(LocCounted) <- c("LocID","Time") #reassign column names
LocCounted$AM <- LocCounted$Time == "AM"
LocCounted$PM <- LocCounted$Time == "PM"
#LocID contains 2 concatenated lists of unique LocID's in bkdata (not likely a complete list of all LocID's ever)
#Time is AM for the first set of LocID's, and PM for the 2nd set.
#the number of members in the AM set is not necessarily the same as that in the PM set
#Count the number of times each location was counted (either 1 or 2); not 0 because then the LocID is not present
LocTimes <- with(LocCounted,aggregate(LocID, by=list(LocID), FUN=length)) 
colnames(LocTimes)<-c("LocID","nTime") #reassign column names
# merge this data to enable total per hour
summdir <- merge(summdir, LocTimes,by="LocID")
summdir$TotPerHr <- round(summdir$Count / summdir$nTime / 2, digits = 0)#R rounds half to even
summdir$AMPerHr <- round(summdir$AMtot / 2, digits = 0) #R rounds half to even
summdir$PMPerHr <- round(summdir$PMtot / 2, digits = 0) #R rounds half to even
# pull in locdata (traffic, etc.)
summdir <- merge(summdir, locdata, by=c("LocID"))
# sort with NS first
summdir <- with(summdir, summdir[order(-xtfrm(Dir), LocID),]) #xtfrm is needed for reverse order of character vector
# output
write.csv(summdir, file = paste0(outPath, dataPrefix, "_summdir.csv", collapse = ""), row.names = FALSE)
#
#Logical indexing
bTime <- bkdata$Time == "AM" #convert to boolean; "AM" = TRUE
bCordon <- bkdata$Cordon == 1 #convert to boolean; 1 = TRUE
#Cordon; Column1: row1=False, row2=true; column2: "x" which is Count
cordonAM <- with(bkdata,aggregate(bkdata$Count, by=list(bTime & bCordon), FUN=sum, na.rm=TRUE)[2,2])
cordonPM <- with(bkdata,aggregate(bkdata$Count, by=list(!bTime & bCordon), FUN=sum, na.rm=TRUE)[2,2])
# get the number of recorders and output special cases
nRecorder <- nRecorders(rawdata, dataPrefix, outPath)
#Report Summary = Table 1
repsumm <- data.frame(
  nCountRaw,nLoc,nRecorder,WrongwayF,SidewalkF,HelmetF,FemaleF,cordonAM,cordonPM,nCount)
write.csv(repsumm,file=repsummfile)
#END OF CODE