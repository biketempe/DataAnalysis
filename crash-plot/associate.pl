
use strict;
use warnings;

=for comments

Reads the bikecrash_2*.csv files and ../count_sites.csv file, and writes bikecrash_all_years_associated.csv.

bikecrash_all_years_associated.csv contains all records from all of the bikecrash_2*.csv files, with
'nearest_count_site' and 'distance_to_nearest_count_site' fields added.

'nearest_count_site' is a site ID like 123.
'distance_to_nearest_count_site' is in units of lat/long, mixed via Pythagoras' theorum

=cut

use Data::Dumper;
use IO::Handle;
use IO::Any;
use List::MoreUtils 'zip';
use Cwd;
use JSON::PP;
use Storable;
use XXX;
use Carp;

use csv;

# location_id,location_W_E,location_N_S,priority,vols_needed,latitude,longitude,automatic_geocoding_failed,geocoded_by,notes,2015_include,"last year done",2015_notes,Counter_notes,column_number_14

my $sites = csv->new('../count_sites.csv');

# combine all bikecrash_2*.csv files

my $buffer = '';
my $have_a_header = 0;
while( my $fn = glob 'bikecrash_2*csv' ) {
   warn "reading $fn...\n";
   my @lines = split "\n", IO::Any->slurp($fn);
   shift @lines if $have_a_header++;
   $buffer .= join '', map "$_\n", @lines;
}

IO::Any->write('bikecrash_all_years_associated.csv')->print($buffer);

# columns:
#
# IncidentID,num_vehicles_involved,eCollisionManner,Longitude,Latitude,InjurySeverity,eIntersectionType,eCollisionManner,city_name,IncidentDateTime,cyclist_citations,driver_citations

my $crashes = csv->new('bikecrash_all_years_associated.csv');

#
# add columns 
#

for my $column (qw/nearest_count_site distance_to_nearest_count_site/) {
    $crashes->add_column($column) if ! grep $_ eq $column, @{ $crashes->headers };
}

#
# associate
#

for my $row ( $crashes->rows ) {

    my $lon = $row->Longitude or next; # die;
    my $lat = $row->Latitude or next; # die;

    next unless $lat >= 33.349147 and $lat <= 33.45128;
    next unless $lon >= -111.96124 and $lon <= -111.891954;

    my $nearest_site;
    my $nearest_site_distance = 100000;

    for my $site ( $sites->rows ) {
        if( distance( $lon, $lat, $site->longitude, $site->latitude ) < $nearest_site_distance ) {
            my $dist = distance( $lon, $lat, $site->longitude, $site->latitude );
            next unless $dist < 0.00449892410972615; # 500 meters, supposedly
            $nearest_site_distance = $dist;
            $nearest_site = $site;
        }
    }

    if( ! $nearest_site ) {
        print "no nearby site\n";
        next;
    }

    print "$lat,$lon is nearest " . $nearest_site->location_id . ' at ' . $nearest_site->location_W_E . ' and ' . $nearest_site->location_N_S, " with distance $nearest_site_distance\n";

    $row->nearest_count_site = $nearest_site->location_id;
    $row->distance_to_nearest_count_site = $nearest_site_distance;

}

$crashes->write;

sub distance {
    my $lon1 = shift;  # longitude is X
    my $lat1 = shift;
    my $lon2 = shift;
    my $lat2 = shift;
    return sqrt( abs( $lon1 - $lon2 ) ** 2 + abs( $lat1 - $lat2 ) ** 2 );

}

