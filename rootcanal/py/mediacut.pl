#!/usr/bin/env perl

#/* ***** BEGIN LICENSE BLOCK *****
# *    Copyright 2002 Michel Jacobson jacobson@idf.ext.jussieu.fr
# *
# *    This program is free software; you can redistribute it and/or modify
# *    it under the terms of the GNU General Public License as published by
# *    the Free Software Foundation; either version 2 of the License, or
# *    (at your option) any later version.
# *
# *    This program is distributed in the hope that it will be useful,
# *    but WITHOUT ANY WARRANTY; without even the implied warranty of
# *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# *    GNU General Public License for more details.
# *
# *    You should have received a copy of the GNU General Public License
# *    along with this program; if not, write to the Free Software
# *    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
# * ***** END LICENSE BLOCK ***** */
use CGI;
use CGI::Carp qw/fatalsToBrowser/;


$query = new CGI;

# CGI for cutting a peace of data inside a media file (for now only mp3 and PCM/wav) and send it
# to the client.
# TODO: doing the same thing with .aif and .avi files
# USAGE: http://localhost/cgi-bin/audiocut.pl?file=a.wav&start=0.0000&end=4.5400
# param file:  location of the media file from mypath variable
#       start: start time expressed in sec.millisec
#       end:   end time expressed in sec.millisec
#
# Put the mypath variable to the directory where you store your media files
#my $mypath = "/Library/WebServer/Documents/sound/";
#my $mypath = "/Library/WebServer/Documents/sound/mp3/";
my $mypath = "/home/stedt/public_html/mp3/";

my $file = $query->param('file');
my $from = $query->param('start');
my $to = $query->param('end');

my   $fileName 	= "$mypath$file";
sysopen(AUDIOFILE, $fileName, O_RDONLY) 			|| die $!;
binmode(AUDIOFILE);
binmode(STDOUT);
if ($fileName =~ /\.mp3$/) {
	#print $query->header(-type=>'text/text', -expires=>'now');
	print $query->header(-type=>'audio/mpeg', -expires=>'now');
	my $what = "";
	my $nbLu = read(AUDIOFILE, $what, 4);
	my $framesize = readHeader($what, 'frameSize');
	my $samplerate = readHeader($what, 'sampleRate');
	my $FROM = ($samplerate*$from)/$framesize ;
	my $TO = ($samplerate*$to)/$framesize;

	my $compteur = 0;
	while ($nbLu != 0) {
		$compteur++;
		my $taille = readHeader($what, 'length');
		seek(AUDIOFILE, -4, 1);
		$nnn = read(AUDIOFILE, $zzz, $taille);
		if (($compteur >= $FROM) && ($compteur <= $TO)){
			print $zzz;
		}
		if ($compteur > $TO) {
			$nbLu = 0;
		} else {
			$nbLu = read(AUDIOFILE, $what, 4);
		}
	}
} elsif ($fileName =~/\.wav$/) {
	print $query->header(-type=>'audio/wav', -expires=>'now');

	#-------------------------------------------->the RIFF chunk
	#                        # constante 'RIFF'
	my $size            = 0; # size of file -8
	#                        # constante 'WAVE'
	#-------------------------------------------->the FORMAT chunk
	#                        # constante 'fmt '
	my $formatChunkSize = 0; # 16 si PCM
	my $audioFormat     = "";# PCM: si c'est autre chose, on ne sait pas traiter
	my $channels        = 0; # 1=mono, 2=stereo
	my $sampleRate      = 0; # par ex 44.100 Hz
	my $byteRate        = 0; # sampleRate * channels * sampleSize/8
	my $nbBytes         = 0; # par ex 2 bytes
	my $sampleSize      = 0; # par ex 16 bits
	#-------------------------------------------->the DATA chunk
	#                        # constante 'data'
	my $lenthOfdata     = 0; # NumSamples * channels * sampleSize/8

	my $what = "";
	my $nbLu = "";
	#-------------------------------------------->the RIFF chunk
	$nbLu = read(AUDIOFILE, $what, 4);
	if (!(($nbLu == 4) && ($what eq 'RIFF')))                              {exit}
	$nbLu = read(AUDIOFILE, $what, 4);
	if ($nbLu == 4) {$size = pack("V1", $what)}                       else {exit}
	$nbLu = read(AUDIOFILE, $what, 4);
	if (!(($nbLu == 4) && ($what eq 'WAVE')))                              {exit}
	#-------------------------------------------->the FORMAT chunk
	$nbLu = read(AUDIOFILE, $what, 4);
	if (!(($nbLu == 4) && ($what eq 'fmt ')))                              {exit}
	$nbLu = read(AUDIOFILE, $what, 4);
	if ($nbLu == 4) {$formatChunkSize = pack("V1", $what)}            else {exit}
	$nbLu = read(AUDIOFILE, $what, 2);
	if (($nbLu == 2) && ($what eq "\x01\x00")) {$audioFormat = "PCM"} else {exit}
	$nbLu = read(AUDIOFILE, $what, 2);
	if ($nbLu == 2) {$channels = unpack("v1", $what)}                 else {exit}
	$nbLu = read(AUDIOFILE, $what, 4);
	if ($nbLu == 4) {$sampleRate = unpack("V1",$what)}                else {exit}
	$nbLu = read(AUDIOFILE, $what, 4);
	if ($nbLu == 4) {$byteRate = unpack("V1",$what)}                  else {exit}
	$nbLu = read(AUDIOFILE, $what, 2);
	if ($nbLu == 2) {$nbBytes = unpack("v1",$what)}                   else {exit}
	$nbLu = read(AUDIOFILE, $what, 2);
	if ($nbLu == 2) {$sampleSize = unpack("v1",$what)}                else {exit}
	#-------------------------------------------->the DATA chunk
	$nbLu = read(AUDIOFILE, $what, 4);
	if (!(($nbLu == 4) && ($what eq 'data')))                              {exit}
	$nbLu = read(AUDIOFILE, $what, 4);
	if ($nbLu == 4)  {$lenthOfdata = unpack("V1",$what)}              else {exit}
	#-------------------------------------------->the DATA

	#print "size:             $size             \n";
	#print "formatChunkSize:  $formatChunkSize  \n";
	#print "audioFormat:      $audioFormat      \n";
	#print "channels:         $channels         \n";
	#print "sampleRate:       $sampleRate       \n";
	#print "byteRate:         $byteRate         \n";
	#print "nbBytes:          $nbBytes          \n";
	#print "sampleSize:       $sampleSize       \n";
	#print "lenthOfdata:      $lenthOfdata      \n";

	my $FROM = ($byteRate*$from);
	my $modFrom = $FROM % $sampleSize;
	$FROM += $modFrom;

	my $TO   = ($byteRate*$to);
	my $modTo = $TO % $sampleSize;
	$TO += $modTO;
	my $SIZE = $TO - $FROM;

	$size = pack("V1", ($SIZE)+44-8);
	$lenthOfdata = pack("V1", $SIZE);

	print 'RIFF'.$size.'WAVEfmt ';
	seek(AUDIOFILE, 16, 0);
	$nbLu = read(AUDIOFILE, $what, 40-16);
	print $what;
	print $lenthOfdata;

	seek(AUDIOFILE, $FROM+44, 0);
	$nbLu = read(AUDIOFILE, $what, $SIZE);
	print $what;
} else {
	print $query->header(-type=>'text/htm', -expires=>'now');
	print '<html><head></head><body>Impossible de lire ce type de fichier: '.$file.'</body></html>';
}

