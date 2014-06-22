#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(floor ceil);
use Device::SerialPort;
use Time::Local;
use version; our $VERSION = qv('1.0.1');
require "/home/ubuntu/Subroutines/debug.pm";


my $sigStrenght;
my $network;
my $MO;
my $MOMSN;
my $MT;
my $MTMSN; 
my $tx;
my $rx;
my $RI;
my $numOfMessages;
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

debug("Serial port ttyO4 to iridium is open");


sleep(1);
checkModem();
checkBuffer();
checkRI();






############################################ subroutines ##################################

sub checkModem
	{

		my $i =1;

		while ($i < 6)
        		{

                		$ob->write("AT\r");
                		debug("Checking if modem is accesable....trial $i");
                		$i++;
                		sleep(1);

                		$rx = $ob->read(255);
                		if ($rx =~ m/OK/)
                        		{
                            			goto READY;
                        		}
        		}
        		debug("Can\'t find Iridium 9602 !!");
        		 exit();

		READY:{debug("Iridium 9602 identyfied and ready to work....");}
	}


sub checkBuffer
        {
                $ob->write("AT+SBDS\r");
                sleep(1);
                $rx = $ob->read(255);
                if ($rx =~ m/SBDS:/)
                        {

                                my @array = split(':',$rx);
                                my $array;
                                my $Part2 = $array[1];
                                my @array2 = split(',',$Part2);
                                my $array2;
                                $MO = $array2[0]; # Mobile originated message 0 - no, 1 - yes
                                $MOMSN = $array2[1]; # Mobile originated message sequence number
                                $MT = $array2[2]; # Terminal originated message
                                $MTMSN = $array2[3]; # Terminal originated message sequence number

                        }
		print "MO: $MO\nMOMSN: $MOMSN\nMT: $MT\nMTMSN: $MTMSN\n\n";
        }


sub checkRI
	{
                 $ob->write("AT+SBDSX\r");
                 sleep(1);
                 $rx = $ob->read(255);
                 if ($rx =~ m/SBDSX:/)
                        {

				my @arrayRI = split(/\n/,$rx);
				foreach (@arrayRI)
					{
						if($_ =~ m/SBDSX:/)	

							{

                                 				my @array = split(':',$_);
                                 				my $Part2 = $array[1];
                                 				my @array2 = split(',',$Part2);
                                 				my $array2;
                                 				$MO = $array2[0]; # Mobile originated message 0 - no, 1 - yes
                                 				$MOMSN = $array2[1]; # Mobile originated message sequence number
                                 				$MT = $array2[2]; # Terminal originated message
                                 				$MTMSN = $array2[3]; # Terminal originated message sequence number
                                 				$RI = $array2[4]; # Ring indicator
                                 				$numOfMessages = $array2[5]; # Number of messages witing
                                 				$numOfMessages =~ s/\r|\n|OK//g;
                                 				debug("MO: $MO\nMOMSN: $MOMSN\nMT: $MT\nMTMSN: $MTMSN\nRI: $RI\nNum of messages waiting: $numOfMessages\n\n");
							}	
					}	
				return $RI;
			}
	}
