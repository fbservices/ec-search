#!/usr/bin/perl -w

# Description: Script downloads the Electoral Commission Master list of documents in the system.
# It then:
# - Adds any URLs that are not in Matrix
# - Sorts the pages array by length (for DAAT processing)
# - Adds any QIE URLs to the top of the list
# After processing the 'correct' crawl is outputted to the supplied collection's crawl list.

use strict;

# Put this require statement into a BEGIN block so 
# that we can import the constants.
BEGIN {
    $ENV{"SEARCH_HOME"} =~ /^(.+)$/; # untaint this variable
    my $SEARCH_HOME = $1;
    push @INC, "$SEARCH_HOME/custom_bin";
}

use ElectoralCommission::ECVariables;

my $username = $ElectoralCommission::ECVariables::matrixUsername;
my $password = $ElectoralCommission::ECVariables::matrixPassword;
my %assetListings = %ElectoralCommission::ECVariables::assetListings;
my $additionalFile = '';
my $urlBlackList = $ElectoralCommission::ECVariables::urlBlackList;
# Include libraries
$ENV{"SEARCH_HOME"} =~ /^(.+)$/;    # untaint this variable
my $SEARCH_HOME = $1;

# Open the collection.cfg
my $collection_cfg = $ARGV[0];
my $url = $ARGV[1];

use lib '/opt/funnelback/lib/perl/';
use Funnelback::Config;

if ( ($#ARGV + 1) < 2 ) {
    print "\nEC Pre-Gather: Usage: $0 <collection config file> <download URL>\n\n";
    exit 1;
}

# Download asset listing pages and create gscope page
my $file_gscope_asset = $collection_cfg;
$file_gscope_asset =~ s/collection\.cfg/gscope-asset-listings.cfg/;
unlink $file_gscope_asset if (-e $file_gscope_asset);

if ( not open( GSCOPEASSET, ">", $file_gscope_asset ) ) {
    warn "EC Pre-Gather: Unable to write to file $file_gscope_asset ($!)";
    return;
}

# URL of each asset listing map with its gscope number.
# This was required as asset listings are determined not by metadata type but by which folder they're in.
while ( my ($key, $value) = each(%assetListings) ) {
    my $asset_listing = `curl --fail --connect-timeout 5 --max-time 120 --retry 3 --retry-delay 10 -u$username:$password $key`
        or die "EC Pre-Gather: Could not access asset list at $key\n";

    while ($asset_listing =~ m/<a href="(.+?)">(.+?)<\/a>/msig) {
	my $assetUrl = $1;

	$assetUrl =~ s/^http\:\/\///;
	$assetUrl =~ s/\.(pdf|xls|doc|ppt|zip|jpg|mpg|mpeg|mp3)\?SQ_DESIGN_NAME=search_clean/.$1/i;
	$assetUrl =~ s/(\?SQ_DESIGN_NAME=search_clean)/\\$1/;

	print GSCOPEASSET "$value $assetUrl\n";
    }
}

close(GSCOPEASSET);

# Download the Matrix master asset list. Originally tried to use LWP, but couldn't get
# basic authentication working with UserAgent.
my $content = `curl --fail -u$username:$password $url`
    or die "EC Pre-Gather: Could not access master list at $url\n";

my $fileMasterList = $collection_cfg;
$fileMasterList =~ s/collection\.cfg/master-list.cfg/;
if ( not open( MASTERLIST, ">", $fileMasterList ) ) {
    warn "EC Pre-Gather: Unable to write to master list $fileMasterList ($!)";
    return;
}

my $file_qie = '/opt/funnelback/conf/electoral-commission/qie.cfg';
if ( not open( QIE, "<", $file_qie) ) {
    warn "EC Pre-Gather: Unable to read QIE file $file_qie ($!)";
    return;
}

my @qie = <QIE>;
close(QIE);
my $cntQie = 0;

# The QIE file has weightings and escape characters. Sanitise the URLs so they will match these ones.
for ($cntQie = 0; $cntQie < scalar(@qie); $cntQie++) {
    $qie[$cntQie] =~ s/^(.+)\s(http.+)$/$2/;

    # We don't want to push downweighted files to the top of the index, so ignore them.
    if ($1 > 0.5) {
        $qie[$cntQie] =~ s/\\\?/?/g;
        chomp($qie[$cntQie]);
    }
    else {
        delete $qie[$cntQie];
    }
}

# Download the blacklist (URLs to exclude)
my $blackList = `curl --fail -u$username:$password $urlBlackList`
        or die "EC Pre-Gather-Instant: Could not access black list at $urlBlackList\n";

my @arrBinary = ();
my @arrPages = ();

CHECKURL: while ($content =~ m/<a href="(.+?)">(.+?)<\/a>/msig) {
    my $strURL = $1;
    my $strAssetId = $2;
    my $checkUrl = $strURL;
    $checkUrl =~ s/\?SQ_DESIGN_NAME=search_clean//;

    foreach (@ElectoralCommission::ECVariables::excludePatterns) {
        next CHECKURL if $checkUrl =~ m/$_/i;
    }

    # Funnelback crawler doesn't recognise these files if they have a trailing query string, so remove it
    # before outputting to the crawl list.
    if ( $blackList !~ m/$checkUrl/ ) {
	print MASTERLIST "<a href=\"$strURL\">$strAssetId<\/a>\n";

        processLink($strURL, $strAssetId, \@arrBinary, \@arrPages);
    }
}

close( MASTERLIST );

# Include additional URLs that aren't in Matrix
$additionalFile = '/opt/funnelback/conf/electoral-commission/additional-page-list.cfg';
addList($additionalFile, \@arrBinary, \@arrPages);

# Sort the page array by length to try to emulate what would happen if a natural crawl occurred.
# This is so the index.manifest will still be useful for DAAT mode.
my @sortedPages = sort { length $a <=> length $b } @arrPages;

my $file = $collection_cfg . '.start.urls';

if ( not open( DATA, ">:utf8", $file) ) {
    warn "EC Pre-Gather: Unable to write to crawl file $file ($!)";
    return;
}

# Output the QIE URLs at the top of the crawl list.
# This is to make sure they are always considered in a DAAT search.
foreach (@qie) {
    my $temp = $_;
    my $checkPresent = 0;

    # This step has been added as if a file is added to the QIE, but later deleted, that file could
    # still be included in the index, if the QIE file is not updated.
    foreach (@sortedPages) {
	$checkPresent = 1 if ($_ eq $temp);
	last;
    }

    print DATA $_ . "\n" if ($checkPresent > 0);
}

# Output the sorted pages, but make sure to skip QIE URLs that have already been outputted.
foreach (@sortedPages) {
    my $temp = $_;
    my $checkPresent = 0;    

    foreach (@qie) {
        $checkPresent = 1 if ($_ eq $temp);
	last;
    }

    print DATA $_ . "\n" if ($checkPresent == 0);
}

# Output the binary URLs, again skipping QIE URLs.
foreach (@arrBinary) {
    my $temp = $_;
    my $checkPresent = 0;

    foreach (@qie) {
        $checkPresent = 1 if ($_ eq $temp);
	last;
    }

    print DATA $_ . "\n" if ($checkPresent == 0);
}

close(DATA);

exit 0;




sub processLink {
    my $link = shift;   
    my $assetId = shift; 
    my $refBinary = shift;
    my $refPages = shift;

    # The EC Matrix setup doesn't output a binary file's document-summary page in the master list
    # So, if the link is to a binary file, create the required doc summ link and append it.
    if ($link =~ m/\.(pdf|xls|doc|ppt|zip|jpg|mpg|mpeg|mp3)/i) {
        $link =~ s/\.(pdf|xls|doc|ppt|zip|jpg|mpg|mpeg|mp3)\?SQ_DESIGN_NAME=search_clean/\.$1/i;
        push(@$refBinary, $link);

        if ($link =~ m/http\:\/\/([^\/]+)\//) {
	    push(@$refBinary, "http://$1/document-summary/_nocache?assetid=$assetId&SQ_DESIGN_NAME=search_clean");
        }
    }
    else {
        push(@$refPages, $link);
    }
}

sub addList {
    my $input = shift;
    my $refBinary = shift;
    my $refPages = shift;

    if ( not open( DATA, "<", $input) ) {
        warn "EC Pre-Gather: Unable to read additional URLs file at $input ($!)";
        return;
    }

    #Read each line
    foreach my $line (<DATA>) {
        chomp($line);              # remove the newline from $line.
        if ($line =~ m/\.(pdf|xls|doc|ppt|zip|jpg|mpg)/i) {
            push(@$refBinary, $line);
        }
	else {
            push(@$refPages, $line);
	}
    }

    close(DATA);
} 
