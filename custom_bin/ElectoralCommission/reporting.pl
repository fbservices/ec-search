#!/opt/ActivePerl-5.8/bin/perl -w

# Author: Ben Pottier

use strict;
use warnings;
use Getopt::Long;
use IO::Handle;
use DBI;
use File::Find;
use File::Copy;
use Data::Dumper;
autoflush STDERR,1;

use Cwd;
use File::Basename;
use File::Path;
use File::Spec;
use File::Spec::Functions;

use lib File::Spec->catdir(dirname(__FILE__), '..', '..', 'lib', 'perl');

use Funnelback::Config;
use Funnelback::NumbersTextTimes;

my %months = (
	'Jan' => '01',
	'Feb' => '02',
	'Mar' => '03',
	'Apr' => '04',
	'May' => '05',
	'Jun' => '06',
	'Jul' => '07',
	'Aug' => '08',
	'Sep' => '09',
	'Oct' => '10',
	'Nov' => '11',
	'Dec' => '12'
);

my @years = ( '2010' );
my @months = ( '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12' );
my %dayRanges = (
  '01' => 31,
  '02' => 28,
  '03' => 31,
  '04' => 30,
  '05' => 31,
  '06' => 30,
  '07' => 31,
  '08' => 31,
  '09' => 30,
  '10' => 31,
  '11' => 30,
  '12' => 31
);


# Set locations
if (not $ENV{"SEARCH_HOME"}) {
    print "$0: \$SEARCH_HOME environment variable not set\n";
    exit 1;
}
my $SEARCH_HOME = $ENV{"SEARCH_HOME"};

# Get system execute names
my %executable = Funnelback::Config::getexecutable();

# required variables
my $is_top_domain = 0;
my $counter = 0;
my $domain = "";
my %outputHash = ();

# CL args to read
my $filename;
my $debug = 0;

# Read in command line options
GetOptions("c|config_file=s"=>\$filename,
           "d|debug"=>\$debug);

# Usage output
if(!$filename){
  warn "\nUsage: $0 [-d] -c <config file>\n\n";
  warn "\t-c, --config_file : The config file of the target collection\n";
  warn "\t-d, --debug       : enable debug mode\n\n";
  exit 1;
}

# Load collection configuration from input file
open(COLLECTION, $filename) or die "Quicklinks Error: Unable to open $filename";
my %collection_info = Funnelback::Config::getConfigData(\*COLLECTION);
my $coll_root = $collection_info{"collection_root"};
close(COLLECTION);

my $archive_root =  File::Spec->catdir($coll_root, 'archive');

# Argument checking
die "$coll_root is not a directory\n\n" if (not -d $coll_root);

if($debug){
  warn "Debug mode is enabled\n";
}

my %executables = Funnelback::Config::getexecutable();
my $gunzip = $executables{'gunzip'} || '/usr/bin/gzip';

my $dbname =File::Spec->catdir(dirname(__FILE__), "electoralcommission");

my $dbargs = {AutoCommit => 0, PrintError => 1};

if(-e "$dbname.tmp"){
   warn "Removing temporary database file\n" if $debug;
   unlink "$dbname.tmp" or die "Could not remove temporary database: $!\n\n";
}

my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname.tmp", "", "", $dbargs);

$dbh->do("CREATE TABLE dayqueries(pkey INTEGER PRIMARY KEY, date DATE, scope TEXT, query TEXT, count INTEGER)");
if ($dbh->err()) { die "Could not create dayqueries table: $DBI::errstr\n\n"; }

$dbh->do("CREATE TABLE monthqueries(pkey INTEGER PRIMARY KEY, month TEXT, scope TEXT, count INTEGER)");
if ($dbh->err()) { die "Could not create monthqueries table: $DBI::errstr\n\n"; }

my $querysth = $dbh->prepare(<<SQL);
INSERT INTO dayqueries (date, scope, query, count)
VALUES (?, ?, ?, ?)
SQL

my %queries = (); # this is going to get BIG

