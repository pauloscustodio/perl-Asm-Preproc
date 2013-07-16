# $Id: Stream.pm,v 1.7 2010/10/15 15:55:34 Paulo Exp $

package Asm::Preproc::Stream;

#------------------------------------------------------------------------------

=head1 NAME

Asm::Preproc::Stream - Deprecated, use Iterator::Simple::Lookahead instead

=cut

#------------------------------------------------------------------------------

use strict;
use warnings;
use Iterator::Simple::Lookahead;

our $VERSION = '0.07';

#------------------------------------------------------------------------------

=head1 SYNOPSIS

  use Asm::Preproc::Stream;
  my $stream = Asm::Preproc::Stream->new(@input)
  my $head = $stream->head;
  my $next = $stream->get;
  $stream->unget(@items);
  my $it = $stream->iterator; my $next = $it->();

=head1 DESCRIPTION

Deprecated.

=head1 FUNCTIONS

=head2 new

Creates iterator.

=head2 head

Calls peek() from Iterator::Simple::Lookahead.

=head2 get

Calls next() from Iterator::Simple::Lookahead.

=head2 unget

Calls unget() from Iterator::Simple::Lookahead.

=head2 iterator

Return an iterator function that returns the next stream element on each call.

=cut

#------------------------------------------------------------------------------

sub new {
    my($class, @input) = @_;
	my $iter = Iterator::Simple::Lookahead->new(@input);
    return bless [$iter], $class;
}

sub _iter {
	my($self) = @_;
	return $self->[0];
}

sub head {
	my($self) = @_;
	return $self->_iter->peek;
}

sub get {
    my($self) = @_;
    return $self->_iter->next;
}

sub unget {
    my($self, @input) = @_;
	$self->_iter->unget(@input);
}

sub iterator {
    my($self) = @_;
	return sub { $self->get };
}

#------------------------------------------------------------------------------

=head1 ACKNOWLEDGEMENTS

Inspired in L<HOP::Stream|HOP::Stream>.

=head1 BUGS, FEEDBACK, AUTHOR, LICENCE and COPYRIGHT

See L<Asm::Preproc|Asm::Preproc>.

=cut

#------------------------------------------------------------------------------

1;
