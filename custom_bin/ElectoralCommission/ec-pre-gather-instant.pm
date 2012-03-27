#!/usr/bin/perl -w

# Description: Script downloads the Electoral Commission Master list of documents in the system.
# It then:
# - Adds any URLs that are not in Matrix
# - Sorts the pages array by length (for DAAT processing)
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
my $urlBlackList = $ElectoralCommission::ECVariables::urlBlackList;
my %assetListings = %ElectoralCommission::ECVariables::assetListings;
my $additionalFile = '';
my $assetId = '';
my $fileKillInstant = '';
my $fileWebPaths = '';
my $fileStartUrls = '';
my $fileFeedLog = '';
my $asset_listing = '';

my @arrStartUrls = ();
my @arrCheckableUrls = ();
my @arrKillUrls = ();

# Include libraries
$ENV{"SEARCH_HOME"} =~ /^(.+)$/;    # untaint this variable
my $SEARCH_HOME = $1;

if ( ($#ARGV + 1) < 1 ) {
    print "\nEC-Pre-Gather-Instant: Usage - $0 <collection config file>\n\n";
    exit 1;
}

# Open the collection.cfg
my $collection_cfg = $ARGV[0];

$fileKillInstant = $collection_cfg;
$fileKillInstant =~ s/collection\.cfg/kill-list-instant\.cfg/;
$fileWebPaths = $collection_cfg;
$fileWebPaths =~ s/collection\.cfg/feed-web-paths.cfg/;
$fileStartUrls = $collection_cfg . '.secondary.start.urls';
$fileFeedLog = $collection_cfg;
$fileFeedLog =~ s/collection\.cfg/log\/update-feed.log/;
$fileFeedLog =~ s/\/conf\//\/data\//;

open( FEEDLOG, ">>", $fileFeedLog );
my $now = scalar localtime;
print FEEDLOG "Pre-gather started at $now\n";

use lib '/opt/funnelback/lib/perl/';
use Funnelback::Config;

if ( ( $#ARGV + 1 ) < 1 ) {
    print "\nEC Pre-Gather-Instant: Usage: $0 <collection config file>\n\n";
    exit 1;
}

# Now that we know the start URLs are OK, download the asset listing pages and check for
# any required gscoping.
my $fileGscopeInstant = $collection_cfg;
$fileGscopeInstant =~ s/collection\.cfg/gscope-instant\.cfg/;
unlink $fileGscopeInstant if (-e $fileGscopeInstant);

if ( not open( GSCOPEINSTANT, ">", $fileGscopeInstant ) ) {
    warn "EC Pre-Gather-Instant: Unable to write to file $fileGscopeInstant ($!)";
    return;
}

# URL of each asset listing map with its gscope number.
# This was required as asset listings are determined not by metadata type but by which folder they're in.
# We do this step first, so that if gscopes aren't downloaded, we haven't overwrittern the start urls.
while ( my ($key, $value) = each(%assetListings) ) {
# Added the timeout and retry values as there were issues with the gscope file sometimes being empty. Could not replicate
# problem at will to figure out exact cause, but I think it might have been because of timeouts not registering as failed connections.
    $asset_listing = `curl --fail --connect-timeout 5 --max-time 120 --retry 3 --retry-delay 10 -u$username:$password $key`
        or die "EC Pre-Gather-Instant: Could not access asset list at $key\n";

    # Loop through the previously downloaded media folder asset listings and write gscopes to files
    while ($asset_listing =~ m/<a href="(.+?)">(.+?)<\/a>/msig) {
        my $assetUrl = $1;
        $assetUrl =~ s/^http\:\/\///;
        $assetUrl =~ s/\.(pdf|xls|doc|ppt|zip|jpg|mpg|mpeg|mp3)\?SQ_DESIGN_NAME=search_clean/.$1/i;
        $assetUrl =~ s/(\?SQ_DESIGN_NAME=search_clean)/\\$1/;

       print GSCOPEINSTANT "$value $assetUrl\n";
    }
}

close( GSCOPEINSTANT );

# We will need to download the starting URLS to clean them up and check against the black list.
# Start by downloading the blacklist
my $blackList = `curl --fail -u$username:$password $urlBlackList`
        or die "EC Pre-Gather-Instant: Could not access black list at $urlBlackList\n";

if ( not open( STARTURLS, "<", $fileStartUrls ) ) {
    warn "EC Pre-Gather-Instant: Unable to read file $fileStartUrls ($!)";
    return;
}

# Need to grab the existing URLs in webpaths so that we don't output any duplicates.
my @checkWebPaths;
my $checkWebPaths;
if ( -e $fileWebPaths ) {
    if ( not open( WEBPATHS, "<", $fileWebPaths ) ) {
        warn "EC Pre-Gather-Instant: Unable to read file $fileWebPaths ($!)";
        return;
    }

    @checkWebPaths = <WEBPATHS>;
    close( WEBPATHS );
    $checkWebPaths = join( "", @checkWebPaths );
}

if ( not open( WEBPATHS, ">>", $fileWebPaths ) ) {
    warn "EC Pre-Gather-Instant: Unable to write to file $fileWebPaths ($!)";
    return;
}

while ( <STARTURLS> ) {
    chomp(my $temp = $_);
    print FEEDLOG "Original URL: $temp\n";

    # Grab each web path list, download it and push the URLs into an array
    if ( $temp =~ m/\/return-url(-file)?/ ) {
        $temp =~ m/\?assetid=(\d+)/;
        $assetId = $1;

	# Check for any existing links for that assetid and kill them
        killAsset( $assetId, $collection_cfg, $fileKillInstant );

        my $listWebPaths = `curl --fail -u$username:$password $temp`
            or die "EC Pre-Gather-Instant: Could not access web path list at $temp\n";

	CHECKURLS: while ( $listWebPaths =~ m/(http.+)(?:,\s)?/g ) {
	    my $tempUrl = $1;
	    $tempUrl =~ s/\s*$//;

	    # Skip this URL if it is on the blacklist.
    	    next CHECKURLS if ( $blackList =~ m/$tempUrl/ );

	    print WEBPATHS "<a href=\"$tempUrl?SQ_DESIGN_NAME=search_clean\">$assetId</a>\n" if ( $checkWebPaths !~ m/<a href=\"$tempUrl\">$assetId<\/a>/ );

	    # Add a link to the doc-summary, if the link is to a binary
	    if ( $tempUrl =~ m/\.(pdf|xls|doc|ppt|zip|jpg|mpg|mpeg|mp3)$/i ) {
                $tempUrl =~ m/http\:\/\/[^\.]+.([^\/]+)/;
                my $linkDocSumm = "http://www.$1/document-summary/_nocache?assetid=$assetId&SQ_DESIGN_NAME=search_clean";
	        push( @arrStartUrls, $tempUrl );
		push( @arrStartUrls, $linkDocSumm );
		print FEEDLOG "Web path URL: $tempUrl\n";
		print FEEDLOG "Web path URL: $linkDocSumm\n";
	    }
	    else {
		print FEEDLOG "Web path URL: $tempUrl?SQ_DESIGN_NAME=search_clean\n";
	        push( @arrStartUrls, "$tempUrl?SQ_DESIGN_NAME=search_clean" ); # If a web page, use the search_clean template
	    }
	}
    }
    else {
	push( @arrStartUrls, $temp ); # If it's not a web path list, we still want to download it (e.g. on manual instant update)
    }
}

close( WEBPATHS );
close( STARTURLS );

# Write the URLs back to the start URLs file.
if ( not open( STARTURLS, ">", $fileStartUrls ) ) {
    warn "EC Pre-Gather-Instant: Unable to write to file $fileStartUrls ($!)";
    return;
}

print STARTURLS "$_\n" foreach ( @arrStartUrls );

close( STARTURLS );

$now = scalar localtime;
print FEEDLOG "Pre-gather finished at $now\n\n";
close( FEEDLOG );

exit 0;



# Using the assetid, check for any previously downloaded versions of the asset
# and add them to a kill list.
sub killAsset {
    my $strAssetId = shift;
    my $strFolderPath = shift;
    my $strFileKill = shift;

    $strFolderPath =~ s/collection\.cfg//;
    my $strFilePath = $strFolderPath;
    $strFilePath =~ s/conf\//data\//;
    $strFilePath .= 'live/secondary-data/';
    my @webPaths = ( 
	$strFolderPath . 'master-list.cfg', 
	$strFolderPath . 'feed-web-paths.cfg'
    );

    if ( not open( KILLLIST, ">", $strFileKill ) ) {
        warn "EC Pre-Gather-Instant: Unable to write to file $strFileKill ($!)";
        return;
    }

    foreach ( @webPaths ) {
    	if ( not open( CHECKLIST, "<", $_ ) ) {
            warn "EC Pre-Gather-Instant: Unable to read file $_ ($!)";
            return;
        }

	my @webPathContent = <CHECKLIST>;
	close( CHECKLIST );
	my $webPathContent = join( "", @webPathContent );

	while ( $webPathContent =~ m/<a href="([^"]+)">(\d+)<\/a>/g ) {
	    my $tempUrl = $1;
	    my $tempId = $2;
	    my $tempPath = '';
	    if ($tempId eq $strAssetId ) {
		$tempUrl =~ s/\.(pdf|xls|doc|ppt|zip|jpg|mpg|mpeg|mp3)\?SQ_DESIGN_NAME=search_clean/.$1/i;
		# Need to delete the downloaded copy as well, otherwise it will just be reindexed.
		$tempPath = $strFilePath . $tempUrl;
		$tempPath =~ s/http\:\/\//http\//;
		$tempPath =~ s/\.(pdf|xls|doc|ppt|zip|jpg|mpg)/.$1.pan.txt/i;
		unlink $tempPath or print "EC Pre-Gather-Instant: Unable to delete $tempPath\n";
		print KILLLIST "$tempUrl\n";
	    }
	}
    }

    close( KILLLIST );

    # Kill any URLs for that asset from both the primary and secondary indexes.
    system("/opt/funnelback/bin/padre-fl", "/opt/funnelback/data/electoral-commission/live/idx/index", "/opt/funnelback/conf/electoral-commission/kill-list-instant.cfg", "-exactmatch", "-kill");
    if(-e '/opt/funnelback/data/electoral-commission/live/idx/index_secondary.dt'){ system("/opt/funnelback/bin/padre-fl", "/opt/funnelback/data/electoral-commission/live/idx/index_secondary", "/opt/funnelback/conf/electoral-commission/kill-list-instant.cfg", "-exactmatch", "-kill");
    }
}

