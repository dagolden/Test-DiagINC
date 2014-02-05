use strict;
use warnings;
use if $ENV{AUTOMATED_TESTING}, 'Test::DiagINC';
use Test::More tests => 1;
use ExtUtils::MakeMaker ();
use lib 'examples/lib';
use Foo;

fail("this failed");
