library(ggmap)

# plots:
# total bicycle count per hour
# Fraction of wrong way riders
# Fraction of riders using sidewalk
# Fraction of riders wearing helmets

###if needed, run this (only needed once for each computer R installation):
###install.packages("ggmap")
###if you get this error message:
### "Removed [n] rows containing missing values (geom_point)."
### then the longitude and/or latitude value is out of range for the given map size.

rm(list=ls())
inPath <- "DataIn/"
outPath <- "DataOut/"
dataPrefix <- readline("Enter the file prefix to be analyzed, e.g., 2014 for input file 2014_Geoplot.csv: ") 
infile <- paste0(inPath, dataPrefix, "_Geoplot.csv", collapse="") #e.g., "2014_Geoplot.csv"
#setwd("C:/RWD/BikeCount")

# alternative: execute and read filename from command line:
#  R -f attribute_plots.R --args 2016_Geoplot.csv
# if using this, uncomment the following 4 lines:
#args <- commandArgs(trailingOnly = T)
#inFile <- args[1]
#print("Reading data from file:")
#print(inFile)

count_data <- read.csv(paste0(inPath,infile))
count_data$unity = 0.2 #equal markers just to show the locations
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
fileAry <- c("per_hour",
             "wrongway",
             "sidewalk",
             "helmet",
             "AllLoc")
fileAry <- paste0(fileAry, "_", dataPrefix, ".png")
#
geo_plot("black", titleAry[1], paste0(outPath, fileAry[1]), count_data, "TotPerHr", locctr, ggzoomAttrib)

# wrong way
geo_plot("red", titleAry[2], paste0(outPath, fileAry[2]), count_data, "Wrongway", locctr, ggzoomAttrib)

# sidewalk
geo_plot("purple", titleAry[3], paste0(outPath, fileAry[3]), count_data, "Sidewalk", locctr, ggzoomAttrib)

# helmet
geo_plot("green", titleAry[4], paste0(outPath, fileAry[4]), count_data, "Helmet", locctr, ggzoomAttrib)

#zoom out to show all locations
#not working well enough - big black circles, but want maybe "x"
#optional plot: uncomment to include it
#geo_plot("black", titleAry[5], paste0(outPath, fileAry[5]), count_data, "unity", locctr, ggzoomAll)
#
# code example for specifying breaks in the legend (instead of R doing it automatically):
# map <- map +
#    scale_size_area(breaks = sqrt(c(1, 5, 10, 50, 100, 500)), labels = c(1, 5, 10, 50, 100, 500), name = "avg total\nbikes counted\nor\ntotal collisions\n2009-2013")

