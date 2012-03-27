#!/usr/bin/perl -w

use strict;
#use lib '/opt/funnelback/lib/perl/';
#use File::Find;
#use Funnelback::Config;

# Include libraries
$ENV{"SEARCH_HOME"} =~ /^(.+)$/; # untaint this variable
my $SEARCH_HOME = $1;

# Build the list of hash names 
# format, one entry per line (lines starting with '#' ignored): <collection id>|<allowed docs>

my $col_lic = "/opt/funnelback/custom_bin/check-licences.cfg";

if (not open(COLLIC,  "<", $col_lic)) {
    warn "Funnelback licence check: Unable to read config file $col_lic ($!)";
    exit 1;
}
my @lic_data = <COLLIC>;
my $lic='';
# build hash
my %hash = ();
foreach $lic (@lic_data)
{
	chomp($lic);
	if ($lic =~ m/(.+?)\|(.*)/)	
	{
		$hash{ $1 } = $2;
	}
}

close(COLLIC);
#rprint out hash to check that this is working ok!

#while ( my ($key, $value) = each(%hash) ) {
#        print "$key => $value\n";
#    }

# go through all the defined collections and check their doc counts against the licence limit.
my $actual_docs="";
my $report="";
while ( my ( $key, $value ) = each( %hash ) ) {
	#download the collection docnum count

print "Checking collection: $key (licenced for $value)\n";
	my $col_data = `echo "licence check" \| \/opt\/funnelback\/bin\/padre-sw \/opt\/funnelback\/data\/$key\/live\/idx\/index -res xml -nolog`;
	$col_data =~ m/<collection_size>(.+?)<\/collection_size>/;
	$actual_docs = $1 if ($col_data =~ m/(\d+) docs/);
 
	my $status = "OK";
	$status = "DOCUMENT COUNT OVER LIMIT" if ($actual_docs > $value); 

	$report.="$key: Allowed docs: $value\; Actual docs: $actual_docs\; Status: $status\n";


}

print "\n\nLicence status report for installed collections\n";
print $report;

#email the report to the administrator

my $sendmail = '/usr/lib/sendmail'; 
open(MAIL, "|$sendmail -oi -t"); 
print MAIL "From: System administrator (crawl01.squiz.co.uk)\n";
print MAIL "To: plevan\@funnelback\.com\n";
print MAIL "Subject: Licence status report for crawl01.squiz.co.uk\n\n";
print MAIL "\n\nLicence status report for installed collections\n$report\n"; 
close(MAIL); 



exit 0;




