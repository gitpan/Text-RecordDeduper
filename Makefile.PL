use 5.008004;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile
(
    NAME           => 'Text::RecordDeduper',
    VERSION_FROM   => 'lib/Text/RecordDeduper.pm', 
    ABSTRACT_FROM  => 'lib/Text/RecordDeduper.pm',
    AUTHOR         => 'Kim Ryan'
);
