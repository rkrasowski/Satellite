#!/usr/bin/perl
use warnings;
use strict;
use lib qw(/home/ubuntu/1-Wire/);
use POSIX qw(floor ceil);
use Device::SerialPort;
use Time::Local;
use version; our $VERSION = qv('1.0.1');
require W1TempReader;  			# module to read temp

##################################### satDeamon.pl ##############################
#										#
#	Take care of all communincation with sat modem routine			#
#	Wait for incomming messages, periodically sends outgoing messages	#
#	Robert J. Krasowski							#
#	8/17/2013								#
#										#
#################################################################################

my $debug = 1;                  # 0 - no debug, 1 - debug goes to terminal, 2 - debug goes to /home/ubuntu/Log/main.log


my $i;
my $SFQ = SFQRetrieve();
my $TBC = 10;			# TBC - Time Between Checks (for new message)  in seconds
my $serialData;                 
my $tx;                 
my $rx; 
my $sigStrenght;
my $network;
my $MO;
my $MOMSN;
my $MT;
my $MTMSN;              
my $registration;
my $inMessage= ""; 
my $outMessage = "";
my $RI;              
my $numOfMessages;


# Start GPS and retrieve time/date from GPS. Set up date and time for BeagleBone

# set pins in appropriate modes:
# Set UART 1
# Set Rx pin
`echo 20 > /sys/kernel/debug/omap_mux/uart1_rxd`;
debug("Starting main program");
debug("UART1 Rx set done....PIN 26");

# set variables:
my $UNIXTime;
my $gpsTime = "";
my $gpsDate = "";
my $status = "";
my $timeSet;
my ($sec,$min,$hour,$day,$month,$year);
my $gpsTrialNum;

START:
$gpsTrialNum = 0;
# Activate serial connection:
my $PORT = "/dev/ttyO1";

my $ob = Device::SerialPort->new($PORT) || die "Can't Open $PORT: $!";

$ob->baudrate(4800) || die "failed setting baudrate";
$ob->parity("none") || die "failed setting parity";
$ob->databits(8) || die "failed setting databits";
$ob->handshake("none") || die "failed setting handshake";
$ob->write_settings || die "no settings";
$| = 1;


open (my $GPS, '<', '$PORT')  || die "Cannot open $PORT: $_";