close (AUDIOFILE);
#-----------------------------------------------------------------------------
sub readHeader {
    		my($x, $quoi) = @_;
    		
	my $oct1 = ord(substr($x, 0, 1));
	my $oct2 = ord(substr($x, 1, 1));
	my $oct3 = ord(substr($x, 2, 1));
	my $oct4 = ord(substr($x, 3, 1));
	my @header = ();

	for ($i=7;$i>=0;$i--) {
		push(@header, &test($oct1,$i));
	}
	for ($i=7;$i>=0;$i--) {
		push(@header, &test($oct2,$i));
	}
	for ($i=7;$i>=0;$i--) {
		push(@header, &test($oct3,$i));
	}
	for ($i=7;$i>=0;$i--) {
		push(@header, &test($oct4,$i));
	}
	my $FrameSync 		= join("",@header[0,1,2,3,4,5,6,7,8,9,10]);
	my $Version 		= join("",@header[11,12]);
	my $Layer 		= join("", @header[13,14]);
	my $protectionBit 	= @header[15];
	my $BitRate 		= join("", @header[16,17,18,19]);
	my $SampleRate		= join("", @header[20,21]);
	my $Padding		= join("", @header[22]);
	my @H = @header[23];
	my @I = @header[24,25];
	my @J = @header[26,27];
	my @K = @header[28];
	my @L = @header[29];
	my @M = @header[30,31];

	if ($FrameSync eq "11111111111") {
		$FrameSync = "OK";
	} else {
		$FrameSync = "not OK";
	}

	if ($Version eq "00") {
		$Version = "2.5";
	} elsif ($Version eq "01") {
		$Version = "reserved";
	} elsif ($Version eq "10") {
		$Version = "2";
	} elsif ($Version eq "11") {
		$Version = "1";
	}

	if ($Layer eq "00") {
		$Layer = "reserved";
	} elsif ($Layer eq "01") {
		$Layer = "III";
	} elsif ($Layer eq "10") {
		$Layer = "II";
	} elsif ($Layer eq "11") {
		$Layer = "I";
	}

	if ($protectionBit eq "0") {
		$protectionBit = "Protected by CRC (16bit crc follows header)";
	} elsif ($protectionBit eq "1") {
		$protectionBit = "Not Protected";
	}

	if ($BitRate eq "0000") {
		$BitRate = "free";
	} elsif ($BitRate eq "0001") {
		if (($Version eq "1") && ($Layer eq "I")) {
			$BitRate = "32";
		} elsif (($Version eq "1") && ($Layer eq "II")) {
			$BitRate = "32";
		} elsif (($Version eq "1") && ($Layer eq "III")) {
			$BitRate = "32";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && ($Layer eq "I")) {
			$BitRate = "32";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && (($Layer eq "II") || ($Layer eq "III"))) {
			$BitRate = "8";
		}
	} elsif ($BitRate eq "0010") {
		if (($Version eq "1") && ($Layer eq "I")) {
			$BitRate = "64";
		} elsif (($Version eq "1") && ($Layer eq "II")) {
			$BitRate = "48";
		} elsif (($Version eq "1") && ($Layer eq "III")) {
			$BitRate = "40";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && ($Layer eq "I")) {
			$BitRate = "48";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && (($Layer eq "II") || ($Layer eq "III"))) {
			$BitRate = "16";
		}
	} elsif ($BitRate eq "0011") {
		if (($Version eq "1") && ($Layer eq "I")) {
			$BitRate = "96";
		} elsif (($Version eq "1") && ($Layer eq "II")) {
			$BitRate = "56";
		} elsif (($Version eq "1") && ($Layer eq "III")) {
			$BitRate = "48";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && ($Layer eq "I")) {
			$BitRate = "56";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && (($Layer eq "II") || ($Layer eq "III"))) {
			$BitRate = "24";
		}
	} elsif ($BitRate eq "0100") {
		if (($Version eq "1") && ($Layer eq "I")) {
			$BitRate = "128";
		} elsif (($Version eq "1") && ($Layer eq "II")) {
			$BitRate = "64";
		} elsif (($Version eq "1") && ($Layer eq "III")) {
			$BitRate = "56";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && ($Layer eq "I")) {
			$BitRate = "64";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && (($Layer eq "II") || ($Layer eq "III"))) {
			$BitRate = "32";
		}
	} elsif ($BitRate eq "0101") {
		if (($Version eq "1") && ($Layer eq "I")) {
			$BitRate = "160";
		} elsif (($Version eq "1") && ($Layer eq "II")) {
			$BitRate = "80";
		} elsif (($Version eq "1") && ($Layer eq "III")) {
			$BitRate = "64";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && ($Layer eq "I")) {
			$BitRate = "80";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && (($Layer eq "II") || ($Layer eq "III"))) {
			$BitRate = "40";
		}
	} elsif ($BitRate eq "0110") {
		if (($Version eq "1") && ($Layer eq "I")) {
			$BitRate = "192";
		} elsif (($Version eq "1") && ($Layer eq "II")) {
			$BitRate = "96";
		} elsif (($Version eq "1") && ($Layer eq "III")) {
			$BitRate = "80";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && ($Layer eq "I")) {
			$BitRate = "96";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && (($Layer eq "II") || ($Layer eq "III"))) {
			$BitRate = "48";
		}
	} elsif ($BitRate eq "0111") {
		if (($Version eq "1") && ($Layer eq "I")) {
			$BitRate = "224";
		} elsif (($Version eq "1") && ($Layer eq "II")) {
			$BitRate = "112";
		} elsif (($Version eq "1") && ($Layer eq "III")) {
			$BitRate = "96";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && ($Layer eq "I")) {
			$BitRate = "112";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && (($Layer eq "II") || ($Layer eq "III"))) {
			$BitRate = "856";
		}
	} elsif ($BitRate eq "1000") {
		if (($Version eq "1") && ($Layer eq "I")) {
			$BitRate = "256";
		} elsif (($Version eq "1") && ($Layer eq "II")) {
			$BitRate = "128";
		} elsif (($Version eq "1") && ($Layer eq "III")) {
			$BitRate = "112";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && ($Layer eq "I")) {
			$BitRate = "128";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && (($Layer eq "II") || ($Layer eq "III"))) {
			$BitRate = "64";
		}
	} elsif ($BitRate eq "1001") {
		if (($Version eq "1") && ($Layer eq "I")) {
			$BitRate = "288";
		} elsif (($Version eq "1") && ($Layer eq "II")) {
			$BitRate = "160";
		} elsif (($Version eq "1") && ($Layer eq "III")) {
			$BitRate = "128";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && ($Layer eq "I")) {
			$BitRate = "144";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && (($Layer eq "II") || ($Layer eq "III"))) {
			$BitRate = "80";
		}
	} elsif ($BitRate eq "1010") {
		if (($Version eq "1") && ($Layer eq "I")) {
			$BitRate = "320";
		} elsif (($Version eq "1") && ($Layer eq "II")) {
			$BitRate = "192";
		} elsif (($Version eq "1") && ($Layer eq "III")) {
			$BitRate = "160";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && ($Layer eq "I")) {
			$BitRate = "160";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && (($Layer eq "II") || ($Layer eq "III"))) {
			$BitRate = "96";
		}
	} elsif ($BitRate eq "1011") {
		if (($Version eq "1") && ($Layer eq "I")) {
			$BitRate = "352";
		} elsif (($Version eq "1") && ($Layer eq "II")) {
			$BitRate = "224";
		} elsif (($Version eq "1") && ($Layer eq "III")) {
			$BitRate = "192";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && ($Layer eq "I")) {
			$BitRate = "176";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && (($Layer eq "II") || ($Layer eq "III"))) {
			$BitRate = "112";
		}
	} elsif ($BitRate eq "1100") {
		if (($Version eq "1") && ($Layer eq "I")) {
			$BitRate = "384";
		} elsif (($Version eq "1") && ($Layer eq "II")) {
			$BitRate = "256";
		} elsif (($Version eq "1") && ($Layer eq "III")) {
			$BitRate = "224";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && ($Layer eq "I")) {
			$BitRate = "192";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && (($Layer eq "II") || ($Layer eq "III"))) {
			$BitRate = "128";
		}
	} elsif ($BitRate eq "1101") {
		if (($Version eq "1") && ($Layer eq "I")) {
			$BitRate = "416";
		} elsif (($Version eq "1") && ($Layer eq "II")) {
			$BitRate = "320";
		} elsif (($Version eq "1") && ($Layer eq "III")) {
			$BitRate = "256";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && ($Layer eq "I")) {
			$BitRate = "224";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && (($Layer eq "II") || ($Layer eq "III"))) {
			$BitRate = "144";
		}
	} elsif ($BitRate eq "1110") {
		if (($Version eq "1") && ($Layer eq "I")) {
			$BitRate = "448";
		} elsif (($Version eq "1") && ($Layer eq "II")) {
			$BitRate = "384";
		} elsif (($Version eq "1") && ($Layer eq "III")) {
			$BitRate = "320";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && ($Layer eq "I")) {
			$BitRate = "256";
		} elsif ((($Version eq "2") || ($Version eq "2.5")) && (($Layer eq "II") || ($Layer eq "III"))) {
			$BitRate = "160";
		}
	} elsif ($BitRate eq "1111") {
		$BitRate = "bad";
	}

	if ($SampleRate eq "00") {
		if ($Version eq "1") {
			$SampleRate = "44100";
		} elsif ($Version eq "2") {
			$SampleRate = "22050";
		} elsif ($Version eq "2.5") {
			$SampleRate = "11025";
		}
	} elsif ($SampleRate eq "01") {
		if ($Version eq "1") {
			$SampleRate = "48000";
		} elsif ($Version eq "2") {
			$SampleRate = "24000";
		} elsif ($Version eq "2.5") {
			$SampleRate = "12000";
		}
	} elsif ($SampleRate eq "10") {
		if ($Version eq "1") {
			$SampleRate = "32000";
		} elsif ($Version eq "2") {
			$SampleRate = "16000";
		} elsif ($Version eq "2.5") {
			$SampleRate = "8000";
		}
	} elsif ($SampleRate eq "11") {
		$SampleRate = "reserved";
	}

	if ($Padding eq "0") {
		$Padding = "0";
	} elsif ($Padding eq "1") {
		if ($Layer eq "I") {
			$Padding = "4";
		} elsif (($Layer eq "II") || ($Layer eq "III")) {
			$Padding = "1";
		}
	}

#	print "MPEG Audio : $Version";
#	print " Layer: $Layer";
#	print " BitRate: $BitRate";
#	print " SampleRate: $SampleRate";
#	print " PaddingBit: $Padding";

	my $FrameLengthInBytes = 0;
	my $FrameSize = 0;
	if (($Layer eq "II") || ($Layer eq "III")) {
		$FrameLengthInBytes = ( ((144 *$BitRate*1000) / $SampleRate) + $Padding);
		$FrameLengthInBytes = sprintf "%d", $FrameLengthInBytes;
		$FrameSize = 1152;
	}
else {
		$FrameSize = 384;
	}
	if ($quoi eq 'length') {
		return $FrameLengthInBytes;
	} elsif ($quoi eq 'sampleRate') {
		return $SampleRate;
	} elsif ($quoi eq 'frameSize') {
		return $FrameSize;
	}
	return 0;
}
sub test {
    	my($x, $n) = @_;
	my $a = (($x) & (1 << $n));
	if ($a > 0) {
		return "1";
	} else {
		return "0";
	}
}
