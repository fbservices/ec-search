package Funnelback::FormPlugin::ecThesaurus;

use strict;
use warnings;

use CGI qw(-oldstyle_urls :standard);

sub process {
    my $nickscript       = shift;
    my $attributes       = shift;
    my $collection       = '';
    my $collectionPath   = '';
    my $result           = '';
    my @thesaurii        = ();
    my $allowedThesaurus = '';

    # Include libraries
    $ENV{"SEARCH_HOME"} =~ /^(.+)$/;    # untaint this variable
    my $SEARCH_HOME = $1;

    # Get the collection details
    ($collection) = query_string() =~ m/collection=([^&]*)/i;

#    if ( !defined($attributes) ) {
#        $attributes = '';
#    }
#    else {
#        $allowedThesaurus = $1 if $attributes =~ m/thesaurus=['"](.+?)['"]/i;
#    }
    $allowedThesaurus = $attributes->{'thesaurus'} if exists $attributes->{'thesaurus'};


    $collectionPath = $SEARCH_HOME . '/conf/' . $collection;
    @thesaurii      = getThesaurusFiles($collectionPath);

    # Get the full query values (query plus meta) to loop through later
    my $cgi        = new CGI;
    my %cgi_params = $cgi->Vars();

    my %full_query = ();
    while ( my ( $param, $value ) = each %cgi_params ) {
        if ( $param =~ m/^(query|meta)/ ) {
            $full_query{$param} = $value;
        }
    }

    # Need the thesaurus file to do all the checking, so quit out if not found.
    if ( !@thesaurii ) {
        $result =
"<div class='pluginError'>\n<h1>Plugin Error</h1>\n<p>No thesaurii were found.</p>\n</div>\n";
        return $result;
    }
    else {
        foreach (@thesaurii) {
            my $thesaurusTitle = $_;
            $thesaurusTitle =~ s/\.thesaurus$//;
            $thesaurusTitle =~ s/-/ /g;

            if (   ( $allowedThesaurus eq '' )
                || ( $allowedThesaurus eq $thesaurusTitle ) )
            {
                $result .=
                  checkForMatches( $_, $collectionPath, $thesaurusTitle,
                    \%full_query );
            }
        }
    }

    return $result;
}

1;

sub getThesaurusFiles {
    my $folderPath     = shift;
    my @thesaurusFiles = ();

    opendir( DIR, $folderPath ) || die "Can't open directory $folderPath\n";
    @thesaurusFiles = grep( /\.thesaurus$/, readdir(DIR) );
    closedir(DIR);

    return @thesaurusFiles;
}

