use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Capture::Tiny 0.23 qw/capture/;

require Test::DiagINC;

my $diaginc_version = Test::DiagINC->VERSION;
$diaginc_version = 'undef' unless defined $diaginc_version;

for my $file (qw/fails.t dies.t/) {
    $ENV{AUTOMATED_TESTING} = 1;
    my ( $stdout, $stderr ) = capture {
        system( $^X, "examples/$file" );
    };
    like(
        $stderr,
        qr/\QListing modules and versions from %INC/,
        "$file: Saw diagnostic header"
    );
    like(
        $stderr,
        qr/\QTest::DiagINC $diaginc_version/,
        "$file: Saw Test::DiagINC in module list"
    );
}

done_testing;
# COPYRIGHT

# vim: ts=4 sts=4 sw=4 et:
