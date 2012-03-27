package ElectoralCommission::ECUtils;
use strict;
use warnings;

use File::Path;

# Create a standin document for media files that are not normally indexable (e.g. mp3, mpg, jpgi, zip)
sub createMediaStandin {
    my $file = shift;
    my $md_section = shift;
    my $md_size = shift;
    my $md_lang = shift;
    my $md_title = shift;
    my $md_type = shift;
    my $md_date = shift;
    my $md_filetype = shift;
    my $md_description = shift;
    my $md_creator = shift;
    my $md_upweight = shift;

    # Create the directory structure if it does not already exist.
    my $filepath = $file;
    $filepath =~ s/\/[^\/]+\..{3}\.pan\.txt//;

    eval { mkpath($filepath) };
    if ($@) {
        print "Couldn't create $filepath: $@";
    }

    # Open file
    if ( not open( MEDIA, ">", $file ) ) {
        warn "Unable to write to file $file ($!)";
        return;
    }

    my $url = $file;
    $url =~ s/.+\/http\//http\:\/\//;
    $url =~ s/\.pan\.txt//;

    print MEDIA "<DOCHDR>\n<BASE HREF=\"$url\">\n</DOCHDR>\n<html>\n<head>";
    print MEDIA "<meta name=\"DC.Date.Modified\" content=\"$md_date\" />\n";
    print MEDIA "<title>$md_title</title>\n";
    print MEDIA "<meta name=\"search_section\" content=\"$md_section\" />\n";
    print MEDIA "<meta name=\"custom.filesize\" content=\"$md_size\" />\n";
    print MEDIA "<meta name=\"dc.language\" content=\"$md_lang\" />\n";
    print MEDIA "<meta name=\"type\" content=\"$md_type\" />\n";
    print MEDIA "<META name=\"dc.format\" content=\"$md_filetype\" />\n";
    print MEDIA "<meta name=\"dc.description\" content=\"$md_description\" />\n";
    print MEDIA "<meta name=\"Creator\" content=\"$md_creator\" />\n";
    print MEDIA "<meta name=\"custom_upweight\" content=\"$md_upweight\" />\n";
    print MEDIA "</head>\n<body>\n</body>\n</html";

    close(MEDIA);
}

# Convert a file size into a nicely formatted version
sub niceSize {
    my $size = '';
    # Will work up to considerable file sizes!
    my $fs = $_[0];	# First variable is the size in bytes
    my $dp = $_[1];	# Number of decimal places required
    my @units = ('bytes','kB','MB','GB','TB','PB','EB','ZB','YB');
    my $u = 0;

    $dp = ($dp > 0) ? 10**$dp : 1;

    while($fs > 1024){
 	$fs /= 1024;
	$u++;
    }

    if($units[$u]){ return (int($fs*$dp)/$dp)." ".$units[$u]; } else{ return int($size); }
}

# There are some farily complex rules for adding noindex tags, so using noindex_expression would have been too cubersome.
sub addNoIndexTags {
    my $output = shift;
    $output =~ s/<!--noindex-->//g;
    $output =~ s/<!--endnoindex-->//g;

    # Add noindex tags
    # What to add the noindex tags around will depend upon the site template being used (e.g. dopolitics.org.uk vs. electoralcommission.org.uk).
    if ($File::Find::name !~ m/dopolitics\.org\.uk/) {
        # Don't add noindex tags to binary files.  Is there a better way of structuring this check?
        if ($File::Find::name !~ m/\.pan\.txt/) {
            $output =~ s/(<body.*?>)/$1\n<!--noindex-->\n/;
            $output =~ s/<div id="content">/<!--endnoindex-->\n<div id="content">/;
            $output =~ s/(<div id="support">.+?<\/div>)/<!--noindex-->$1/msi;
            $output =~ s/(<div id="page-navigation">.+?<\/div>)/<!--noindex-->$1/msi;
            $output =~ s/<\/body>/<!--endnoindex-->\n<\/body>/;
	    # Disabled noindex on tables as EC want them to be included now
            #$output =~ s/(<(?:table|select).*?<\/(?:table|select)>)/<!--noindex-->$1<!--endnoindex-->/gmsi;
            $output =~ s/(<select.*?<\/select>)/<!--noindex-->$1<!--endnoindex-->/gmsi;
            $output =~ s/(<div class="display-off">.+?<\/div>)/<!--noindex-->$1<!--endnoindex-->/gmsi;

            if ($File::Find::name =~ m/registers\.electoralcommission\.org\.uk/) {
                $output =~ s/(<div id="colophon">)/<!--noindex-->\n$1/gmsi;
            }
        }
    }
    else {
        if ($File::Find::name !~ m/\.pan\.txt/) {
            $output =~ s/(<body.*?>)/$1\n<!--noindex-->\n/;
            $output =~ s/<div id="dopol_right">/<!--endnoindex-->\n<div id="dopol_right">/;
            $output =~ s/<div id="footer">/<!--noindex-->\n<div id="footer">/;
            $output =~ s/<\/body>/<!--endnoindex-->\n<\/body>/;
        }
    }

    return $output;
}