debug("GPS port is open, ready to receive GPS data");
while ( $serialData = <GPS> )
         {

                if ($serialData =~ m/GPRMC/)
                        {

                               # print $serialData;

                                # split gps data by coma

                                my @gps = split (/\,/,$serialData);
                                my $gps;

                                ###########################################
                                # check if GPS data is valid 
                                # Status  A - data valid,  V - data not valid

                                $status = $gps[2];
                                #$status = "V";
                                if ($status eq "A")
                                        {

                                                ##########################################
                                                # get time
                                                $gpsTime = $gps[1];
                                                my @gpsTime = split(//,$gpsTime);
                                                $hour = $gpsTime[0].$gpsTime[1];
                                                $min = $gpsTime[2].$gpsTime[3];
                                                $sec = $gpsTime[4].$gpsTime[5];
                                                $gpsTime = $hour.":".$min.":".$sec;
						                                                ###########################################
                                                # get date
                                                $gpsDate = $gps[9];
                                                my @gpsDate = split(//,$gpsDate);
                                                $day = $gpsDate[0].$gpsDate[1];
                                                $month = $gpsDate[2].$gpsDate[3];
                                                $year = $gpsDate[4].$gpsDate[5];
                                                $gpsDate = $month."/".$day."/".$year;

                                                ###########################################

                                                $timeSet = "$month"."$day"."$hour"."$min"."20"."$year"."."."$sec";
	
                                                debug("GPS status is $status \(A - fix ok\)");
                                                debug("gpsDate is $gpsDate");
                                                debug("gpsTime is $gpsTime");
                                                `date $timeSet`;
                                                debug("Computer time has been set to: $timeSet");
                                                goto AFTERTIMESET;

                                        }
                                else
                                        {
                                                $gpsTrialNum = $gpsTrialNum +1;
                                                debug("Acquiring GPS satellite .. trial number $gpsTrialNum");
                                                sleep(1);
                                                if ($gpsTrialNum >= 10)
                                                        {
                                                                goto FAILGPS;
                                                        }
                                        }

				}

                        }
undef $ob;
close (GPS);

FAILGPS:
debug("Could't acquire GPS satellite ssignal, will try again later.");
sleep(1);
goto START;
AFTERTIMESET:


# set pins in appropriate modes to communicate with satellite modem:
# Set UART 2
# Set Tx pin
`echo 1 > /sys/kernel/debug/omap_mux/spi0_d0`;
# set Rx pin
`echo 21 > /sys/kernel/debug/omap_mux/spi0_sclk`;

debug("Setting up UART2 RX22/TX21 for Iridium modem");
 
# start GPS deamon
$SIG{CHLD} = 'IGNORE';

my $kidPid = fork();

if( $kidPid )
	{
  		# I'm the parent
		debug("Forking.....");
   
	}
else
	{       # I'm the child: my child PID is zero; I don't have a child
		debug("Child process is going.");
		exec "sudo /home/ubuntu/GPS/gpsReader.pl";
	}



#`sudo /home/ubuntu/GPS/gpsReader.pl`;
debug("GPS demon started.");

# Activate serial connection:
$PORT = "/dev/ttyO2";
$ob = Device::SerialPort->new($PORT) || die "Can't Open $PORT: $!";

$ob->baudrate(19200) || die "failed setting baudrate";
$ob->parity("none") || die "failed setting parity";
$ob->databits(8) || die "failed setting databits";
$ob->handshake("none") || die "failed setting handshake";
$ob->write_settings || die "no settings";
$| = 1;

debug("Opening port for Iridium modem");

echo();			# turn the echo off
checkModem();		# check if midem is connected and working

#registrationNotification();
#checkBuffer();
#checkRI();
#checkNewMessage();
#registrationNotification();
#signalNetwork();
#sendMessage($outMessage);
#checkBuffer();
#$inMessage = readMessage();
#print "In message is: $inMessage\n\n";
#checkNewMessage();
#checkModem();
#checkBuffer();
#$inMessage = "%?FMEM";

#my $testMessage = readMessage();
#print "Message received: $testMessage\n";



##### Main routine #################
debug("Setup completed, starting main subroutine\n##############################################################\n");


while (1)
	{
		$SFQ = SFQRetrieve();
		if ($SFQ != 0)
			{
				debug("Will send message every $SFQ s");
				$outMessage = gmtime(time);
				debug("Sending message\n$outMessage");
				sendMessage($outMessage);
			
		
				for ($i = 0; $i < $SFQ ; $i++)
					{
						debug("Checking for Ring Indicator $i");
						my $RI = checkRI();
			
						if ($RI == 1 or $numOfMessages > 0 )
	
							{
								debug("Ring Indicator is $RI or Num Of Messages is $numOfMessages");
								receiveMessage();
							
							}
						else 	
							{
								debug("No new messages.");
							}	

						sleep($TBC);						
				        
					}	
			}
		else
			{
				debug("Sending telemetry not active, SFQ = 0");
				debug("Checking for Ring Indicator");
                                my $RI = checkRI();
                        
                                if ($RI == 1 or $numOfMessages > 0 )
                             		{
                                        	debug("RI is $RI and Num of messages is $numOfMessages indicate new message is waiting");
                                        	receiveMessage();

                         		}
                            	else
                         		{
                                        	debug("No new messages.");
                               		}

                            	sleep($TBC);

			}

	}





# Code the message:


#my $coded =coderMainMessage ($debug);
#print "$coded\n";

#######################################################################################################################
############################################### Subroutines ###########################################################


sub checkModem{

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
                                $MO = $array2[0];       	# Mobile originated message 0 - no, 1 - yes
                                $MOMSN = $array2[1];            # Mobile originated message sequence number
                                $MT = $array2[2];               # Terminal originated message 
                                $MTMSN = $array2[3];            # Terminal originated message sequence number

                        }
		print "MO: $MO\nMOMSN: $MOMSN\nMT: $MT\nMTMSN: $MTMSN\n\n";
        }


sub registrationNotification 
        {
        BEGININGREG:    $ob->write("AT+SBDREG?\r");
                        print "Checking registratin\n";
                sleep(1);

                $rx = $ob->read(255);

                if ($rx =~ m/SBDREG/)
                        {
                                my @array = split(':',$rx);
                                my $array;
                                $registration = $array[1];
                                $registration = substr( $registration,0,1);
                                if ($registration == 0)
                                        {
                                                $ob->write("AT+SBDREG\r");
                                                print "Will register again\n";
                                                sleep(1);
                                                $rx = $ob->read(255);
                                                if ($rx =~ m/OK/)
                                                        {
                                                                goto BEGININGREG;
                                                        }
                                        }

                        }

                print "Registration done : $registration\n";

                $ob->write("AT+SBDMTA=1\r");
                sleep(1);
                $rx = $ob->read(255);
                 if ($rx =~ m/OK/)
                        {
                             print "Notification enabled\n";
                   }


        }


sub signalNetwork{


                $ob->write("AT+CIER=1,1,1,0\r");
                debug("Checking network and signal strenght\n");
                do
                        {
                                sleep(1);
                                $rx = $ob->read(255);
                                if ($rx)
                                        {
                                                if ($rx =~ m/CIEV:1/)
                                                        {
                                                              
                                                                my @array = split(':',$rx);
                                                                my $array;
                                                                @array = split(',',$array[1]);
                                                                $network = substr($array[1], 0, 1);
                                                                if ($network  == 1)
                                                                        {
                                                                                debug("\nNetwork available\n\n");
                                                                        }
                                                        }



                                                if  ($rx =~ m/CIEV:0/)
                                                       {

                                                                my @array2 = split(':',$rx);
                                                         my $array2;
                                                                    #print $array[1];
                                                                @array2 = split(',',$array2[1]);
                                                                $sigStrenght = substr( $array2[1],0,1);
                                                                debug("Sig streght = $sigStrenght\n");

                                                        }
                                        }

                        }
                                until ($sigStrenght >2);
                                debug("Ready to communicate\n");

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
                                			$MO = $array2[0];               # Mobile originated message 0 - no, 1 - yes
                                			$MOMSN = $array2[1];            # Mobile originated message sequence number
                                			$MT = $array2[2];               # Terminal originated message 
                                			$MTMSN = $array2[3];            # Terminal originated message sequence number
                                			$RI = $array2[4];               # Ring indicator
                                			$numOfMessages = $array2[5];    # Number of messages witing
                                			$numOfMessages =~ s/\r|\n|OK//g;
                                			debug("MO: $MO\nMOMSN: $MOMSN\nMT: $MT\nMTMSN: $MTMSN\nRI: $RI\nNum of messages waiting: $numOfMessages\n\n");
						}		
				}	
		return $RI;
		}
	}



