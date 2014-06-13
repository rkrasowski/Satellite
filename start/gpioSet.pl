#!/usr/bin/perl
use warnings;
use strict;

my @array = (44,26,89,75,45,86);
my $pin;

foreach(@array)
	{
		$pin = $_;
		print "Setting up Pin number: $pin\n";

		`sudo echo $pin > /sys/class/gpio/export`;
		`sudo echo out > /sys/class/gpio/gpio$pin/direction`;
	#	`sudo echo 1 > /sys/class/gpio/gpio$pin/value`;
		print "PIN $pin is set for OUT\n";
	#	sleep(3);
	#	`sudo echo 0 > /sys/class/gpio/gpio$pin/value`;
	#	print "PIN $pin should be OFF now\n\n";
	}
