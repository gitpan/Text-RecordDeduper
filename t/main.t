# main.t for Text::RecordDeduper

use Test::Simple tests => 4;
use strict;
use Text::RecordDeduper;

my %nick_names = (Bob => 'Robert',Rob => 'Robert');
my $near_deduper = new Text::RecordDeduper();
$near_deduper->field_separator("\t");
$near_deduper->add_key(field_number => 1,ignore_case => 1, alias => \%nick_names);
$near_deduper->add_key(field_number => 2, ignore_whitespace => 1);
$near_deduper->dedupe_file("t/tab_delim.txt") or die $!;

open(UNIQ,"<t/tab_delim_uniqs.txt") or die $!;
my @lines = <UNIQ>;
close(UNIQ);
ok( $lines[0] eq  "Robert\tO'Brien\tWaverley\t100\n",'unique record 1 found' );
ok( $lines[1] eq  "Jane\tDoe\tBondi\t103\n",       'unique record 2 found' );

open(DUPES,"<t/tab_delim_dupes.txt") or die $!;
@lines = <DUPES>;
close(DUPES);

ok( $lines[0] eq  "Robert\tO'Brien\tWaverley\t101\n",'duplicate record 1 found' );
ok( $lines[1] eq  "Bob\tO'Brien\tWaverley\t102\n",   'duplicate record 2 found' );