sub receiveMessage
	{
		## 
		if ($MT == 1)
			{
				debug("There is a messgae in the buffer, will process it\n");
				readMessage();
			}

		satCom();		

	}





sub   checkNewMessage 
	{
		 $ob->write("AT+SBDSX\r");
                                sleep(1);
                                $rx = $ob->read(255);
                          
				 if ($rx =~ m/SBDSX:/)
                        {

                                my @array = split(':',$rx);

                                my $Part2 = $array[1];
                                my @array2 = split(',',$Part2);
                                my $array2;
                            	
			  	$MO = $array2[0];       	# Mobile originated message 0 - no, 1 - yes
                                $MOMSN = $array2[1];            # Mobile originated message sequence number
                                $MT = $array2[2];               # Terminal originated message 
                                $MTMSN = $array2[3];            # Terminal originated message sequence number
				$RI = $array2[4];		# Ring indicator
				$numOfMessages = $array2[5];	# Number of messages witing
				$numOfMessages =~ s/\r|\n|OK//g;
				debug("MO: $MO\nMOMSN: $MOMSN\nMT: $MT\nMTMSN: $MTMSN\nRI: $RI\nNum of messages waiting: $numOfMessages\n\n");
				
			
				if ($RI == 1)
					{
						print "Within RI loop\n";

						chomp $numOfMessages;
						my $i = 0;
						for ($i = 0; $i < $numOfMessages; $i++)
							{
								debug("RI activated: getting new message\n");
								#readMessage();
											
							}
					}				

				
				 elsif($MT != 0)
                                        {
                                                debug("One MT message to be read\n");
                                                readMessage();
                                        }


                        }


	
	}



sub sendMessage 
	{	

		my $outMessage = shift;

		## Check the buffer if there is any MO messages to be send

		$ob->write("AT+SBDS\r");
                sleep(1);
                $rx = $ob->read(255);
                if ($rx =~ m/SBDS:/)
                        {
				

				my @arrayBUF  = split(/\n/,$rx);
				foreach (@arrayBUF)
					{
						if ($_ =~ m/SBDS:/)
							{
								my @array = split(':',$_);
                                				my $array;
                                				my $Part2 = $array[1];
                                				my @array2 = split(',',$Part2);
                                				my $array2;
                                				$MO = $array2[0];               # Mobile originated message 0 - no, 1 - yes
                                				$MOMSN = $array2[1];            # Mobile originated message sequence number
                                				$MT = $array2[2];               # Terminal originated message 
                                				$MTMSN = $array2[3];            # Terminal originated message sequence number
							
							}

                        		}		
			}

		if ($MO != 0)
			{
				#send a message
				debug("One message to be send from MO\n");
				satCom();	
			}
		

		## Put message into buffer

		$ob->write("AT+SBDWT=$outMessage\r");		
                sleep(1);
                $rx = $ob->read(255);
                if ($rx =~ m/OK/)
 			{
                        	
			# communicate with sattelite - cost money
				satCom();

			}
	}



