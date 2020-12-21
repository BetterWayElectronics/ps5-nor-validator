#!/usr/bin/perl 

use strict;
use warnings;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Win32::Console::ANSI;
use Term::ANSIScreen qw/:color /;
use Term::ANSIScreen qw(cls);
use Time::HiRes;
use Fcntl qw(:flock :seek);
use String::HexConvert ':all';
use Win32::Console;
use File::Copy qw(copy);
use Regexp::Assemble;
use Smart::Comments;
use List::Util qw( sum );

my $CONSOLE=Win32::Console->new;
$CONSOLE->Title('BwE PS5 NOR Statistics');

my $clear_screen = cls(); 
my $osok = (colored ['bold green'], "OK");
my $osdanger = (colored ['bold red'], "DANGER");
my $oswarning = (colored ['bold yellow'], "WARNING");
my $osunlisted = (colored ['bold blue'], "UNLISTED");

my $BwE = (colored ['bold green'], qq{
===========================================================
|            __________          __________               |
|            \\______   \\ __  _  _\\_   ____/               |
|             |    |  _//  \\/ \\/  /|  __)_                |
|             |    |   \\\\        //       \\               |
|             |______  / \\__/\\__//______  /               |
|                    \\/  PS5 NOR Stats  \\/0.2             |
|        		                                  |
===========================================================\n});
print $BwE;

START:

my @files=(); 

while (<*.bin>) 
{
    push (@files, $_) if (-s eq "2097152");
}

my $input; my $file; my $original;

if ( @files == 0 ) {
	print "\n$oswarning: Nothing to validate. Aborting...\n"; 
	goto FAILURE;
} else {

if ( @files > 1 ) { 
	print "\nMultiple .bin files found within the directory:\n\n";
	foreach my $file (0..$#files) {
		print $file + 1 . " - ", "$files[$file]\n";
}

print "\nPlease make a selection: ";
my $input = <STDIN>; chomp $input; 
my $nums = scalar(@files);

if ($input > $nums) {
	print "\n\n$oswarning: Selection out of range. Aborting...\n\n"; 
	goto FAILURE;}
	
elsif ($input eq "0") {
	print "\n\n$oswarning: Selection out of range. Aborting...\n\n"; 
	goto FAILURE;}
	
elsif ($input eq "") {
	print "\n\n$oswarning: You didn't select anything. Aborting...\n\n"; 
	goto FAILURE;} else {
		$file = $files[$input-1]; 
		$original = $files[$input-1];}; 
	
} else { 
$file = $files[0]; 
$original = $file = $files[0];}
}

# Now that the file is selected....
print $clear_screen;
print $BwE;

# Settings
my $settings = "settings.ini";

my $Entropy_High;
my $Entropy_Low;
my $FF_High;
my $FF_Low;
my $Null_High;
my $Null_Low;

if (-e "settings.ini") {

open(my $bin, "<", $settings) or die { print "Cant open $settings\n", goto FAILURE}; binmode $bin;

# Entropy Settings
seek($bin, 0x40C, 0); 
read($bin, $Entropy_High, 0x4);
seek($bin, 0x420, 0); 
read($bin, $Entropy_Low, 0x4);

# FF Settings
seek($bin, 0x434, 0); 
read($bin, $FF_High, 0x5);
seek($bin, 0x446, 0); 
read($bin, $FF_Low, 0x5);

# 00 Settings
seek($bin, 0x45B, 0); 
read($bin, $Null_High, 0x5);
seek($bin, 0x46C, 0); 
read($bin, $Null_Low, 0x5);

} else {

# Default Entropy Settings
$Entropy_High = "4.30";
$Entropy_Low = "4.20";

# Default FF Settings
$FF_High = "3.80";
$FF_Low = "3.60";

# Default 00 Settings
$Null_High = "0.10";
$Null_Low = "0.08";

}

my $start_time = [Time::HiRes::gettimeofday()]; # Start Counting!

# Entropy
my $len = -s $file;
my ($entropy, %t) = 0;

