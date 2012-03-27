package ElectoralCommission::ECVariables;
use strict;
use warnings;

our @excludePatterns = (
    '/nestedcontent/',
    '/rss/',
    '/open-consultations-rss/'
);

our $urlBlackList = 'http://www.electoralcommission.org.uk/search/search-crawler-blacklist/_nocache';
our $matrixUsername = 'adavis';
our $matrixPassword = 'Cup1pa2w';

our %assetListings = (
    'http://www.electoralcommission.org.uk/search/search-crawler-consultations/_nocache' => '14',
    'http://www.electoralcommission.org.uk/search/search-crawler-corporate-publications/_nocache' => '4',
    'http://www.electoralcommission.org.uk/search/search-crawler-election-reports/_nocache' => '9',
    'http://www.electoralcommission.org.uk/search/search-crawler-factsheets-casestudies/_nocache' => '6',
    'http://www.electoralcommission.org.uk/search/search-crawler-policy-research/_nocache' => '12',
    'http://www.electoralcommission.org.uk/search/search-crawler-guidance/_nocache' => '11',
    'http://www.electoralcommission.org.uk/search/search-crawler-forms/_nocache' => '7',
    'http://www.electoralcommission.org.uk/search/search-crawler-circulars-alerts/_nocache' => '5',
    'http://www.electoralcommission.org.uk/search/search-crawler-freedom-information/_nocache' => '10',
);
