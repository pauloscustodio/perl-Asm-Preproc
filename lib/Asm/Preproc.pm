# $Id: Preproc.pm,v 1.3 2010/09/21 19:39:07 Paulo Exp $

package Asm::Preproc;

#------------------------------------------------------------------------------

=head1 NAME

Asm::Preproc - Preprocessor to be called from an assembler

=cut

#------------------------------------------------------------------------------

use warnings;
use strict;

use File::Spec;
use Asm::Preproc::Line;
use Asm::Preproc::Stream;

our $VERSION = '0.03';

#------------------------------------------------------------------------------
# TODO :
# 	- macros; implies tokenizer
#	- asmpp command line
#	- does conditional text expansion
#------------------------------------------------------------------------------

=head1 SYNOPSIS

  use Asm::Preproc;
  my $pp = Asm::Preproc->new();
  my $pp = Asm::Preproc->new(@files);
  
  $pp->add_path(@path); @path = $pp->path;
  $pp->include($file); $pp->include($file, $from_line);
  my $full_path = $pp->path_search($file);

  $pp->include_list(@input);
  
  my $iter = sub {return scalar <STDIN>};
  $pp->include_list($iter);
  
  my $line = $pp->getline;     # isa Asm::Preproc::Line
  my $strm = $pp->line_stream; # isa Asm::Preproc::Stream

=head1 DESCRIPTION

This module implements a preprocessor that reads source files 
and handles recursive file includes.
It is intended to be called from inside an assembler or compiler.

=cut

# TODO: does conditional text expansion and macro substitution. 

=head1 METHODS

=head2 new

Creates a new object. If an argument list is given, calls C<include>
for each of the file starting from the last, so that the files are 
read in the given order.

=cut

#------------------------------------------------------------------------------
# preprocessor : has a list of stuff to read
# Perl 5.6 can only declare one constant at a time

# $self attributes
use constant STACK 		=> 0;
use constant PATH 		=> 1;

# $self->[STACK] attributes
use constant ITER 		=> 0;
use constant FILE 		=> 1;
use constant LINE_NR 	=> 2;
use constant LINE_INC 	=> 3;

use constant TOP 		=> -1;		# top of stack, i.e. current input file


sub new { 
	my($class, @files) = @_;
	my $self = bless [
				[],			# STACK of [iter(), file, line_nr, line_inc]
				[],			# PATH of search directories
		], $class;
	$self->include($_) for reverse @files;
	return $self;
}
#------------------------------------------------------------------------------

=head2 path

Returns the list of directories to search in sequence for source files.

=cut

#------------------------------------------------------------------------------
sub path { @{$_[0][PATH]} }
#------------------------------------------------------------------------------

=head2 add_path

Adds the given directories to the path searched for include files.

=cut

#------------------------------------------------------------------------------
sub add_path {
	my($self, @dirs) = @_;
	push @{$self->[PATH]}, @dirs;
}
#------------------------------------------------------------------------------

=head2 path_search

Searches for the given file in the C<path> created by C<add_path>, returns 
the first full path name where the file can be found.

Returns the input file name if the file is found in the current directory,
or if it is not found in any of the C<path> directories.

=cut

#------------------------------------------------------------------------------
sub path_search {
	my($self, $file) = @_;
	
	return $file if -f $file;	# found
	
	for my $dir (@{$self->[PATH]}) {
		my $full_path = File::Spec->catfile($dir, $file);
		return $full_path if -f $full_path;
	}
	
	return $file;				# not found
}
#------------------------------------------------------------------------------

=head2 include

Open the input file and sets-up the object to read each line in sequence.

The optional second argument is a L<Asm::Preproc::Line|Asm::Preproc::Line>
object pointing at the C<%include> line that included the file, to be used
in error messages.

An exception is raised if the input file cannot be read, or if a file is
included recursively, to avoid an infinite include loop.

=cut

#------------------------------------------------------------------------------
sub include {
	my($self, $file, $from_line) = @_;
	
	# search include path
	my $full_path = $self->path_search($file);
	
	# check for include loop
	if (grep {$_->[FILE] eq $full_path} @{$self->[STACK]}) {
		($from_line || Asm::Preproc::Line->new)
			->error("%include loop")
	}
	
	# open the file
	open(my $fh, $full_path) or
		($from_line || Asm::Preproc::Line->new)
		->error("unable to open input file '$full_path'");
		
	# create a new iterator to read file lines
	my $iter = sub { 
		return undef unless $fh;
		my $text = <$fh>;
		defined($text) and return $text;

		undef $fh;				# close fh at end of file
		return undef;
	};
	$self->_push_iter($iter, $full_path);
}
#------------------------------------------------------------------------------

=head2 include_list

Sets-up the object to read each element of the passed input
list one line at a time.

Each element of the list is either a text string 
or a code reference of an iterator.
The iterator may return text strings, or other iterators that will be
called recursively. The iterator returns C<undef> at the end of input.

The text strings are split by lines, so that each C<getline> calls returns 
one complete line. 

As the text lines are scanned for pre-processor directives, the following two
lines are equivalent:

  $pp->include('file.asm');
  $pp->include_list('%include <file.asm>');

=cut

