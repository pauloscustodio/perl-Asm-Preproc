#!perl

# $Id: Token-new.t,v 1.5 2010/09/12 21:09:27 Paulo Exp $

use strict;
use warnings;

use Test::More;
use_ok 'Asm::Preproc::Token';
use_ok 'Asm::Preproc::Line';
use_ok 'Asm::Preproc::Lexer';

my $lex;
my $token;

#------------------------------------------------------------------------------
# error creating lexer
eval {Asm::Preproc::Lexer->new};
like $@, qr/^tokens expected at /, "no tokens";

eval {Asm::Preproc::Lexer->new('ID')};
like $@, qr/^regexp expected at /, "no regexp";

#------------------------------------------------------------------------------
# match one pattern, check for pattern with /x and multiple lines
isa_ok	$lex = Asm::Preproc::Lexer->new(
		ID => qr/
				\w+
				/ix), 'Asm::Preproc::Lexer';

# match text
$lex->from('abc'); 
$lex->from('def');
t_get(ID	=> 'def',	'def',	undef,	undef );

$lex->from('ghi');
t_get(ID	=> 'ghi',	'ghi',	undef,	undef );
t_get(ID	=> 'abc',	'abc',	undef,	undef );
t_get(undef );

# match lines
$lex->from(
		Asm::Preproc::Line->new('aa',	'f.asm', 1),
		Asm::Preproc::Line->new('bb',	'f.asm', 2),
);
t_get(ID	=> 'aa',	'aa',	'f.asm',	1 );
t_get(ID	=> 'bb',	'bb',	'f.asm',	2 );
t_get(undef );

# error in text
$lex->from('abc,def'); 
t_get(ID	=> 'abc',	'abc,def',	undef,	undef );
eval { $lex->get };
is $@, "error: no token recognized at: ,def\n", "unrecognized text";

# error in line
$lex->from(
		Asm::Preproc::Line->new('aa,bb',	'f.asm', 1),
);
t_get(ID	=> 'aa',	'aa,bb',	'f.asm',	1 );
eval { $lex->get };
is $@, "f.asm(1) : error: no token recognized at: ,bb\n", "unrecognized line";

#------------------------------------------------------------------------------
# match with transform
isa_ok	$lex = Asm::Preproc::Lexer->new(
	NUM		=> qr/\d+/,		sub { my($t,$v) = @_; [lc($t), $v*10]},
	ID 		=> qr/(\w+)/i,	sub {[uc($1), uc($1)]},
	WS		=> qr/\s+/,		sub {()},
), 'Asm::Preproc::Lexer';
$lex->from('abc 123 def 456');
t_get(ABC	=> 'ABC',	'abc 123 def 456',	undef,	undef );
t_get(num	=> 1230,	'abc 123 def 456',	undef,	undef );
t_get(DEF	=> 'DEF',	'abc 123 def 456',	undef,	undef );
t_get(num	=> 4560,	'abc 123 def 456',	undef,	undef );
t_get(undef );

#------------------------------------------------------------------------------
# read with stream
isa_ok	$lex = Asm::Preproc::Lexer->new(
	NUM		=> qr/\d+/,
	ID 		=> qr/(\w+)/i,
	WS		=> qr/\s+/,		undef,
), 'Asm::Preproc::Lexer';
$lex->from('abc 123 def 456');
my $stream = $lex->stream;
my $line = Asm::Preproc::Line->new('abc 123 def 456');
is_deeply $stream->get, Asm::Preproc::Token->new(ID  => 'abc', $line);
is_deeply $stream->get, Asm::Preproc::Token->new(NUM => 123,   $line);
is_deeply $stream->get, Asm::Preproc::Token->new(ID  => 'def', $line);
is_deeply $stream->get, Asm::Preproc::Token->new(NUM => 456,   $line);
is $stream->get, undef;

#------------------------------------------------------------------------------
# clone
isa_ok	$lex = Asm::Preproc::Lexer->new(
	NUM		=> qr/\d+/,
	ID 		=> qr/\w+/i,
	WS		=> qr/\s+/,		sub {()},
), 'Asm::Preproc::Lexer';
$lex->from('abc 123 def 456');
t_get(	ID	=> 'abc',	'abc 123 def 456',	undef,	undef );
t_get(	NUM	=> 123,		'abc 123 def 456',	undef,	undef );

isa_ok my $lex2 = $lex->clone, 'Asm::Preproc::Lexer';
is $lex2->get, undef, "clone empty";
$lex2->from('zx');