# Update a binary file with the parent doc asset's title and metadata
sub updateDocument {
    my $file = shift;
    my $md_section = shift;
    my $md_size = shift;
    my $md_lang = shift;
    my $md_title = shift;
    my $md_type = shift;
    my $md_date = shift;
    my $md_subject = shift;
    my $md_spatial = shift;
    my $md_audience = shift;
    my $md_activity = shift;
    my $md_section_cymraeg = shift;
    my $md_type_cymraeg = shift;
    my $md_description = shift;
    my $md_creator = shift;
    my $md_sort = shift;
    my $md_date_cymraeg = shift;
    my $md_upweight = shift;

    if ( not open( BINARY, "<", $file) ) {
        warn "EC Pre-processing: Unable to read file $file ($!)";
        return;
    }

    # Read the file contents into memory
    my @binary = <BINARY>;
    close(BINARY);
    my $binary = join( "", @binary );

    if ($binary !~ m/<\/head>/i) {
	$binary .= "<html>\n<head>\n</head>\n<body>\n</body>\n</html>";
    }

    $binary =~ s/<TITLE>.+?<\/TITLE>//gmsi;
    $binary =~ s/<\/head>/<title>$md_title<\/title>\n<\/head>/i;

    $binary =~ s/<meta name="search_section" content=".*?" \/>//g;
    $binary =~ s/<\/head>/<meta name="search_section" content="$md_section" \/>\n<\/head>/;

    $binary =~ s/<meta name="custom\.filesize" content=".*?" \/>//g;
    $binary =~ s/<\/head>/<meta name="custom\.filesize" content="$md_size" \/>\n<\/head>/;
 
    $binary =~ s/<meta name="Language" content=".*?" \/>//g;
    $binary =~ s/<\/head>/<meta name="Language" content="$md_lang" \/>\n<\/head>/;

    $binary =~ s/<meta name="Type" content=".*?" \/>//g;
    $binary =~ s/<\/head>/<meta name="Type" content="$md_type" \/>\n<\/head>/;
   
    # Remove any conflicting dates provided by the original PDF document
    $binary =~ s/<META name="DC.Date.Modified" content=".*?"\s*\/?>//ig;
    $binary =~ s/<META name="DC.Date.Created" content=".*?"\s*\/?>//ig;
    $binary =~ s/<meta content='.*?' name='created'\/>//ig;
    $binary =~ s/<meta content='.*?' name='lastSaved'\/>//ig;
    $binary =~ s/<meta name="Modified" content=".*?" \/>//ig;
    $binary =~ s/<\/head>/<meta name="DC.Date.Modified" content="$md_date" \/>\n<\/head>/;

    $binary =~ s/<meta name="Subject" content=".*?" \/>//g;
    $binary =~ s/<\/head>/<meta name="Subject" content="$md_subject" \/>\n<\/head>/;

    $binary =~ s/<meta name="Spatial" content=".*?" \/>//g;
    $binary =~ s/<\/head>/<meta name="Spatial" content="$md_spatial" \/>\n<\/head>/;

    $binary =~ s/<meta name="Audience" content=".*?" \/>//g;
    $binary =~ s/<\/head>/<meta name="Audience" content="$md_audience" \/>\n<\/head>/;

    $binary =~ s/<meta name="dpactivity" content=".*?" \/>//g;
    $binary =~ s/<\/head>/<meta name="activity" content="$md_activity" \/>\n<\/head>/;

    $binary =~ s/<meta name="search_section_cymraeg" content=".*?" \/>//g;
    $binary =~ s/<\/head>/<meta name="search_section_cymraeg" content="$md_section_cymraeg" \/>\n<\/head>/;

    $binary =~ s/<meta name="type_cymraeg" content=".*?" \/>//g;
    $binary =~ s/<\/head>/<meta name="type_cymraeg" content="$md_type_cymraeg" \/>\n<\/head>/;

    $binary =~ s/<meta name="dc.description" content=".*?" \/>//g;
    $binary =~ s/<\/head>/<meta name="dc.description" content="$md_description" \/>\n<\/head>/;

    $binary =~ s/<meta name="Creator" content=".*?" \/>//g;
    $binary =~ s/<\/head>/<meta name="Creator" content="$md_creator" \/>\n<\/head>/;

    $binary =~ s/<meta name="numeric_sort" content=".*?" \/>//g;
    $binary =~ s/<\/head>/<meta name="numeric_sort" content="$md_sort" \/>\n<\/head>/;

    $binary =~ s/<meta name="date_cymraeg" content=".*?" \/>//g;
    $binary =~ s/<\/head>/<meta name="date_cymraeg" content="$md_date_cymraeg" \/>\n<\/head>/;

    $binary =~ s/<meta name="custom_upweight" content=".*?" \/>//g;
    $binary =~ s/<\/head>/<meta name="custom_upweight" content="$md_upweight" \/>\n<\/head>/;

    if ( not open( BINARY, ">", $file) ) {
        warn "EC Pre-processing: Unable to write to file $file ($!)";
        return;
    }

    print BINARY $binary;
    close(BINARY);

    return;
}

1;