find(\&pre_process_file, $archive_root);

# todo enter the right stuff into DB
foreach my $date (keys %queries){
  my %day = %{$queries{$date}};
  foreach my $j (keys %day){ 
    if($j =~ /^(.*?)###(.*?)$/){
      my $scope = $1;
      my $query = $2;
      my $count = $day{$j};
      $querysth->execute($date, $scope, $query, $count);
    }
  }
}

foreach my $year (@years){
 foreach my $month (@months){
   my $startDate = "$year-$month-01";
   my $endDate = "$year-$month-" . $dayRanges{$month};
    
   my $sql = "SELECT scope, sum(count) as total FROM dayqueries WHERE date BETWEEN '$startDate' AND '$endDate' group by scope";

   my $rows = $dbh->selectall_arrayref($sql);
   if(scalar(@$rows) != 0){ 

    my $querysth2 = $dbh->prepare(<<SQL2);
INSERT INTO monthqueries (month, scope, count)
VALUES (?, ?, ?)
SQL2
      my $insertMonth = "$year-$month";
      foreach my $row (@$rows) {
         my $insertScope = @$row[0];
         my $insertCount = @$row[1];
        
         $querysth2->execute($insertMonth, $insertScope, $insertCount);
      }
    }
  }
}

$dbh->commit();
$dbh->disconnect();

move("$dbname.tmp", $dbname) or die "Could not move database to live";

exit 0;

###########################
##          SUBS         ##
###########################

