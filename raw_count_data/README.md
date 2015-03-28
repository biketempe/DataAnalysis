
# This contains the raw or nearly raw count data.

See the published Bike Count Report on `biketempe.org` for the study methodology.

## 20.*csv

Count data is for hours of 7am-9am in the morning and 4pm-6pm in the evening.

"cliff out" refers to the data having been converted form the form we get it back from
Amazon Mechanical Turk (and that our own fake-turk continues to use as volunteers
check and correct the data) to the format that we use internally (specifically, that
Cliff Anderson's xlsx spreadsheet wants).

At this point, data has been filtered for these inconsistencies, with bad data rejected:

Page number agrees with the hour.
AM/PM agrees with the hour.
Location ID (which ends in 'A' or 'P') agrees with AM/PM checkbox.

Definitions:

	Page			
1	First hour			
2	Second hour			
				
	Segment			
1	:00			
2	:15			
3	:30			
4	:45			

     Direction
		2014Data	Dir correction	count sheet order
1	NB	1	1	1
2	SB	2	2	2
3	WB	4	4	4
4	EB	3	3	3

These is one record per 15 minute block per bicycle approach direction per hour per two hour
shift for each of AM and PM shifts, for each count site.

Location ID -- matches the ID in count_sites.csv
Time -- AM or PM
Recorder -- name of the volunteer who collected data for that shift at that location
Page -- as above; which hour of the two hour count shift
Segment -- as above; which 15 minute block of the hour
Direction -- as above; indicates approach direction of bicycles for this record
Count -- total number of bicycles that approached from that direction for that 15 minute block of time; other fields (Gender, Helmet, Wrong way, Sidewalk) should be each be equal to or less than this value
"Gender " -- total number of apparently female or female presenting riders in this 15 minute block for this approach direction
Helmet -- total number of riders wearing helmets in this 15 minute block for this approach direction
"Wrong way" -- total number of riders riding against traffic in this 15 minute block for this approach direction
Sidewalk -- total number of riders riding on the sidewalk (when there is a road that could be ridden on) in this 15 minute block for this approach direction

## count_sites.csv

This contains a list of count site locations.

Fields:

location_id -- numerical monotonically increasing unique ID for the site
location_W_E,location_N_S -- crossroads (or path name)
priority -- lower number indicates higher priority
vols_needed -- 0 indicates that it isn't being counted for the most recent year; 1 indicates that one person is required; 2 indicates that two are needed and one counter will count W-E and the other N-S
latitude,longitude -- coordinates of the count site
automatic_geocoding_failed,geocoded_by -- we attempt to automatically geocode sites but sometimes we have to correct these by hand
notes -- organizer notes about the location
"last year done" -- most recent year this intersection was done; this may not be kept up to date and should be viewed with suspicion
Counter_notes -- location specific instructions to the person counting the intersection

Note that entries are added to count_sites.csv each year but location_ids are never
changed or re-assigned.  It is always safe to use the latest version of this file.
Geocoding and other errors are corrected as errors are found, and notes are added.
