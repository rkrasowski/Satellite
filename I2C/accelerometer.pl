#!/usr/bin/perl 
use strict;
use warnings;

############### acceerometer.pl #####################
#													#
#	Reads accelemeter data via c program mma7455 	#
#	and return x,y,z value							#
# 	by Robert J. Krasowski							#
#	8/7/2012										#
#													#
#####################################################


while(1)
	{
		getAccelerometer();
		sleep(1);
	}



##################################################################
sub getAccelerometer
	{
		my $x;
		my $y;
		my $z;
		my $xCorr = 0;
		my $yCorr = 0;
		my $zCorr = 0;


		my $array;

		open(my $PS,"./mma7455 |") || die "Failed: $!\n";
		while ( <$PS> )
			{
  				my @array = split (/\|/,$_);
  				$x = $array[0];
				$y = $array[1];
				$z = $array[2];
			}
 
		close($PS);

		$x = $x + $xCorr;
		$y = $y + $yCorr;
		$z = $z + $zCorr;

		print "X = $x\nY = $y\nZ = $z\n";
	}

