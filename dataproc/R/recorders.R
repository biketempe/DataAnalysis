#Calc number of recorders
nRecorders <- function(rawdata, dataPrefix, outPath) {
  rectemp <- tolower(rawdata$Recorder[rawdata$recStatus==TRUE]) 
  #use lower case to avoid case differences that should be insignificant
  rectempNA <- tolower(rawdata$Recorder[rawdata$recStatus==FALSE])
  #rectempNA <- rawdata$Recorder[rawdata$recStatus==FALSE]
  Recorders <- sort(unique(unlist(rectemp, use.names=FALSE)),decreasing=FALSE)
  RecordersNA <- sort(unique(unlist(rectempNA, use.names=FALSE)),decreasing=FALSE) #blank recorder
  rtypo1 <- character(0)
  grepdist <- c(0.2, 0.05) #use higher and lower values; 
    #lower (2nd listed) is final calc with names output, higher is output for user consideration
  for(i in 1:2) {
  for(r in 1:length(Recorders))
  {
    if(length(agrep(Recorders[r],Recorders,max.distance=grepdist[i]))>1)
    {
      rtypo1 <- c(rtypo1,paste(agrep(Recorders[r],Recorders,max.distance=grepdist[i],value=TRUE),collapse=", "))
    }
  }
  rtypo <- unique(unlist(rtypo1, use.names=FALSE))
  sink(file = paste0(outPath, dataPrefix, "_recorder_special_", i, ".txt", collapse = ""))
    writeLines(paste0("Potential typos and team counts for grepdist = ", grepdist[i], collapse = ""))
    writeLines("Detected typos in recorder names")
    print(rtypo)
    ntypo <- length(rtypo) #need to get user input on real typo count
    rteam <- c(grep("&",Recorders,value=TRUE),grep(" and ",Recorders,value=TRUE))
    writeLines("Detected team counts")
    print(rteam)
    writeLines("")
  sink()
  }
  writeLines("Review the recorder special output")
  writeLines(paste0("Output recorder count used typos and team counts for grepdist = ", grepdist[2], collapse = ""))
  writeLines(paste0("Number of missing recorder names = ", length(RecordersNA)))
  print(RecordersNA)
  nteam<-length(rteam) 
  nRec <- length(Recorders) + nteam - ntypo + length(RecordersNA)
  write.csv(rtypo, file = paste0(outPath, dataPrefix, "_rtypo.csv", collapse = ""))
  write.csv(rteam, file = paste0(outPath, dataPrefix, "_rteam.csv", collapse = ""))
  write.csv(Recorders, file = paste0(outPath, dataPrefix, "_recorders.csv", collapse = ""))
  return(nRec)
  }
# 2014 value: 78
# END OF RECORDER CODE
###