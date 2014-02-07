use 5.006;

package Test::DiagINC;
# ABSTRACT: List modules and versions loaded if tests fail
# VERSION

# If the tested module did not load strict/warnings we do not want
# to load them either. On the other hand we would like to know our
# code is at least somewhat ok. Therefore this madness ;)
BEGIN {
    if ( $ENV{RELEASE_TESTING} ) {
        require warnings && warnings->import;
        require strict   && strict->import;
    }
}

sub _max_length {
    my $max = 0;
    do { $max = length if length > $max }
      for @_;
    return $max;
}

# Get our CWD *without* loading anything. Original idea by xdg++
# ribasushi thinks this is fragile and will break sooner rather than
# later, but adding it as is because haarg and xdg both claim it's fine
my $REALPATH_CWD = do {
    local $ENV{PATH};
    my ($perl) = $^X =~ /(.+)/; # $^X is internal how could it be tainted?!
    `$perl -MCwd -e print+getcwd`;
};

my $ORIGINAL_PID = $$;

END {
    if ( $$ == $ORIGINAL_PID ) {
        # make sure we report only on stuff that was loaded by the test,
        # nothing more
        # get a snapshot early in order to not misreport B.pm and friends
        # below - this *will* skip any extra modules loaded in END, it was
        # deemed an acceptable compromise by ribasushi and xdg
        my @INC_list = keys %INC;

        # If we meet the "fail" criteria - no need to load B and fire
        # an extra check in an extra END (also doesn't work on 5.6)
        if ( _assert_no_fail(@INC_list) and $] >= 5.008 ) {

            # we did not report anything yet - add an extra END to catch
            # possible future-fails
            require B;
            push @{ B::end_av()->object_2svref }, sub {
                _assert_no_fail(@INC_list);
            };
        }
    }
}

# Dump %INC IFF in the main process and test is failing or exit is non-zero
# return true if no failure or if PID mismatches, return false otherwise
sub _assert_no_fail {

    return 1 if $$ != $ORIGINAL_PID;

    if (
        $?
        or (    $INC{'Test/Builder.pm'}
            and Test::Builder->can('is_passing')
            and !Test::Builder->new->is_passing )
      )
    {

        require Cwd;
        require File::Spec;
        require Cwd;

        my %results;

        for my $pkg_as_path (@_) {
            next unless ( my $p = $pkg_as_path ) =~ s/\.pm\z//;
            $p =~ s{/}{::}g;
            next unless $p =~ /\A[A-Z_a-z][0-9A-Z_a-z]*(?:::[0-9A-Z_a-z]+)*\Z/;

            # a module we recorded as INCed disappeared...
            if ( not exists $INC{$pkg_as_path} ) {
                $results{$p} = 'Module unloaded in END...?';
                next;
            }

            if ( not defined $INC{$pkg_as_path} ) {
                $results{$p} = 'Found and failed to load';
                next;
            }

            next
              if (
                # rel2abs on an absolute path is a noop
                # https://metacpan.org/source/SMUELLER/PathTools-3.40/lib/File/Spec/Unix.pm#L474
                # https://metacpan.org/source/SMUELLER/PathTools-3.40/lib/File/Spec/Win32.pm#L324
                Cwd::realpath( File::Spec->rel2abs( $INC{$pkg_as_path}, $REALPATH_CWD ) )
                =~ m| \A \Q$REALPATH_CWD\E [\\\/] |x
              );

            my $ver = do {
                local $@;
                my $v = eval { $p->VERSION };
                $@ ? '->VERSION call failed' : $v;
            };
            $ver = 'n/a' unless defined $ver;
            $results{$p} = $ver;
        }

        my $diag = "Listing modules from %INC\n";

        my $ml = _max_length( keys %results );
        my $vl = _max_length( values %results );

        for ( sort keys %results ) {
            $diag .= sprintf(
                " %*s  %*s\n",
                # pairs of [ padding-length => content ]
                $vl  => $results{$_},
                -$ml => $_
            );
        }

        if ( $INC{"Test/Builder.pm"} ) {
            Test::Builder->new->diag($diag);
        }
        else {
            $diag =~ s/^/# /mg;
            print STDERR $diag;
        }

        return 0;
    }

    return 1;
}

1;

=for Pod::Coverage BUILD

=head1 SYNOPSIS

    # preferably load before anything else
    use if $ENV{AUTOMATED_TESTING}, 'Test::DiagINC';
    use Test::More;

=head1 DESCRIPTION

Assuming you shipped your module to CPAN with working tests, test failures from
L<CPAN Testers|http://www.cpantesters.org/> might be due to platform issues,
Perl version issues or problems with dependencies.  This module helps you
diagnose deep dependency problems by showing you exactly what modules and
versions were loaded during a test run.

When this module is loaded, it sets up an C<END> block that will take action if
the program is about to exit with a non-zero exit code or if
L<< $test_builder->is_passing|Test::Builder/is_passing >>
is false by the time the C<END> block is reached.  If that happens, this module
prints out the names and version numbers of non-local modules appearing in
L<%INC|perlvar/%INC> at the end of the test.

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

B<NOTE>:  Because this module uses an C<END> block, it is a good idea to load
it as early as possible, so the C<END> block it installs will execute as
B<late> as possible (see L<perlmod> for details on how this works). While
this module does employ some cleverness to work around load order, it is
still a heuristic and is no substitute to loading this module early. A notable
side-effect is when a module is loaded in an C<END> block executing B<after>
the one installed by this library: such modules will be "invisible" to us and
will not be reported as part of the diagnostic report.

Modules that appear to be sourced from below the current directory when
C<Test::DiagINC> was loaded will be excluded from the report (e.g. excludes
local modules from C<./>, C<lib/>, C<t/lib>, and so on).

The heuristic of searching C<%INC> for loaded modules may fail if the module
path loaded does not map to a package within the module file.

If C<Test::More> is loaded, the output will go via the C<diag> function.
Otherwise, it will just be sent to STDERR.

=cut

# vim: ts=4 sts=4 sw=4 et:
