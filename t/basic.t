use strict;
use warnings;
use Test::More;
use Capture::Tiny 0.21 qw/capture/;

my @testfiles = qw/fails.t dies.t/;
push @testfiles, 'fails_in_end.t' unless $] < 5.008;

plan tests => @testfiles * ($] < 5.010 ? 3 : 4);

for my $file (@testfiles) {
    $ENV{AUTOMATED_TESTING} = 1;
    my ( $stdout, $stderr ) = capture {
        system( $^X, "examples/$file" );
    };

    like( $stderr, qr/\QListing modules from %INC/, "$file: Saw diagnostic header" );
    like( $stderr, qr/[0-9.]+\s+ExtUtils::MakeMaker/, "$file: Saw EUMM in module list" );
    unlike( $stderr, qr/Foo/, "$file: Did not see local module Foo in module list", );

    like( $stderr, qr/Found and failed to load\s+[\w\:]*SyntaxErr/,
      "$file: Saw failed load attempt of SyntaxErr" ) unless $] < 5.010;
}

# COPYRIGHT

# vim: ts=4 sts=4 sw=4 et:
