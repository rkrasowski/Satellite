#!/usr/bin/perl 
use strict;
use warnings;


# set pin as output 8_39

`echo 76 > /sys/class/gpio/export`;
`echo out > /sys/class/gpio/gpio76/direction`;
`logger "Starting hardware dogwatch"`;



while (1)
	{
		`echo 1 > /sys/class/gpio/gpio76/value`;
		select(undef,undef,undef,0.01);
		`echo 0 > /sys/class/gpio/gpio76/value`;
		sleep(2);
		#select(undef,undef,undef,0.01);
 	}



