#!/bin/perl

=pod
# Manual monitor brightness adjuster
Adjust your monitor's brightness manually in CUI.

# Refer:
http://perldoc.perl.org/perlfaq5.html#How-can-I-read-a-single-character-from-a-file%3f-From-the-keyboard%3f
=cut

sub X_BACKLIGHT_BRIGHTNESS_STEP() { 0.2 }
sub X_BACKLIGHT_BRIGHTNESS_MAX() { 10.0 }
sub BRIGHTNESS_MIN()  { 0.0 }
sub BRIGHTNESS_MAX()  { 1.0 }

use strict;
$| = 1;

my @ms = `xrandr -q | grep connected | grep -v disconnected | grep -v eDP-1`;
if (@ms >= 2) {
    print @ms;
}
while (@ms >= 2) {
    print "Select monitor: ";
    my $m = <>;
    if ($m ne "") {
	@ms = `xrandr -q | grep connected | grep -v disconnected | grep $m`;
    }
}

my $m = substr($ms[0], 0, index $ms[0], " ");

my $current = `xbacklight -get`;
printf "Current: %02.2f\n", $current;

my $in = "";
do {
    $in = read_input("+-q^");
    if ($in eq "+") {
        $current += X_BACKLIGHT_BRIGHTNESS_STEP;
    } elsif ($in eq "-") {
        $current -= X_BACKLIGHT_BRIGHTNESS_STEP;
    } elsif ($in eq "^") {
        $current = X_BACKLIGHT_BRIGHTNESS_MAX;
    }
    $current = BRIGHTNESS_MIN if ($current < BRIGHTNESS_MIN);
    if ($current < 1.0 || $current > X_BACKLIGHT_BRIGHTNESS_MAX) {
        print "Warn: current brightness=$current\n";
    }
    my $mcur = xbacklight_to_xrandr_brightness($current);
    `xbacklight -set $current`;
    `xrandr --output $m --brightness $mcur`;
} while ($in ne "q");

if ($in eq "q") {
    my $mcur = xbacklight_to_xrandr_brightness($current);
    printf "xbacklight -set %02.2f\n", $current;
    printf "xrandr --output %s --brightness %02.4f\n", $m, $mcur;
}

exit;

sub xbacklight_to_xrandr_brightness {
    my $backlight = shift;
    my $brightness = $backlight / 7.5;
    $brightness = BRIGHTNESS_MAX if ($brightness > BRIGHTNESS_MAX);
    $brightness;
}

sub read_input {
    my $pat = shift;
    my $got;
    do {
	$got = getone();
    } while (-1 == index $pat, $got);
    $got;
}

BEGIN {
    use POSIX qw(:termios_h);

    my $term     = POSIX::Termios->new();
    my $oterm = $term->getlflag();

    my $fd_stdin = fileno(STDIN);
    $term->getattr($fd_stdin);

    sub cbreak {
        my $echo = ECHO | ECHOK | ICANON;
        my $noecho = $oterm & ~$echo;
        $term->setlflag($noecho);
        $term->setcc(VTIME, 1);
        $term->setattr($fd_stdin, TCSANOW);
    }

    sub cooked {
        $term->setlflag($oterm);
        $term->setcc(VTIME, 0);
        $term->setattr($fd_stdin, TCSANOW);
    }

    sub getone {
	my $key = '';
	cbreak();
	sysread(STDIN, $key, 1);
	cooked();
	return $key;
    }
}

END { cooked() }
