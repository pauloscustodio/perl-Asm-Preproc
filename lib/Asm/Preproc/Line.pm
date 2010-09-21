# $Id: Line.pm,v 1.2 2010/09/12 20:19:26 Paulo Exp $

package Asm::Preproc::Line;

#------------------------------------------------------------------------------

=head1 NAME

Asm::Preproc::Line - One line of text retrieved from the input

=cut

#------------------------------------------------------------------------------

use strict;
use warnings;

our $VERSION = '0.02';

#------------------------------------------------------------------------------

=head1 SYNOPSIS

  use Asm::Preproc::Line;
  my $line = Asm::Preproc::Line->new($text, $file, $line_nr);
  $line->text; $line->rtext; $line->file; $line->line_nr;
  my $line2 = $line->clone;
  if ($line == $line2) {...}
  if ($line != $line2) {...}
  $line->error($message);
  $line->warning($message);

=head1 DESCRIPTION

This module defines the object to represent one line of input text
to preprocess. It contains the actual text from the line, and the file name 
and line number where the text was retrieved. It contains also utility methods
for error messages.

=head1 METHODS

=head2 new

Creates a new object with the given text, file name and line number.

=head2 text

Get/set line text.

=head2 rtext

Return reference to the text value.

=head2 file

Get/set file name.

=head2 line_nr

Get/set line number.

=head2 clone

Creates an identical copy as a new object.

=cut

#------------------------------------------------------------------------------
# Perl 5.6 can only declare one constant at a time
use constant TEXT 		=> 0;
use constant FILE 		=> 1;
use constant LINE_NR	=> 2;

sub new { 
	#my($class, $text, $file, $line_nr) = @_;
	my $class = shift;
	bless [@_], $class;
}

sub clone {
	my $self = shift;
	bless [@$self], ref($self);
}

sub text    { $#_ ? $_[0][TEXT   ] = $_[1] : $_[0][TEXT   ] }
sub rtext   { \($_[0][TEXT]) }

sub file    { $#_ ? $_[0][FILE   ] = $_[1] : $_[0][FILE   ] }
sub line_nr { $#_ ? $_[0][LINE_NR] = $_[1] : $_[0][LINE_NR] }
#------------------------------------------------------------------------------

=head2 is_equal

  if ($self == $other) { ... }

Compares two line objects. Overloads the '==' operator.

=cut

#------------------------------------------------------------------------------
sub is_equal { my($self, $other) = @_;
	no warnings 'uninitialized';
	return $self->[TEXT]    eq $other->[TEXT]    &&
		   $self->[LINE_NR] == $other->[LINE_NR] &&
		   $self->[FILE]    eq $other->[FILE];
}

use overload '==' => \&is_equal, fallback => 1;
#------------------------------------------------------------------------------

=head2 is_different

  if ($self != $other) { ... }

Compares two line objects. Overloads the '!=' operator.

=cut

#------------------------------------------------------------------------------
sub is_different { my($self, $other) = @_;
	return ! $self->is_equal($other);
}

use overload '!=' => \&is_different, fallback => 1;
#------------------------------------------------------------------------------

=head2 error

Dies with the given error message, indicating the place in the input source file
where the error occured as:

  FILE(LINE) : error: MESSAGE

=cut

#------------------------------------------------------------------------------
sub error { 
	my($self, $message) = @_;
	die $self->_error_msg("error", $message);
}
#------------------------------------------------------------------------------

=head2 warning

Warns with the given error message, indicating the place in the input source file
where the error occured as:

  FILE(LINE) : warning: MESSAGE

=cut

#------------------------------------------------------------------------------
sub warning { my($self, $message) = @_;
	warn $self->_error_msg("warning", $message);
}
#------------------------------------------------------------------------------
# error message for error() and warning()
sub _error_msg { 
	my($self, $type, $message) = @_;
	
	no warnings 'uninitialized';
	
	my $file = $self->file;
	my $line_nr = $self->line_nr ? '('.$self->line_nr.')' : '';
	my $pos = "$file$line_nr"; $pos .= " : " if $pos;
	
	$message =~ s/\s+$//;		# in case message comes from die, has a "\n"
	
	return "$pos$type: $message\n";
}
#------------------------------------------------------------------------------

=head1 AUTHOR, BUGS, SUPPORT, LICENSE, COPYRIGHT

See L<Asm::Preproc|Asm::Preproc>.

=cut

#------------------------------------------------------------------------------

1;