sub satCom 
	{
		BEGININGSAT:
		signalNetwork();        # check the network and wait for good signal
		debug("Executing SBDIXA command\n");

		$ob->write("AT+SBDIXA\r");
		
		do
     			{
                		sleep(1);
                 		$rx = $ob->read(255);
                                debug(".$rx");
           		}
        	until ($rx =~ m/SBDIX/);
		debug("\n");
                 
		my @arrayIX  = split(/\n/,$rx);

		foreach (@arrayIX)
			{
				if ($_ =~ m/SBDIX:/)
  					{
						my @array6 = split(':',$_);
 						my $array6;
						my $Part26 = $array6[1];
  						my @array26 = split(',',$Part26);
      						my $array26;
     						$MO = $array26[0];               # 0 - message transfered, 
  						$MOMSN = $array26[1];            # Mobile originated message sequence number
        					$MT = $array26[2];               # 0-no messages to be received, 1-Succesfully recvd, 2-error  
 						$MTMSN = $array26[3];           # Mobile terminated message sequence number		
						$numOfMessages = $array26[5];   # number of messages to be transfered from GSS
						$numOfMessages = substr($numOfMessages, 0, 3);
						$numOfMessages =~ s/\r|\n//g;
					}
			}		

   		debug("MO: $MO, MOMSN: $MOMSN, MT: $MT, MTMSN: $MTMSN, numOfMessages: $numOfMessages\n");

   		if ($MO == 0)   # MO=0 - transfered ok, MO=1 
				                              
                  	{
         			$ob->write("AT+SBDD0\r");
             			sleep(1);
              			$rx = $ob->read(255);
              			if ($rx =~ m /0/)
       					{
                           			debug("Message sent and MO buffer cleaned\n");
                        		}
    			}
		elsif($MO == 17 or $MO == 18 or $MO == 13 or $MO == 10 or $MO == 35)			# gataway not respondng
			{
				goto BEGININGSAT;
			}
		elsif($MO == 18)	# connection lost
			{
				goto BEGININGSAT;
			}

 		if ($MT == 1)
        		{
                		debug("There is a MT in the buffer\n");
                  		$inMessage = readMessage();	
				processMessage();
			}
		if ($numOfMessages > 1)
			{
				debug("More mesages waiting at GSS, will get them.\n");
				satCom();	
			}	
    	}





sub readMessage {

                        $ob->write("AT+SBDRT\r");			# reading buffer                  
                        sleep(1);
                        $rx = $ob->read(255);
                        my @array = split(':',$rx);
                        my $array;
                        $rx = $array[1];
                        $rx =~ s/^\s+//; #remove leading spaces
                        $rx =~ s/\s+$//; #remove trailing spaces
                        my $okRead = substr($rx, -2);
                        $inMessage = substr($rx, 0, -2);
			
		
			$ob->write("AT+SBDD1\r");			# cleaning buffer
			sleep(1);
			$rx = $ob->read(255);
			
			my @cleanBuff = split(/\n/,$rx);
			my $cleanBuff;
			if ($cleanBuff[1] == 0)
				{
					debug("Buffer cleaned succesfully\n");
				}
			debug("Received message is: $inMessage\n");
			return $inMessage;

	}


sub processMessage 	
	{
		if ($inMessage =~ m/%?SMN/i)
           		{
           			SMN();
      			}
    		elsif ($inMessage =~ /%?SFQ/i)
          		{
                  		chomp $inMessage;
                  		my @frq = split ('Q',$inMessage);
                     		my $frq;
                     		SFQ($frq[1]);
            		}
    		
		elsif ($inMessage =~ /%?LTQ/i)
                	{
                       		my @frq = split ('Q',$inMessage);
                             	my $frq;
                            	LTQ($frq[1]);
                  	}

 		elsif ($inMessage =~ m/%?GPS/i)
                    	{
                               	GPS();
                      	}
     		elsif ($inMessage =~ /%?BTQ/i)
          		{
                   		my @frq = split ('Q',$inMessage);
                       		my $frq;
                            	BTQ($frq[1]);
             		}
    		elsif ($inMessage =~ /%?AAD/i)
                       	{
                      		my @dis = split ('=',$inMessage);
                     		my $dis;
                   		ANCHORALARM($dis[1]);
             		}
           	elsif ($inMessage =~ m/%?CON/i)
              		{
                     		CONTACT();
           		}
     		elsif ($inMessage =~ m/%?SCH/i)
             		{
                       		sysCheck();
            		}
       		elsif ($inMessage =~ m/%?REBOOT/i)
              		{
                       		REBOOT($debug);
                     	}
       		elsif ($inMessage =~ m/%?FMEM/i)
             		{
                       		FMEM($debug);
       			}
		elsif ($inMessage =~ m/%?ALARM/i)
                    	{
                        	ALARM();
                    	}
         	elsif ($inMessage =~ m/%?SST/i)
                 	{
                        	sysTIME();
                       	}
		 elsif ($inMessage =~ m/%?STOP/i)
                        {
                                STOP();
                        }



              	else
                   	{
                            	mailIn($inMessage);
               		}

           	$inMessage = "";

	}



