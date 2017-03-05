# This code reads file with location ID & name & GPS coordinates
# it plots with the name as a label on 1 plot and LodID as a label on 2nd plot; for 3 zoom levels
# the purpose is to facilitate verification of GPS coordinates by showing the name at the location on a map
rm(list=ls())
library(ggmap)
inPath <- "DataIn/"
infile <- "LocIDverify.csv"
cdata <- read.csv(paste0(inPath,infile))
locctr = c( lon = -111.9295916, lat = 33.4015448)

ggzoom = c(12, 13, 14) #smaller is zoomed out (more area)

for (ii in 1:3) {
#plot names
  map <- get_googlemap(center = locctr, zoom = ggzoom[ii], scale=2, maptype = "road")
  map <- ggmap(map) + geom_point(aes(x = longitude, y = latitude), data = cdata, colour = "black", size = .5) +
    geom_text(data = cdata, aes(x = longitude, y = latitude + .001/ii, label = LocNameShort), size = 0.8, angle=15)
  map <- map + theme(legend.justification=c(0,0), legend.position=c(0.02,0.02),
                     axis.text.x=element_blank(), axis.text.y=element_blank(),
                     axis.ticks=element_blank(),
                     axis.title.x=element_blank(), axis.title.y=element_blank())
  plot(map)
  ggsave(filename=paste0("LocNamePlotZoom",ggzoom[ii],".png"), plot=map)
  
  # plot LocID
  map <- get_googlemap(center = locctr, zoom = ggzoom[ii], scale=2, maptype = "road")
  map <- ggmap(map) + geom_point(aes(x = longitude, y = latitude), data = cdata, colour = "black", size = .5) +
    geom_text(data = cdata, aes(x = longitude+.0015/ii, y = latitude + .0015/ii, label = LocID), size = 1.5, angle=20)
  map <- map + theme(legend.justification=c(0,0), legend.position=c(0.02,0.02),
                     axis.text.x=element_blank(), axis.text.y=element_blank(),
                     axis.ticks=element_blank(),
                     axis.title.x=element_blank(), axis.title.y=element_blank())
  plot(map)
  ggsave(filename=paste0("LocIDPlotZoom",ggzoom[ii],".png"), plot=map)
}
#for get_googlemap, the style option doesn't seem to affect anything
#style = 'feature:road|element:all|visibility:simplified&style=feature:administrative.locality|element:labels|visibility:off')

