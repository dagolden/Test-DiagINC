use 5.008001;
use strict;
use warnings;

package Test::DiagINC;
# ABSTRACT: List modules and versions loaded if tests fail
# VERSION

use Path::Tiny;

sub _max_length {
    my $max = 0;
    do { $max = length if length > $max }
      for @_;
    return $max;
}

my $ORIGINAL_PID = $$;
my $CWD          = path(".")->absolute;

END {
    # Dump %INC if in the main process and have a non-zero exit code
    if ( $$ == $ORIGINAL_PID && $? ) {
        chdir $CWD; # improve resolution of relative path names
        my @packages;
        for my $p ( sort keys %INC ) {
            next unless defined( $INC{$p} ) && !$CWD->subsumes( $INC{$p} );
            next unless $p =~ s/\.pm\z//;
            $p =~ s{[\\/]}{::}g;
            push @packages, $p if $p =~ /\A[A-Z_a-z][0-9A-Z_a-z]*(?:::[0-9A-Z_a-z]+)*\Z/;
        }

        my %versions = map {
            my $v = eval { $_->VERSION };
            $_ => defined($v) ? $v : "undef"
        } @packages;

        my $header = "Listing modules from %INC\n";
        my $format = "  %*s %*s\n";
        my $ml     = _max_length(@packages);
        my $vl     = _max_length( values %versions );

        if ( $INC{"Test/Builder.pm"} ) {
            my $tb = Test::Builder->new;
            $tb->diag($header);
            $tb->diag( sprintf( $format, $vl, $versions{$_}, -$ml, $_ ) ) for @packages;
        }
        else {
            print STDERR "# $header";
            printf( STDERR "#$format", $vl, $versions{$_}, -$ml, $_ ) for @packages;
        }
    }
}

1;

=for Pod::Coverage BUILD

=head1 SYNOPSIS

    # Load *BEFORE* Test::More
    use if $ENV{AUTOMATED_TESTING}, 'Test::DiagINC';
    use Test::More;

=head1 DESCRIPTION

Assuming you shipped your module to CPAN with working tests, test failures from
L<CPAN Testers|http://www.cpantesters.org/> might be due to platform issues,
Perl version issues or problems with dependencies.  This module helps you
diagnose deep dependency problems by showing you exactly what modules and
versions were loaded during a test run.

When this module is loaded, it sets up an C<END> block that will take action if
a program exits with a non-zero exit code.  If that happens, this module prints
out the names and version numbers of non-local modules appearing in C<%INC> at
the end of the test.

For example:

    $ perl -MTest::DiagINC -MTest::More -e 'fail("meh"); done_testing'
    not ok 1 - meh
    #   Failed test 'meh'
    #   at -e line 1.
    1..1
    # Looks like you failed 1 test of 1.
    # Listing modules and versions from %INC
    #   5.018002 Config
    #       5.68 Exporter
    #       5.68 Exporter::Heavy
    #       1.07 PerlIO
    #   1.001002 Test::Builder
    #   1.001002 Test::Builder::Module
    #      0.001 Test::DiagINC
    #   1.001002 Test::More
    #       1.22 overload
    #       0.02 overloading
    #       1.07 strict
    #       1.03 vars
    #       1.18 warnings
    #       1.02 warnings::register

B<NOTE>:  Because this module uses an C<END> block, it must be loaded B<before>
C<Test::More> so that the C<Test::More>'s C<END> block has a chance to set
the exit code first.  If you're not using C<Test::More>, then it's up to you to
ensure your code generates the non-zero exit code (e.g. C<die()> or C<exit(1)>).

Modules that appear to be sourced from below the current directory when
C<Test::DiagINC> was loaded will be excluded from the report (e.g. excludes
local modules from C<lib/>, C<t/lib>, and so on).

The heuristic of searching C<%INC> for loaded modules may fail if the module
path loaded does not map to a package within the module file.

If C<Test::More> is loaded, the output will go via the C<diag> function.
Otherwise, it will just be sent to STDERR.

=cut

# vim: ts=4 sts=4 sw=4 et:
