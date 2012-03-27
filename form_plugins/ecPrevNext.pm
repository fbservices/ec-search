package Funnelback::FormPlugin::ecPrevNext;
use strict;
use warnings;

use lib '/opt/funnelback/lib/perl';
use Funnelback::Utils;

sub process {
    my $nickscript = shift;
    my $attributes = shift;
    my $content = shift;

    my $prevText = 'Previous';
    my $nextText = 'Next';
    my %resultdata = $nickscript->generate_result_data();
    my $anyresults = scalar @{ $nickscript->{'results'} };
    # my %cfg = $nickscript->{'collection_obj'};

    my $uiSearchLink = 'search_matrix.cgi';

    my $orig_query_string = $nickscript->get_original_query_string();

    # The asset listing Matrix asset has a hardcoded querystring of form=xxx&collection=xxxx&scope=
    # This was getting repeated within the results navigation links. These lines get rid of them.
    $orig_query_string =~ s/form=(.+?)&form=(.+?)&/form=$1&/g;
    $orig_query_string =~ s/collection=(.+?)&collection=(.+?)&/collection=$1&/g;
    $orig_query_string =~ s/scope=(.*?)&scope=(.*?)&/scope=$1&/g;

    return ""
      unless $anyresults
      and ( $resultdata{num_ranks} or $resultdata{currstart} );
    my $retval = "";

    
    # Retrieve the label attribute
    #my ($label) = $attributes =~ /label=("[^"]+"|\S+)/i;
    my $label='';
    $label = $attributes->{'label'} if exists $attributes->{'label'};

    # Retrieve the separator attribute
    #my ($separator) = $attributes =~ /separator=("[^"]+"|\S+)/i;
    my $separator=' ';
    $separator = $attributes->{'separator'} if exists $attributes->{'separator'};

    # Retrieve the form attribute
    #my ($form) =  $attributes =~ /form=("[^"]+"|\S+)/i;
    my $form='';
    $form = $attributes->{'form'} if exists $attributes->{'form'};

    # Retrieve the next and previous text to use
    #$nextText = $1 if $attributes =~ /next=("[^"]+"|\S+)/i;
    #$prevText = $1 if $attributes =~ /previous=("[^"]+"|\S+)/i;
    $nextText = $attributes->{'next'} if exists $attributes->{'next'};
    $prevText = $attributes->{'previous'} if exists $attributes->{'previous'};

    # Set defaults
    #$separator = " " if ( not defined $separator );
    #$label     = ""  if ( not defined $label );

    # HTML decode
    $separator =~ s/&lt;/</g;
    $separator =~ s/&gt;/>/g;
    $separator =~ s/&#34;/"/g;
    $label     =~ s/&lt;/</g;
    $label     =~ s/&gt;/>/g;
    $label     =~ s/&#34;/"/g;

    # Remove leading and trailing quotes
    if ($form) {
        $form      =~ s/^"//;
        $form      =~ s/"$//;
    }
    $label     =~ s/^"//;
    $label     =~ s/"$//;
    $separator =~ s/^"//;
    $separator =~ s/"$//;
    $prevText  =~ s/^"//;
    $prevText  =~ s/"$//;
    $nextText  =~ s/^"//;
    $nextText  =~ s/"$//;

    if (defined $form) {
	$orig_query_string =~ s/form=([^&]+)/form=$form/;	
    }

    if ($orig_query_string =~ m/\&sq=([^&]+)/) {
	my $sq = $1;
	$orig_query_string =~ s/\&query=([^&]+)/\&query=$sq/;
    }

    # Do "Prev" link, if any
    if ( $resultdata{prevstart} ) {
        # my $url = $cfg{ui_search_link} . "?" . $orig_query_string;
        my $url = "?" . $orig_query_string;
        $url = Funnelback::CGIExtras::changeParam( $url, "start_rank", $resultdata{prevstart} );
        $url =~ s/&/&amp;/g;
        $retval .= "<a href=\"$url\"><< $prevText</a>&nbsp;";
    } elsif ( $resultdata{fully_matching} ) {
	$retval .= "";
    }

    # Do e.g. 10 pages of available results
    my $pages;
    if ( $resultdata{fully_matching} ) {
        $pages = int(
            (
                $resultdata{fully_matching} + $resultdata{partially_matching} +
                  $resultdata{num_ranks} - 1
            ) / $resultdata{num_ranks}
        );
    }
    else {
        $pages =
          int( ( $resultdata{total_matching} + $resultdata{num_ranks} - 1 ) /
              $resultdata{num_ranks} );
    }

    my $curr_page;
    if ( $resultdata{currstart} && $resultdata{num_ranks} ) {
        $curr_page =
          int( ( $resultdata{currstart} + $resultdata{num_ranks} - 1 ) /
              $resultdata{num_ranks} );
    }
    else {
        $curr_page = 1;
    }

    my $first_pg = 1;
    $first_pg = $curr_page - 4 if $curr_page > 4;
    for ( my $pg = $first_pg ; $pg < $first_pg + 10 ; $pg++ ) {
        last if $pg > $pages;
        if ( $pg == $curr_page ) {

            # Current page, so no href
            $retval .= "$pg&nbsp;";
        }
        else {
		    # Do link to page $pg
            # my $url = $cfg{ui_search_link} . "?" . $orig_query_string;
            my $url = "?" . $orig_query_string;
            $url =
              Funnelback::CGIExtras::changeParam( $url, "start_rank",
                ( $pg - 1 ) * $resultdata{num_ranks} + 1 );
            $url =~ s/&/&amp;/g;
            $retval .= "<a href=\"$url\">$pg</a>&nbsp;";
        }
        $retval .= " $separator "
          unless ( ( $pg == $first_pg + 9 ) or ( $pg > $pages - 1 ) );
    }

    # Do "Next" link, if any
    if ( $resultdata{nextstart} ) {
        # my $url = $cfg{ui_search_link} . "?" . $orig_query_string;
        my $url = "?" . $orig_query_string;
        $url = Funnelback::CGIExtras::changeParam( $url, "start_rank", $resultdata{nextstart} );
        $url =~ s/&/&amp;/g;
        $retval .= "<a href=\"$url\" >$nextText >></a>";
    } elsif ( $resultdata{fully_matching} ) {
	$retval .= "";
    }

    return "" if $retval and $retval =~ m@^\s*<li class="selected"><a href="#">1</a></li>\s*$@;

    # Add the label if the return value is not empty
    $retval = "$label $retval" if ( $retval =~ /\S/ );
    return $retval;
}

1;