#------------------------------------------------------------------------------
sub include_list {
	my($self, @input) = @_;
	
	# create a new iterator to read text lines from iterators or strings
	my $iter = sub {
		while (1) {
			return undef unless @input;
			
			# call iterator to get first string, if any
			if (ref $input[0]) {
				my $text = $input[0]->();			# get first from iterator
				if (defined $text) {
					unshift @input, $text;			# insert line at head
				}
				else {
					shift @input;					# iter exhausted, drop it
				}
				next;								# need to test list again
			}
			
			# line is a string, return each complete line
			for ($input[0]) {
				last unless defined $_;				# skip undef lines
				if (/ \G ( .*? \n | .+ ) /gcx) {
					shift @input if pos == length;	# consumed all, drop it
					return $1;
				}
			}
			shift @input;							# end of input
		}
	};
	$self->_push_iter($iter, "-");
}

#------------------------------------------------------------------------------

=head2 getline

Returns the next line from the input, after doing all the pre-processing.
The line is returned as a L<Asm::Preproc::Line|Asm::Preproc::Line> object
containing the actual text, and the file and line number where the text
was found.

Returns C<undef> at the end of the input.

=cut

#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# prepare the object to read the given iterator and file name
sub _push_iter {
	my($self, $iter, $file) = @_;
	
	# new file in the stack
	push @{$self->[STACK]}, 
		[$iter, $file, 0, 1];	# iter, file, line_nr, line_inc
}

#------------------------------------------------------------------------------
# return next line as a Asm::Preproc::Line object
sub getline {
	my($self) = @_;

	while (1) {
		return undef unless @{$self->[STACK]};	# no more files
		my $top = $self->[STACK][TOP];

		# read line
		my $text = $top->[ITER]->();
		if (! defined $text) {					# file finished, read next
			pop @{$self->[STACK]};
			next;
		}

		# inc line number, save it to use as the line_nr of a multi-line
		# continuation
		my $line_nr = $top->[LINE_NR] += $top->[LINE_INC];

		# while line ends in \\, remove all blanks around it, incl. \r \n
		while ($text =~ s/ \s* \\ \s* \z / /x) {
			my $next = $top->[ITER]->();
			$top->[LINE_NR] += $top->[LINE_INC];
			
			defined($next) or last;		# no more input, ignore last \\
			$text .= $next;
		}
		
		# normalize eol
		$text =~ s/ \s* \z /\n/x;		# any ending blanks replaced by \n

		# line to be returned, is used in %include below
		my $line = Asm::Preproc::Line->new($text, $top->[FILE], $line_nr);
		
		# check for pre-processor directives
		if ($text =~ /^ \s* [\#\%] /gcix) {
			if ($text =~ / \G line /gcix) {
				# %line n+m file
				# #line n "file"
				if ($text =~ / \G \s+ (\d+) /gcix) {	# line_nr
					$top->[LINE_NR] = $1;

					if ($text =~ / \G \+ (\d+) /gcix) {	# optional line_inc
						$top->[LINE_INC] = $1;
					}
					else {
						$top->[LINE_INC] = 1;
					}

					if ($text =~ / \G \s+ \"? ([^\"\s]+) \"? /gcix) {	# file
						$top->[FILE] = $1;
					}

					# next line in nr+inc
					$top->[LINE_NR] -= $top->[LINE_INC];		
					next;		# get next line
				}
			}
			elsif ($text =~ / \G include /gcix) {
				# %include <file>
				# #include 'file'
				# %include "file"
				# #include  file 
				if ($text =~ / \G \s+	(?: \< ([^\>]+) \>  | 
											\' ([^\']+) \'  | 
											\" ([^\"]+) \"  |
											   (\S+)
										) /gcix) {
					my $file = $1 || $2 || $3 || $4;	
					$self->include($file, $line);
					next;		# get next line
				}
				else {
					$line->error("%include expects a file name\n");
				}
			}
			else {
				# ignore other unknown directives
				next;		# get next line
			}
		}
		else {
			# TODO: macro expansion
		}
		
		# return complete line
		return $line;
	}
}
#------------------------------------------------------------------------------

=head2 line_stream

Returns a L<Asm::Preproc::Stream|Asm::Preproc::Stream> object that will 
return the result of C<getline> on each C<get> call.

=cut

#------------------------------------------------------------------------------
sub line_stream {
	my($self) = @_;
	return Asm::Preproc::Stream->new(sub {$self->getline});
}
#------------------------------------------------------------------------------

=head1 PREPROCESSING

The following preprocessor-like lines are processed:

  %line N+M FILE

nasm-like line directive, telling that the next input line is 
line N from file FILE, 
followed by lines N+M, N+2*M, ... 
This information is used to generate error messages.
Usefull to parse a file preprocessed by nasm.

  #line N "FILE"

cpp-like line directive, telling that the next input line is 
line N from file FILE, 
followed by lines N+1, N+2, ... 
This information is used to generate error messages.
Usefull to parse a file preprocessed by cpp.

  %include 'FILE'
  %include "FILE"
  %include <FILE>
  %include  FILE
  #include 'FILE'
  #include "FILE"
  #include <FILE>
  #include  FILE

nasm/cpp-like include directive, asking to insert the contents 
of the given file in the input stream. 

All the other preprocessor-like lines are ignored, i.e. lines starting with '#' or '%'.

=head1 AUTHOR

Paulo Custodio, C<< <pscust at cpan.org> >>

=head1 BUGS and FEEDBACK

Please report any bugs or feature requests through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Asm-Preproc>.  

=head1 ACKNOWLEDGEMENTS

Inspired in the Netwide Assembler, L<http://www.nasm.us/>

=head1 LICENSE and COPYRIGHT

Copyright (c) 2010 Paulo Custodio.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1; # End of Asm::Preproc
