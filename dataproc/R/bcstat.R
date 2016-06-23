#bike count R script 
#to analyze data, report stats and generate plots
#assumes data errors have been corrected
setwd("C:/DataAnalysis/dataproc/R")
rawfile <- "BCdata2014.csv"
locfile <- "LocID2014.csv"
divbyfile <- "DivBy2014.csv"
rawdata <- read.csv(rawfile)
#rawdata fields: LocID	Time	Recorder  Page	Segment	Direction	Count	Gender 	Helmet	Wrongway	Sidewalk Seg SegSeq
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
#Append "A" or "P" to LocID (numbers), e.g., 101A, 102A, etc. for data frame column names (can't use numbers)
Count <- data.frame(matrix(ncol = LocAll*2, nrow = 8)) # 1 row for each 15-minute segment
Gender <- data.frame(matrix(ncol = LocAll*2, nrow = 8)) 
Helmet <- data.frame(matrix(ncol = LocAll*2, nrow = 8)) 
Wrongway <- data.frame(matrix(ncol = LocAll*2, nrow = 8)) 
Sidewalk <- data.frame(matrix(ncol = LocAll*2, nrow = 8)) 
AMPM <- c("AM","PM")
valid <- data.frame(matrix(ncol = LocAll, nrow = 2)) 
# Seg 1:8 AM, 9:16 PM
# SegSeq 1:8
locvec <-locid[,1]
locnames <- c(paste(locvec,"A",sep=""),paste(locvec,"P",sep=""))
colnames(Count) <- locnames
# sum data for each segment and put in a data frame
for(j in 1:LocAll) #for each location
{
#identify which Loc & time are counted
  valid[1,j] <- 0 < sum(rawdata$Time == "AM" & rawdata$LocID == locvec[j])
  valid[2,j] <- 0 < sum(rawdata$Time == "PM" & rawdata$LocID == locvec[j])
#  valid[1,j] <- 0 < sum(rawdata$Time == "AM" & rawdata$LocID == as.integer(substr(colnames(countAM[j]),2,4)))
#  valid[2,j] <- 0 < sum(rawdata$Time == "PM" & rawdata$LocID == as.integer(substr(colnames(countPM[j]),2,4)))
  for(t in 1:2) #AM, PM
  {
    for(i in 1:8) #for each segment
    {
      if(valid[t,j])
      {
        Count[i,j+(t-1)*LocAll] <- 
          sum(rawdata$Count[rawdata$SegSeq == i & rawdata$LocID == locvec[j] & rawdata$Time == AMPM[t]])/divby$DivBy[j+(t-1)*LocAll]
        Gender[i,j+(t-1)*LocAll] <- 
          sum(rawdata$Gender[rawdata$SegSeq == i & rawdata$LocID == locvec[j] & rawdata$Time == AMPM[t]])/divby$DivBy[j+(t-1)*LocAll]
        Helmet[i,j+(t-1)*LocAll] <- 
          sum(rawdata$Helmet[rawdata$SegSeq == i & rawdata$LocID == locvec[j] & rawdata$Time == AMPM[t]])/divby$DivBy[j+(t-1)*LocAll]
        Wrongway[i,j+(t-1)*LocAll] <- 
          sum(rawdata$Wrongway[rawdata$SegSeq == i & rawdata$LocID == locvec[j] & rawdata$Time == AMPM[t]])/divby$DivBy[j+(t-1)*LocAll]
        Sidewalk[i,j+(t-1)*LocAll] <- 
          sum(rawdata$Sidewalk[rawdata$SegSeq == i & rawdata$LocID == locvec[j] & rawdata$Time == AMPM[t]])/divby$DivBy[j+(t-1)*LocAll]
      }
    }
  }    
}

#display the data frames
Count
Gender
Helmet
Wrongway
Sidewalk

#Report Summary = Table 1
repsumm <- data.frame(TotalCount,Locations,Recorders) #NEEDS WORK: ,Wrongway,Sidewalk,Helmet,Female,CordonIn,CordOut
write.csv(repsumm,file="repsumm.csv")
