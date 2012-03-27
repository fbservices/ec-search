#!/usr/bin/perl -w

# Description: General pre-processing script. Functions:
# - Extract better titles for document summaries
# - Mark documents as news releases
#
# TODO:
# - Investigate storing reg ex patterns for efficiency

use strict;
use File::Find;
use Switch;

# Put this require statement into a BEGIN block so 
# that we can import the constants.
BEGIN {
    $ENV{"SEARCH_HOME"} =~ /^(.+)$/; # untaint this variable
    my $SEARCH_HOME = $1;
    push @INC, "$SEARCH_HOME/custom_bin";
}

use ElectoralCommission::ECUtils;

my %sections = (
	'about-us' => 'About us',
        'aboutus' => 'About us',
	'boundaryreviews' => 'Boundary reviews',
	'elections' => 'Elections',	
	'guidance' => 'Guidance',
	'news-and-media' => 'News and media',
	'newsandmedia' => 'News and media',
	'partyfinance' => 'Party finance',
	'performancestandards' => 'Performance standards',
	'publicationsresearch' => 'Publications and research'
);

my %sections_cymraeg = (
	'About us' => 'Amdanom ni',
	'Boundary reviews' => 'Adolygiadau Ffiniau',
	'Elections' => 'Etholiadau',
	'Guidance' => 'Gyngor',
	'News and media' => 'Newyddion a Chyfryngau',
	'Party finance' => 'Parti cyllid',
	'Performance standards' => 'Safonau perfformiad',
        'Publications and research' => 'Cyhoeddiadau ac ymchwil'
);

my %types = (
	'Advertising' => 'Advertising',
	'Alert' => 'Alert',
	'Annual_accounts' => 'Annual accounts',
	'Annual_report' => 'Annual report',
	'Briefing' => 'Briefing',
	'Case_studies' => 'Case studies',
	'Circular' => 'Circular',
	'Corporate_plan' => 'Corporate plan',
	'Consultation_paper' => 'Consultation paper',
	'Correspondence' => 'Correspondence',
	'Data' => 'Data',
        'Diary_or_calendar' => 'Diary or calendar',
        'Do_Politics_materials' => 'Do Politics materials',
	'Election_report' => 'Election report',
	'Election_result' => 'Election result',
	'Executive_summary' => 'Executive summary',
	'Factsheet' => 'Factsheet',
	'Form' => 'Form',
	'Freedom_of_information_request' => 'FOI request',
	'Guidance' => 'Guidance',
	'Image' => 'Image',
	'Invitation_to_tender' => 'Invitation to tender',
	'Job_ad_/_description' => 'Job ad/description',
	'Legislative_extract' => 'Legislative extract',
	'Map' => 'Map',
	'Minutes' => 'Minutes',
	'News_release' => 'News release',
	'Newsletter_magazine' => 'Newsletter magazine',
	'Organisation_chart' => 'Organisation chart',
	'Policy_report' => 'Policy report',
	'Presentation/speech' => 'Presentation/speech',
	'Questionnaire' => 'Questionnaire',
	'Research_report' => 'Research reports',
	'Response/submission' => 'Response/submission',
        'Statement_of_accounts' => 'Statement of accounts',
	'Web_page' => 'Web page'
);

my %types_cymraeg = (
	'Advertising' => 'Hysbysebu',
        'Alert' => 'rhybudd',
        'Annual accounts' => 'Cyfrifon Blynyddol',
        'Annual report' => 'Adroddiad Blynyddol',
        'Briefing' => 'Briffio',
        'Case studies' => 'Astudiaethau Achos',
        'Circular' => 'Cylchlythyr',
        'Corporate plan' => 'Cynllun Corfforaethol',
        'Consultation paper' => 'Papur Ymgynghori',
        'Correspondence' => 'Correspondence',
        'Data' => 'Data',
        'Diary or calendar' => 'Dyddiadur neu calendr',
	'Do Politics materials' => 'Do Politics materials',
        'Election report' => 'Adroddiad etholiad',
        'Election result' => 'Ganlyniad etholiad',
        'Executive summary' => 'Crynodeb gweithredol',
        'Factsheet' => 'Factsheet',
        'Form' => 'Ffurflen',
        'FOI request' => 'Cais FOI',
        'Guidance' => 'Gyngor',
        'Image' => 'Delwedd',
        'Invitation to tender' => 'Gwahoddiad i dendro',
        'Job ad/description' => 'Hysbyseb swydd',
        'Legislative extract' => 'Echdynnu Deddfwriaethol',
        'Map' => 'Map',
        'Minutes' => 'Cofnodion',
        'News release' => 'Rhyddhau Newyddion',
        'Newsletter magazine' => 'Cylchlythyr cylchgrawn',
        'Organisation chart' => 'Siart Sefydliad',
        'Policy report' => 'Adroddiad Polisi',
        'Presentation/speech' => 'Cyflwyniad / lleferydd',
        'Questionnaire' => 'Holiadur',
        'Research reports' => 'Adroddiadau Ymchwil',
        'Response/submission' => 'Ymateb / cyflwyno',
        'Statement of accounts' => 'Datganiad o gyfrifon',
        'Web page' => 'Tudalen We'
);

