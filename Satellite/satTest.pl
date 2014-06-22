#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(floor ceil);
use Device::SerialPort;
use Time::Local;
use version; our $VERSION = qv('1.0.1');
require "/home/ubuntu/Subroutines/debug.pm";




my $rx;
our $debug = 1; 


debug("Satellite system is starting");


# Activate serial connection:
my $PORT = "/dev/ttyO4";
my $ob = Device::SerialPort->new($PORT) || die "Can't Open $PORT: $!";

$ob->baudrate(19200) || die "failed setting baudrate";
$ob->parity("none") || die "failed setting parity";
$ob->databits(8) || die "failed setting databits";
$ob->handshake("none") || die "failed setting handshake";
$ob->write_settings || die "no settings";
$| = 1;

debug("Opening serial port ttyO4 to modem");

echo();
sleep(1);
checkModem();








############################################ subroutines ##################################

sub checkModem{

my $i =1;

while ($i < 6)
        {

                $ob->write("AT\r");
                debug("Checking if modem is accesable....trial $i");
                $i++;
                sleep(1);


                $rx = $ob->read(255);
		print "Rx: $rx\n";
                if ($rx =~ m/OK/)
                        {
                            goto READY;
                        }

        }
        debug("Can\'t find Iridium 9602 !!");
         exit();

READY:{debug("Iridium 9602 identyfied and ready to work....");}
}


sub echo        
        {
                 $ob->write("ATEn0\r");
                 debug("Turning echo off");
                 sleep(1);
                  $rx = $ob->read(255);
                  print "Echo off results: $rx\n";
        }

