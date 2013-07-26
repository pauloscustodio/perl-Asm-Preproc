#!perl

# $Id: Stream.t,v 1.2 2010/10/12 21:18:13 Paulo Exp $

use strict;
use warnings;

use Test::More;
use Iterator::Simple qw( iter );

use_ok 'Asm::Preproc::Stream';

my $s;

#------------------------------------------------------------------------------
sub t_get (@) {
	my $where = "[line ".(caller)[2]."]";
	for (@_) {
		is $s->head, $_, "$where head is ".($_||"undef");
		is $s->get,  $_, "$where get  is ".($_||"undef");
	}
}
	
#------------------------------------------------------------------------------
# new without arguments
{
	isa_ok	$s = Asm::Preproc::Stream->new(), 'Asm::Preproc::Stream';
	t_get 	undef, undef;
	$s->unget(1..3);
	t_get 	1, 2, 3, undef, undef;
}

#------------------------------------------------------------------------------
# new with arguments
{
	isa_ok	$s = Asm::Preproc::Stream->new(1..3),
			'Asm::Preproc::Stream';
	t_get 	1, 2, 3, undef, undef;
}

#------------------------------------------------------------------------------
# iterator
{
	my @d1 = (4..6);
	my @d2 = (1..3);

	isa_ok	$s = Asm::Preproc::Stream->new(sub {shift @d1}),
			'Asm::Preproc::Stream';
	t_get 	4, 5;
	$s->unget(sub {shift @d2});
	t_get 	1, 2, 3, 6, undef, undef;
}

#------------------------------------------------------------------------------
# return iterator from get()
{
	my @d1 = (4..6);

	isa_ok	$s = Asm::Preproc::Stream->new(
				sub { 
					my $ret = shift @d1; 
					if ($ret && $ret == 5) {
						my @d2 = ($ret, 1..3);
						return sub { shift @d2 };
					}
					return $ret;
				}),
			'Asm::Preproc::Stream';
	t_get 	4, 5, 1, 2, 3, 6, undef, undef;
}

#------------------------------------------------------------------------------
# unget from within the iterator
{
	my @d1 = (4..6);

	isa_ok	$s = Asm::Preproc::Stream->new(
				sub {
					my $ret = shift @d1; 
					if ($ret && $ret == 5) {
						$s->unget(iter([1..3]));
					}
					return $ret;
				}),
			'Asm::Preproc::Stream';
	t_get 	4, 5, 1, 2, 3, 6, undef, undef;
}

#------------------------------------------------------------------------------
# iterator
{
	isa_ok	$s = Asm::Preproc::Stream->new(1..3),
			'Asm::Preproc::Stream';
	is ref(my $it = $s->iterator), 'CODE', "iterator is code ref";

	is	$s->head,		1, 		"head";
	is 	$it->(), 		1, 		"iterator get";

	is	$s->head,		2, 		"head";
	is 	$it->(), 		2, 		"iterator get";

	is	$s->head,		3, 		"head";
	is 	$it->(), 		3, 		"iterator get";

	t_get 	undef, undef;
}


done_testing();