sub echo 	
	{
		 $ob->write("ATEn0\r");
		 debug("Turning echo off");
		 sleep(1);
		  $rx = $ob->read(255);
		 # print "Echo off results: $rx\n";
	}



sub coderMainMessage{
	
my $UNIXtime; 
my $lat;
my $NS;
my $lon;
my $EW;
my $COG;
my $SOG;
my $barPres;
my $presChange3h;
my $presChange6h;
my $tempCPU;
my $tempOUT;
my $tempIN;
my $tempENG;
my $temp2;
my $volt1;
my $volt2;
my $volt3;
my $meanX;
my $sdX;
my $maxX;
my $minX;
my $meanY;
my $sdY;
my $maxY;
my $minY;
my $meanZ;
my $sdZ;
my $maxZ;
my $minZ;
my $light;
my $lightSensor = "ain4";
my $volt1AIN = "ain1";
my $volt2AIN = "ain2";
my $volt3AIN = "ain3";

## start AIN on Ubuntu

`sudo modprobe ti_tscadc`; 

## get data from GPS archives
my $gpsCurr = '/home/ubuntu/Data/gps.dat';	
open GPS, "$gpsCurr" or die $!;
my @lines = <GPS>;	
my $lines;		
	foreach(@lines)
		{
					
			if ($_ =~ m/UNIXTime/)
				{
					my @UNIX = split(/=/,$_);
					my $UNIX;
					$UNIXtime =   $UNIX[1];
					chomp $UNIXtime;
					# remove first 2 numbers from UNIX time:
					$UNIXtime =~ s/.//;
					$UNIXtime =~ s/.//;

				}
			if ($_ =~ m/Lat/)
				{
					my @Lat = split(/=/,$_);
					my $Lat;
					$lat =   $Lat[1];
					chomp $lat;
				}
			if ($_ =~ m/Lon/)
				{
					my @Lon = split(/=/,$_);
					my $Lon;
					$lon =   $Lon[1];
					chomp $lon;
				}
			if ($_ =~ m/COG/)
				{
					my @COG = split(/=/,$_);
					$COG =   $COG[1];
					chomp $COG;
				}
			
				if ($_ =~ m/SOG/)
				{
					my @SOG = split(/=/,$_);
					$SOG =   $SOG[1];
					chomp $SOG;
				}	
			}
	
		close(GPS);


if ( $lat =~ m/-/)
        {
                $NS = "-";
        }
else {$NS = "+"};

$lat =~ s/-//;                                   # remove "-" in front
$lat = sprintf("%08.5f", $lat);
$lat =~ s/\.//;                                  # remove "period"
debug("Lat: $lat\n");

if ( $lon =~ m/-/)
        {
                $EW = "-";
        }
else {$EW = "+"};

$lon =~ s/-//;                                    # remove "-" in front
$lon = sprintf("%09.5f", $lon);
$lon =~ s/\.//;                                   # remove "period"
debug("Lon: $lon\n");


$SOG = $SOG * 10;
$SOG = sprintf("%03d", $SOG);
$COG = sprintf("%03d", $COG);
debug("SOG: $SOG\n");
debug("COG: $COG\n");	
	
## Get data from Barometic Pressure Archives		

my $presCurr = '/home/ubuntu/Data/pressure.dat';	
open PRESS, "$presCurr" or die $!;
my @presLines = <PRESS>;
my $presLines;
	
$barPres = pop@presLines;
chomp $barPres;

$barPres = $barPres * 10;
$barPres = sprintf("%05d", $barPres);

my $pres3h = $presLines[20] * 10;
$pres3h = sprintf("%05d", $pres3h);
$presChange3h = $barPres - $pres3h;
$presChange3h = sprintf("%03d", $presChange3h);

my $pres6h = $presLines[17] * 10;
$pres6h = sprintf("%05d", $pres6h);
$presChange6h = $barPres - $pres6h;
$presChange6h = sprintf("%03d", $presChange6h);

close(PRESS);	
debug("Barometric pressure: $barPres\n");
debug("PresChange3h: $presChange3h\n");	
debug("PresChange6h: $presChange6h\n");

## get temperatures

# CPU sensor:
my $sensorTempCPU ="10-0008026a7a2c";                # sensor ID

my $fileTempCPU = "\/sys\/bus\/w1\/devices/$sensorTempCPU\/w1_slave";

if ( -e $fileTempCPU)                                   # check if sensor is connected
        {
                $tempCPU =  W1Temp($sensorTempCPU);
                $tempCPU = sprintf("%.1f", $tempCPU);
             #   print "TempCPU is $tempCPU\n";
		$tempCPU = $tempCPU * 10;
		$tempCPU = sprintf("%03d", $tempCPU);

        }
else    {
                $tempCPU = "000";
              #  print "TempCPU not available\n";
        }
debug("tempCPU: $tempCPU\n");

# OUT sensor:
my $sensorTempOUT ="10-0008026a8f55";                # sensor ID

my $fileTempOUT = "\/sys\/bus\/w1\/devices/$sensorTempOUT\/w1_slave";

if ( -e $fileTempOUT)                                   # check if sensor is connected
        {
                $tempOUT =  W1Temp($sensorTempOUT);
                $tempOUT = sprintf("%.1f", $tempOUT);
               # print "TempOUT is $tempOUT\n";
		$tempOUT = $tempOUT * 10;
		$tempOUT = sprintf("%03d", $tempOUT);
        }
else    {
                $tempOUT = "000";
               # print "TempOUT not available\n";
        }
debug("tempOUT: $tempOUT\n");


## Temp Inside sensor:

my $sensorTempIN ="10-00";                # sensor ID

my $fileTempIN = "\/sys\/bus\/w1\/devices/$sensorTempIN\/w1_slave";

if ( -e $fileTempIN)                                   # check if sensor is connected
        {
                $tempIN =  W1Temp($sensorTempIN);
                $tempIN = sprintf("%.1f", $tempIN);
              #  print "TempIN is $tempIN\n";
		$tempIN = $tempIN * 10;
		$tempIN = sprintf("%03d", $tempIN);


        }
else    {
                $tempIN = "000";
              #  print "TempIN not available\n";
        }
debug("tempIN: $tempIN\n");

## Temp Engine sensor:

my $sensorTempENG ="10-00";                # sensor ID

my $fileTempENG = "\/sys\/bus\/w1\/devices/$sensorTempENG\/w1_slave";

if ( -e $fileTempENG)                                   # check if sensor is connected
        {
                $tempENG =  W1Temp($sensorTempENG);
                $tempENG = sprintf("%.1f", $tempENG);
              #  print "TempENG is $tempENG\n";
                $tempENG = $tempENG * 10;
                $tempENG = sprintf("%04d", $tempENG);


        }
else    {
                $tempENG = "0000";
             #   print "TempENG not available\n";
        }
debug("tempENG: $tempENG\n");



## Temp 2 sensor: 

my $sensorTemp2 ="10-00";                # sensor ID

my $fileTemp2 = "\/sys\/bus\/w1\/devices/$sensorTemp2\/w1_slave";

if ( -e $fileTemp2)                                   # check if sensor is connected
        {
                $temp2 =  W1Temp($sensorTemp2);
                $temp2 = sprintf("%.1f", $temp2);
              #  print "Temp2 is $temp2\n";
                $temp2 = $temp2 * 10;
                $temp2 = sprintf("%03d", $temp2);


        }
else    {
                $temp2 = "000";
             #   print "Temp2 not available\n";
        }

debug("temp2: $temp2\n");
## get volt1 reading 

$volt1 = getAIN($volt1AIN);
$volt1 = $volt1 * 10;
$volt1 = sprintf("%03d", $volt1);
debug("volt1: $volt1\n");

## get volt2 reading 
$volt2 = getAIN($volt2AIN);
$volt2 = $volt2 * 10;
$volt2 = sprintf("%03d", $volt2);
debug("volt2: $volt2\n");


## get volt3 reading
$volt3 = getAIN($volt3AIN);
$volt3 = $volt3 * 10;
$volt3 = sprintf("%03d", $volt3);
debug("volt3: $volt3\n");


## Get accelerometer data from accelerometerCur.dat


my $accelerometerCur = '/home/ubuntu/Data/accelerometerCur.dat';	
open ACC, "$accelerometerCur" or die $!;
my @accLines = <ACC>;		
	foreach(@accLines)
		{
					
			if ($_ =~ m/meanX=/)
				{
					my @meanX = split(/=/,$_);
					$meanX =   $meanX[1];
					$meanX = sprintf ("%04d", $meanX);
					chomp $meanX;
					debug ("meanX : $meanX\n");
				}
			if ($_ =~ m/sdX=/)
				{
					my @sdX = split(/=/,$_);
					$sdX =   $sdX[1];
					$sdX = sprintf ("%04d", $sdX);
					chomp $sdX;
					debug("sdX : $sdX\n");
				}	
			if ($_ =~ m/maxX=/)
				{
					my @maxX = split(/=/,$_);
					$maxX =   $maxX[1];
					$maxX = sprintf ("%04d", $maxX);
					chomp $maxX;
					debug("maxX : $maxX\n");
				}		
			if ($_ =~ m/minX=/)
				{
					my @minX = split(/=/,$_);
					$minX =   $minX[1];
					$minX = sprintf ("%04d", $minX);
					chomp $minX;
					debug("minX : $minX\n");
				}		
				
			if ($_ =~ m/meanY=/)
				{
					my @meanY = split(/=/,$_);
					$meanY =   $meanY[1];
					$meanY = sprintf ("%04d", $meanY);
					chomp $meanY;
					debug("meanY : $meanY\n");
				}
			if ($_ =~ m/sdY=/)
				{
					my @sdY = split(/=/,$_);
					$sdY =   $sdY[1];
					$sdY = sprintf ("%04d", $sdY);
					chomp $sdY;
					debug("sdY : $sdY\n");
				}	
			if ($_ =~ m/maxY=/)
				{
					my @maxY = split(/=/,$_);
					$maxY =   $maxY[1];
					$maxY = sprintf ("%04d", $maxY);
					chomp $maxY;
					debug("maxY : $maxY\n");
				}		
			if ($_ =~ m/minY=/)
				{
					my @minY = split(/=/,$_);
					$minY =   $minY[1];
					$minY = sprintf ("%04d", $minY);
					chomp $minY;
					debug("minY : $minY\n");
				}	
				
			if ($_ =~ m/meanZ=/)
				{
					my @meanZ = split(/=/,$_);
					$meanZ =   $meanZ[1];
					$meanZ = sprintf ("%04d", $meanZ);
					chomp $meanZ;
					debug("meanZ : $meanZ\n");
				}
			if ($_ =~ m/sdZ=/)
				{
					my @sdZ = split(/=/,$_);
					$sdZ =   $sdZ[1];
					$sdZ = sprintf ("%04d", $sdZ);
					chomp $sdZ;
					debug("sdZ : $sdZ\n");
				}	
			if ($_ =~ m/maxZ=/)
				{
					my @maxZ = split(/=/,$_);
					$maxZ =   $maxZ[1];
					$maxZ = sprintf ("%04d", $maxZ);
					chomp $maxZ;
					debug("maxZ : $maxZ\n");
				}		
			if ($_ =~ m/minZ=/)
				{
					my @minZ = split(/=/,$_);
					$minZ =   $minZ[1];
					$minZ = sprintf ("%04d", $minZ);
					chomp $minZ;
					debug("minZ : $minZ\n");
				}			
		}


## Get data from light sensor

$light = getAIN($lightSensor);
$light = sprintf("%02d", $light);
debug("Light :$light\n");


my $coded = "%"."$UNIXtime"."$NS"."$lat"."$EW"."$lon"."$COG"."$SOG"."$barPres"."$presChange3h"."$presChange6h"."$tempCPU"."$tempOUT"."$tempIN"."$tempENG"."$temp2"."$volt1"."$volt2".
"$volt3"."$meanX"."$sdX"."$meanY"."$sdY"."$meanZ"."$sdZ"."$light"."%";


my $codedLength =length($coded);


debug("\nNumber of bytes in coded message $codedLength\n\n");
return $coded;


}

