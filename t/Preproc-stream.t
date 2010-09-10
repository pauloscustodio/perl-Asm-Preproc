#!perl

use strict;
use warnings;

use Test::More;
use File::Slurp;

use_ok 'Asm::Preproc';
use_ok 'Asm::Preproc::Line';
use_ok 'Asm::Preproc::Stream';

our $pp;

#------------------------------------------------------------------------------
# test eol normalization and joining continuation lines
isa_ok $pp = Asm::Preproc->new, 'Asm::Preproc';
$pp->include_list(1..3);
isa_ok my $s = $pp->line_stream, 'Asm::Preproc::Stream';

is_deeply $s->get, Asm::Preproc::Line->new("1\n", 		"-", 	1);
is_deeply $s->get, Asm::Preproc::Line->new("2\n", 		"-", 	2);
is_deeply $s->get, Asm::Preproc::Line->new("3\n", 		"-", 	3);
is $s->get, undef;

done_testing;
