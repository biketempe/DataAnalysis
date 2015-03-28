observations <- read.csv("accident_rate.csv")
sites <- read.csv("count_sites.csv")

mergedData <- merge(observations, sites, by.x="location_id", by.y="location_id", all=TRUE)

mergedData$location_W_E <- NULL
mergedData$location_N_S <- NULL
mergedData$priority <- NULL
mergedData$Counter_notes <- NULL
mergedData$notes  <- NULL
mergedData$last.year.done <- NULL
mergedData$vols_needed <- NULL
mergedData$geocoded_by <- NULL
mergedData$X2015_include <- NULL
mergedData$X2015_notes <- NULL
mergedData$column_number_14 <- NULL
mergedData$automatic_geocoding_failed <- NULL

# head(mergedData)
# colnames(mergedData)

# [1] "location_id"                "four_hour_count"           
# [3] "accidents"                  "accident_rate"             
# [5] "latitude"                   "longitude"                 

library(ggmap)

# map <- get_map(location = 'ASU, Tempe, AZ', zoom = 12)
map <- get_map(location = c( lon = -111.9295916, lat = 33.4015448), zoom = 13)

mapPoints <- ggmap(map) +
    geom_point(aes(x = longitude, y = latitude, size = sqrt(accidents)), data = mergedData, alpha = 0.5, colour = 'red')

# mapPoints  # causes it to render

mapPoints <- mapPoints +
    geom_point(aes(x = longitude, y = latitude, size = sqrt(four_hour_count)), data = mergedData, alpha = 0.5, colour = 'black')

mapPointsLegend <- mapPoints +
   scale_size_area(breaks = sqrt(c(1, 5, 10, 50, 100, 500)), labels = c(1, 5, 10, 50, 100, 500), name = "avg total\nbikes counted\nor\ntotal accidents\n2009-2013")

mapPointsLegend  # causes it to render