sub getAIN 
        {
                my $ain = shift;
                my @array;
                my $numEl;

                do
                        {
                                open (FH, "\/sys\/devices\/platform\/omap\/tsc\/$ain") or die $!;
                                select (undef,undef,undef,0.01);
                                while (<FH>)
                                        {
                                                chomp $_;
                                                $_ =~ s/\0//g;
                                                #print "Value is $_\n"; 
                                                push (@array,"$_");
                                        }

                                $numEl = @array;
                                close(FH);
                        } until  ($numEl == 12);

                shift @array;
                pop @array;
                my $total = 0;
                ($total+=$_) for @array;
                my $value = $total / 10;

                $value = $value/40;
                $value = floor($value);
                return $value;
        }





sub SFQRetrieve 
        {

                my $file = '/home/ubuntu/Config/config.txt';
                open INFO, "$file" or die $!;
                my @lines = <INFO>;
                my $lines;

                foreach(@lines)
                        {

                                        if ($_ =~ m/SFQ/)
                                                {
                                                        my @frq = split(/=/,$_);
                                                        my $frq;
                                                        my $frqClean = $frq[1];
                                                        $frqClean =~  s/\r\n//;
                                                        return  $frqClean;
                                                }
                        }

                close(INFO);
        }


sub SFQChange 
        {
                my $newFrq = shift;
                my $file = '/home/ubuntu/Config/config.txt';
                open INFO, "$file" or die $!;
                my @lines = <INFO>;
                my $lines;

                foreach(@lines)
                        {

                                        if ($_ =~ m/SFQ/)
                                                {
                                                        my @frq = split(/=/,$_);
                                                        my $frq;
                                                        $frq[1] = $newFrq;
                                                        $frq[1] =~  s/\r\n//;
                                                        $_ = $frq[0]."=".$frq[1]."\n";

                                                }
                        }
                close(INFO);

            open INFO, ">$file" or die $!;
                foreach ( @lines )
                        {
                                print INFO $_;
                        }
                close INFO;

        }




