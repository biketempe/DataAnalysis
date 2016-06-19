library(ggmap)

# run this with eg:

#  R -f attribute_plots.R --args CountSummary2015_for_Geoplot.csv

# plots:

# total bicycle count per hour
# percent of wrong way riders
# percent of riders using sidewalk
# percent of riders wearing helmets

#args <- commandArgs(trailingOnly = T)
#count_data_fn = args[1]

###NOTE: ## designates lines from Scott's code that Cliff commented out
###Cliff's added lines
###if needed, run this (only needed once):
###install.packages("ggmap")
###if you get this error message:
### "Removed [n] rows containing missing values (geom_point)."
### then the longitude and/or latitude value is out of range for the given map size.

##print("Reading data from file:")
##print(count_data_fn)

##count_data <- read.csv(count_data_fn)[,c("Loc.ID", "Total.per.hr", "Female.", "Helmet.", "Wrong.way.", "Sidewalk.", "Accidents.per.100.hr", "latitude", "longitude")]
### this is Cliff's new line
infile <- "Geoplot2014.csv"
setwd("C:/RWD/BikeCount")
count_data <- read.csv(infile)[,c("Loc.ID", "Total.per.hr", "Female.", "Helmet.", "Wrong.way.", "Sidewalk.", "latitude", "longitude")]

geo_plot <- function(color, title, filename, data, field) {
    data$data_field <- data[, field]
    map <- get_map(location = c( lon = -111.9295916, lat = 33.4015448), zoom = 13, filename = "ggmapTemp", scale=1)
    map <- ggmap(map) + geom_point(aes(x = longitude, y = latitude, size = data_field), data = data, colour = color)
    map <- map + scale_size_area(name=title)
    map <- map + theme(legend.justification=c(0,0), legend.position=c(0.02,0.02),
                       axis.text.x=element_blank(), axis.text.y=element_blank(),
                       axis.ticks=element_blank(),
                       axis.title.x=element_blank(), axis.title.y=element_blank())
    ggsave(filename=filename, plot=map)
}
###Cliff added element_blank to hide axes
# per hour

geo_plot("black", "Total Count\nper Hour", "per_hour.png", count_data, "Total.per.hr")

# wrong way

geo_plot("red", "Percent of\nWrong Way Riders", "wrong_way.png", count_data, "Wrong.way.")

# sidewalk

geo_plot("purple", "Percent of\nRiders Using\nSidewalk", "sidewalk.png", count_data, "Sidewalk.")

# helmet

geo_plot("green", "Percent of\nRiders Wearing\nHelmets", "helmet.png", count_data, "Helmet.")


# code example for specifying breaks in the legend (instead of R doing it automatically):
# map <- map +
#    scale_size_area(breaks = sqrt(c(1, 5, 10, 50, 100, 500)), labels = c(1, 5, 10, 50, 100, 500), name = "avg total\nbikes counted\nor\ntotal collisions\n2009-2013")


