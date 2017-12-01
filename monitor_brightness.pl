#!/bin/perl

=pod
# Manual monitor brightness adjuster
Adjust your monitor's brightness manually in CUI.

# Refer:
http://perldoc.perl.org/perlfaq5.html#How-can-I-read-a-single-character-from-a-file%3f-From-the-keyboard%3f
=cut

sub BRIGHTLIGHT_MIN() { 0 }
sub BRIGHTLIGHT_MAX() { 200 }
sub BRIGHTLIGHT_WARN_MIN() { 30 }
sub BRIGHTLIGHT_WARN_MAX() { 150 }
sub BRIGHTLIGHT_STEP() { 4 }
# sub X_BACKLIGHT_BRIGHTNESS_STEP() { 0.2 }
# sub X_BACKLIGHT_BRIGHTNESS_MAX() { 10.0 }
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

my $m = $ms[0];
my $m = substr($m, 0, index $m, " ");

my $current = get_brightness();
printf "Current: %d\n", $current;

my $step = BRIGHTLIGHT_STEP();
my $max = BRIGHTLIGHT_MAX();
my $min = BRIGHTLIGHT_MIN();
my $warn_max = BRIGHTLIGHT_WARN_MAX();
my $warn_min = BRIGHTLIGHT_WARN_MIN();

my $in = "";
do {
    $in = read_input("+-q^");
    if ($in eq "+") {
        $current += $step;
    } elsif ($in eq "-") {
        $current -= $step;
    } elsif ($in eq "^") {
        $current = $max;
    }
    $current = $min if ($current < $min);
    if ($current < $warn_min || $current > $warn_max) {
        print "Warn: current brightness=$current\n";
    }
    set_brightness($current);
} while ($in ne "q");

if ($in eq "q") {
    show_brightness($current);
}

exit;

sub get_brightness {
    get_brightlight();
}

sub set_brightness {
    my $value = shift;
    set_brightlight($value);
    if ($m) {
        my $xrvalue = brightlight_to_xrandr_brightness($value);
        set_xrandr_brightness($xrvalue);
    }
    show_brightness();
}

sub show_brightness {
    my $value = shift;
    show_brightlight();
    if ($m) {
        show_xrandr_brightness();
    }
}

sub set_brightlight {
    my $value = shift;
    `brightlight -w $value`;
}

sub get_brightlight {
    my $output = `brightlight -r`;
    if ($output =~ m/(\d+)/) {
        $1;
    } else {
        warn "Unable to get brightness value from brightlight";
	0;
    }
}

sub show_brightlight {
    printf "brightlight -set %d\n", get_brightlight();
}

sub set_xrandr_brightness {
    my $value = shift;
    `xrandr --output $m --brightness $value`;
}

sub show_xrandr_brightness {
    my $blvalue = get_brightlight();
    my $xrvalue = brightlight_to_xrandr_brightness($blvalue);
    printf "xrandr --output %s --brightness %02.4f\n", $m, $xrvalue;
}

sub brightlight_to_xrandr_brightness {
    my $bl = shift;
    my $xr = $bl / 300.0;
    $xr = BRIGHTNESS_MAX if ($xr > BRIGHTNESS_MAX);
    $xr;
}

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