open (my $file_en, '<', $file) || die "Cant open $file\n", goto FAILURE;
binmode $file_en;


while( read( $file_en, my $buffer, 1024) ) {  ### Calculating Entropy...    
	$t{$_}++ 
		foreach split '', $buffer; 
	$buffer = '';
}

foreach (values %t) { 
	my $p = $_/$len;
	$entropy -= $p * log $p ;
}       
my $result = sprintf("%.2f", $entropy / log 2);
my $result_percent = sprintf("%.2f", $result / 8 * 100);

# Entropy Result
my $entropy_validation;
if ($result gt $Entropy_High) { 
$entropy_validation = $oswarning;
}
elsif ($result lt $Entropy_Low) {
$entropy_validation = $osdanger;
} else {
$entropy_validation = $osok;
}

# Byte Counting
use constant BLOCK_SIZE => 4*1024*1024;

open(my $fh, '<:raw', $file)
   or die("Can't open \"$file\": $!\n"), goto FAILURE;

my @counts = (0) x 256;
while (1) {  ### Counting Bytes...
   my $rv = sysread($fh, my $buf, BLOCK_SIZE);
   die($!) if !defined($rv);
   last if !$rv;

   ++$counts[$_] for unpack 'C*', $buf;
}

my $N = sum @counts;

my $FFCountPercent = sprintf("%.2f",($counts[0xFF] / 33554432 * 100));
my $NullCountPercent = sprintf("%.2f",($counts[0x00] / 33554432 * 100));

# FF Result
my $FF_count_validation;
if ($FFCountPercent gt $FF_High) {
$FF_count_validation = $oswarning;
}
elsif ($FFCountPercent lt $FF_Low) {
$FF_count_validation = $osdanger;
} else {
$FF_count_validation = $osok;
}

# 00 Result
my $Null_count_validation;
if ($NullCountPercent gt $Null_High) {
$Null_count_validation = $oswarning;
}
elsif ($NullCountPercent lt $Null_Low) { 
$Null_count_validation = $osdanger;
} else {
$Null_count_validation = $osok;
}

# End Results
print $clear_screen;
print $BwE;

# MD5
my $md5sum = uc Digest::MD5->new->addfile($file_en)->hexdigest; 

# SKU
seek($file_en, 0x1C7230,0);
read($file_en, my $SKU, 0xE); 
$SKU =~ tr/a-zA-Z0-9 -//dc; #Hahahaha! Easy!?

# Version
my $whatistheversion;
seek($file_en, 0x1CBC26, 0); #It is either at 0x1c4001, 0x1c7011, 0x1c8c26 or 0x1cbc26
read($file_en, my $FW_Version1, 0x2);
$FW_Version1 = uc ascii_to_hex($FW_Version1); 
if ($FW_Version1 eq "FFFF")
{
	$whatistheversion = "N/A";
} 
else
{
	$FW_Version1 = unpack "H*", reverse pack "H*", $FW_Version1;
	$FW_Version1 = hex($FW_Version1); $FW_Version1 = uc sprintf("%x", $FW_Version1);
	$whatistheversion = substr($FW_Version1, 0, 1) . "." . substr($FW_Version1, 1);
}

print "\nSelected File: $file";
print "\nFile Size: $len"; #Yes I know its obvious...
print "\nSKU: $SKU";
print "\nVersion: $whatistheversion";
print "\nMD5: $md5sum";

print "\n\nEntropy: ", $result, " ($result_percent%)", " - ", $entropy_validation;
print "\nFF: ", $counts[0xFF], " (", $FFCountPercent, "%)", " - ", $FF_count_validation;
print "\n00: ", $counts[0x00], " (", $NullCountPercent, "%)", " - ", $Null_count_validation;

print "\n\nTime to calculate: ", sprintf("%.2f", Time::HiRes::tv_interval($start_time))," seconds";



FAILURE:
print "\n\nPress Enter to Exit... ";
while (<>) {
chomp;
last unless length;
}

