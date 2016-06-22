#bike count R script 
#to analyze data, report stats and generate plots
#assumes data errors have been corrected
setwd("C:/DataAnalysis/dataproc/R")
rawfile <- "BCdata2014.csv"
locfile <- "LocID2014.csv"
divbyfile <- "DivBy2014.csv"
rawdata <- read.csv(rawfile)
#rawdata fields: LocID	Time	Recorder  Page	Segment	Direction	Count	Gender 	Helmet	Wrongway	Sidewalk Seg
#locid has a row for every location ever counted, but not all locations are counted every year.
locid <- read.csv(locfile)
#locid fields: LocID	LocEW	LocNS	Cordon	NS_Lane	EW_Lane	DistToASU	Traffic	latitude	longitude	Crash_2009_2013
#divby handles multiple recorders for the same location
#needs work: can divby be a partial list? Then just apply if a locid is present
divby <- read.csv(divbyfile)
#divby fields: LocID	Time	Invalid	DivBy

TotalCount <- sum(rawdata$Count)
Locations <- length(unique(rawdata$LocID))
Recorders <- length(unique(rawdata$Recorder)) #need to check this; 82 should be 78
LocAll <- nrow(locid) # number of locations ever counted
#Prepend "L" to LocID (numbers), e.g., L101, L102, etc. for data frame column names (can't use numbers)
countAM <- data.frame(matrix(ncol = LocAll, nrow = 8)) # row for each 15-minute segment
countPM <- data.frame(matrix(ncol = LocAll, nrow = 8)) # row for each 15-minute segment
validAM <- data.frame(matrix(ncol = LocAll, nrow = 1)) 
validPM <- data.frame(matrix(ncol = LocAll, nrow = 1)) 
#  Seg 1:8 AM, 9:16 PM
colnames(countAM) <- paste("L",locid[,1], sep="")
colnames(countPM) <- paste("L",locid[,1], sep="")
# sum data for each segment and put in a data frame
for(j in 1:LocAll) #for each column
{
#identify which Loc & time are counted
  validAM[1,j] <- 0 < sum(rawdata$Time == "AM" & rawdata$LocID == as.integer(substr(colnames(countAM[j]),2,LocAll)))
  validPM[1,j] <- 0 < sum(rawdata$Time == "PM" & rawdata$LocID == as.integer(substr(colnames(countPM[j]),2,LocAll)))
  for(i in 1:8) #for each row
 {
    if(validAM[1,j])
    {
      countAM[i,j] <- 
      sum(rawdata$Count[rawdata$Seg == i & rawdata$LocID == as.integer(substr(colnames(countAM[j]),2,LocAll))])
    }
    if(validPM[1,j])
    {
      countPM[i,j] <- 
        sum(rawdata$Count[rawdata$Seg == i+8 & rawdata$LocID == as.integer(substr(colnames(countPM[j]),2,LocAll))])
    }
  }
}
#display the data frame
countAM
countPM

#Report Summary = Table 1
repsumm <- data.frame(TotalCount,Locations,Recorders) #NEEDS WORK: ,Wrongway,Sidewalk,Helmet,Female,CordonIn,CordOut
write.csv(repsumm,file="repsumm.csv")
