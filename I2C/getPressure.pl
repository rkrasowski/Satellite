#!/usr/bin/perl
use strict;
use warnings;

######## getPressure.pl #########
# Gets data from ain #
# by Robert J Krasowski #
# 8/4/2012 #
#################################


`echo bmp085 0x77 > /sys/class/i2c-adapter/i2c-2/new_device`;

while (1) {
sleep(1);
my $value = getPres();


print "\nFinal is $value\n\n";

}

######################## Subroutines #################################


sub getPres
{
my @array;
my $numEl;
my $correction = 1.03;
my $value;
do
{
open (FH, "\/sys\/bus\/i2c\/drivers\/bmp085\/2-0077\/pressure0_input") or die $!;
while (<FH>)
{

chomp $_;
push (@array,"$_");

}	


$numEl = @array;

close(FH);


} until ($numEl == 12);	

shift @array;
pop @array;
my $total = 0;
($total+=$_) for @array;
$value = $total / 10;

$value = $value/100;
$value = $value * $correction;
$value = sprintf("%.1f", $value);
return $value;
}
