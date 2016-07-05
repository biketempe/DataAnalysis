#bike count R script 
#to analyze data, report stats and generate plots
#assumes data errors have been corrected
require(graphics)
library(stringr) # interface to common string operations
#set the working directory before launching this code, e.g.:
#need to avoid setwd; not robust to different users
setwd("C:/DataAnalysis/dataproc/R")
dataPrefix <- "2014"
inPath <- "DataIn/"
outPath <- "DataOut/"
rawfile <- paste0(inPath, dataPrefix, "_BCdata.csv", collapse="") #e.g., "2014_BCdata.csv"
locfile <- paste0(inPath, dataPrefix, "_LocID.csv", collapse="") #e.g., "2014_LocID.csv"
divbyfile <- paste0(inPath, dataPrefix, "_DivBy.csv", collapse="") #e.g., "2014_DivBy.csv"
#CHECK IF FILE EXISTS
stopifnot(file.exists(rawfile) & file.exists(locfile))
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
} else bdivby <- false

#Stats
nCountRaw <- sum(rawdata$Count)
nLoc <- length(unique(rawdata$LocID))

#Merge rawdata with locdata; coerces cordon, traffic, collisions, etc. into rawdata sequence
bkdata<-merge(rawdata,locdata,by="LocID")
#divby is the vector of duplicate divide-by numbers
# CAUTION: a partial divby list will eliminate rows not in divby
#needs work: allow a partial divby list
if (bdivby) {
# missing LocId's from divby list will be assigned DivBy=1, Invalid=FALSE
# all.x=TRUE keeps missing LocID's from divby from eliminating data; get NA
  bkdata<-merge(bkdata,divby,by=c("LocID","Time"),all.x=TRUE,sort=FALSE)
  bkdata$DivBy[is.na(bkdata$DivBy)]<-1 #change from NA to 1
  bkdata$Invalid[is.na(bkdata$Invalid)]<-FALSE #change from NA to FALSE
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

#print("NA detected in input data; replaced with 0")
print("NA replaced with 0 for the following LocID")
print(bkdata$LocID[bkdata$naDetect == TRUE])
#
#account for duplicates
bkdata$tCount<-bkdata$Count/bkdata$DivBy
bkdata$tGender<-bkdata$Gender/bkdata$DivBy
bkdata$tHelmet<-bkdata$Helmet/bkdata$DivBy
bkdata$tWrongway<-bkdata$Wrongway/bkdata$DivBy
bkdata$tSidewalk<-bkdata$Sidewalk/bkdata$DivBy
#Corrected total count, used for fractional attribute calc
nCount <- sum(bkdata$tCount)
#fractional attributes, corrected for duplicates
GenderF <- sum(bkdata$tGender)/nCount
HelmetF <- sum(bkdata$tHelmet)/nCount
WrongwayF <- sum(bkdata$tWrongway)/nCount
SidewalkF <- sum(bkdata$tSidewalk)/nCount

#count tally by location, divided by nTime to get "per hour"
#attribute tallies by location
LocCounted <- with(bkdata,aggregate(bkdata$LocID, by=list(LocID,Time), FUN=sum)[,1:2]) #sum is meaningless
#this gives a data frame with column names Group.1, Group.2
colnames(LocCounted)<-c("LocID","Time") #reassign column names
LocCounted$AM <- LocCounted$Time == "AM"
LocCounted$PM <- LocCounted$Time == "PM"
#LocID contains 2 concatenated lists of unique LocID's in bkdata (not likely a complete list of all LocID's ever)
#Time is AM for the first set of LocID's, and PM for the 2nd set.
#the number of members in the AM set is not necessarily the same as that in the PM set
#
###NEEDS WORK - need to split LocCounted into two separate data frames: LocCountAM, LocCountPM
if(FALSE)
{
locdata<-merge(locdata,LocCountAM,by=c("LocID","Time"))
locdata<-merge(locdata,LocCountPM,by=c("LocID","Time"))
locdata[,year] <- locdata$AM & locdata$PM 
}
#identify which Loc & time are counted
###NEEDS WORK:
if(FALSE)
{
#add nTime column to locdata: 1 if Time=AM or PM; 2 if AM & PM; else 0)
locdata<-transform(locdata,nTime=switch(Time+1,0,1,2))

#another way to get there:
for(j in 1:LocAll) #for each location
{
  valid[1,j] <- 0 < sum(rawdata$Time == "AM" & rawdata$LocID == locvec[j])
  valid[2,j] <- 0 < sum(rawdata$Time == "PM" & rawdata$LocID == locvec[j])
  #  valid[1,j] <- 0 < sum(rawdata$Time == "AM" & rawdata$LocID == as.integer(substr(colnames(countAM[j]),2,4)))
  #  valid[2,j] <- 0 < sum(rawdata$Time == "PM" & rawdata$LocID == as.integer(substr(colnames(countPM[j]),2,4)))
  #
}
#NEED TO OUTPUT VALID
}
###


#Logical indexing
bTime <- bkdata$Time == "AM" #convert to boolean; "AM" = TRUE
bCordon <- bkdata$Cordon == 1 #convert to boolean; 1 = TRUE
#Cordon; Column1: row1=False, row2=true; column2: "x" which is Count
cordonAM <- with(bkdata,aggregate(bkdata$Count, by=list(bTime & bCordon), FUN=sum, na.rm=TRUE)[2,2])
cordonPM <- with(bkdata,aggregate(bkdata$Count, by=list(!bTime & bCordon), FUN=sum, na.rm=TRUE)[2,2])

#Calc number of recorders
rectemp <- tolower(rawdata$Recorder)
Recorders <- sort(unique(unlist(rectemp, use.names=FALSE)),decreasing=FALSE)
rtypo1 <- character(0)
grepdist <- 0.2
for(r in 1:length(Recorders))
{
  if(length(agrep(Recorders[r],Recorders,max.distance=grepdist))>1)
  {
    rtypo1 <- c(rtypo1,paste(agrep(Recorders[r],Recorders,max.distance=grepdist,value=TRUE),collapse=", "))
  }
}
rtypo <- unique(unlist(rtypo1, use.names=FALSE))
print("Here are potential typos in recorder names")
rtypo
ntypo<-length(rtypo) #need to get user input on real typo count
rteam <- c(grep("&",Recorders,value=TRUE),grep(" and ",Recorders,value=TRUE))
print("Here are potential team counts")
rteam
nteam<-length(rteam) #need to get user input on real team count
nRec <- length(Recorder) + nteam -ntypo
# END OF RECORDER CODE
###

#Report Summary = Table 1
repsumm <- data.frame(TotalCount,Locations,nRecorder) #NEEDS WORK: ,Wrongway,Sidewalk,Helmet,Female,CordonIn,CordOut
write.csv(repsumm,file="repsumm.csv")
