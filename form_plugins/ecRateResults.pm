package Funnelback::FormPlugin::ecRateResults;
use strict;
use warnings;

use CGI;
use Funnelback::CGIExtras;
use Funnelback::NumbersTextTimes ();

sub process {
    my $nickscript = shift;
    my $attributes = shift;
    my $link_description = shift;
    my $class = '';
    my $rating = 'unknown'; 
    my $email = '';
    my $title = '';
    my $result_title = '';

	$rating = $attributes->{'rating'} if exists $attributes->{'rating'};
	$email = $attributes->{'email'} if exists $attributes->{'email'};
	$class = $attributes->{'class'} if exists $attributes->{'class'};
	$result_title = $attributes->{'result_title'} if exists $attributes->{'result_title'};

#    if (!defined($attributes)) {
#        $attributes = '';
#    }
#    else {
#        $rating = $1 if ($attributes =~ m/rating=['"](.+?)['"]/i);
#        $email = $1 if ($attributes =~ m/email=['"](.+?)['"]/i);
#        $class = $1 if ($attributes =~ m/class=['"](.+?)['"]/i);
#	$result_title = $1 if ($attributes =~ m/result_title=['"](.+?)['"]/i);
#    }

    if ($rating eq 'good') {
        $title = ' title="Yes - I found this search result helpful"';
    } 
    elsif ($rating eq 'bad') {
        $title = ' title="No - I did not find this search result helpful"';
    }

    # If no service name was specified in the form, use the display name of the collection as a description
    unless ( defined($link_description) and length($link_description) > 0 ) {
        $link_description = "Feedback";
    }

    my $cgi = new CGI;
    my $url = $cgi->self_url();
    $url = CGI::escape($url);

    my $parsed_query = CGI::escape(join( ' ', $nickscript->get_padre_query() ));
    # For some bizarre reason the parsed query at this stage is URL encoded and HTML encoded. Although
    # I hate to have to account for what is clearly a padre error here, this is safer than probably breaking
    # everything that relies on padre's strange behaviour.
    $parsed_query = CGI::escape(Funnelback::NumbersTextTimes::HTML_decode(CGI::unescape($parsed_query)));
    my $collection = $nickscript->get_collection();
    my $querystring = $ENV{'QUERY_STRING'};
    $querystring =~ s/&/AMP/g;   
 
    my $result;
    $result = "<a href='http://bureau-query.funnelback.co.uk/search/rate_results.tcgi?collection=$collection&amp;query=$parsed_query&amp;rating=$rating&amp;email=$email&amp;querystring=$querystring&amp;redirect=http://www.electoralcommission.org.uk/search_fb&amp;result_title=$result_title' class='$class'$title>$link_description</a>";

    return $result;
}

1;
