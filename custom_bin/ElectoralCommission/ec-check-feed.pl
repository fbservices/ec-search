#!/usr/bin/perl -w

# Description: Checks the CUSTOM feeds file passed to it and if it contains content, triggers
# a normal feed run.

use strict;

use File::Basename;
use File::Spec;
use File::Copy;

use lib File::Spec->catdir(dirname(__FILE__), '../../', 'lib', 'perl');

use Funnelback::Execution;

$ENV{"SEARCH_HOME"} =~ m/^(.+?)$/;
my $SEARCH_HOME = $1;

if ( ($#ARGV + 1) < 1 ) {
    print "\nCheck Feed: Usage: $0 <feed filepath>\n\n";
    exit 1;
}

my $feed = $ARGV[0];

# Check server load is within acceptable limits before triggering a search
my @server_load = split " ",`cat /proc/loadavg`;

if ($server_load[0] > 10) {
    print "Server load too high, update aborted.";
    exit(0);
}

if ((-e $feed) && ((-s $feed) > 0)) {
    my $date = scalar(localtime);
    print "$date: File not empty, triggering update using $feed.\n";
    # Move the feed file to a holding location. This is to allow for additional feed requests that may be
    # received whilst the update is in progress and to reset the feed file, as requests are simply appended
    # to it.
    move($feed, "$SEARCH_HOME/log/feed-processing.log");    
    Funnelback::Execution::exec_perl_script(
        "$SEARCH_HOME/bin" # where to execute
        , 0 # no taint
        , "$SEARCH_HOME/log/feed-custom.log" #logfile
        , 0 # don't append, overwrite log
        , 1 # wait for the script to finish
        , "feed-perform.pl" #script name for the feed handler
        , "$SEARCH_HOME/log/feed-processing.log" #quoted xml document
        );
    $date = scalar(localtime);
    # Remove the temporary processing file.
    unlink("$SEARCH_HOME/log/feed-processing.log");
    print "$date: Finished update.\n";
}
