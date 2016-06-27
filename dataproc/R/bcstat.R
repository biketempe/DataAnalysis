#bike count R script 
#to analyze data, report stats and generate plots
#assumes data errors have been corrected
require(graphics)
library(stringr) # interface to common string operations
setwd("C:/DataAnalysis/dataproc/R")
rawfile <- "BCdata2014.csv"
locfile <- "LocID2014.csv"
divbyfile <- "DivBy2014.csv"
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
nCount <- sum(rawdata$Count)
nLoc <- length(unique(rawdata$LocID))

#This doesn't work (gives a single column):
#cordon<-data.frame(count=rawdata$Count,crdn=locdata[match(rawdata$LocID,locid$Cordon),0])
#Merge rawdata with locdata; coerces cordon, traffic, collisions, etc. into rawdata sequence
bkdata<-merge(rawdata,locdata,by.x="LocID",by.y="LocID")
#gives error:
#cordonAM<-aggregate(mrg,by=list(Count,Cordon),FUN=sum,na.rm=TRUE)
#cordonAM<-colSums(mrg[,sum(Count,na.rm=TRUE),by=Cordon])
#
#Logical indexing
bTime <- bkdata$Time == "AM" #convert to boolean; "AM" = TRUE
bCordon <- bkdata$Cordon == 1 #convert to boolean; 1 = TRUE
#Cordon
cordonAM <- with(bkdata,aggregate(bkdata$Count, by=list(bTime & bCordon), FUN=sum, na.rm=TRUE)[2,2])
cordonPM <- with(bkdata,aggregate(bkdata$Count, by=list(!bTime & bCordon), FUN=sum, na.rm=TRUE)[2,2])

### delete this:
# timesum <- aggregate(bkdata$Count, by=list(Time), FUN=sum, na.rm=TRUE)
# cordonAM <- timesum[timesum$Group.1=="AM","x"] #Group.1 is Time because it's 1st in the by list
# cordonPM <- timesum[timesum$Group.1=="PM","x"] #x is assigned by default
###

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

#Set up data frame with tallies for each segment (not sure this needs to be done)
LocAll <- nrow(locdata) # number of locations ever counted
CountSeg <- data.frame(matrix(ncol = LocAll*2, nrow = 8)) # 1 row for each 15-minute segment
GenderSeg <- data.frame(matrix(ncol = LocAll*2, nrow = 8)) 
HelmetSeg <- data.frame(matrix(ncol = LocAll*2, nrow = 8)) 
WrongwaySeg <- data.frame(matrix(ncol = LocAll*2, nrow = 8)) 
SidewalkSeg <- data.frame(matrix(ncol = LocAll*2, nrow = 8)) 
AMPM <- c("AM","PM")
valid <- data.frame(matrix(ncol = LocAll, nrow = 2)) 
# Seg 1:8 AM, 9:16 PM
# SegSeq 1:8
locvec <-locdata[,1]
#Append "A" or "P" to LocID (numbers), e.g., 101A, 102A, etc. for data frame column names (can't use numbers)
locnames <- c(paste(locvec,"A",sep=""),paste(locvec,"P",sep=""))
colnames(CountSeg) <- locnames
colnames(GenderSeg) <- locnames
colnames(HelmetSeg) <- locnames
colnames(WrongwaySeg) <- locnames
colnames(SidewalkSeg) <- locnames
# sum data for each segment and put in a data frame
for(j in 1:LocAll) #for each location
{
#identify which Loc & time are counted
  valid[1,j] <- 0 < sum(rawdata$Time == "AM" & rawdata$LocID == locvec[j])
  valid[2,j] <- 0 < sum(rawdata$Time == "PM" & rawdata$LocID == locvec[j])
#  valid[1,j] <- 0 < sum(rawdata$Time == "AM" & rawdata$LocID == as.integer(substr(colnames(countAM[j]),2,4)))
#  valid[2,j] <- 0 < sum(rawdata$Time == "PM" & rawdata$LocID == as.integer(substr(colnames(countPM[j]),2,4)))
#
# THIS COULD BE MUCH SIMPLER IF DATA WAS COUNTED INSTEAD OF PUT INTO BIG DATA FRAMES AND THEN COUNTED.
#
for(t in 1:2) #AM, PM
  {
    for(i in 1:8) #for each segment
    {
      if(valid[t,j])
      {
        CountSeg[i,j+(t-1)*LocAll] <- 
          sum(rawdata$Count[rawdata$SegSeq == i & rawdata$LocID == locvec[j] & rawdata$Time == AMPM[t]])/divby$DivBy[j+(t-1)*LocAll]
        GenderSeg[i,j+(t-1)*LocAll] <- 
          sum(rawdata$Gender[rawdata$SegSeq == i & rawdata$LocID == locvec[j] & rawdata$Time == AMPM[t]])/divby$DivBy[j+(t-1)*LocAll]
        HelmetSeg[i,j+(t-1)*LocAll] <- 
          sum(rawdata$Helmet[rawdata$SegSeq == i & rawdata$LocID == locvec[j] & rawdata$Time == AMPM[t]])/divby$DivBy[j+(t-1)*LocAll]
        WrongwaySeg[i,j+(t-1)*LocAll] <- 
          sum(rawdata$Wrongway[rawdata$SegSeq == i & rawdata$LocID == locvec[j] & rawdata$Time == AMPM[t]])/divby$DivBy[j+(t-1)*LocAll]
        SidewalkSeg[i,j+(t-1)*LocAll] <- 
          sum(rawdata$Sidewalk[rawdata$SegSeq == i & rawdata$LocID == locvec[j] & rawdata$Time == AMPM[t]])/divby$DivBy[j+(t-1)*LocAll]
      }
    }
  }    
}
#combine AM & PM
Count <- colSums(CountSeg)
Gender <- colSums(GenderSeg)
Helmet <- colSums(HelmetSeg)
Wrongway <- colSums(WrongwaySeg)
Sidewalk <- colSums(SidewalkSeg)

GenderF <- Gender/Count
HelmetF <- Helmet/Count
WrongwayF <- Wrongway/Count
SidewalkF <- Sidewalk/Count
#
for(i in 1:LocAll)
{
  CountT[i]<-Count[i]+Count[i+LocAll]
}
#display the data frames
Count
Gender
Helmet
Wrongway
Sidewalk


#Report Summary = Table 1
repsumm <- data.frame(TotalCount,Locations,nRecorder) #NEEDS WORK: ,Wrongway,Sidewalk,Helmet,Female,CordonIn,CordOut
write.csv(repsumm,file="repsumm.csv")
