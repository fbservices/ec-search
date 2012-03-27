package Funnelback::FormPlugin::ecRelatedResultsTest;
use strict;
use warnings;
use Data::Dumper;

use CGI qw(-oldstyle_urls :standard);

sub process {
    my $nickscript = shift;
    my $attributes = shift;
    my $result = '';
    my $form = 'plugin';
    my $checkField = '';
    my $restrictTo = '';
    my $numRanks = '5';

#    $attributes = '' if (!defined($attributes));
#    ($form) = $attributes =~ m/form=['"](.*?)['"]/i;
#    ($checkField) = $attributes =~ m/check-field=['"](.*?)['"]/i;
#    ($restrictTo) = $attributes =~ m/restrict-to=['"](.*?)['"]/i;
#    ($numRanks) = $attributes =~ m/num-ranks=['"](.*?)['"]/i;
    $form = $attributes->{'form'} if exists $attributes->{'form'};
    $checkField = $attributes->{'check-field'} if exists $attributes->{'check-field'};
    $restrictTo = $attributes->{'restrict-to'} if exists $attributes->{'restrict-to'};
    $numRanks = $attributes->{'num-ranks'} if exists $attributes->{'num-ranks'};

    if ($restrictTo =~ m/,/) {
        $restrictTo =~ s/,/" "/g;
        $restrictTo = '["' . $restrictTo . '"]';
    }

    $result = doSearch($form, $checkField, $restrictTo, $numRanks);

    return $result;
}

1;