t_get(	ID	=> 'def',	'abc 123 def 456',	undef,	undef );
is_deeply $lex2->get, 
	Asm::Preproc::Token->new( ID => 'zx', 
		Asm::Preproc::Line->new('zx')), "clone zx";

t_get(	NUM	=> 456,		'abc 123 def 456',	undef,	undef );
is $lex2->get, undef, "clone empty";

t_get(	undef );
is $lex2->get, undef, "clone empty";

# clone is empty
$lex = $lex2;
t_get(	undef );

# clone recognizes same tokens
$lex->from('abc 123 def 456');
t_get(ID	=> 'abc',	'abc 123 def 456',	undef,	undef );
t_get(NUM	=> 123,		'abc 123 def 456',	undef,	undef );
t_get(ID	=> 'def',	'abc 123 def 456',	undef,	undef );
t_get(NUM	=> 456,		'abc 123 def 456',	undef,	undef );
t_get(undef );

#------------------------------------------------------------------------------
# multi-line blocks
isa_ok	$lex = Asm::Preproc::Lexer->new(
     BLANKS  => qr/\s+/,       sub {()},
     COMMENT => [qr/\/\*/, qr/\*\//],
                               undef,
     QSTR    => [qr/'/],       sub { my($type, $value) = @_;
                                     [$type, 
                                      substr($value, 1, length($value)-2)] },
     QQSTR   => [qr/"/, qr/"/],
     NUM     => qr/\d+/,
     ID      => qr/[a-z]+/,    sub { my($type, $value) = @_; 
                                     [$type, $value] },
     SYM     => qr/(.)/,       sub { [$1, $1] },
), 'Asm::Preproc::Lexer';
my $input = q{
a = 25/* 'hello' */;/* 'world' */;/* multi-line

*/b = 26;
'single line';'multiple line
continues here
and ends here';
"single line"; "single line"; "multiple line
continues here
and ends here";
"unfinished line
};
$input =~ s/\r\n/\n/g;
my @input = map {"$_\n"} split(/\n/, $input);
$lex->from(@input);

my @line = (qq{a = 25/* 'hello' */;/* 'world' */;/* multi-line\n}, undef, undef);
t_get(ID	=> 'a',		@line);
t_get('='	=> '=',		@line);
t_get(NUM	=> 25,		@line);
t_get(';'	=> ';',		@line);
t_get(';'	=> ';',		@line);

@line = (qq{*/b = 26;\n}, undef, undef);
t_get(ID	=> 'b',		@line);
t_get('='	=> '=',		@line);
t_get(NUM	=> 26,		@line);
t_get(';'	=> ';',		@line);

@line = (qq{'single line';'multiple line\n}, undef, undef);
t_get(QSTR	=> 'single line',		@line);
t_get(';'	=> ';',		@line);
t_get(QSTR	=> "multiple line\ncontinues here\nand ends here",		@line);

@line = (qq{and ends here';\n}, undef, undef);
t_get(';'	=> ';',		@line);

@line = (qq{"single line"; "single line"; "multiple line\n}, undef, undef);
t_get(QQSTR	=> qq{"single line"},		@line);
t_get(';'	=> ';',		@line);
t_get(QQSTR	=> qq{"single line"},		@line);
t_get(';'	=> ';',		@line);
t_get(QQSTR	=> qq{"multiple line\ncontinues here\nand ends here"},		@line);

@line = (qq{and ends here";\n}, undef, undef);
t_get(';'	=> ';',		@line);
eval {$lex->get};
is $@, "error: unbalanced token at: \"unfinished line\n", "unbalanced token";

$lex->from("/* unfinished comment ");
eval {$lex->get};
is $@, "error: unbalanced token at: /*\n", "unbalanced token";


done_testing;

#------------------------------------------------------------------------------
# TEST
sub t_get {
	my($type, $value, $text, $file, $line_nr) = @_;
	my $id = "[line ".(caller)[2]."]";

	if (defined $type) {
		isa_ok	$token = $lex->get, 'Asm::Preproc::Token';
		is		$token->type, 		$type, 			"$id type $type";
		is		$token->value, 		$value,			"$id value $value";
		is		$token->line->text, $text,			"$id text $text";
		is		$token->line->file, $file,			"$id file ".($file||'');
		is		$token->line->line_nr, $line_nr,	"$id line_nr ".($line_nr||0);
	}
	else {
		is	$lex->get, undef, "$id EOF";
	}
}
