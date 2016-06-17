#!/usr/bin/perl

=for comment

Convert data entered one-line-per-quarter-hour format (Mechanical Turk format) to Cliff's partially normalized one-line-per-direction format (used in the Excel spreadsheet that does the analysis).

We no longer actually use Amazon's Mechanical Turk (as of 2015), but the file format lives on as the replacement for it was originally written for volunteers to do entry validation on data from it.  The one-row-per-sheet format still fits well.

=cut

use strict;
use warnings;

use IO::Handle;
use Text::CSV;
use Data::Dumper;

my $fn = shift or die "pass filename of the csv";

my $csv = Text::CSV->new or die Text::CSV->error_diag;

open my $fh, '<', $fn or die $!;

my $header = $csv->getline( $fh );

my %header;
for my $i ( 0 .. $#$header ) {
    $header{ $header->[$i] } = $i; #   %header is column name to column number
}

# maybe useful: Answer.date, Answer.name, Answer.intersection_of, Answer.am_shift_checkbox, Answer.page_num, Answer.pm_shift_checkbox

# my %seen;
my $line_no = 2;  # header was line_no 1

sub id {
    my $row = shift;
    return join '_', $row->{'location_id'}, $row->{Hour};
}

my %location_seen;

my @rows;
while ( my $row = $csv->getline( $fh ) ) {

    my %row;
    for my $k (keys %header) {
        $row{$k} = $row->[ $header{$k} ];
    }

    $row{'location_id'} = uc $row{'location_id'};

    # sanitize page_num
    $row{'page_num'} =~ s/ of (\d+)$//;

    push @rows, \%row;

    # warn "already seen Location ID/Hour combination: $line_no and previously at " . $seen{ id( \%row ) } if $seen{ id(\%row) };
    # $seen{ id(\%row) } = $line_no;

    $line_no++;
}
$csv->eof or $csv->error_diag;
close $fh;


# XXX reconcile: Answer.am_shift_checkbox, Answer.pm_shift_checkbox, Answer.hour_for_00,Answer.hour_for_15,Answer.hour_for_30,Answer.hour_for_45
# Answer.organizer_notes,Answer.page_num

my $row_num = 2;  # start after the header row; also, spreadsheet programs count from 1, not 0, so row 2 is our first data row

for my $row ( @rows ) {

    # propogate hour information up if its in some later blanks
    $row->{'hour_for_30'} ||= $row->{'hour_for_45'}; 
    $row->{'hour_for_15'} ||= $row->{'hour_for_30'}; 
    $row->{'hour_for_00'} ||= $row->{'hour_for_15'}; 

    my $location_id = $row->{location_id};
    my $image_url = $row->{image_url};

    next if $location_id =~ m/AX$/;  # extended hour shifts

    $row->{page_num} =~ s{^0}{}g;
    $row->{page_num} =~ s{/2$}{}g;
    $row->{'page_num'} =~ m/^\d+$/ or die "row $row_num: $location_id invalid page number: $row->{'page_num'}";
    grep $row->{'page_num'} eq $_, 1, 2 or die "row $row_num: $location_id invalid page number: $row->{'page_num'}";

    if( $row->{'am_shift_checkbox'} and $row->{'pm_shift_checkbox'} ) {

        die qq{row $row_num: $location_id has both "AM" and "PM" checked};

    } elsif( $row->{'am_shift_checkbox'} and ! $row->{'hour_for_00'} ) {

        # attempt to infer the hour from the page number
        my $page = $row->{'page_num'};
        $page or die "row $row_num: $location_id has no page number nor starting hour";
        $row->{'hour_for_00'} = '7' if $page eq '1';
        $row->{'hour_for_00'} = '8' if $page eq '2';

    } elsif( $row->{'pm_shift_checkbox'} and ! $row->{'hour_for_00'} ) {

        # attempt to infer the hour from the page number
        my $page = $row->{'page_num'};
        $page or die "$row $row_num: location_id has no page number nor starting hour";
        $row->{'hour_for_00'} = '4' if $page eq '1';
        $row->{'hour_for_00'} = '5' if $page eq '2';

    } elsif( ! $row->{'am_shift_checkbox'} and ! $row->{'pm_shift_checkbox'} and $row->{'hour_for_00'} ) {

        # attempt to infer am_shift_checkbox / pm_shift_checkbox from the hour
        my $hour = $row->{'hour_for_00'};
        $hour =~ s{^0}{}g;
        grep $hour eq $_, 7, 8, 4, 5 or die "row $row_num: $location_id by $row->{'name'} invalid hour: $hour";
        $row->{'am_shift_checkbox'} = 'on' if grep $hour eq $_, 7, 8;
        $row->{'pm_shift_checkbox'} = 'on' if grep $hour eq $_, 4, 5;

        # make sure the hour jives with the page number or set the page number
        my $page = $row->{'page_num'};
        if( $page ) {
            die "row $row_num: $location_id: page $page doesn't jive with hour $hour" if $page eq '1' and $hour ne '7' and $hour ne '4'; 
            die "row $row_num: $location_id: page $page doesn't jive with hour $hour" if $page eq '2' and $hour ne '8' and $hour ne '5'; 
        } else {
            $row->{'page_num'} = 1 if grep $hour eq $_, '7', '4';
            $row->{'page_num'} = 2 if grep $hour eq $_, '8', '5';
        }

    } elsif( ( $row->{'am_shift_checkbox'} or $row->{'pm_shift_checkbox'} ) and $row->{'hour_for_00'} and ! $row->{'page_num'} ) {

        # no page number, but am/pm is checked and there's an hour (Gabe, lookin' at you)
        my $hour = $row->{'hour_for_00'};
        grep $hour eq $_, 7, 8, 4, 5 or die "row $row_num: $location_id invalid hour: $hour";
        $row->{'page_num'} = 1 if grep $hour eq $_, '7', '4';
        $row->{'page_num'} = 2 if grep $hour eq $_, '8', '5';

    } elsif( ( $row->{'am_shift_checkbox'} or $row->{'pm_shift_checkbox'} ) and $row->{'hour_for_00'} and $row->{'page_num'} ) {

        # everything set... does it jive?
        my $page = $row->{'page_num'};
        my $hour = $row->{'hour_for_00'};
        die "row $row_num: $location_id: $image_url: page $page doesn't jive with hour $hour" if $page eq '1' and $hour ne '7' and $hour ne '4'; 
        die "row $row_num: $location_id: $image_url: page $page doesn't jive with hour $hour" if $page eq '2' and $hour ne '8' and $hour ne '5'; 
        die "row $row_num: $location_id: $image_url: hour $hour doesn't jive with checkbox" if $row->{'am_shift_checkbox'} and $hour ne '7' and $hour ne '8';
        die "row $row_num: $location_id: $image_url: hour $hour doesn't jive with checkbox" if $row->{'pm_shift_checkbox'} and $hour ne '4' and $hour ne '5';

    } else {

        die "row $row_num: $location_id by $row->{'name'} inadequate time information: AM: $row->{'am_shift_checkbox'} PM: $row->{'pm_shift_checkbox'} hour: $row->{'hour_for_00'} page: $row->{'page_num'}";

    }

    $location_seen{ $row->{'location_id'} }{ $row->{"date"} }{ $row->{"hour_for_00"} } ++;

    $row_num++;

}