# Processing sub
sub pre_process_file {
    my $file = $_;

    return if (not defined $file or ($file !~ /\.gz$/) or ($file !~ /(fnb02|\.\.)/) or ($file =~ m/xml/) or ($File::Find::name =~ m/\/\.svn\//));

    # Skip directories and binary documents
    if (-d $file) {
        return;
    }
  
   my $open_path = "$gunzip --stdout $file |";
   open my $LOGFILE, $open_path or die("Cannot open $file: $!");

   my $line_counter = 0; 
   while(<$LOGFILE>){
     my $line = $_;
     chomp($line);
     # progress counter
     ++$line_counter;
     # printing of progress meter
     if($debug && ($line_counter % 100000) == 0){
        my $tmpLine = Funnelback::NumbersTextTimes::commify($line_counter);
        print STDERR "DEBUG: Processed $tmpLine lines for $file\r";
     }
     

     if($file =~ /click/){
     }else{
        processQueryLine($line);
     }
   }
   close $LOGFILE;
   $line_counter = Funnelback::NumbersTextTimes::commify($line_counter);
   warn "DEBUG: Read a total of $line_counter lines from $file\n" if $debug;
}

sub processQueryLine {
   my $entry = shift;
   $entry =~ s/g"(.*?),(.*?)"/g"$1;$2"/g;
   my @entries = split ',', $entry;
   my $date = $entries[0];
  # Wed Nov  3 16:43:56 2010,
   if($date =~ /^\w+\s*(\w+)\s*(\d+)\s*\d+:\d+:\d+\s*(\d{4}).*?$/){
      my $month = $1;
      my $day = $2;
      my $year = $3;
      if($day =~ /^\d$/){
         $day = '0' . $day;
      }
      $month = $months{$month};
      $date = "$year-$month-$day";
   } 
   my $query =  $entries [2];
   $query = cleanQuery($query); # Clean up unwanted repetitions inside a query
   my $scope = $entries [3];
   $scope = cleanScope($scope);
   
   my $combined = $scope . '###' . $query;

   if(defined $queries{$date}){
      ++${$queries{$date}}{$combined};
   }else{
      $queries{$date} = ();
      ++${$queries{$date}}{$combined}; # my brain is melting now
   }
}

sub cleanQuery {
   my $unclean = shift;
   my $clean = $unclean;
   my $subscope = '';
   $clean =~ s/20(.) 3A/ $1:/gi;
   $clean =~ s/\!(.) 3A/\!$1:/gi;
   $clean =~ s/60//gi;
   $clean =~ s/ 20/ /gi;
   $clean =~ s/\!parrnell\s*//ig;

   if($clean =~ /\!t:padrenullcons/i){
      $clean =~ s/\!t:padrenullcons//ig;
    #  $subscope = 'Consultations Responses';
   }
   if($clean =~ /\!t:padrenullpolicy/i){
      $clean =~ s/\!t:padrenullpolicy//ig;
   #   $subscope = 'Policy and Research';
   }
   if($clean =~ /\!t:padrenullpol/i){
      $clean =~ s/\!t:padrenullpol//ig;
    #  $subscope = 'DoPolitics';
   }
   if($clean =~ /\!t:padrenullall/i){
      $clean =~ s/\!t:padrenullall//ig;
     # $subscope = 'All Reviews';
   }
   if($clean =~ /\!t:padrenullfact/i){
      $clean =~ s/\!t:padrenullfact//ig;
     # $subscope = 'Factsheets and casestudies';
   }
   if($clean =~ /\!t:padrenullcorp/i){
      $clean =~ s/\!t:padrenullcorp//ig;
      #$subscope = 'Corporate Publications';
   }
   if($clean =~ /\!t:padrenullform/i){
      $clean =~ s/\!t:padrenullform//ig;
     # $subscope = 'Forms';
   }
   if($clean =~ /\!t:padrenullelec/i){
      $clean =~ s/\!t:padrenullelec//ig;
      #$subscope = 'Election Results';
   }
   if($clean =~ /\!t:padrenullfreedom/i){
      $clean =~ s/\!t:padrenullfreedom//ig;
      #$subscope = 'Freedom of Information';
   } 
   if($clean =~ /\!t:padrenullnews/i){
      $clean =~ s/\!t:padrenullnews//ig;
   #   $subscope = 'News';
   }
    if($clean =~ /\!t:padrenullcirc/i){
      $clean =~ s/\!t:padrenullcirc//ig;
    #  $subscope = 'Circulars and Alerts';
   }
   if($clean =~ /\!t:padrenullguid/i){
      $clean =~ s/\!t:padrenullguid//ig;
     # $subscope = 'Guidance';
   }
   if($clean =~ /\!t:padrenull/i){
      $clean =~ s/\!t:padrenull//ig;
   }
   if($clean =~ /F:guidance form/i){
      $clean =~ s/F:guidance (form)?//ig;
      $clean =~ s/\s+/ /g;
   }
   $clean =~ s/F:".*?"//g; 
   $clean =~ s/F: 22.*? 22//g;
   $clean =~ s/s:"(.*?)"/Subject=$1/g;
  $clean =~ s/\!padrenull//g;
   $clean =~ s/\!padre//g;
   $clean =~ s/\!paderen//g;
   $clean =~ s/\-C:"[^"]+"//g;
   $clean =~ s/\-C:[^\s]+//g;
   $clean =~ s/\s*C:/ Country=/g; 
   $clean =~ s/Country=Northern\s*Country=Ireland/Country=Northern Ireland/;
   $clean =~ s/\`//g;
   $clean =~ s/- Country=//g;
   $clean =~ s/22//g;
   $clean =~ s/F:guidance//g;
   $clean =~ s/\s\s+/ /g;
   $clean =~ s/d=/Date=/g;
   if($clean =~ /^\s*$/){
    $clean = 'List all results';
   } 
    if($subscope ne ''){
   #   $clean .= ' in ' . $subscope;
    }
   return $clean;
}

sub cleanScope {
   my $unclean = shift;
   my $scope = $unclean;
   $scope =~ s/;/,/g;
   if($scope =~ /g"13"/ || $scope =~ /g"13,3!(\+)?"/){
       $scope = 'All Reviews';
   }
   if($scope =~ /g"5,3!(\+)?"/){
       $scope = 'Circulars and Alerts';
   }
   if($scope =~ /g"4,3!(\+)?"/){
       $scope = 'Corporate Publications';
   }
   if($scope =~ /g"14,3!(\+)?"/){
       $scope = 'Consultations responses';
   }
   if($scope =~ /g"8,3!(\+)?"/){
       $scope = 'DoPolitics';
   }
   if($scope =~ /g"9,3!(\+)?"/){
       $scope = 'Election Reports';
   }
   if($scope =~ /g"6,3!(\+)?"/){
       $scope = 'Factsheets and Casestudies';
   }
   if($scope =~ /g"7,3!(\+)?"/){
       $scope = 'Forms';
   }
   if($scope =~ /g"10"/ || $scope =~ /g"10,3!(\+)?"/){
       $scope = 'Freedom of Information';
   }
   if($scope =~ /g"11,3!(\+)?"/){
       $scope = 'Guidance';
   }
   if($scope =~ /g"1"/ || $scope =~ /g"1,3!(\+)?"/){
       $scope = 'News Releases';
   }
   if($scope =~ /g"3!(\+)?"/){
       $scope = 'General English';
   }
   if($scope =~ /g"12,3!(\+)?"/){
       $scope = 'Policy Research';
   }
   if($scope =~ /g"2,3!(\+)?"/){
       $scope = 'Publications';
   }
   if($scope =~ /g"3(\+)?"/){
      $scope = 'General Welsh';
   }
   if($scope =~ /g"12,3(\+)?"/){
      $scope = 'Welsh - Policy and Research';
   }  
   if($scope =~ /g"14,3(\+)?"/){
      $scope = 'Welsh - Consultations Responses';
   }
   if($scope =~ /g"4,3(\+)?"/){
      $scope = 'Welsh - Corporate Publications';
   }
   if($scope =~ /g"5,3(\+)?"/){
      $scope = 'Welsh - Circulars and Alerts';
   }
   if($scope =~ /g"9,3(\+)?"/){
      $scope = 'Welsh - Election Reports';
   }
   if($scope =~ /g"6,3(\+)?"/){
      $scope = 'Welsh - Factsheets and Casestudies';
   }
   if($scope =~ /g"7,3(\+)?"/){
      $scope = 'Welsh - Forms';
   }
   if($scope =~ /g"11,3(\+)?"/){
      $scope = 'Welsh - Guidance';
   }
   if($scope eq $unclean){
      $scope = "General";
    }
   
   return $scope;
}

sub cleanQueryOld {
  my $unclean = shift;
  my $clean = '';
  
  my %seen = ();
  # handle surrounding parameters

# F:"Guidance" C:Scotland -C:England -C:Wales -C:"Northern Ireland"
  while ($unclean =~ s/(`.*?`)//ig){
     my $entry = $1;
     if(not defined $seen{$entry}){
	$seen{$entry} = '';
        $clean .= "$entry ";
     }
  }
  while ($unclean =~ s/([!+-][\w^:]+)//i){
     my $entry = $1;
     if(not defined $seen{$entry}){
        $seen{$entry} = '';
        $clean .= "$entry ";
     }
  }
  while ($unclean =~ s/[^:]([!+-]?".*?")//i){
     my $entry = $1;
     if(not defined $seen{$entry}){
        $seen{$entry} = '';
        $clean .= "$entry ";
     }
  }
  while ($unclean =~ s/([!-+]?[a-zA-Z]:".*?")//i){
     my $entry = $1;
     if(not defined $seen{$entry}){
        $seen{$entry} = '';
        $clean .= "$entry ";
     }
  }
  while ($unclean =~ s/([!-+]?[a-zA-Z]:[^\s]+)//i){
     my $entry = $1;
     if(not defined $seen{$entry}){
        $seen{$entry} = '';
        $clean .= "$entry ";
     }
  }
  while ($unclean =~ s/([\w]+)//i){
     my $entry = $1;
     if(not defined $seen{$entry}){
        $seen{$entry} = '';
        $clean .= "$entry ";
     }
  }
  return $clean; 
}

