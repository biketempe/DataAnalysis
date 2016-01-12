library(ggmap)

# run this with eg:

#  R -f attribute_plots.R --args ../raw_count_data/2014_count_data.csv

# plots:

# total bicycle count per hour
# percent of wrong way riders
# percent of riders using sidewalk
# percent of riders wearing helmets

args <- commandArgs(trailingOnly = T)
count_data_fn = args[1]

print("Reading data from file:")
print(count_data_fn)

count_data <- read.csv(count_data_fn)[,c("Loc.ID", "Total.per.hr", "Female.", "Helmet.", "Wrong.way.", "Sidewalk.", "Accidents.per.100.hr", "latitude", "longitude")]

# per hour

map <- get_map(location = c( lon = -111.9295916, lat = 33.4015448), zoom = 13, filename = "ggmapTemp", scale=1)
map <- ggmap(map) + geom_point(aes(x = longitude, y = latitude, size = Total.per.hr), data = count_data, colour = 'black')
map <- map + scale_size_area(name="Total Count per Hour")
map <- map + theme(legend.justification=c(0,0), legend.position=c(0,0))
ggsave(filename="per_hour.png", plot=map)

# wrong way

map <- get_map(location = c( lon = -111.9295916, lat = 33.4015448), zoom = 13, filename = "ggmapTemp", scale=1)
map <- ggmap(map) + geom_point(aes(x = longitude, y = latitude, size = Wrong.way. * 100), data = count_data, colour = 'red')
map <- map + scale_size_area(name="Percent of Wrong Way Riders")
map <- map + theme(legend.justification=c(0,0), legend.position=c(0,0))
ggsave(filename="wrong_way.png", plot=map)

# sidewalk

map <- get_map(location = c( lon = -111.9295916, lat = 33.4015448), zoom = 13, filename = "ggmapTemp", scale=1)
map <- ggmap(map) + geom_point(aes(x = longitude, y = latitude, size = Sidewalk. * 100), data = count_data, colour = 'purple')
map <- map + scale_size_area(name="Percent of Riders Using Sidewalk")
map <- map + theme(legend.justification=c(0,0), legend.position=c(0,0))
ggsave(filename="sidewalk.png", plot=map)

# helmet

map <- get_map(location = c( lon = -111.9295916, lat = 33.4015448), zoom = 13, filename = "ggmapTemp", scale=1)
map <- ggmap(map) + geom_point(aes(x = longitude, y = latitude, size = Helmet. * 100), data = count_data, colour = 'green')
map <- map + scale_size_area(name="Percent of Riders Wearing Helmets")
map <- map + theme(legend.justification=c(0,0), legend.position=c(0,0))
ggsave(filename="helmet.png", plot=map)



# map <- map +
#    scale_size_area(breaks = sqrt(c(1, 5, 10, 50, 100, 500)), labels = c(1, 5, 10, 50, 100, 500), name = "avg total\nbikes counted\nor\ntotal collisions\n2009-2013")