sub doSearch {
    my $formName = shift;
    my $mdField = shift;
    my $mdQuery = shift;
    my $num_ranks = shift;

    our $orig_query_string = query_string();
    our $cgi = new CGI();
    our $SEARCH_HOME = Funnelback::Platform::search_home();
    our ( $collection, $collection_obj ) = Funnelback::SearchInterface::pre_search( $SEARCH_HOME, $cgi );

    # Get the profile and form information
    our $profile = Funnelback::CGIExtras::getCGIParam($cgi,  'profile', Funnelback::CGIExtras::TYPE_PROFILE );
    $profile = undef if ( defined($profile) && $profile eq '' );

    # Choose an encoding
    my $encoding = Funnelback::CGIExtras::getCGIParam($cgi,  'enc', Funnelback::CGIExtras::TYPE_UNKNOWN ) || 'UTF-8';
    if ( $encoding ne 'UTF-8' && $encoding ne 'ISO-8859-1' ) {
        $encoding = 'UTF-8';          # White-list filter
    }

    unless ($collection) {
        # As this plugin is desinged to be called from with an existing form template
        # there is no need to printHeader again.
        print "<div class='pluginError'>"; 
        print "<h1>Plugin Error</h1>";
        print "<p>The collection name was not found.</p>";
        print "</div>";

        # Run any post-search code
        Funnelback::Utils::search_append_include();
        exit;
    }

# Number of results to display is configurable, but we shouldn't ever want tierbars or partial matches
$cgi->param(-name=>'fmo', -value=>'on');
$cgi->param(-name=>'tierbars', -value=>'off');
$cgi->param(-name=>'num_ranks', -value=>$num_ranks);
$cgi->param(-name=>'start_rank', -value=>'1');
my $cgi_params_ref = $cgi->Vars();
my $q = $cgi_params_ref->{'query'};
    # Remember that our CGI params are either UTF8 strings or plain ASCII,
    # so encode appropriately.
    %{$cgi_params_ref} = map
                         { $_ => Encode::decode_utf8($cgi_params_ref->{$_}) }
                         keys %{$cgi_params_ref};

    our ($padrequery) = Funnelback::Padre::buildPadreQuery( $encoding, $SEARCH_HOME, $collection, $cgi_params_ref );

    unless ( defined($profile) and ( open IN, "$SEARCH_HOME/conf/$collection/$profile/$formName.form" ) ) {
        # Fallback to main form if no profile or profiled form doesn't exist
        unless ( open IN, "$SEARCH_HOME/conf/$collection/$formName.form" ) {
            print "<div class='pluginError'>";
            print "<h1>Search Error</h1>";
            print "The $formName form does not exist.";
            print "</div>";
            # Exit here if there is no form
            exit(1);
        }
    }

    read IN, my ($resultspage), -s IN;

    # init nickscript with the collection config now, since
    # security_check() depends on this
    our $nickscript = Funnelback::Nickscript->new();
    $nickscript->set_collection_obj($collection_obj);

#if($padrequery eq ""){$padrequery = $q;}
# Modify original query to include restriction parameters
$padrequery .= ' ' . $mdField . ':' . $mdQuery;

    my $customText;
    ( $customText, $padrequery ) = Funnelback::SearchInterface::perform_query_transforms( $SEARCH_HOME, $padrequery, $collection, $nickscript );

    my $padre_query_string = Funnelback::Padre::get_encoded_padre_query_string( $SEARCH_HOME, $padrequery, $cgi_params_ref );

    our $xml                  = '';
    our $padrestatus          = '';
    our %extra_search_sources = ();
    # Don't need Fluster results, so just set to false
    our $FlusterEnabled = '';
    our $integratedPadreFluster = '';

    if ( length($padrequery) > 0 ) {
        # These settings seem to be relevant for the new Query processor API/Messaging. Leaving
        # in here, but definitely untested.
        # Get any subqueries
        my $extra_url_names = $collection_obj->get('search_source.extra_url_names');

        if ($extra_url_names) {
            for my $ex_name ( split /,/, $extra_url_names ) {
                my $url = $collection_obj->get("search_source.url.$ex_name");

                if ($url) {
                    my $qp_api;
                    eval { $qp_api = $qp_factory->produce_qp_from_url($url); };

                    if ($@) {
                        $extra_search_sources{$ex_name} = "Error getting subresults: $@";
                    }
                    else {
                        my $new_query_string = Funnelback::CGIExtras::morph_query_string_for_extra_search_source( $padre_query_string, $ex_name );
                        $new_query_string =~ s/(?:^|\&)query=([^\&]*)//;
                        $qp_api->setQuery($1);
                        $qp_api->{'QUERY_STRING'} = $new_query_string;
                        $qp_api->performQuery();
                        $extra_search_sources{$ex_name} = $qp_api;
                    }
                }
	    }
        }
    }

    my ( $qp_api, $query_to_pass, $timeout_to_use ) = $qp_factory->produce_qp_from_collection_and_query_string_and_default_timeout( $collection_obj, $padre_query_string, 30 );

    $qp_api->set_query_processor_options("-fluster") if $integratedPadreFluster;
$qp_api->set_query_processor_options("-nolog");
    $xml = $qp_api->performQueryAndWaitForResults( $query_to_pass, $timeout_to_use );
    $padrestatus = $qp_api->getStatusCode();
    $qp_api->disconnect();

    # Disconnect from the extra qp_apis
    for my $key (keys %extra_search_sources) {
        my $qp_api = $extra_search_sources{$key};
        if (ref($qp_api) =~ /QueryProcessing/) {
            my $timeout = $collection_obj->get('search_source.query_timeout_seconds');
            $timeout = 10 unless $timeout or $timeout eq '0';
            eval {
                $qp_api->waitForResults($timeout);
            };
            warn ("<!-- ERROR : Getting Extra Results\n $@ -->") if $@;
            $qp_api->disconnect();
	}
    }

    $nickscript->set_search_home($SEARCH_HOME);
    $nickscript->set_encoding($encoding);
    $nickscript->set_collection($collection);
    $nickscript->set_custom_text($customText);
    $nickscript->set_padre_query_string($padre_query_string);
    $nickscript->set_profile($profile);
    $nickscript->set_form($formName);
    $nickscript->set_padre_query($padrequery);
    $nickscript->set_xml($xml);
    $nickscript->set_padre_status($padrestatus);
    $nickscript->set_original_query_string($orig_query_string);
    $nickscript->set_results_page($resultspage);
    $nickscript->set_params_hash($cgi_params_ref);

    $resultspage = $nickscript->final_html();
    
    return $resultspage;
}