@rows = sort { 
    $a->{'location_id'} cmp $b->{'location_id'} ||
    $a->{'date'} cmp $b->{'date'} ||
    $a->{'hour_for_00'} <=> $b->{'hour_for_00'} 
} @rows;


open my $out, '>', "$fn\_cliff_out.csv" or die $!;
$csv->eol ("\r\n");

# In:

# Timestamp, <-- not used
# "Your name",'location_id',Date,Hour,"Quarter Hour",
# "NB Count","NB Female","NB Helmet","NB Wrong Way","NB Sidewalk",
# "SB Count","SB Female","SB Helmet","SB Wrong Way","SB Sidewalk",
# "EB Count","EB Female","EB Helmet","EB Wrong Way","EB Sidewalk",
# "WB Count","WB Female","WB Helmet","WB Wrong Way","WB Sidewalk",
# Comments,"Street Intersection"

# 00_EB_count,00_EB_female,00_EB_helmet,00_EB_sidewalk,00_EB_wrong_way,
# 00_NB_count,00_NB_female,00_NB_helmet,00_NB_sidewalk,00_NB_wrong_way,
# 00_SB_count,00_SB_female,00_SB_helmet,00_SB_sidewalk,00_SB_wrong_way,
# 00_WB_count,00_WB_female,00_WB_helmet,00_WB_sidewalk,00_WB_wrong_way,
# 15_EB_count,15_EB_female,15_EB_helmet,15_EB_sidewalk,15_EB_wrong_way,
# 15_NB_count,15_NB_female,15_NB_helmet,15_NB_sidewalk,15_NB_wrong_way,
# 15_SB_count,15_SB_female,15_SB_helmet,15_SB_sidewalk,15_SB_wrong_way,
# 15_WB_count,15_WB_female,15_WB_helmet,15_WB_sidewalk,15_WB_wrong_way,
# 30_EB_count,30_EB_female,30_EB_helmet,30_EB_sidewalk,30_EB_wrong_way,
# 30_NB_count,30_NB_female,30_NB_helmet,30_NB_sidewalk,30_NB_wrong_way,
# 30_SB_count,30_SB_female,30_SB_helmet,30_SB_sidewalk,30_SB_wrong_way,
# 30_WB_count,30_WB_female,30_WB_helmet,30_WB_sidewalk,30_WB_wrong_way,
# 45_EB_count,45_EB_female,45_EB_helmet,45_EB_sidewalk,45_EB_wrong_way,
# 45_NB_count,45_NB_female,45_NB_helmet,45_NB_sidewalk,45_NB_wrong_way,
# 45_SB_count,45_SB_female,45_SB_helmet,45_SB_sidewalk,45_SB_wrong_way,
# 45_WB_count,45_WB_female,45_WB_helmet,45_WB_sidewalk,45_WB_wrong_way,
# am_shift_checkbox,date,hour_for_00,hour_for_15,hour_for_30,hour_for_45,pm_shift_checkbox,
# intersection_of,location_id,name,observations_notes_1,observations_notes_2,
# organizer_notes,page_num

