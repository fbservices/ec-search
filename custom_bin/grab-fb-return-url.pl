#!/usr/bin/perl -w

# Description: Script finds out the right URL for a matrix retrieve-url 
# entry

use strict;

# Put this require statement into a BEGIN block so 
# that we can import the constants.
BEGIN {
    $ENV{"SEARCH_HOME"} =~ /^(.+)$/; # untaint this variable
    my $SEARCH_HOME = $1;
    push @INC, "$SEARCH_HOME/custom_bin";
}

# Include libraries
$ENV{"SEARCH_HOME"} =~ /^(.+)$/;    # untaint this variable
my $SEARCH_HOME = $1;


if ( ($#ARGV + 1) < 3 ) {
    print "\n$0: Usage - $0 <collection config file> <user> <pw>\n\n";
    exit 1;
}
# Open the collection.cfg
my $collection_cfg = $ARGV[0];
my $user = $ARGV[1];
my $pw = $ARGV[2];
my @arrStartUrls = ();


my $fileStartUrls = $collection_cfg . '.secondary.start.urls';

if ( not open( STARTURLS, "<", $fileStartUrls ) ) {
    warn "$0: Unable to read file $fileStartUrls ($!)";
    exit 1;
}

while ( <STARTURLS> ) {
    chomp(my $temp = $_);
    print "Now handling $temp\n";
    if ( $temp =~ m/return-url(-file)?/ ) {
       
        my $url = `curl --fail -u$user:$pw $temp`
            or die "$0: Could not access  $temp\n";

        if($url !~ /^http/){
           print "Issue retrieving $temp, no url was returned\n";
           next;
        }else{
           print "Managed to retrieve $url\n";
        }
        push( @arrStartUrls, $url ); # If it's not a web path list, we still want to download it (e.g. on manual instant update)
    }
}

close( STARTURLS );



# Write the URLs back to the start URLs file.
if ( not open( STARTURLS, ">", $fileStartUrls ) ) {
    warn "$0: Unable to write to file $fileStartUrls ($!)";
    exit 1;
}
if(scalar(@arrStartUrls) != 0){
  print STARTURLS "$_\n" foreach ( @arrStartUrls );
}else{
  print "No URLs were fetched, exiting...\n\n";
  exit 1;
}
close( STARTURLS );
