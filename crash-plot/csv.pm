package csv;

use strict;
use warnings;

use XXX;
use Text::CSV;
use IO::Handle;
use List::MoreUtils 'zip';
use Data::Dumper;
use Carp;

sub new {
    my $package = shift;
    my $fn = shift or die;
    my $header_row_num = shift || 0;
    my $record_class = shift || 'csv::rec';

    my $csv = Text::CSV->new({ binary => 1 }) or die Text::CSV->error_diag;

    open my $fh, '<', $fn or die "$fn: $!";

    my $mod_time = -M $fn;

    my @preheader_data;
    die if $header_row_num < 0;
    my $header_row_num_cp = $header_row_num;
    push @preheader_data, $csv->getline( $fh ) while $header_row_num_cp--;  # header is probably row 0 or row 1

    my $header = $csv->getline( $fh ) or die "unexpected end of cvs data:  no header at all";
    for my $i ( 0 .. $#$header ) { $header->[$i] ||=  "column_number_$i" }

    my @rows;

    while ( my $line = $csv->getline( $fh ) ) {
       push @$line, undef while @$line < @$header;
       push @$header, "column_number_" . ( $#$header + 1 ) while @$line > @$header;
       push @rows, bless { zip @$header, @$line }, $record_class;
    }

    bless { 
        rows => \@rows, 
        preheader_data => \@preheader_data, 
        header => $header, 
        header_row_num => $header_row_num, 
        in_filename => $fn, 
        mod_time => $mod_time,
        record_class => $record_class,
    }, $package;
}

sub reload {
    my $self = shift;
    if( -M $self->{in_filename} != $self->{mod_time} ) {
warn "file changed; reloading; $self->{mod_time} vs " . -M $self->{in_filename};
        my $new_self = ref($self)->new( $self->{in_filename}, $self->{header_row_num} );
        for my $k ( keys %$new_self ) {
            $self->{$k} = $new_self->{$k};
        }
        $self->{mod_time} = -M $self->{in_filename};
    }
    return $self;
}

sub write {
    my $self = shift;
    my $out_fn = shift || $self->{in_filename};

    my $header = $self->{header};
    my $rows = $self->{rows};

    my $csv = Text::CSV->new({ binary => 1, eol => "\015\012" }) or die Text::CSV->error_diag;

    if( -e $out_fn )  {
        unlink "$out_fn.bak" if -e "$out_fn.bak";
        rename $out_fn, "$out_fn.bak" or die $!;
    }

    open my $out_fh, '>', $out_fn or die "$out_fn: $!";

    # write the stuff that comes before the header

    for my $row ( @{ $self->{preheader_data} } ) {
        $csv->print( $out_fh, $row );
    }

    # write the header 

    $csv->print( $out_fh, $header );

    # write the data

    for my $row ( @$rows ) {
        my @row_data = map { $row->{$_} } @$header;
        $csv->print( $out_fh, \@row_data ); 
    }
}

sub find {
    my $self = shift;
    my $field_name = shift;
    my $field_value = shift;
    return unless @{ $self->{rows} };
    exists $self->{rows}->[0]->{$field_name} or die "field name ``$field_name'' provided to find not found: " . Data::Dumper::Dumper $self->{rows}->[0];
    my @res = grep { defined $_->{$field_name} and $_->{$field_name} eq $field_value } @{ $self->{rows} };
    return unless @res;
    return $res[0];
}

sub add {
    my $self = shift;
    my $header = $self->{header};
    my $rows = $self->{rows};
    my @fill_data = (undef) x $#$header;
    my $new_row = bless { zip @$header, @fill_data }, $self->{record_class};
    push @$rows, $new_row;
    return $new_row;
}

sub rows {
    my $self = shift;
    my $rows = $self->{rows};
    return wantarray ? @$rows : $rows;
}

sub headers {
    my $self = shift;
    return wantarray ? @{ $self->{header} } : $self->{header};
}

sub add_column {
    my $self = shift;
    my $column_name = shift or die;
    die "column already exists" if grep $_ eq $column_name, @{ $self->{header} };
    push @{ $self->{header} }, $column_name;
    for my $row ( @{ $self->{rows} } ) {
        $row->{ $column_name } = undef;
    }
    1;
}

package csv::rec;

sub AUTOLOAD :lvalue {
    my $self = shift;
    my $method = our $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    # grep $method eq $_, @{ $self->{header} } or Carp::confess "csv: ``$method'' not in list of known fields: @{ $self->{header} }"; # nope, we're csv::rec.  only csv has this.
    exists $self->{$method} or Carp::confess "csv: ``$method'' not in list of known fields: @{[ keys %$self ]}";
    $self->{$method};
}

package main;

use Test::More;

do {

    # test

    my $test_data = <<'EOF';
"Location ID",Time,Recorder,"Rec Count",Page,Segment,Direction,Count,"Gender ",Age_Y,Age_O,Helmet,"Wrong way",Sidewalk,Distracted,Pedestrian,Motoroized,Electric,Decor/Lights,"ADA Peds","ADA Chairs",Notes,Construction,LocRank,LocRankUniq,Seg,Seg1,LocTime,LocTimeDir,,"Gender ",Age_Y,Age_O,Helmet,"Wrong way",Sidewalk,Distracted,,"Cordon in","Cordon out","Bike Lane Size","Bike Lane"
1101,AM,"Joe (Okie) Oconnor",1,1,1,1,2,,,,2,,,,1,,,,,,,,1,1,1,101_1,101AM,101AMNS,,,,,,,,,,0,0,3,1
2101,AM,"Joe (Okie) Oconnor",1,1,1,2,2,,,,2,,,,1,,,,,,,,1,,1,101_1,101AM,101AMNS,,,,,,,,,,0,0,0,0
3101,AM,"Joe (Okie) Oconnor",1,1,1,3,1,1,,,1,,1,,,,,,,,,,1,,1,101_1,101AM,101AMEW,,,,,,,,,,0,0,3,1
4101,AM,"Joe (Okie) Oconnor",1,1,1,4,2,,,,2,,,,1,,,,,,,,1,,1,101_1,101AM,101AMEW,,,,,,,,,,0,0,0,0
5101,AM,"Joe (Okie) Oconnor",1,1,2,1,5,,,,4,,,,1,,,,,,,,1,,2,101_2,101AM,101AMNS,,,,,,,,,,0,0,3,1
6101,AM,"Joe (Okie) Oconnor",1,1,2,2,1,,,,1,,,,,,,,,,,,1,,2,101_2,101AM,101AMNS,,,,,,,,,,0,0,0,0
7101,AM,"Joe (Okie) Oconnor",1,1,2,3,3,,,,2,,1,,,,,,,,,,1,,2,101_2,101AM,101AMEW,,,,,,,,,,0,0,3,1
8101,AM,"Joe (Okie) Oconnor",1,1,2,4,2,1,,,2,,,,,,,,,,,,1,,2,101_2,101AM,101AMEW,,,,,,,,,,0,0,0,0
9101,AM,"Joe (Okie) Oconnor",1,1,3,1,6,,,,6,1,1,,,,,,,,,,1,,3,101_3,101AM,101AMNS,,,,,,,,,,0,0,3,1
EOF
    open my $fh, '>', '/tmp/test.csv' or die $!;
    $fh->print($test_data);
    close $fh;    

    my $me = csv->new('/tmp/test.csv', 0);
    my $rec = $me->find('Location ID', 2101);
    ok $rec, 'rec found'; 
    # warn Data::Dumper::Dumper $rec;
    is $rec->Time,'AM', 'Time field as expected';
    is $rec->Direction,'2', 'Direction field as expected';
    $rec->Direction = '212';
    is $rec->Direction, '212', 'Updated Direction field as expected';
    $me->write;

    $me = csv->new('/tmp/test.csv', 0);
    ok $me, 'Re-read the csv file after write';
    $rec = $me->find('Location ID', 2101);
    # warn "rec after find: " . Data::Dumper::Dumper $rec;
    ok $rec, 'rec found after write'; 
    is $rec->Direction, '212', 'Updated Direction field as expected after write';
    $rec = $me->find('Location ID', 8101);
    is $rec->Direction, '4', 'Not updated Direction field as expected after write';

    $rec = $me->add;
    $rec->{'Location ID'} = 4321;
    $rec->Time = 'PM';
    $rec->Recorder = 'Fred';
    $rec->Sidewalk = 10;
    $me->write;

    $me = csv->new('/tmp/test.csv', 0);
    $rec = $me->find('Location ID', 4321);
    ok $rec, "Found newly added rec after write and re-read";
    is $rec->Recorder, 'Fred', "Data in new record is as expected";

    done_testing;
};


