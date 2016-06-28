#bike count R script 
#to analyze data, report stats and generate plots
#assumes data errors have been corrected
require(graphics)
library(stringr) # interface to common string operations
setwd("C:/DataAnalysis/dataproc/R")
year <- "2014"
rawfile <- paste0("BCdata",year,".csv") #e.g., "BCdata2014.csv"
locfile <- paste0("LocID",year,".csv") #e.g., "LocID2014.csv"
divbyfile <- paste0("DivBy",year,".csv") #e.g., "DivBy2014.csv"
#CHECK IF FILE EXISTS
stopifnot(file.exists(rawfile) & file.exists(locfile) & file.exists(divbyfile))
#
rawdata <- read.csv(rawfile)
#rawdata fields: LocID	Time	Recorder  Page	Segment	Direction	Count	Gender 	Helmet	Wrongway	Sidewalk Seg SegSeq
#locdata has a row for every location ever counted, but not all locations are counted every year.
locdata <- read.csv(locfile)
#locdata fields: LocID	LocEW	LocNS	Cordon	NS_Lane	EW_Lane	DistToASU	Traffic	latitude	longitude	Crash_2009_2013
#divby handles multiple recorders for the same location
#needs work: can divby be a partial list? Then just apply if a LocID is present
divby <- read.csv(divbyfile)
#divby fields: LocID	Time	Invalid	DivBy

#Stats
nCountRaw <- sum(rawdata$Count)
nLoc <- length(unique(rawdata$LocID))

#Merge rawdata with locdata; coerces cordon, traffic, collisions, etc. into rawdata sequence
bkdata<-merge(rawdata,locdata,by="LocID")
#divby is the vector of duplicate divide-by numbers
bkdata<-merge(bkdata,divby,by=c("LocID","Time"))

#correct for duplicates NEEDS WORK - DOES NOT WORK AS INTENDED
bkdata<-transform(bkdata,
  tCount=prod(Count,DivBy), 
  tGender=prod(Gender,DivBy),
  tHelmet=prod(Helmet,DivBy),
  tWrongway=prod(Wrongway,DivBy),
  tSidewalk=prod(Sidewalk,DivBy)
)

#Corrected total count, used for fractional attribute calc
nCount <- sum(rawdata$tCount)
#fractional attributes, corrected for duplicates
GenderF <- sum(rawdata$tGender)/nCount
HelmetF <- sum(rawdata$tHelmet)/nCount
WrongwayF <- sum(rawdata$tWrongway)/nCount
SidewalkF <- sum(rawdata$tSidewalk)/nCount

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