sub SMN {
        print "Sending standart message now \n";
}

sub SFQ {
        my $frq = shift;
	SFQChange($frq);
        print "Will send message q $frq h\n";
}

sub GPS {
                        print "Sending GPS data now\n";
}

sub BTQ {
        my $frq = shift;

        print "Will send barometers data q $frq h\n";
}

sub LTQ {
        my $frq = shift;

        print "Will send light  data q $frq h\n";
}


sub REBOOT
	 {
        	debug("Rebooting now !!\n");
		`sudo reboot now`;	
	}


sub FMEM {
	        
	debug("Checking free memory  !!\n");
        my $memory;
                {
                        local(*PS, $/);
                        open(PS,"free -t -m |");
                        $memory = <PS>;
                }

my @arrMemory = split (/\n/,$memory);
my $arrMemory;

my @freeMemory = split (/ /,$arrMemory[4]);

my $freememory;
my $totMem = $freeMemory[9];
my $usedMem = $freeMemory[18];
my $freeMem = $freeMemory[26];
my $memMessage = "TM:$totMem UM:$usedMem FM:$freeMem";
debug("Mem data: $memMessage\n");
}


sub ALARM {
        print "Alarm !!\n";
}


sub rcvMessage 
                {
                        my $rcvMessage = shift;
                        print "Received message: $rcvMessage\n";
                         }

