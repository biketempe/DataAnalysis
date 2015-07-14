#!/usr/bin/perl

#  My definition was:
#  1 NB
#  2 SB
#  3 EB
#  4 WB
# 
#  In the file you sent me, this was the order (based on my limited sampling):
#  1 NB
#  2 SB
#  3 WB
#  4 EB
# 
# **** Page-Segment(15 min block num)-Direction  ... change all values for Direction 4 to 3 and vice versa


use strict;
use warnings;

use IO::Handle;
use Text::CSV;
use Data::Dumper;

my $csv = Text::CSV->new({ binary => 1, eol => "\015\012" }) or die Text::CSV->error_diag;

sub build_header {
    my $header = shift;
    my %header;
    for my $i ( 0 .. $#$header ) {
        $header{ $header->[$i] } = $i; #   %header is column name to column number
        # $header[ $i ] = $header->[$i]; #   @header is column number to column name
    }
    return wantarray ? %header : \%header;
}

for my $input (qw/ 2012_combined_spot_checked_cliff_out.csv / ) {

    open my $fh, '<', $input or die $!;
    open my $out_fh, '>', "$input.directions_fixed.csv" or die $!;
    
    my $header_line = $csv->getline( $fh );
    $csv->print( $out_fh, $header_line ) or die;
    my %header = build_header( $header_line );
 
    while ( my $row = $csv->getline( $fh ) ) {
    
        if( $row->[ $header{Direction} ] eq '3' ) {
            $row->[ $header{Direction} ] = 4;
        } elsif( $row->[ $header{Direction} ] eq '4' ) {
            $row->[ $header{Direction} ] = 3;
        } 
 
        $csv->print( $out_fh, $row ) or die;
    }

    $csv->eof or $csv->error_diag;
    close $fh;

}

