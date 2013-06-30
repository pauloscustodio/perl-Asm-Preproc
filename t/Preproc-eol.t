#!perl

use strict;
use warnings;

use Test::More;
use File::Slurp;

require_ok 't/utils.pl';

our $pp;
my $file = "$0.tmp"; $file =~ s/\\/\//g;

#------------------------------------------------------------------------------
# test eol normalization and joining continuation lines
my @input = ("1\r\n",
			 "2\n",
			 "3",
			 "4a\\\r\n",
			 "4b\\\n",
			 "4c\\ ",		# back-slash only joins if at end of line
			 "5a\\",
			 "5b\\\n",
			 "5c\r\n",
			 "6\r",
			 "7\n\r",
			 "8\\ \n",
			 "9\\");
			 
#------------------------------------------------------------------------------
# different config for line continuation
{ 
	package MyPreproc;
	use parent 'Asm::Preproc';
	sub config_line_continuation { 0 }
}
	
#------------------------------------------------------------------------------
# do line continuation
isa_ok $pp = Asm::Preproc->new, 'Asm::Preproc';
$pp->include_list(@input);
test_getline("1\n", 			"-", 	1);
test_getline("2\n", 			"-", 	2);
test_getline("3\n", 			"-", 	3);
test_getline("4a 4b 4c\\\n", 	"-", 	4);
test_getline("5a 5b 5c\n", 		"-", 	7);
test_getline("6\n", 			"-", 	10);
test_getline("7\n", 			"-", 	11);
test_getline("8\\\n", 			"-", 	12);
test_getline("9\n", 			"-", 	13);
test_eof();

write_file($file, {binmode => ':raw'}, @input);
isa_ok $pp = Asm::Preproc->new, 'Asm::Preproc';
$pp->include($file);
test_getline("1\n", 			$file, 	1);
test_getline("2\n", 			$file, 	2);
test_getline("34a 4b 4c\\ 5a\\5b 5c\n",
								$file, 	3);
test_getline("6\n", 			$file, 	7);
test_getline("7\n", 			$file, 	8);
test_getline("8\\\n", 			$file, 	9);
test_getline("9\n", 			$file, 	10);
test_eof();

#------------------------------------------------------------------------------
# do not line continuation
isa_ok $pp = MyPreproc->new, 'Asm::Preproc';
$pp->include_list(@input);
test_getline("1\n", 			"-", 	1);
test_getline("2\n", 			"-", 	2);
test_getline("3\n", 			"-", 	3);
test_getline("4a\\\n",		 	"-", 	4);
test_getline("4b\\\n", 			"-", 	5);
test_getline("4c\\\n", 			"-", 	6);
test_getline("5a\\\n", 			"-", 	7);
test_getline("5b\\\n",	 		"-", 	8);
test_getline("5c\n",	 		"-", 	9);
test_getline("6\n", 			"-", 	10);
test_getline("7\n", 			"-", 	11);
test_getline("8\\\n", 			"-", 	12);
test_getline("9\\\n", 			"-", 	13);
test_eof();

write_file($file, {binmode => ':raw'}, @input);
isa_ok $pp = MyPreproc->new, 'Asm::Preproc';
$pp->include($file);
test_getline("1\n", 			$file, 	1);
test_getline("2\n", 			$file, 	2);
test_getline("34a\\\n",			$file, 	3);
test_getline("4b\\\n",			$file, 	4);
test_getline("4c\\ 5a\\5b\\\n",	$file, 	5);
test_getline("5c\n",			$file, 	6);
test_getline("6\n", 			$file, 	7);
test_getline("7\n", 			$file, 	8);
test_getline("8\\\n", 			$file, 	9);
test_getline("9\\\n", 			$file, 	10);
test_eof();

unlink($file);
done_testing();