my %month_cymraeg = ( 
	'Jan' => 'Ion',
	'Feb' => 'Chwe',
	'Mar' => 'Maw',
	'Apr' => 'Ebrill',
	'May' => 'Mai',
	'Jun' => 'Meh',
	'Jul' => 'Gorff',
	'Aug' => 'Awst',
	'Sep' => 'Medi',
	'Oct' => 'Hyd',
	'Nov' => 'Tach',
	'Dec' => 'Rhag'
);

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

# Remove the web paths file as following this update, the index will be in a clean state.
my $fileWebPaths = $collection_cfg;
$fileWebPaths =~ s/collection\.cfg/feed-web-paths.cfg/;
unlink $fileWebPaths;
my $fileFeedLog = $collection_cfg;
$fileFeedLog =~ s/collection\.cfg/log\/update-feed.log/;
$fileFeedLog =~ s/\/conf\//\/data\//;
unlink $fileFeedLog;

# Check that the collection's data root exists
my $data_path = $collection_info{'data_root'} . "/";
$data_path =~ s/\$COLLECTION_NAME/electoral-commission/g;
die("EC-Preprocess: Data root doesn't exist: $data_path") if ( not -d $data_path );

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

# Print out Welsh pages for gscoping
my $file_gscope = $collection_cfg;
$file_gscope =~ s/collection\.cfg/gscope-welsh.cfg/;
# Open file
if ( not open( GSCOPE, ">", $file_gscope ) ) {
    warn "EC Pre-processing: Unable to write to file $file_gscope ($!)";
    return;
}

# Recurse through the data directory and process each file
find( \&pre_process_file, $data_path );

close(GSCOPE);

# Timestamp finish
$date = scalar(localtime);
print "EC Pre-processing: Finished processing files at $date\n";

# Done
exit 0;


sub pre_process_file {
    my $file = $_;
    my $betterTitle = '';

    return if ( not defined $file );

    # Skip directories and binary documents
    # except for jpg files (special processing applies for those files)
    # The pdf, ppt, doc, mp3, mpg, zip and xls files will only be processed if a matching doc summary is found.
    if ( -d $file or $file =~ /\.(pdf|doc|xls|ppt|ps|jpg|mp3|mpeg|mpg|zip)\./i ) {
        return;
    }

    # Open file
    if ( not open( DATA, "<", $file ) ) {
        warn "EC Pre-processing: Unable to read file $file ($!)";
        return;
    }

    # Read the file contents into memory
    my @content = <DATA>;
    close(DATA);
    my $content = join( "", @content );

    my $site = '';
    my $doc_audience = '';
    my $doc_activity = '';
    my $doc_creator = '';
    my $doc_date = '';
    my $doc_date_cymraeg = '';
    my $doc_description = '';
    my $doc_lang = '';
    my $doc_path = '';
    my $doc_section = '';
    my $doc_section_cymraeg = '';
    my $doc_size = '';
    my $doc_spatial = '';
    my $doc_subject = '';
    my $doc_type = '';
    my $doc_type_cymraeg = '';
    my $doc_url = '';
    my $doc_sort = '';
    my $doc_upweight = '';

    #-------- START: GET METADATA VALUES ---------
    $doc_path = $File::Find::name;
    $doc_url = $doc_path;
    $doc_url =~ s/$data_path//;
    $doc_url =~ s/http\///;
    $doc_url =~ s/\.pan\.txt//;
    $doc_url =~ s/\/_default.fun.html//;
    $doc_url =~ s/(\?SQ_DESIGN_NAME=search_clean)/\\$1/;
    $site = 'www.electoralcommission.org.uk';
    $site = 'www.dopolitics.org.uk' if ( $doc_path =~ m/\.dopolitics\.org\.uk/ );
    $doc_date = $1 if ( $content =~ m/<meta name="Modified" content="(.+?)" \/>/ );

    if ( $doc_date =~ m/\d\d (.+) \d\d\d\d/ ) {
        my $temp_month = $1;
        $doc_date_cymraeg = $doc_date;
        $doc_date_cymraeg =~ s/$temp_month/$month_cymraeg{$temp_month}/;
    }

    $doc_section = $1 if ( $content =~ m/<meta name="search_section" content="(.+?)" \/>/ );
    # 'News and media' and 'about us' pages are assigned a section manually as currently they're all 'guidance'
    # This is incorrect but would take ages to get done in Matrix.
    $doc_section = $1 if ($doc_path =~ m/electoralcommission\.org\.uk\/(about-us|news-and-media)/);
    $doc_section = $sections{$doc_section} if ( defined $sections{$doc_section} );
    $doc_section_cymraeg = $sections_cymraeg{$doc_section} if ( defined $sections_cymraeg{$doc_section} );

    if ( $content =~ m/<language>(.+?)<\/language>/ ) {
        $doc_lang = $1;
    }
    elsif ( $content =~ m/<meta name="Language" content="(.+?)" \/>/ ) {
	$doc_lang = $1;
    }

    if ( $content =~ m/<doctype>(.+?)<\/doctype>/ ) {
	$doc_type = $1;
    }
    elsif ( $content =~ m/<meta name="Type" content="(.+?)" \/>/ ) {
	$doc_type = $1;
    }
    $doc_type = $types{$doc_type} if (defined $types{$doc_type});
    $doc_type_cymraeg = $types_cymraeg{$doc_type} if ( defined $types_cymraeg{$doc_type} );
    $doc_subject = $1 if ( $content =~ m/<meta name="Subject" content="(.+?)" \/>/ );
    $doc_subject .= '; ' . $1 if ( $content =~ m/<meta name="EC Subject" content="(.+?)" \/>/ );
    $doc_subject .= '; ' . $1 if ( $content =~ m/<meta name="BC Subject" content="(.+?)" \/>/ );
    $doc_subject =~ s/^; //;
    $doc_spatial = $1 if ( $content =~ m/<meta name="Spatial" content="(.+?)" \/>/ );
    $doc_audience = $1 if ( $content =~ m/<meta name="Audience" content="(.+?)" \/>/ );
    $doc_audience .= '; ' . $1 if ( $content =~ m/<meta name="dpaudiance" content="(.+?)" \/>/ );
    $doc_activity = $1 if ( $content =~ m/<meta name="dpactivity" content="(.+?)" \/>/ );
    $doc_description = $1 if ( $content =~ m/<meta name="dc.description" content="(.*?)" \/>/msi ); # This has to check multilines, as sometimes they put carriage returns in their metadata...
    if($doc_description eq ''){ 
      # try regular description
      $doc_description = $1 if ( $content =~ m/<meta name="description" content="(.*?)" \/>/msi );
    }
    $doc_description =~ s/"/'/g;  # Funnelback truncates metadata values at the first double quote, so remove any if found
    $doc_creator = $1 if ( $content =~ m/<meta name="Creator" content="(.+?)" \/>/i );
    $doc_creator = 'Do Politics Centre' if ( $site =~ m/dopolitics\.org\.uk/ );
    $doc_upweight = $1 if ( $content =~ m/<meta name="custom_upweight" content="(.+?)" \/>/i );
    #-------- END: GET METADATA VALUES ---------

    # This step may be redundant now that we're using the clean template.
    $content = ElectoralCommission::ECUtils::addNoIndexTags($content);

    # Mark as a 'news release' if applicable and disregard whatever the marked 'section' value is.
    if ($content =~ m/<BASE HREF="http\:\/\/www\.electoralcommission\.org\.uk\/news-and-media\/news-releases\/.+?\/(.+?)\/.+?">/) {
        $content =~ s/<meta name="search_section" content=".+?" \/>//g;
	$content =~ s/<\/head>/<meta name="search_section" content="News release" \/>\n<\/head>/;
	$doc_section = 'News release';	

        if ( $content =~ m/<meta name="Issued" content="(.+?)" \/>/ ) {
            my $tempModified = $1;
            $content =~ s/(<meta name="Date" content=").+?(" \/>)/$1$tempModified$2/g;
        }
    }
    # For non-news-releases, make sure the search section is nicely formatted.
    # Also update creator value if required.
    else {
        if ($doc_section ne '') {
	    $content =~ s/<meta name="search_section" content=".+?" \/>//g;
	    $content =~ s/<\/head>/<meta name="search_section" content="$doc_section" \/>\n<\/head>/;
        }
        print "Section for $doc_url is $doc_section\n";
	# Update document with nicely formatted doc type    
	$content =~ s/<meta name="type" content="([^"]+?)" \/>/<meta name="type" content="$doc_type" \/>/g;
	# Update the creator value if required.
  	$content =~ s/<meta name="Creator" content="(.*?)" \/>/<meta name="Creator" content="$doc_creator" \/>/g;
    }

    if ($doc_path =~ m/document-summary\/_nocache\?assetid=/) {
        # Document summary pages have bad titles. The real title is in the h3 tag.
	if ($content =~ m/<h3>(.+?)<\/h3>/msi) {
	    $betterTitle = $1;
        }

	# Grab the metadata from the document asset pages and assign it to the referenced documents
	if ($content =~ m/<p><a href="(.+?)" target="_blank">Download the document<\/a><\/p>/) {
	    $doc_url = $1;
	    $doc_path = $data_path . 'http/' . $site . $doc_url . '.pan.txt';
	    $doc_size = $1 if ($content =~ m/<p><strong>File size:<\/strong> (.+?)<\/p>/);
	    $doc_date = $1 if ($content =~ m/<p><strong>Last updated\:<\/strong> (.+?)<\/p>/);

	    if ( $doc_date =~ m/\d\d (.+) \d\d\d\d/ ) {
                my $temp_month = $1;
                $doc_date_cymraeg = $doc_date;
                $doc_date_cymraeg =~ s/$temp_month/$month_cymraeg{$temp_month}/;
            }

	    if ($doc_lang =~ m/cym/) {
		print GSCOPE "3 $site$doc_url\n";
            }

	    switch ($doc_type) {
		case "FOI request" { 
		    $doc_sort = $1 if ( $betterTitle =~ m/^FOI (\d+)/ );
		}
	    }	

	    if ($doc_path =~ m/(mp3|mpg|zip)/) {
		my $doc_filetype = $1;
		$doc_type = 'Zip' if ( ( $doc_type eq '' ) && ( $doc_filetype eq 'zip' ) );
		if ($doc_path =~ m/\.(jpg)\./i) {
                    $doc_size = ElectoralCommission::ECUtils::niceSize(-s $doc_path, 0);
                }
		ElectoralCommission::ECUtils::createMediaStandin($doc_path, $doc_section, $doc_size, $doc_lang, $betterTitle, $doc_type, $doc_date,$doc_filetype,$doc_description, $doc_creator, $doc_upweight);
		print "Created: $doc_path\n\n";
	    }
	    elsif (-e $doc_path && $doc_path !~ /jpg/) {
		ElectoralCommission::ECUtils::updateDocument($doc_path, $doc_section, $doc_size, $doc_lang, $betterTitle, $doc_type, $doc_date, $doc_subject, $doc_spatial, $doc_audience, $doc_activity, $doc_section_cymraeg, $doc_type_cymraeg,$doc_description, $doc_creator, $doc_sort, $doc_date_cymraeg, $doc_upweight);	
	    }
	    else {
		print "Does not exist: $doc_path\nReferenced by: $file\n\n";
	    }
	}
    }
    else {
	# Mark any non-binary pages (web pages) for gscoping if the language is 'cym' or 'eng_cym'
        # I've added the 'cymru' directory check as some pages aren't marked with the correct language,
        # but are still in Welsh.
    	if ( ($doc_lang =~ m/cym/i) || ($doc_path =~ m/\/cymru\//) ) {
	    $content =~ s/<meta name="search_section_cymraeg" content=".*?" \/>//g;
	    $content =~ s/<\/head>/<meta name="search_section_cymraeg" content="$doc_section_cymraeg" \/>\n<\/head>/;

            $content =~ s/<meta name="type_cymraeg" content=".*?" \/>//g;
            $content =~ s/<\/head>/<meta name="type_cymraeg" content="$doc_type_cymraeg" \/>\n<\/head>/;

	    $content =~ s/<meta name="date_cymraeg" content=".*?" \/>//msg;
	    $content =~ s/<\/head>/<meta name="date_cymraeg" content="$doc_date_cymraeg" \/>\n<\/head>/;

            print GSCOPE "3 $doc_url\n";
        }
    }

    if ( not open( DATA, ">", $file) ) {
        warn "EC Pre-processing: Unable to write to file $file ($!)";
        return;
    }
   
    print DATA $content;
    close(DATA);
}
