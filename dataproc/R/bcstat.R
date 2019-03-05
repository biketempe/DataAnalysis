#bike count R script 
#to analyze data, report stats and generate plots
#assumes data errors have been corrected
#assumes duplicates have been averaged in _BCdata, with dup's (both instances) in separate file _BCdata_Dup if dup's exist
userinput <- "N"
while (!(tolower(userinput) == "y" | userinput == "")) {userinput <- readline("OK to clear workspace? [Y]")}
rm(list=ls()) 
#remove (almost) everything in the working environment
#Note: user must start R in the correct directory
#setwd("C:/DataAnalysis/dataproc/R") #better to avoid setwd; not robust to different users
print("**Team counts must be combined prior to running this code (to get correct results)**")
dataPrefix <- readline("Enter the file prefix to be analyzed, e.g., 2014 for input file 2014_bcdata.csv: ") 
#
#for running portion of code manually, start here (bypasses user input)
if(!exists("dataPrefix")) dataPrefix <- 2018 #debug step for 2018 analysis
source("recorders.R")
require(graphics)
library(stringr) # interface to common string operations
library(plyr)
library(ggmap) #for Geoplot
#get API key @ https://developers.google.com/places/web-service/get-api-key
APIfile <- "GoogleAPIkey.txt"
key <- readChar(APIfile, file.info(APIfile)$size)
register_google(key = key)
#Note: works with ggmap_3.0.0 but not ggmap_2.5.1
#https://stackoverflow.com/questions/53275443/unable-to-use-register-google-in-r
#
inPath <- "DataIn/"
outPath <- paste0("DataOut/", dataPrefix, "/")
#input files
rawfile <- paste0(inPath, dataPrefix, "_BCdata.csv") #e.g., "2014_BCdata.csv"
rawfiledup <- paste0(inPath, dataPrefix, "_BCdata_Dup.csv") #e.g., "2016_BCdata_Dup.csv"
locfile <- paste0(inPath, dataPrefix, "_LocID.csv") #e.g., "2014_LocID.csv"
divbyfile <- paste0(inPath, dataPrefix, "_DivBy.csv") #e.g., "2014_DivBy.csv"
recfile <- paste0(inPath, dataPrefix, "_RecCount.csv") #e.g., "2017_RecCount.csv"
#CHECK IF FILE EXISTS
stopifnot(file.exists(rawfile) & file.exists(locfile))
#
#output files
repsummfile <- paste0(outPath, dataPrefix, "_RepSumm.csv") #e.g., "2014_repsumm.csv"
#
rawdata <- read.csv(rawfile)
if(file.exists(rawfiledup)) rawdatadup <- read.csv(rawfiledup)
#rawdata fields: LocID	Time	Recorder  Date Page	Segment	Direction	Count	Gender 	Helmet	Wrongway	Sidewalk
#
#Error check
rawdata$Error <- with(rawdata, Count < Gender | Count < Helmet | Count < Wrongway | Count < Sidewalk)
print("Number of lines with detected errors (any attribute > count)")
print(sum(rawdata$Error))
errList <- rawdata[rawdata$Error == TRUE,]
write.csv(errList, file = paste0(outPath, dataPrefix, "_ErrList.csv", collapse = ""), row.names = FALSE)
#
#blank data check
sessionTot <- aggregate(Count ~ LocID + Time, sum, data = rawdata)
blankSession <- sessionTot[sessionTot$Count == 0,]
print("LocIDs with blank or zero data")
print(nrow(blankSession))
#
#locdata has a row for every location ever counted, but not all locations are counted every year.
locdata <- read.csv(locfile)
#convert NA to 0 for appropriate columns
nakeep <- c("Traffic","TrafficNS","TrafficEW","Node1","Node2","Node3","Node4")
na0 <- names(locdata[ ,!(colnames(locdata) %in% nakeep)])
locdata[na0][is.na(locdata[na0])] <- 0
#
#locdata fields: LocID	LocEW	LocNS	Cordon	NB_ASU_in	SB_ASU_in	EB_ASU_in	WB_ASU_in	NBLane	SBLane	EBLane	WBLane	
#  NBZip	SBZip	Zone	DistASU	Traffic	TrafficNS	TrafficEW	Latitude	Longitude	
#  NBswSkip	SBswSkip	EBswSkip	WBswSkip
# "Traffic" is the max of all directions
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
  print("Using external file for duplicate calculation (overrides internal calculation)")
} else bdivby <- FALSE
#
#Stats
nCountRaw <- sum(rawdata$Count) + ifelse(file.exists(rawfiledup), round(0.5*sum(rawdatadup$Count, na.rm = TRUE),0),0) 
#total counted including duplicate counts; 
# for 2016, the rawdata used the average of the duplicate totals, as a replacement for each of the two original counts.
#The replaced data was put in the separate file rawfiledup. 
#Use 1/2 of the dup count from rawfiledup because the main count has half already
nLoc <- length(unique(rawdata$LocID))
#
#Merge rawdata with locdata; coerces cordon, traffic, collisions, etc. into rawdata sequence
bkdata <- merge(rawdata,locdata,by="LocID",all=TRUE)
bkdata <- bkdata[!is.na(bkdata$Time),] #removes LocIDs that aren't counted for the current year
#Set Sw, Ww to zero if sidewalk ignore = 1 for the appropriate direction
bkdata$LocTime <- paste0(bkdata$LocID, bkdata$Time)
bkdata$SwErr <- with(bkdata, {
  (NBswSkip == 1 & Direction == 1 & (Sidewalk > 0 | Wrongway > 0)) |
  (SBswSkip == 1 & Direction == 2 & (Sidewalk > 0 | Wrongway > 0)) |
  (EBswSkip == 1 & Direction == 3 & (Sidewalk > 0 | Wrongway > 0)) |
  (WBswSkip == 1 & Direction == 4 & (Sidewalk > 0 | Wrongway > 0)) })
