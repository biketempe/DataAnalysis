library(ggmap)

#
# collisions
#

collisions <- read.csv("bikecrash_all_years_associated.csv")

# select only collisions with a nearest count site, throwing away the rest

collisions <- collisions[ ! is.na(collisions$nearest_count_site), ]

# tally up how many collisions there were near each count site
# length() counts the number of collisions for each factor level (distinct value of 2nd arg)

collision_frequencies <- aggregate(collisions$nearest_count_site, list(collisions$nearest_count_site), length)
colnames(collision_frequencies) = c("location_id", "collisions")

#
# count sites
#

sites <- read.csv("../count_sites.csv")[,c("location_id", "longitude", "latitude")]

#
# bike counts
#

# read all count data and tally counts by site and year combination

count_data = data.frame()
for( fn in list.files(path='../raw_count_data', pattern='\\.csv$', full.names=T, include.dirs=T) ) {
    # read the file into more_count_data, picking out only the columns we want
    # "Location ID",Time,Recorder,"Rec Count",Page,Segment,Direction,Count,"Gender ",,,Helmet,"Wrong way",Sidewalk,,,,,,,,Notes
    print("Reading count data from:"); print(fn)
    more_count_data <- read.csv(fn)[,c("Location.ID", "Count")]         # read from the file, but pick out only the two columns we want
    more_count_data$Count <- as.numeric(more_count_data$Count)          # crummy data; still some comments in the number fields; filter that out
    more_count_data <- aggregate(Count ~ Location.ID, data=more_count_data, sum)
    more_count_data$fn = fn      # we don't have a record of year, but we want average by year (with rm.na=T), so use this as the year identifier
    count_data <- rbind(count_data, more_count_data)
}

# count_data now has these columns:
# [1] "Location.ID" "Count"       "fn" 

# now compute year to year means for each count site, and round them to a whole number for plotting

count_data <- aggregate(Count ~ Location.ID, data=count_data, mean)
count_data$Count = round(count_data$Count, 0)

#
# diagnostics
#

print("number of collisions associated with a count site:")
print(sum(! is.na(collisions$nearest_count_site)))

print("number of collisions *not* associated with a count site:")
print(sum(is.na(collisions$nearest_count_site)))

print("mean number of bikes counted any year, any site:")
print(mean(count_data$Count))

#
# merge data
#

# we're doing a three way merge here, taking lat/lon from sites (from count_sites.csv), mean number of observed bikes
# (from the year by year csv files in the raw_count_data directory), and the total number of collisions in collision_frequencies
# (from the bikecrash_all_years_associated.csv file)

mergedData <- merge(collision_frequencies, sites, by.x="location_id", by.y="location_id", all=TRUE)

# combine in the total bikes counted data

mergedData <- merge(mergedData, count_data, by.x="location_id", by.y="Location.ID", all=TRUE)

print(mergedData)

# start with a map

# map <- get_map(location = 'ASU, Tempe, AZ', zoom = 12)
map <- get_map(location = c( lon = -111.9295916, lat = 33.4015448), zoom = 13)

# add points

mapPoints <- ggmap(map) +
    geom_point(aes(x = longitude, y = latitude, size = sqrt(collisions)), data = mergedData, alpha = 0.5, colour = 'red')

mapPoints <- mapPoints +
    geom_point(aes(x = longitude, y = latitude, size = sqrt(Count)), data = mergedData, alpha = 0.5, colour = 'black')

mapPointsLegend <- mapPoints +
   scale_size_area(breaks = sqrt(c(1, 5, 10, 50, 100, 500)), labels = c(1, 5, 10, 50, 100, 500), name = "avg total\nbikes counted\nor\ntotal collisions\n2009-2013")

mapPointsLegend  # causes it to render