sub sysCheck 

        {
                print "Runing system check\n";
        }

sub sysTIME 
        {
                my $time = gmtime();
                debug("System time is $time\n");
        }


sub CONTACT 
        {
                print "Contact request received\n";
        }


sub ANCHORALARM 
        {
                my $dis = shift;
                print "Setting anchor alarm on $dis m\n";
        }

sub STOP 
	{
		debug("STop sending data received\n");
		SFQChange(0);
	}



sub mailIn
	{
		my $mailIn = shift;
		print "Mail in received: $mailIn \n\n";
                my $time = time();
                my $file = "/home/ubuntu/Mail/newIn/$time";               
                open MAILFILE, ">$file" or die $!;
                print MAILFILE $mailIn;
                close MAILFILE;            
	}


sub debug 
        {
                my $text = shift;
                if ($debug == 2)
                        {
                                open LOG, '>>/home/ubuntu/Log/main.log' or die "Can't write to /home/ubuntu/Log/main.log: $!";
                                select LOG;
                                my $time = gmtime();
                                my @arrayTime = split(/ /,$time);
                                my $arrayTime;
                                $time = "$arrayTime[1]"."$arrayTime[2]"." "."$arrayTime[3]";

                                print "$time: $text\n";
                                select STDOUT;
                                close (LOG);
                        }
                if ($debug == 1)
                        {
                                my $time = gmtime();
                                my @arrayTime = split(/ /,$time);
                                my $arrayTime;
                                $time = "$arrayTime[1]"."$arrayTime[2]"." "."$arrayTime[3]";

                                print "$time: $text\n";
                        }

        }




