use 5.008001;
use strict;
use warnings;

package Test::DiagINC;
# ABSTRACT: List all modules and versions loaded if tests fail
# VERSION

my $ORIGINAL_PID = $$;

END {
    # Dump %INC if in the main process and have a non-zero exit code
    if ( $$ == $ORIGINAL_PID && $? ) {
        # Some code copied/adapted from Dist::Zilla::Plugin::Test::PrereqsFromMeta
        my @packages = grep {
            s/\.pm\Z//
              and do { s![\\/]!::!g; 1 }
        } sort keys %INC;

        my %versions = map {
            my $v = eval { $_->VERSION };
            $_ => defined($v) ? $v : "undef"
        } @packages;

        my $len = 0;
        for (@packages) { $len = length if length > $len }
        $len = 68 if $len > 68;

        if ( $INC{"Test/Builder.pm"} ) {
            my $tb = Test::Builder->new;
            $tb->diag("Listing modules and versions from %INC\n");
            $tb->diag( sprintf( "%${len}s %s\n", $_, $versions{$_} ) ) for @packages;
        }
        else {
            print STDERR "# Listing modules and versions from %INC\n";
            printf( STDERR "# %${len}s %s\n", $_, $versions{$_} ) for @packages;
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
out the names and version numbers of all modules appearing in C<%INC> at the
end of the test.

For example:

    $ perl -MTest::DiagINC -MTest::More -e 'fail("meh"); done_testing'
    not ok 1 - meh
    #   Failed test 'meh'
    #   at -e line 1.
    1..1
    # Looks like you failed 1 test of 1.
    # Listing modules and versions from %INC
    #                Config 5.018002
    #              Exporter 5.68
    #       Exporter::Heavy 5.68
    #                PerlIO 1.07
    #         Test::Builder 1.001002
    # Test::Builder::Module 1.001002
    #         Test::DiagINC 0.001
    #            Test::More 1.001002
    #              overload 1.22
    #           overloading 0.02
    #                strict 1.07
    #                  vars 1.03
    #              warnings 1.18
    #    warnings::register 1.02    

B<NOTE>:  Because this module uses an C<END> block, it must be loaded B<before>
C<Test::More> so that the C<Test::More>'s C<END> block has a chance to set
the exit code first.  If you're not using C<Test::More>, then it's up to you to
ensure your code generates the non-zero exit code (e.g. C<die()> or C<exit(1)>).

If C<Test::More> is loaded, the output will go via the C<diag> function.
Otherwise, it will just be sent to STDERR.

=cut

# vim: ts=4 sts=4 sw=4 et:
