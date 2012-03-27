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
    print "\nEC-Compile: Usage: $0 <collection config file> <live or offline>\n\n";
    exit 1;
}

die("EC-Compile: Unable to open $collection_cfg")
  if not( open( COLLECTION, "<$collection_cfg" ) );
my %collection_info = Funnelback::Config::getConfigData( \*COLLECTION );
close(COLLECTION);

# Check that the collection's data root exists
my $data_path = $collection_info{'data_root'} . "/";
die("EC-Compile: Data root doesn't exist.") if ( not -d $data_path );

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
print "EC-Compile: Processing files at $date...\n";
print "Data path: $data_path\n";

my %subjects = ();
my %spatials = ();
my %audiences = ();
my %authours = ();
my %contributors = ();
my %types = ();
my %sections = ();

# Recurse through the data directory and process each file
find( \&pre_process_file, $data_path );

writeFile("/opt/funnelback/conf/electoral-commission/count_subject.log", \%subjects);
writeFile("/opt/funnelback/conf/electoral-commission/count_spatials.log", \%spatials);
writeFile("/opt/funnelback/conf/electoral-commission/count_audiences.log", \%audiences);
writeFile("/opt/funnelback/conf/electoral-commission/count_authours.log", \%authours);
writeFile("/opt/funnelback/conf/electoral-commission/count_contributors.log", \%contributors);
writeFile("/opt/funnelback/conf/electoral-commission/count_types.log", \%types);
writeFile("/opt/funnelback/conf/electoral-commission/count_sections.log", \%sections);

# Timestamp finish
$date = scalar(localtime);
print "EC-Compile: Finished processing files at $date\n";

# Done
exit 0;


sub pre_process_file {
    my $file = $_;
    my $subject = '';
    my $spatial = '';
    my $audience = '';
    my $authour = '';
    my $contributor = '';
    my $type = '';
    my $section = '';

    return if ( not defined $file );

    # Open file
    if ( not open( DATA, "<", $file ) ) {
        warn "EC-Compile: Unable to read file $file ($!)";
        return;
    }

    # Read the file contents into memory
    my @content = <DATA>;
    close(DATA);
    my $content = join( "", @content );

    $subject = $1 if ($content =~ m/<meta name="DC\.subject" scheme="eGMS\.IPSV" content="([^"]+)" \/>/);
    $subject .= ' ' . $1 if ($content =~ m/<meta name="subject" content="([^"]+) \/>/);
    splitTerms(\%subjects, $subject, ';');

    $spatial = $1 if ($content =~ m/<meta name="DCTERMS\.spatial" scheme="eGMS\.ONSSNAC" content="([^"]+)" \/>/);
    splitTerms(\%spatials, $spatial, ';');

    $audience = $1 if ($content =~ m/<meta name="DCTERMS\.audience" scheme="eGMS\.AES" content="([^"]+)" \/>/);
    splitTerms(\%audiences, $audience, ';');

    $authour = $1 if ($content =~ m/<meta name="author" content="([^"]+)" \/>/);
    splitTerms(\%authours, $authour, ';');

    $contributor = $1 if ($content =~ m/<meta name="DC.contributor" content="([^"]+)" \/>/);
    splitTerms(\%contributors, $contributor, ';');

    $type = $1 if ($content =~ m/<meta name="type" content="([^"]+)" \/>/);
    splitTerms(\%types, $type, ';');

    $section = $1 if ($content =~ m/<meta name="search_section" content="([^"]+)" \/>/);
    splitTerms(\%sections, $section, ';');
}

sub splitTerms {
    my $refHash = shift;
    my $metadata = shift;
    my $splitOn = shift;

    my @arrMetadata = split(/$splitOn/, $metadata);
    foreach (@arrMetadata) {
        my $temp = $_;
        $temp =~ s/^\s//g;
        $temp =~ s/\s$//g;

        if (defined $refHash->{$temp}) {
	    $refHash->{$temp}++;
	}
	else {
	    $refHash->{$temp} = 1;
	}
    }
}

sub writeFile {
    my $file = shift;
    my $refHash = shift;

    if ( not open( LOG, ">", $file) ) {
        warn "EC-Compile: Unable to write to file $file ($!)";
        return;
    }

    foreach my $key (sort (keys(%$refHash))) {
        print LOG $key . ',' . $refHash->{$key} . "\n";
    }

    close(LOG);
}
