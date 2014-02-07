use warnings;
use strict;
use File::Spec;

# there is talk of possible perl compilations where -T is a fatal
# we don't want to have the user deal with that
system( $^X => -T => -e => 'use warnings; use strict; exit 0' );
if ($?) {
    print "1..0 # SKIP Your perl does not seem to like -T...\n";
    exit 0;
}

# all is well - just rerun the basic test
exec( $^X => -T => File::Spec->catpath(
    (File::Spec->splitpath( __FILE__ ))[0,1],
    'basic.t'
) );
