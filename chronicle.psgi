use strict;
use warnings;

use Chronicle;

my $app = Chronicle->apply_default_middlewares(Chronicle->psgi_app);
$app;

