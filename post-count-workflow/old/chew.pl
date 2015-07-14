#!/usr/bin/perl

use strict;
use warnings;

use IO::Handle;
use Text::CSV;
use Data::Dumper;

# convert the data from the format it comes back from Amazon Mechanical Turk in to the format that Cliff wants

# see also bccsv.last.pl

my $csv = Text::CSV->new or die Text::CSV->error_diag;

sub id {
    my $row = shift;
    return join '_', $row->{"Location ID"}, $row->{Hour}, $row->{"Quarter Hour"};
}

sub build_header {
    my $header = shift;
    my %header;
    for my $i ( 0 .. $#$header ) {
        $header{ $header->[$i] } = $i; #   %header is column name to column number
        # $header[ $i ] = $header->[$i]; #   @header is column number to column name
    }
    return wantarray ? %header : \%header;
}

for my $input (qw/ 2011_bikecount_data.csv  2012_combined_spot_checked_cliff_out.csv / ) {

    open my $fh, '<', $input or die $!;
    
    my %header = build_header( $csv->getline( $fh ) );
    
    my %seen;
    my $line_no = 2;  # header was line_no 1
    
    my %location_seen;

    # "Location ID",Time,Recorder,"Rec Count",Page,Segment,Direction,Count,"Gender ",,,Helmet,"Wrong way",Sidewalk,,,,,,,,Notes
    
    my @rows;
    while ( my $row = $csv->getline( $fh ) ) {
    
        my %row;
        for my $k (keys %header) {
            $row{$k} = $row->[ $header{$k} ];
        }
    
        $row{"Location ID"} = uc $row{"Location ID"};
    
        push @rows, \%row;
    
        warn "already seen Location ID/Hour/Quarter Hour combination: $line_no and previously at " . $seen{ id( \%row ) } if $seen{ id(\%row) };
        $seen{ id(\%row) } = $line_no;
    
        $location_seen{ $row{"Location ID"} }{ $row{"Hour"} }{ $row{"Quarter Hour"} }++;
    
        $line_no++;
    }

    $headers->{ $input } = \%header;
    $data->{ $input }

    $csv->eof or $csv->error_diag;
    close $fh;

}


# "Location ID",Time,Recorder,"Rec Count",Page,Segment,Direction,Count,"Gender ",
# Helmet,"Wrong way",Sidewalk,
# Notes,
# Construction

my %out = (
    "Location ID"         => 0,
    Time                  => 1,
    Recorder              => 2,
    "Rec Count"           => 3,  # <-- let the formula compute this; this counts between different locations/shifts
    Page                  => 4,  # <-- first half of shift vs second half of shift
    Segment               => 5,  # <-- which 15 minute block
    Direction             => 6,  # <-- 1 = North, 2 = South, 3 = West, 4 = East XXXX double check this
    Count                 => 7,
    "Gender "             => 8,  # <-- number of females
    # Age_Y               => 9,  # <-- not used in 2012
    # Age_O               => 10, # <-- not used in 2012
    Helmet                => 11,
    "Wrong way"           => 12,
    Sidewalk              => 13,
    # Distracted          => 14, <-- not used
    # Pedestrian          => 15, <-- not used
    # Motoroized          => 16, <-- not used
    # Electric            => 17, <-- not used
    # Decor/Lights        => 18, <-- not used
    # "ADA Peds"          => 19, <-- not used
    # "ADA Chairs"        => 20, <-- not used
    Notes                 => 21,
    # Construction        => 22, <-- not used
);

# sort data by count shift, then hour, then minute

@rows = sort { $a->{"Location ID"} cmp $b->{"Location ID"} || $a->{Hour} <=> $b->{Hour} || $a->{"Quarter Hour"} <=> $b->{"Quarter Hour"} } @rows;

open my $out, '>', 'cliff_out.csv' or die $!;
$csv->eol ("\r\n");

do {
    my %inverse_out = reverse %out;
    my @nums = sort { $a <=> $b } keys %inverse_out;
    my @row;
    for my $num ( @nums ) {
        $row[$num] = $inverse_out{$num};
    }
    $csv->print( $out, \ @row );
};

for my $in ( @rows ) {
    my @out;
    $out[ $out{"Location ID"} ] = $in->{"Location ID"};
    $out[ $out{"Location ID"} ] =~ s{[AaPp]}{};
    $out[ $out{"Recorder"} ]    = $in->{"Your name"};
    $out[ $out{"Time"} ]        = $in->{"Location ID"} =~ m/A/i ? 'AM' : 'PM';
    $out[ $out{"Notes"} ]        = $in->{"Comments"};
    warn "location: $in->{'Location ID'}: bunk hour: $in->{Hour}" if $out[ $out{"Time"} ] eq 'A' and ! grep $_ eq $in->{Hour}, 7, 8;
    warn "location: $in->{'Location ID'}: bunk hour: $in->{Hour}" if $out[ $out{"Time"} ] eq 'P' and ! grep $_ eq $in->{Hour}, 4, 5;
    $out[ $out{"Page"} ] = 1 if grep $_ eq $in->{Hour}, 4, 7; 
    $out[ $out{"Page"} ] = 2 if grep $_ eq $in->{Hour}, 5, 8; 
    $out[ $out{"Segment"} ] = 1 if $in->{"Quarter Hour"} eq "0";
    $out[ $out{"Segment"} ] = 2 if $in->{"Quarter Hour"} eq "15";
    $out[ $out{"Segment"} ] = 3 if $in->{"Quarter Hour"} eq "30";
    $out[ $out{"Segment"} ] = 4 if $in->{"Quarter Hour"} eq "45";
    warn "location: $in->{'Location ID'}: bunk quarter hour: $in->{'Quarter Hour'}" unless $out[ $out{"Segment"} ];
    for my $direction ( 1, 2, 3, 4 ) {
        $out[ $out{"Direction"} ] = $direction;
        my $dir_code = [ undef, "NB", "SB", "WB", "EB", ]->[ $direction ]; # double checked comparing Okie's 101AM count sheet scans vs CountSummary2.xls
        $out[ $out{"Count"} ] = $in->{"$dir_code Count"} || 0;
        $out[ $out{"Gender "} ] = $in->{"$dir_code Female"} || 0;
        $out[ $out{"Helmet"} ] = $in->{"$dir_code Helmet"} || 0;
        $out[ $out{"Wrong way"} ] = $in->{"$dir_code Wrong Way"} || 0;
        $out[ $out{"Sidewalk"} ] = $in->{"$dir_code Sidewalk"} || 0;
        $csv->print( $out, [ @out ] );
    }
}

close $out or die $!;

for my $location_id ( keys %location_seen ) {
    warn "$location_id has 4, missing 5" if exists $location_seen{$location_id}{4} and ! exists $location_seen{$location_id}{5};
    warn "$location_id has 5, missing 4" if ! exists $location_seen{$location_id}{4} and exists $location_seen{$location_id}{5};
    warn "$location_id has 7, missing 8" if exists $location_seen{$location_id}{7} and ! exists $location_seen{$location_id}{8};
    warn "$location_id has 8, missing 7" if ! exists $location_seen{$location_id}{7} and exists $location_seen{$location_id}{8};
    for my $hour ( keys %{ $location_seen{$location_id} } ) {
        my @quarter_hours = sort { $a <=> $b } keys %{ $location_seen{$location_id}{$hour} }; 
        warn "$location_id for hour $hour missing or has extra quarter hours: @quarter_hours" unless "@quarter_hours" eq "0 15 30 45";
    }
}