print("Locations detected with Sidewalk or Wrongway data that should have been ignored:")
print(unique(bkdata$LocTime[bkdata$SwErr == TRUE]))
#If you need it, here is code to fix Sidewalk, wrongway issues
#with(bkdata, {
#  Sidewalk[NBswSkip == 1 & Direction == 1] <- 0
#  Sidewalk[SBswSkip == 1 & Direction == 2] <- 0
#  Sidewalk[EBswSkip == 1 & Direction == 3] <- 0
#  Sidewalk[WBswSkip == 1 & Direction == 4] <- 0 })
#
#divby is the vector of duplicate divide-by numbers
# all.x=TRUE allows a partial divby list
# all.x: if TRUE, then extra rows will be added to the output, one for each row in x that has no matching row in y. 
# These rows will have NAs in those columns that are usually filled with values from y.
#
#Tallies by location + AM or PM, divided by nTime to get "per hour"
#Create a data frame with 1 row per counted LocID & Time
LocCounted <- with(bkdata,aggregate(bkdata$LocID, by=list(LocID,Time), FUN=sum)[,1:2]) #FUN=sum is meaningless
#this gives a data frame with column names Group.1, Group.2
names(LocCounted) <- c("LocID","Time") #reassign column names
#add columns which are TRUE or FALSE
LocCounted$AM <- LocCounted$Time == "AM"
LocCounted$PM <- LocCounted$Time == "PM"
#
#divby2 is calculated based on bkdata
divby2 <- data.frame(table(bkdata$LocTime))
names(divby2) <- c("LocTime","Freq")
divby2 <- divby2[divby2$Freq>1,]
divby2$DivBy <- divby2$Freq/32
divby2$LocID <- as.integer(substr(divby2$LocTime,1,3))
divby2$Time <- substr(divby2$LocTime,4,5)
#
#External file divbyfile overrides internal calculation of duplicates
#Either way, team counts (which are not "duplicates") must be combined in bcdata input to give correct results
if (bdivby) {
  bkdata <- merge(bkdata, divby, by=c("LocID","Time"), all=TRUE, sort=TRUE) #sort=FALSE doesn't keep original order
#  bkdata <- merge(bkdata, divby, by=c("LocID","Time"), all.x=TRUE, sort=TRUE) #sort=FALSE doesn't keep original order
  # missing LocId's from divby list are assigned DivBy=1, Invalid=FALSE
  bkdata$DivBy[is.na(bkdata$DivBy)] <- 1 #change from NA to 1
  bkdata$Invalid[is.na(bkdata$Invalid)] <- FALSE #change from NA to FALSE
} else {
  bkdata <- merge(bkdata, divby2, by=c("LocID","Time"), all=TRUE, sort=TRUE) #sort=FALSE doesn't keep original order
##OLD#bkdata$DivBy <- 1 #no divby file; set divby=1, i.e., assume there are no duplicates
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
#Within bkdata, AM and PM are split into different rows
#the number of rows in the AM set is not necessarily the same as that in the PM set
#Count the number of times each location was counted (AM or PM gives 1; AM and PM gives 2)
LocTimes <- with(LocCounted,aggregate(LocID, by=list(LocID), FUN=length)) 
names(LocTimes)<-c("LocID","nTime") #reassign column names
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
# create sums by location (Table in Appendix)
summ <- aggregate(cbind(tCount,tGender,tHelmet,tWrongway,tSidewalk) ~ LocID, sum, data = bkdata)
#
#total transformed count by location, direction and time of day (AM or PM)
dirTimeTot <- aggregate(tCount ~ LocID + Dir + Time, sum, data = bkdata)  #tCount is corrected for duplicates
AMcount <- dirTimeTot[dirTimeTot$Time == "AM",] #corrected for duplicates
PMcount <- dirTimeTot[dirTimeTot$Time == "PM",] #corrected for duplicates
names(AMcount)[4] <- "AMtot" #was tCount; set name for upcoming merge
names(PMcount)[4] <- "PMtot" #was tCount; set name for upcoming merge
# all=TRUE keeps LocIDs from getting culled (e.g., AM but not PM); sort is not in final form
summdir <- merge(summdir, AMcount, by=c("LocID", "Dir"), all=TRUE)
summdir <- summdir[ , !(names(summdir) %in% "Time")] #remove unwanted "Time" column
summdir <- merge(summdir, PMcount, by=c("LocID", "Dir"), all=TRUE)
summdir <- summdir[ , !(names(summdir) %in% "Time")] #remove unwanted "Time" column
#Tallies by location + Am or PM + Direction
summdir$Count <- summdir$tCount
summdir$Female <- summdir$tGender/summdir$tCount
summdir$Helmet <- summdir$tHelmet/summdir$tCount
summdir$Wrongway <- summdir$tWrongway/summdir$tCount
summdir$Sidewalk <- summdir$tSidewalk/summdir$tCount
#note: if tCount==0 then result is NaN which is fine, e.g., LocID 112 EW
#
summ$Count <- summ$tCount
summ$Female <- summ$tGender/summ$tCount
summ$Helmet <- summ$tHelmet/summ$tCount
summ$Wrongway <- summ$tWrongway/summ$tCount
summ$Sidewalk <- summ$tSidewalk/summ$tCount
summ <- merge(summ, LocTimes, by="LocID")
summ$TotPerHr <- summ$Count / summ$nTime / 2 #Count = tCount from a previous formula (corrected for dupes)
summ$TotPerHr[summ$TotPerHr==0] <- NA
#32 rows per session, 2 hours per session
summ <- merge(summ, locdata, by="LocID")
#
#Total count, corrected for duplicates; used for fractional attribute calc
nCount <- sum(bkdata$tCount) #removed round function; keep fractional
#overall fractional attributes, corrected for duplicates
FemaleF <- sum(bkdata$tGender)/nCount
HelmetF <- sum(bkdata$tHelmet)/nCount
WrongwayF <- sum(bkdata$tWrongway)/nCount
SidewalkF <- sum(bkdata$tSidewalk)/nCount
#
# merge this data to enable total per hour (was rounded)
summdir <- merge(summdir, LocTimes,by="LocID")
summdir$TotPerHr <- summdir$Count / summdir$nTime / 2 #Count = tCount from a previous formula (corrected for dupes)
summdir$AMPerHr <- summdir$AMtot / 2 
summdir$PMPerHr <- summdir$PMtot / 2 
# pull in locdata (traffic, etc.)
summdir <- merge(summdir, locdata, by=c("LocID"))
summdir$RouteLanePathEW <- with(summdir, ifelse(Dir=="EW" & (EBLane>1 | WBLane>1),1,0))
summdir$RouteLanePathNS <- with(summdir, ifelse(Dir=="NS" & (NBLane>1 | SBLane>1),1,0))
# sort with NS first
summdir <- with(summdir, summdir[order(-xtfrm(Dir), LocID),]) #xtfrm is needed for reverse order of character vector
summdirNS <- summdir[summdir$Dir == "NS",c("LocID","LocEW","LocNS","TotPerHr","AMPerHr","PMPerHr","Helmet","Wrongway","Sidewalk","Female","TrafficNS","DistASU","RouteLanePathNS","Dir")]
summdirEW <- summdir[summdir$Dir == "EW",c("LocID","LocEW","LocNS","TotPerHr","AMPerHr","PMPerHr","Helmet","Wrongway","Sidewalk","Female","TrafficEW","DistASU","RouteLanePathEW","Dir")]
#set TrafficDir as the traffic corresponding to the direction (NS or EW)
summdir$TrafficDir <- summdir$TrafficNS #set all to NS in this step; then overwrite EW
summdir[summdir$Dir=="EW",]$TrafficDir <- summdir[summdir$Dir=="EW",]$TrafficEW
#
########################
# output
write.csv(summdirNS, file = paste0(outPath, dataPrefix, "_ReportDirNS.csv"), row.names = FALSE)
write.csv(summdirEW, file = paste0(outPath, dataPrefix, "_ReportDirEW.csv"), row.names = FALSE)
#
#Logical indexing
bTime <- bkdata$Time == "AM" #convert to boolean; "AM" = TRUE
# Cordon around ASU
bkdata$DirN <- ifelse(bkdata$Direction == 1,1,0)
bkdata$DirS <- ifelse(bkdata$Direction == 2,1,0)
bkdata$DirE <- ifelse(bkdata$Direction == 3,1,0)
bkdata$DirW <- ifelse(bkdata$Direction == 4,1,0)
bkdata$cordonAM <- with(bkdata, (Time=="AM") * (tCount*NB_ASU_in*DirN + tCount*SB_ASU_in*DirS + 
                                                tCount*EB_ASU_in*DirE + tCount*WB_ASU_in*DirW))
bkdata$cordonPM <- with(bkdata, (Time=="PM") * (tCount*SB_ASU_in*DirN + tCount*NB_ASU_in*DirS + 
                                                tCount*WB_ASU_in*DirE + tCount*EB_ASU_in*DirW))
#Cordon statistic can be misleading due to lack of completeness of intersections counted
#  and variation in intersections counted year to year.
Cordon_in <- sum(bkdata$cordonAM)/2 #per hour
Cordon_out <- sum(bkdata$cordonPM)/2 #per hour
#
# get the number of recorders and output special cases
# replace empty recorder fields with a recorder ID that is unique to the location & time
#rawdata$Recorder[rawdata$Recorder == "", "Recorder"] <- paste0("R", rawdata$LocID, rawdata$Time, collapse = "")
rawdata$LocTime <- with(rawdata, paste0("R", LocID, Time))
rawdata$Recorder <- as.character(rawdata$Recorder) #change to character type for detecting blanks
rawdata$recStatus <- !rawdata$Recorder=="" #TRUE if recorder name exists, FALSE if blank
rawdata$Recorder[rawdata$Recorder==""] <- rawdata$LocTime[rawdata$Recorder==""]
rawdata$Recorder <- as.factor(rawdata$Recorder) #change to back to factor type
#rawdata$Recfix <- ifelse(rawdata$Recorder == "", rawdata$LocTime, rawdata$Recorder)
#rawdata$Recorder <- ifelse(rawdata$Recorder == "", rawdata$LocTime, rawdata$Recorder)
# there shouldn't be any blank recorder fields at this point.
# replace blank field with NA; disadvantage of this approach is that NA is ignored, so recorder count would likely be underestimated
is.na(rawdata$Recorder) <- rawdata$Recorder == ""
#
nRecorder <- nRecorders(rawdata, dataPrefix, outPath)
#use manual count file if it exists (overwrite calculated), else use calculated number of recorders
if(file.exists(recfile)) {
  reccnt <- read.csv(recfile) #recorder count manual input file
  nRecorder <- reccnt$RecCount[1]}
#
#Linear model for regression plots
fitww <- lm(Wrongway ~ TrafficDir, data=summdir)
fitsw <- lm(Sidewalk ~ TrafficDir, data=summdir)
# Statistics on regression: R-squared and p-value
R2ww <- summary(fitww)$r.squared
pww <- summary(fitww)$coefficients[2,4] #p-value
capture.output(summary(fitww), file = paste0(outPath, dataPrefix, "_fitww.txt"))
#
R2sw <- summary(fitsw)$r.squared
psw <- summary(fitsw)$coefficients[2,4]
capture.output(summary(fitsw), file = paste0(outPath, dataPrefix, "_fitsw.txt"))
#
#Report Summary = Table 1
# Report	Total_Count	LocCnt	Recorders	Wrongway	Sidewalk	Helmet	Female	Cordon_in	Cordon_out
#   R-squared Wrongway  p-value Wrongway  R-squared Sidewalk  p-value Sidewalk
reportstr <- paste0("Tempe ", dataPrefix)
reportnew <- data.frame(reportstr,nCountRaw,nLoc,nRecorder,
    round(WrongwayF,9),round(SidewalkF,9),round(HelmetF,9),round(FemaleF,9),Cordon_in,Cordon_out,
    R2ww,pww,R2sw,psw)
# round attribute fractions to 9 digits to be consistent with Excel csv export
lastYear <- as.numeric(substr(dataPrefix,1,4)) - 1
outLast <- paste0("DataOut/", lastYear, "/")
repsummfilelast <- paste0(outLast, lastYear, "_RepSumm.csv")
#if last year's file exists, append to it; else make a new file with 1 data row; either way, rename col headers
#to incorporate additional PAG data line, edit last year's file in last year's dataout folder
#  or just add it to the current output manually, but that would be overwritten each time code is run.
if(file.exists(repsummfilelast)) {
  repsumm <- read.csv(repsummfilelast)
  names(reportnew) <- names(repsumm)
  repsumm <- rbind(reportnew, repsumm)
} else {
  names(reportnew) <- c("Report","Total_Count","LocCnt","Recorders",
    "Wrongway","Sidewalk","Helmet","Female","Cordon_in","Cordon_out","R2ww","pww","R2sw","psw")
  repsumm <- reportnew
}
write.csv(repsumm, file = repsummfile, row.names = FALSE)
#
### Geoplot
geocol <- c("LocID","TotPerHr","Female","Helmet","Wrongway","Sidewalk","Latitude","Longitude")
Geoplot <- summ[,geocol]
write.csv(Geoplot, file = paste0(outPath, dataPrefix, "_Geoplot.csv"), row.names = FALSE)
#
#Attribute plots
# Copied (with mod) from "attribute_plots_CA.R"
Geoplot$unity = 0.2 #equal markers just to show the locations
lat_limit <- c(33.32725, 33.45128)
lon_limit <- c(-111.9631, -111.900497)
# these are min, max of latitude and longitude, for use with zoom = 12
lat_limit <- lat_limit + c(0.0036, -0.0036) #0.25 mile extra in each direction
lon_limit <- lon_limit + (c(-0.0043, 0.0043) * 6.28) #0.25 * factor to make it square, mile extra in each direction
#
locctr = c( lon = -111.9295916, lat = 33.4015448)
ggzoomAttrib = 13
ggzoomAll = 12
#
geo_plot <- function(color, title, filename, data, field, locctr, ggzoom) {
  data$data_field <- data[, field]
  map <- get_map(location = locctr, zoom = ggzoom, filename = "ggmapTemp", scale=2)
  map <- ggmap(map) + geom_point(aes(x = Longitude, y = Latitude, size = data_field), data = data, colour = color)
  #    map <- map + coord_fixed(xlim = lon_limit, ylim = lat_limit)
  # the problem is that Google logo is clipped off. Required to show google logo and copyright
  # therefore, keep zoom=13 and accept that fringe locations are clipped
  map <- map + scale_size_area(name=title) 
  #When scale_size_area is used, the default behavior is to scale the area of points 
  #  to be proportional to the value.
  map <- map + theme(legend.justification=c(0,0), legend.position=c(0.02,0.02),
                     axis.text.x=element_blank(), axis.text.y=element_blank(),
                     axis.ticks=element_blank(),
                     axis.title.x=element_blank(), axis.title.y=element_blank())
  ggsave(filename=filename, plot=map, width=5, height=5)
}
# per hour
titleAry <- c("Total Count\nper Hour",
              "Fraction of Wrongway\nRiders",
              "Fraction of\nRiders Using\nSidewalk",
              "Fraction of\nRiders Wearing\nHelmets",
              "All Locations")
titleAry <- paste0(titleAry, " (", dataPrefix, ")")
fileAry <- c("Geo_PerHr",
             "Geo_Wrongway",
             "Geo_Sidewalk",
             "Geo_Helmet")
fileAry <- paste0(dataPrefix, "_", fileAry, ".png")
#
geo_plot("black", titleAry[1], paste0(outPath, fileAry[1]), Geoplot, "TotPerHr", locctr, ggzoomAttrib)

# wrong way
geo_plot("red", titleAry[2], paste0(outPath, fileAry[2]), Geoplot, "Wrongway", locctr, ggzoomAttrib)

# sidewalk
geo_plot("purple", titleAry[3], paste0(outPath, fileAry[3]), Geoplot, "Sidewalk", locctr, ggzoomAttrib)

# helmet
geo_plot("green", titleAry[4], paste0(outPath, fileAry[4]), Geoplot, "Helmet", locctr, ggzoomAttrib)
#
#Note: Console warning message: "Removed 6 rows containing missing values (geom_point)"
#  may be due to points outside plot area. This is a trade-off; zooming out causes loss of resolution.
###End of Geoplot
#
#Historical Bike Count Data = Appendix F
# LocID	LocEW	LocNS	2011 Total per hr	2012 Total per hr	2013 Total per hr	2014 Total per hr	2015 Total per hr	2016 Total per hr
Histnew <- summ[,c("LocID","LocEW","LocNS","TotPerHr")]
#Historical bike count data; overall total per hour
Histfile <- paste0(outPath, dataPrefix, "_Historical.csv") #e.g., "2014_repsumm.csv"
HistLastFile <- paste0(outLast, lastYear, "_Historical.csv")
#if last year's file exists, append to it; else make a new file with 1 data row; either way, rename col headers
if(file.exists(HistLastFile)) {
  Historical <- read.csv(HistLastFile)
  names(Histnew)[4] <- paste0("TotPerHr",dataPrefix)
  Historical <- merge(Historical, Histnew, all=TRUE) #keep all rows
} else {
  names(Histnew)[4] <- paste0("TotPerHr",dataPrefix)
  Historical <- Histnew
}
write.csv(Historical, file = Histfile, row.names = FALSE)
#
#plots
#DEFAULT: par(mar=c(5,4,4,2)+0.1)
#sets the bottom, left, top and right margins respectively of the plot region in number of lines of text.
#there are roughly 35 lines wide and high in a plot
pxs <- 480 #pixel size (used for png output); 480 gives a plot at scale for report
ptx <- 18 #point size (for text)
asp <- 1.6
#gr <- 0.5*(1+sqrt(5)) #golden ratio, for good looks
#for barplot:
#  las=2 rotates the axis labels 90 degrees
#  space = the amount of space (as a fraction of the average bar width) left before each bar
marbar <- c(9,4,1,.1)+0.1 #plot parameters for barplots with long names
png(paste0(outPath, dataPrefix, "_bar_ww.png"),width=pxs*asp,height=pxs,pointsize=ptx)
par(mar=marbar)
with(summ[order(-summ$Wrongway),][1:20,], barplot(Wrongway, 
    names.arg=LocNameShort, ylab="Wrongway Fraction", space=.5, ylim=c(0,0.6),
    col="white", las=2))
dev.off()
png(paste0(outPath, dataPrefix, "_bar_sw.png"),width=pxs*asp,height=pxs,pointsize=ptx)
par(mar=marbar)
with(summ[order(-summ$Sidewalk),][1:20,], barplot(Sidewalk, 
    names.arg=LocNameShort, ylab="Sidewalk Fraction", space=.5, ylim=c(0,1),
    col="white", las=2))
dev.off()
#
maxTraf <- max(summdir$TrafficDir, na.rm=TRUE)
newx <- seq(0,maxTraf, by=1000)
#ref for confidence interval lines:  https://stat.ethz.ch/pipermail/r-help/2007-November/146285.html
mar1 <- c(4,4,1.5,1)+0.1  #for use with no title
png(paste0(outPath, dataPrefix, "_traffic_WW.png"),width=pxs*asp,height=pxs,pointsize=ptx)
par(mar=mar1)
with(summdir, {
  plot(TrafficDir, Wrongway, xlab="Vehicular Traffic per 24 Hour Period", ylab="Wrongway Fraction", ylim=c(0,0.6))
  #ylim may need adjustment depending on data
  abline(fitww, col="blue")
  prd<-predict(fitww,newdata=data.frame(TrafficDir=newx),interval = c("confidence"),level = 0.95,type="response")
  lines(newx,prd[,2],col="blue",lty=2)
  lines(newx,prd[,3],col="blue",lty=2)
})
dev.off()
png(paste0(outPath, dataPrefix, "_traffic_SW.png"),width=pxs*asp,height=pxs,pointsize=ptx)
par(mar=mar1)
with(summdir, {
  plot(TrafficDir, Sidewalk, xlab="Vehicular Traffic per 24 Hour Period", ylab="Sidewalk Fraction", ylim=c(0,1.0))
  abline(fitsw, col="blue")
  prd<-predict(fitsw,newdata=data.frame(TrafficDir=newx),interval = c("confidence"),level = 0.95,type="response")
  lines(newx,prd[,2],col="blue",lty=2)
  lines(newx,prd[,3],col="blue",lty=2)
})
dev.off()
# Total per hour vs. Distance to ASU
png(paste0(outPath, dataPrefix, "_DistASU.png"),width=pxs*asp,height=pxs,pointsize=ptx)
par(mar=mar1)
with(summ, {
  plot(DistASU, TotPerHr, xlab="Distance to ASU (miles)", ylab="Count per hour", xlim=c(0,6), ylim=c(0,300))
})
dev.off()
###WIP
# Count per hour vs. Time of day
rawdata$TimeID <- with(rawdata, 8 * ifelse(Time=="AM",0,1) + (Page - 1) * 4 + Segment)
timeTot <- aggregate(Count ~ TimeID, FUN=mean, data = rawdata, na.rm=TRUE)
timeTot$Count <- 16 * timeTot$Count # 4 segments per hour * 4 directions; from mean count/(seg, dir) to mean count/(hr,loc)
timeTot$timeTxt <- c("7:00","7:15","7:30","7:45","8:00","8:15","8:30","8:45","16:00","16:15","16:30","16:45","17:00","17:15","17:30","17:45")
segBreak <- 2
timeTot$tLinear <- timeTot$TimeID + ifelse(timeTot$TimeID > 8, segBreak,0)
rInsert <- 9 #row number where to insert blank rows (between 9 am and 4 pm)
timeTotSplit <- timeTot
for (i in 1:segBreak){
  newrow <- c(NA,NA,NA,i+8)
  timeTotSplit <- rbind(timeTotSplit[1:rInsert-1+i,],newrow,timeTotSplit[-(1:rInsert-1+i),]) #insert a row
}
timeTotSplit <- timeTotSplit[order(timeTotSplit$tLinear),]
mar2 <- c(5,4,1.5,1)+0.1  #for use with time histogram, no title
png(paste0(outPath, dataPrefix, "_Time_histogram.png"),width=pxs*asp,height=pxs,pointsize=ptx)
par(mar=mar2)
with(timeTotSplit, {
  barplot(Count, names.arg=timeTxt, las=2, xlab="Time of day", ylab="Count per hour", space=.5, col="white") #optional: ylim=c(0,150)
})
dev.off()
#Histograms for Appendix
binW <- 20
maxTot <- ceiling(max(summ$TotPerHr,na.rm=TRUE)/binW)*binW
mar3 <- c(4,4,.5,1)+0.1  #for use with histogram, no title
png(paste0(outPath, dataPrefix, "_hist_TotPerHr.png"),width=pxs*asp,height=pxs,pointsize=ptx)
par(mar=mar3)
with(summ, hist(TotPerHr, xlab="Count per hour", main=NULL, breaks=seq(0,maxTot,by=binW)))
dev.off()
#
binW <- .05
png(paste0(outPath, dataPrefix, "_hist_SW.png"),width=pxs*asp,height=pxs,pointsize=ptx)
par(mar=mar3)
with(summ, hist(Sidewalk, xlab="Sidewalk Fraction", main=NULL, breaks=seq(0,1,by=binW)))
dev.off()
#
png(paste0(outPath, dataPrefix, "_hist_WW.png"),width=pxs*asp,height=pxs,pointsize=ptx)
par(mar=mar3)
with(summ, hist(Wrongway, xlab="Wrongway Fraction", main=NULL, breaks=seq(0,1,by=binW)))
dev.off()
#
png(paste0(outPath, dataPrefix, "_hist_Helmet_.png"),width=pxs*asp,height=pxs,pointsize=ptx)
par(mar=mar3)
with(summ, hist(Helmet, xlab="Helmet Fraction", main=NULL, breaks=seq(0,1,by=binW)))
dev.off()
#
png(paste0(outPath, dataPrefix, "_hist_Female.png"),width=pxs*asp,height=pxs,pointsize=ptx)
par(mar=mar3)
with(summ, hist(Female, xlab="Female Fraction", main=NULL, breaks=seq(0,1,by=binW)))
dev.off()
#
## some tweaks that are WIP:
#xx <- summ[order(-summ$Wrongway),][1:20,]
#grid(nx = NULL, ny = 6, col = "lightgray", lwd = par("lwd"), equilogs = TRUE)
#axis(2, at=xx$Wrongway, labels=sprintf("%.1f %%", 100*xx$Wrongway))
#
##DEBUG purposes:
##write.csv(bkdata, file = paste0(outPath, dataPrefix, "_bkdata.csv", collapse = ""), row.names = FALSE)
#
#Figure 1
###initiate summ
#summ$Wrongway <- with(summdir,aggregate(summdir$Wrongway, by=list(dir), FUN=sum)[,1:2])
#wrongway20 <- 
#summ[order(Wrongway),]

#END OF CODE