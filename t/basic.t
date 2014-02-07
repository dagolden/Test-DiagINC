use strict;
use warnings;
use Test::More;
use Capture::Tiny 0.21 qw/capture/;

my @testfiles = qw/fails.t dies.t/;
push @testfiles, 'fails_in_end.t' unless $] < 5.008;

plan tests => @testfiles * ( $] < 5.010 ? 3 : 4 );

my $tainted_run = !eval { $ENV{PATH} . kill(0) and 1 }
  and diag( __FILE__ . ' running under taint mode' );

local $ENV{AUTOMATED_TESTING} = 1;

# untaint PATH but do not unset it so we test that $^X will
# run with it just fine
local ( $ENV{PATH} ) = $ENV{PATH} =~ /(.*)/ if $tainted_run;

for my $file (@testfiles) {
    my ( $stdout, $stderr ) = capture {
        system(
            ( $^X =~ /(.+)/ ), # $^X is internal how can it be tainted?!
            ( $tainted_run ? (qw( -I . -I lib -T )) : () ),
            "examples/$file"
        );
    };

    like( $stderr, qr/\QListing modules from %INC/,   "$file: Saw diagnostic header" );
    like( $stderr, qr/[0-9.]+\s+ExtUtils::MakeMaker/, "$file: Saw EUMM in module list" );
    unlike( $stderr, qr/Foo/, "$file: Did not see local module Foo in module list", );

    like(
        $stderr,
        qr/Found and failed to load\s+[\w\:]*SyntaxErr/,
        "$file: Saw failed load attempt of SyntaxErr"
    ) unless $] < 5.010;
}

# COPYRIGHT

# vim: ts=4 sts=4 sw=4 et:
