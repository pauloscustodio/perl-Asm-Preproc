use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Asm::Preproc',
    AUTHOR              => q{Paulo Custodio <pscust@cpan.org>},
    VERSION_FROM        => 'lib/Asm/Preproc.pm',
    ABSTRACT_FROM       => 'lib/Asm/Preproc.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
		'File::Spec'	=> 0,
        'Test::More' 	=> 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => [ 'Asm-Preproc-*',
										'*.tmp',
										'*.bak',
									  ]
						   },
);
