#!/usr/bin/perl -w

use strict;
use File::Find;

# Include libraries
$ENV{"SEARCH_HOME"} =~ /^(.+)$/;    # untaint this variable
my $SEARCH_HOME = $1;

# Open the collection.cfg
my $collection_cfg = $ARGV[0];
my $collection_state = $ARGV[1];

use lib '/opt/funnelback/lib/perl/';
use Funnelback::Config;

if ( ($#ARGV + 1) < 2 ) {
    print "\nEC-Preprocess: Usage: $0 <collection config file> <live or offline>\n\n";
    exit 1;
}

die("EC-Preprocess: Unable to open $collection_cfg")
  if not( open( COLLECTION, "<$collection_cfg" ) );
my %collection_info = Funnelback::Config::getConfigData( \*COLLECTION );
close(COLLECTION);

# Check that the collection's data root exists
my $data_path = $collection_info{'data_root'} . "/";
die("EC-Preprocess: Data root doesn't exist.") if ( not -d $data_path );

# As a precaution, don't let this script be run on anything but a valid
# Funnelback data directory
$data_path =~ s/(offline|live)/$collection_state/;
if ( not $data_path =~ /(live|offline)[\\\/](?:secondary-)?data/i ) {
    print
"ERROR: This script should only be run on a collection's data directory.\n$data_path\n";
    exit 1;
}

# Timestamp start
my $date = scalar(localtime);
print "EC Pre-processing: Processing files at $date...\n";
print "Data path: $data_path\n";

my $file = "/opt/funnelback/conf/electoral-commission/grab.cfg";
if ( not open( SUMMARIES, ">", $file) ) {
    warn "EC Pre-processing: Unable to write to file $file ($!)";
    return;
}

# Recurse through the data directory and process each file
find( \&pre_process_file, $data_path );

close(SUMMARIES);

# Timestamp finish
$date = scalar(localtime);
print "EC Pre-processing: Finished processing files at $date\n";

# Done
exit 0;


sub pre_process_file {
    my $file = $_;

    return if ( not defined $file );

    # Skip directories and binary documents
    if ( -d $file ) {
        if ($File::Find::name =~ m/www\.electoralcommission\.org\.uk\/__data\/assets\/.+?\/\d+?\/(\d+)/) {
	    print SUMMARIES "http://www.electoralcommission.org.uk/document-summary?assetid=$1\n";	
	}
	elsif ($File::Find::name =~ m/www\.dopolitics\.org\.uk\/__data\/assets\/.+?\/\d+?\/(\d+)/) {
	    print SUMMARIES "http://www.dopolitics.org.uk/document-summary?assetid=$1\n";
	}
    }

}