# Out:
# 'Location ID',Time,Recorder,"Rec Count",Page,Segment,Direction,Count,"Gender ",
# Age_Y,Age_O, <-- not used
# Helmet,"Wrong way",Sidewalk,
# Distracted,Pedestrian,Motoroized,Electric,Decor/Lights,"ADA Peds","ADA Chairs", <-- not used
# Notes,
# Construction

my %out = (
    'Location ID'         => 0,
    Time                  => 1,
    Recorder              => 2,
    "Rec Count"           => 3,  # <-- let the formula compute this; this counts between different locations/shifts
    Page                  => 4,  # <-- first half of shift vs second half of shift                                       \
    Segment               => 5,  # <-- which 15 minute block                                                             |
    Direction             => 6,  # <-- 1 = North, 2 = South, 3 = West, 4 = East XXXX double check this                   /
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

do {
    # generate a header row
    my %inverse_out = reverse %out;
    my @nums = sort { $a <=> $b } keys %inverse_out;
    my @row;
    for my $num ( @nums ) {
        $row[$num] = $inverse_out{$num};
    }
    $csv->print( $out, \ @row );
};

for my $in ( @rows ) {

    # each input row contains all 4 15 minute segments and all 4 directions

    for my $segment ('00', '15', '30', '45') {

        my @out;
        $out[ $out{'Location ID'} ] = $in->{'location_id'};
        $out[ $out{'Location ID'} ] =~ s{[AaPp]}{};
        $out[ $out{"Recorder"} ]    = $in->{'name'};
        $out[ $out{"Time"} ]        = $in->{'location_id'} =~ m/A/i ? 'AM' : 'PM';
        $out[ $out{"Notes"} ]       = $in->{'observations_notes_1'} . $in->{'observations_notes_2'};
        $out[ $out{"Page"} ]        = $in->{'page_num'};
        $out[ $out{"Segment"} ]     = 1 if $segment eq '00';
        $out[ $out{"Segment"} ]     = 2 if $segment eq '15';
        $out[ $out{"Segment"} ]     = 3 if $segment eq '30';
        $out[ $out{"Segment"} ]     = 4 if $segment eq '45';

        for my $direction ( 1, 2, 3, 4 ) {
            $out[ $out{"Direction"} ] = $direction;
            my $dir_code = [ undef, "NB", "SB", "EB", "WB", ]->[ $direction ]; # double checked comparing Okie's 101AM count sheet scans vs CountSummary2.xls; number/direction corrected per Cliff  Tue, 25 Sep 2012
            # 00_NB_count,00_NB_female,00_NB_helmet,00_NB_sidewalk,00_NB_wrong_way,
            $out[ $out{"Count"} ] = $in->{"$segment\_$dir_code\_count"} || 0;
            $out[ $out{"Gender "} ] = $in->{"$segment\_$dir_code\_female"} || 0;
            $out[ $out{"Helmet"} ] = $in->{"$segment\_$dir_code\_helmet"} || 0;
            $out[ $out{"Wrong way"} ] = $in->{"$segment\_$dir_code\_wrong_way"} || 0;
            $out[ $out{"Sidewalk"} ] = $in->{"$segment\_$dir_code\_sidewalk"} || 0;
            $csv->print( $out, [ @out ] );
        }

    }
}

close $out or die $!;



#  $location_seen{ $row{'location_id'} }{ $row{"date"} }{ $row{"hour_for_00"} } ++;

# XXX repair this error checking
#for my $location_id ( keys %location_seen ) {
#    warn "$location_id has 4, missing 5" if exists $location_seen{$location_id}{4} and ! exists $location_seen{$location_id}{5};
#    warn "$location_id has 5, missing 4" if ! exists $location_seen{$location_id}{4} and exists $location_seen{$location_id}{5};
#    warn "$location_id has 7, missing 8" if exists $location_seen{$location_id}{7} and ! exists $location_seen{$location_id}{8};
#    warn "$location_id has 8, missing 7" if ! exists $location_seen{$location_id}{7} and exists $location_seen{$location_id}{8};
#    for my $hour ( keys %{ $location_seen{$location_id} } ) {
#        my @quarter_hours = sort { $a <=> $b } keys %{ $location_seen{$location_id}{$hour} }; 
#        warn "$location_id for hour $hour missing or has extra quarter hours: @quarter_hours" unless "@quarter_hours" eq "0 15 30 45";
#    }
#}