sub checkForMatches {
    my $filePath      = shift;
    my $folderPath    = shift;
    my $title         = shift;
    my $queryRef      = shift;
    my $suggestions   = '';
    my $instanceFound = 0;

    my $thesaurusPath = $folderPath . '/' . $filePath;

    unless ( open( THESAURUS, "<$thesaurusPath" ) ) {
        print
"<div class='pluginError'>\n<h1>Plugin Error</h1>\n<p>Could not find thesaurus file: $thesaurusPath.</p>\n</div>";
        exit(1);
    }

    $suggestions .= '<div class="thesaurus-suggestions">';
    $suggestions .= '<h4>' . $title . '</h4>';
    $suggestions .= '<p>Have you tried:</p><ul>';

# TODO - Would it be more efficient to slurp the entir file and do a regex rather than line-by-line?
  READTHESAURUS: while (<THESAURUS>) {
        my $line = $_;
        next READTHESAURUS if ( $line =~ m/^#/ );

        $line =~ m/^(.+)=(.+)$/;
        my $origTerms      = $1;
        my $suggestedTerms = $2;
        my @origTerms =
          split( /,/, $origTerms );    #There can be multiple terms to relate
        my @suggestedTerms =
          split( /,/, $suggestedTerms ); #There can be multiple terms to suggest

      ORIGTERMS: foreach (@origTerms) {

            my $term = $_;
            $term =~ s/^\s+//;
            $term =~ s/\s+$//;

# Loop through the query hash and check each value against the current thesaurus entry
            foreach my $key ( keys %$queryRef ) {

# Check for a match (thesaurus original term has to exactly match a substring in the query)
                if ( $queryRef->{$key} =~ m/\b$term\b/i ) {
                    foreach (@suggestedTerms) {
                        my $suggestedTerm = $_;
                        $suggestedTerm =~ s/^\s+//;
                        $suggestedTerm =~ s/\s+$//;

# TODO - Change this to use the Encode library
# suggestedTerm is the displayable version. suggestedSearchTerm willbe HTML encoded.
                        my $suggestedSearchTerm = $suggestedTerm;
                        $suggestedSearchTerm =~ s/\s/%20/g;

             # term is the displayable version. searchTerm will be HTML encoded.
                        my $searchTerm = $term;
                        $searchTerm =~ s/\s/%20/g;

                        # TODO - Has to be a better way of managing this part.
                        my $test = $queryRef->{$key};
                        $test =~ s/$term/$suggestedTerm/i;
                        $suggestedTerm = $test;

                        # Create the link to the suggested search.
                        my $suggestedSearch = query_string();
                        $suggestedSearch =~
                          s/$searchTerm/$suggestedSearchTerm/ig;

                        $suggestions .=
                            '<li><a href="'
                          . $ENV{SCRIPT_NAME} . '?'
                          . $suggestedSearch . '">'
                          . $suggestedTerm . '</a>';
                        $suggestions .= '</li>';
                    }

                    $instanceFound = 1;
                }
            }
            last READTHESAURUS if $instanceFound == 1;
        }
    }
    $suggestions .= '</ul>';
    $suggestions .= '</div>';
    $suggestions = '' if $instanceFound == 0;

    return $suggestions;
}

# Reads in the specified thesaurus file and checks for an expansion. Returns the expansion
# text (if any).
sub checkThesaurus {
    my $file                = shift;
    my $query               = shift;
    my $checkQueries        = shift;
    my $expansion           = '';
    my $tokenExpansionFound = 0;
    my $expandedKey         = '';
    my $expandedValue       = '';

    my $FB_PATH = Funnelback::Platform::search_home();

    my ($collection) = $query =~ m/collection=([^&]*)/i;
    $file = $FB_PATH . '/conf/' . $collection . '/' . $file . '.cfg';

    my $temp         = '';
    my $strMetaField = '';
    my %metaQueries  = ();

# Split the 'check these fields' parameter by commas. This gives us the metadata search fields
# that will need to be checked for a transformation.
    my @arrMetaFields = split( /,/, $checkQueries );

  # Search the query string for any parameters that have been entered, grab them
  # and add to an array that will be used for checking the thesaurus file.
    foreach $strMetaField (@arrMetaFields) {
        ($temp) = $query =~ m/meta_$strMetaField=([^&]*)/;
        $metaQueries{$strMetaField} = $temp;
    }

    unless ( open( THESAURUS, "<$file" ) ) {
        print
"<div class='pluginError'>\n<h1>Plugin Error</h1>\n<p>Could not find thesaurus file: $file.</p>\n</div>";
        exit(1);
    }

  EXPANSION: while (<THESAURUS>) {
        if ( $_ =~ m/^#/ ) {
            next EXPANSION;
        }

        my ($line) = $_;
        chomp($line);

        my $key;
        foreach $key ( keys %metaQueries ) {
            if ( $line =~ m/$key=$metaQueries{$key}=(.*)/i ) {
                $expandedValue       = $1;
                $expandedKey         = $key;
                $tokenExpansionFound = 1;
                last EXPANSION;
            }
        }
    }

    %metaQueries = ();

    if ( $tokenExpansionFound != 0 ) {
        $metaQueries{$expandedKey} = $expandedValue;
    }

    close(THESAURUS);

    return %metaQueries;
}
