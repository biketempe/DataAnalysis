#!/usr/local/bin/perl

use lib '/home/scott/projects/bikecount/visualization';

=for comment

Notes:

    pdftoppm Local.pdf bus.ppm
    ppmtogif <  ppmquant 32 bus.ppm-000001.ppm > bus.gif
    text2gif -t 'East' > imgs/east.gif
    transcode -x imlist,null -i list.txt  -o bus.mpg -g 950x740 --use_rgb -y xvid -k -w 2600  # none of those arguments exist any more
    mencoder mf://*.bmp -ovc lavc -oac copy -o out.avi 
    mencoder mf://*.bmp -ovc lavc -oac copy -mf fps=10 -o out.avi 

=cut

use strict;
use warnings;

use lib '.';
use graphics;
use csv;

use AnyEvent;

use Coro;
# use Coro::Cont;
use Coro::Event;
use Coro::Handle;
use Coro::Channel;
# use Coro::Debug;

use IO::Handle;
use IO::Socket;
use IO::Socket::INET;
use IO::Socket::SSL;

use PeekPoke 'peek', 'poke';

use Fcntl;
use Errno;

use Carp 'confess';

#
#
#

sub opt ($) { scalar grep $_ eq $_[0], @ARGV }
sub arg ($) { my $opt = shift; my $i=1; while($i<=$#ARGV) { return $ARGV[$i] if $ARGV[$i-1] eq $opt; $i++; } }

my $mouse_events;   # interface to SDL mouse 

my $app_x = 616;
my $app_y = 815;

my $graphics = graphics->new(appx => $app_x, appy => $app_y, eventcb => \&event_callback, title => 'Bike Count Visualization', mouse => 0, ) or die;
my  $app = $graphics->{app} or die;

my %imgs = $graphics->load_images('/home/scott/projects/bikecount/visualization/imgs');
my $max_x = $imgs{tempe}->w - $app_x; 
my $max_y = $imgs{tempe}->h - $app_y;

my $show_accidents = opt '--accidents';

#
#
#

my $rate = csv->new('accident_rate.csv');

my @count_tiers = tiers( [ map $_->four_hour_route, $rate->rows ] );  # how many bikes were observed in the 10 percentile, 20 percentile, etc
my @accident_tiers = tiers( [ map $_->


#
#
#

sub tiers {
    my $data = shift;
    my @tiers;
    my @all_numbers = sort { $b <=> $a } @$data;  # descending 
    for my $i ( 1 .. 10 ) {
        $iers[ $i-1 ] = $all_numbers[ int( @all_numbers / 10 ) * $i  ];
    }
    return @tiers;

}

my @count_tiers = tiers( [ map $_->{count}||0, @$count_data ] );  # how many bikes were observed in the 10 percentile, 20 percentile, etc

die \

do {
    my $count_data = $timetables->{count_data};
    my @all_count_numbers = sort { $b <=> $a } map $_->{count}||0, @$count_data;
    for my $i ( 1 .. 10 ) {
        $count_tiers[ $i-1 ] = $all_count_numbers[ int( @all_count_numbers / 10 ) * $i  ];
    }
    # warn "@count_tiers";
};

$SIG{CHLD} = sub { wait; };

#
# debugging goop
#

# BEGIN { $Devel::Trace::TRACE = 0; };  # Disable
my $delay = Coro::Event->timer( after => 1 );
# my $debugserver = Coro::Debug->new_unix_server( "/tmp/coro" );

#
#
#

sub draw_playfield {

    # draw the background, which happens to be tempe for my purposes

    SDL::Video::blit_surface(
        $imgs{tempe},
        SDL::Rect->new(0, 0, $app_x, $app_y, ), # clipping from the source, $imgs{bus} 
        $app,     # destination surface
        SDL::Rect->new( 0, 0, 0, 0 ), # target offset. "Only the position is used in the dstrect (the width and height are ignored)"
    );

    $graphics->text(30, 30, $timetables->current_time);

    #
    #
    #

    my $accidents = $show_accidents ? $timetables->{accident_data} : [];
    my $accidents_by_time = opt '--accidents-by-time';
    for my $accident ( @$accidents ) {
        # Longitude, Latitude,
        # IncidentDateTime,
        # cyclist_age, cyclist_sex, cyclist_alochol,
        # cyclist_violation, cyclist_injury,
        # motorist_alochol, motorist_violation

        my $current_time = sprintf "%d%02d", map $timetables->{current_time}->[$_], 0, 1;

        my $scale = 1;

        # 2012-01-03 02:44:00
        (my $hour, my $minute) = $accident->{IncidentDateTime} =~ m< (\d{2}):(\d{2}):\d{2}$> or die "failed to parse time: $accident->{IncidentDateTime}";
        my $ampm = $hour >= 12 ? 'p' : 'a';
        $hour -= 12 if $hour > 12;
        my $accident_time = "$hour$minute";

        my $accident_is_at_this_time = 1;
        $accident_is_at_this_time = 0 if $ampm ne $timetables->{current_time}->[2];
        $accident_is_at_this_time = 0 if $accident_time < $current_time - 12;
        $accident_is_at_this_time = 0 if $accident_time > $current_time + 12;

        my $full_brightness = 1;
        if( $accidents_by_time ) {
            # only fade in/fade out if we're showing only the accidents for approximately the current time
            $full_brightness = 0 if $accident_time < $current_time - 2; # XXX don't think this is working
            $full_brightness = 0 if $accident_time > $current_time + 10;
        } else {
            $scale = 0.5;  # smaller if they're always there for less clutter
            $full_brightness = 0;
        }

        if( ! $accidents_by_time or $accident_is_at_this_time ) {
            (my $x, my $y) = degeocode( $accident->{Latitude}, $accident->{Longitude} ) or next;
            if( $full_brightness ) {
                $imgs{X}->draw($x, $y, $scale);
            } else {
                $imgs{Xdim}->draw($x, $y, $scale);
            }
        }

    }

    #
    #
    #

    my $set_alpha = sub {
        my $new_alpha = shift;
        $new_alpha <<= 24;
        $imgs{bluedot}->transform(sub {
            my $addy = shift;
            my $x = shift;
            my $y = shift;
            my $alpha = ( peek( $addy ) & 0xff000000 ) >> 24;
            # warn "$x $y alpha $alpha minutes past $minutes_left_in_block";
            return if $alpha == 0x00; # skip completely transparent pixels
            # XXX some pixels will be in various states of transparency
            my $everything_but_alpha = peek( $addy ) & 0x00ffffff;
            poke( $addy, $everything_but_alpha | $new_alpha );
        });
    };

    $set_alpha->( 0x80 );

    # 616 815
    my $leg_y = 675;
    $graphics->text(50, $leg_y - 40, "Legend");
    for my $count (5, 10, 20, 40 ) {
        $leg_y += 5 + $count;
        my $scale = 1/30;
        $scale *= $count;
        $imgs{bluedot}->draw(50, $leg_y, $scale);
        $graphics->text_small(50 - 3, $leg_y - 3 , $count);
    }

    #
    #
    #

    my $degrees_per_minute_at_10mph = 0.00171213333333332;

    my $saved_current_time = $timetables->current_time;

    my $minutes_left_in_block = 15 - ( $timetables->{current_time}->[1] % 15 );

    for my $segment ( 0, 1, 2 ) {

        if( $segment == 0 ) {
            # look into the future; was right the first time
            # these are the bikes that are a long ways from coming in to the checkpoint
            $timetables->inc_time for 1..15;
            $minutes_left_in_block += 15;  # increase how many minutes the bike effectively is away
            $set_alpha->( 0x30 );
        } elsif( $segment == 1 ) {
            # go back to the present
            # these are the bikes that are approaching the checkpoint
            $minutes_left_in_block -= 15;
            $timetables->dec_time for 1..15;
            # perl -e 'printf "%x\n", ( 0xff - 15 * 0x08 );' # 0x87
            # perl -e 'printf "%x\n", ( 0xff - 15 * 0x0b );' # 0x5a
            $set_alpha->( 0xff - $minutes_left_in_block * 0x0b );
        } elsif( $segment == 2 ) {
            # look at the block in the past so we can fade bikes out from the destination checkpoint
            last if $minutes_left_in_block <= 12; # only animate a fade out for three minutes worth of animation
            $timetables->dec_time for 1..15;
            $set_alpha->( 0xff - ( 16 - $minutes_left_in_block )  * 0x40 );
        }
 
        my @bikes = $timetables->active_bikes();

        for my $bike ( @bikes ) {
            # warn "active bike: @$bike segment: $segment";
            (my $location_id, my $lat, my $long, my $count, my $direction) = @$bike;

            next unless $count;
 
            # add to/subtract from lat/long depending on $direction and $minutes_past
            # lat gets larger as it goes north
            # long gets larger as it goes west

            my $distance_away = $degrees_per_minute_at_10mph * $minutes_left_in_block;

            $distance_away = - (15 - $minutes_left_in_block ) * $degrees_per_minute_at_10mph if $segment == 2;  # bicycles that have already arrived at the checkpoint
 
            if( $direction eq 'NB' ) {
                $lat -= $distance_away;
            } elsif( $direction eq 'SB' ) {
                $lat += $distance_away;
            } elsif( $direction eq 'WB' ) {
                $long -= $distance_away;
            } elsif( $direction eq 'EB' ) {
                $long += $distance_away;
            }

            (my $x, my $y) = degeocode($lat, $long) or next;

            next if $x < 0 or $y < 0;
            next if $x > $app_x or $y > $app_y;
            # warn "drawing a bus at $x, $y between positions of $x1, $y1 and $x2, $y2";

            # the blob starts out at 30,30 pixels
            # give it a nice linear scale
            my $scale = 1/30;
            $scale *= $count;

            # if( $segment == 2 ) {
            #     # animate a fade out of a glob that reached its checkpoint
            #     $scale *= 0.6 for 1 .. ( 15 - $minutes_left_in_block ); 
            # }

            $imgs{bluedot}->draw($x, $y, $scale);

            # $graphics->text($x, $y, $location_id); # debug
            # $graphics->text_small($x, $y, $count); # debug

        }

    }

    $timetables->set_current_time( $saved_current_time );

    $graphics->refresh();

}

sub degeocode {
    # convert lat/long into x, y coordinates

    # top left:     33.449927,-111.981824
    # bottom left:  33.333917,-111.979737
    # bottom right: 33.334878,-111.875909
    # top right:    33.448335,-111.877009

    my $lat = shift;   # north/south position;
    my $long = shift;  # west/east
    my $top = 33.449927;     my $bottom = 33.333917;
    my $left = -111.979737; my $right = -111.877009; 
    $lat -= $bottom;
    my $tmp_lat = $top - $bottom;
    my $lat_percent = $lat / $tmp_lat;
    my $y = $app_y - $app_y * $lat_percent;

    $long -= $right;
    my $tmp_long = $left - $right;
    my $long_percent = $long / $tmp_long;
    my $x = $app_x - $app_x * $long_percent;

    return $x, $y;
}

#
# misc UI events
#

sub event_callback {
    # event: type: 5 x: 303 y: 402 button: 1 key: unknown key
    my @event = @_;
    if($event[0] == 5 and $event[3] == 1) {
        warn "click! x: @{[ $event[1]  ]} y: @{[ $event[2] ]}\n";
    }
}

#
# main loop
#

do {

    my $i = 0;
    
    while( 1 ) {

        $timetables->inc_time;

        # a bit after the end of the AM shift, to the PM shift 
        if( $timetables->current_time eq '910a' ) {
            $timetables->set_current_time('350p');
        }

        if( $timetables->current_time eq '610p' ) {
            last;
        }

        draw_playfield();

        SDL::Video::save_BMP( $app, sprintf "/tmp/bikeanim/%08d.anim.bmp", $i ++ );
    
#    my $timer = Coro::Event->timer( interval => 1, );  
#        while($timer->next) {
#            # print "tick...\n";
#        }
# sleep 1;
    
        cede;
    }
    
};

# cede for 1..5;


#
#
#

