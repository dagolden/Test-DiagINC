use 5.008001;

package Test::DiagINC;
# ABSTRACT: List modules and versions loaded if tests fail
# VERSION

# If the tested module did not load strict/warnings we do not want
# to load them either. On the other hand we would like to know our
# code is at least somewhat ok. Therefore this madness ;)
BEGIN { if($ENV{RELEASE_TESTING}) {
    require warnings && warnings->import;
    require strict && strict->import;
} }

sub _max_length {
    my $max = 0;
    do { $max = length if length > $max }
      for @_;
    return $max;
}

# Get our CWD *without* loading anything. Original idea by xdg++
# ribasushi thinks this is fragile and will break sooner rather than
# later, but adding it as is because haarg and xdg both claim it's fine
my $REALPATH_CWD = `$^X -MCwd -e print+getcwd`;
my $ORIGINAL_PID = $$;

END {
    # Dump %INC if in the main process and have a non-zero exit code
    if ( $$ == $ORIGINAL_PID && $? ) {

        # make sure we report only on stuff that was loaded by the test, nothing more
        my @INC_list = keys %INC;

        require Path::Tiny;
        my $CWD = Path::Tiny::path($REALPATH_CWD);

        chdir $CWD; # improve resolution of relative path names
        my @packages;
        for my $p ( sort @INC_list ) {
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
    #       0.98 Test::Builder
    #       0.98 Test::Builder::Module
    #      0.003 Test::DiagINC
    #       0.98 Test::More
    #       1.22 overload
    #       0.02 overloading
    #       1.07 strict
    #       1.03 vars
    #       1.18 warnings
    #       1.02 warnings::register

This module deliberately does not load B<any other modules> during runtime,
instead delaying all loads until it needs to generate a failure report in its
C<END> block. The only exception is loading L<strict> and L<warnings> for
self-check B<if and only if> C<RELEASE_TESTING> is true. Therefore an empty
invocation will look like this:

    $ perl -MTest::DiagINC -e 'exit(1)'
    # Listing modules from %INC
    #  0.003 Test::DiagINC

B<NOTE>:  Because this module uses an C<END> block, it must be loaded B<before>
C<Test::More> so that the C<Test::More>'s C<END> block has a chance to set
the exit code first.  If you're not using C<Test::More>, then it's up to you to
ensure your code generates the non-zero exit code (e.g. C<die()> or C<exit(1)>).

Modules that appear to be sourced from below the current directory when
C<Test::DiagINC> was loaded will be excluded from the report (e.g. excludes
local modules from C<./>, C<lib/>, C<t/lib>, and so on).

The heuristic of searching C<%INC> for loaded modules may fail if the module
path loaded does not map to a package within the module file.

If C<Test::More> is loaded, the output will go via the C<diag> function.
Otherwise, it will just be sent to STDERR.


=cut

# vim: ts=4 sts=4 sw=4 et:
