=head1 NAME

Text::RecordDeduper - Separate complete, partial and near duplicate text records

=head1 SYNOPSIS

    use Text::RecordDeduper;

    my $deduper = new Text::RecordDeduper;

    # Find and remove entire lines that are duplicated
    $deduper->dedupe_file("orig.txt");

    # Dedupe comma separated records, duplicates defined by several fields
    $deduper->field_separator(',');
    $deduper->add_key(field_number => 1, ignore_case => 1 );
    $deduper->add_key(field_number => 2, ignore_whitespace => 1);

    # Find 'near' dupes by allowing for given name aliases
    my %nick_names = (Bob => 'Robert',Rob => 'Robert');
    my $near_deduper = new Text::RecordDeduper();
    $near_deduper->add_key(field_number => 2, alias => \%nick_names) or die;
    $near_deduper->dedupe_file("names.txt");

    # Now find 'near' dupes in an array of records
    my ($uniqs,$dupes) = $near_deduper->dedupe_array(\@some_records);



=head1 DESCRIPTION

This module allows you to take a text file of records and split it into 
a file of unique and a file of duplicate records.

Records are defined as a set of fields. Fields may be separated by spaces, 
commas, tabs or any other delimiter. Records are separated by a new line.

If no options are specifed, a duplicate will be created only when all the
fields in arecord is duplicated.

By specifying options a duplicate record is defined by which fields or partial 
fields must not occur more than once per record. There are also options to 
ignore case sensitivity, leading and trailing white space.

Additionally 'near' or 'fuzzy' duplicates can be defined. This is done by creating
aliases, such as Bob => Robert.

This module is useful for finding duplicates that have been created by
multiple data entry, or merging of similar records

=head1 Example

Given a text file F<names.txt> with space separated values and duplicates defined 
by the second and third columns:

    100 Robert   Smith    
    101 Bob      Smith    
    102 John     Brown    
    103 Jack     White   
    104 Bob      Smythe    
    105 Robert   Smith    


    use Text::RecordDeduper;

    my %nick_names = (Bob => 'Robert',Rob => 'Robert');
    my $near_deduper = new Text::RecordDeduper();
    $near_deduper->field_separator(' ');
    $near_deduper->add_key(field_number => 2, alias => \%nick_names) or die;
    $near_deduper->add_key(field_number => 3) or die;
    $near_deduper->dedupe_file("names.txt");

Text::RecordDeduper will produce a file of unique records, F<names_uniqs.txt>

    100 Robert   Smith    
    102 John     Brown    
    103 Jack     White   
    104 Bob      Smythe    

and a file of duplicates, F<names_dupes.txt>

    101 Bob      Smith    
    105 Robert   Smith   

The original file, F<names.txt> is left intact.

=head1 METHODS

=head2 new

The C<new> method creates an instance of a deduping object. This must be
called before any of the following methods are invoked.

=head2 field_separator

Sets the token to use as the field delimiter. Accepts any character as well as
Perl escaped characters such as "\t" etc.  If this method ins not called the 
deduper assumes you have fixed width fields .

    $deduper->field_separator(',');


=head2 add_key

Lets you add a field to the definition of a duplicate record. If no keys
have been added, the entire record will become the key, so that only records 
duplicated in their entirity are removed.

    $deduper->add_key
    (
        field_number => 1, 
        key_length => 5, 
        ignore_case => 1,
        ignore_whitespace => 1,
        alias => \%nick_names
    );

=over 4

=item field_number

Specifies the number of the field in the record to add to the key (1,2 ...). 
Note that this option only applies to character separated data. You will get a 
warning if you try to specify a field_number for fixed width data.

=item start_pos

Specifies the position of the field in characters to add to the key. Note that 
this option only applies to fixed width data. You will get a warning if you 
try to specify a start_pos for character separated data. You must also specify
a key_length.

Note that the first column is numbered 1, not 0.


=item key_length

The length of a key field. This must be specifed if you are using fixed width 
data (along with a start_pos). It is optional for character separated data.

=item ignore_case 

When defining a duplicate, ignore the case of characters, so Robert and ROBERT
are equivalent.

=item ignore_whitespace

When defining a duplicate, ignore white space that leasd or trails a field's data.

=item alias

When defining a duplicate, allow for aliases substitution. For example

    my %nick_names = (Bob => 'Robert',Rob => 'Robert');
    $near_deduper->add_key(field_number => 2, alias => \%nick_names) or die;

Whenever field 2 contains 'Bob', it will be treated as a duplicate of a record 
where field 2 contains 'Robert'.

=back


=head2 dedupe_file

This method takes a file name F<basename.ext> as it's only argument. The file is
processed to detect duplicates, as defined by the methods above. Unique records
are place in a file named  F<basename_uniq.ext> and duplicates in a file named 
F<basename_dupe.ext>. Note that If either of this output files exist, they are 
over written The orignal file is left intact.

    $deduper->dedupe_file("orig.txt");


=head2 dedupe_array

This method takes an array reference as it's only argument. The array is
processed to detect duplicates, as defined by the methods above. Two array
references are retuned, the first to the set of unique records and the second 
to the set of duplicates.

Note that the memory constraints of your system may prvent you from processing 
very large arrays.

    my ($unique_records,duplicate_records) = $deduper->dedupe_array(\@some_records);


=head1 TO DO

    Allow for multi line records
    Add batch mode driven by config file or command line options
    Allow option to warn user when over writing output files
    Allow user to customise suffix for uniq and dupe output files


=head1 SEE ALSO

sort(3), uniq(3), L<Text::ParseWords>, L<Text::RecordParser>, L<Text::xSV>


=head1 AUTHOR

RecordDeduper was written by Kim Ryan <kimryan at cpan d o t org>


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 Kim Ryan. 


This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.


=cut


package Text::RecordDeduper;
use File::Basename;
use Text::ParseWords;
use Data::Dumper;




use 5.008004;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);
our $VERSION = '0.03';

#-------------------------------------------------------------------------------
# Create a new instance of a deduping object. 

sub new
{
    my $class = shift;
    my %args = @_;

    my $deduper = {};
    bless($deduper,$class);


    # Default to no separator, until we find otherwise
    $deduper->{field_separator} = '';

    return ($deduper);
}
#-------------------------------------------------------------------------------
# Create a new instance of a deduping object. 

sub field_separator
{
    my $deduper = shift;

    my ($field_separator) = @_;

    # Escape pipe symbol so it does get interpreted as alternation character
    # when splitting fields in _get_key_fields
    $field_separator eq '|' and $field_separator = '\|';

    # add more error checking here

    $deduper->{field_separator} = $field_separator;
    return($deduper);
}
#-------------------------------------------------------------------------------
#  
sub add_key
{
    my $deduper = shift;
    my %args = @_;


    $deduper->{key_counter}++;

    if ( $args{field_number} )
    {
        unless ( $deduper->{field_separator} )
        {
            warn "Cannot use field_number on fixed width lines";
            return;
        }
    }
    elsif ( $args{start_pos} )
    {
        if ( $deduper->{field_separator} )
        {
            warn "Cannot use start_pos on character separated records";
            return;
        }
        else
        {
            unless ( $args{key_length} )
            {
                warn "No key_length defined for start_pos: $args{start_pos}";
                return;
            }
        }
    }

    foreach my $current_key (keys %args)
    {
        $deduper->{key}{$deduper->{key_counter}}{$current_key} = $args{$current_key};
    }
    return ($deduper);
}
#-------------------------------------------------------------------------------
# 
sub dedupe_file
{
    my ($deduper,$input_file_name) = @_;


    # to do, move file ops to it's own sub routine
    unless ( -T $input_file_name and -s $input_file_name )
    {
        warn("Could not open input file: $input_file_name"); 
        return;
    }

    unless (open(INPUT_FH,"<$input_file_name"))
    {
        warn "Could not open input file: $input_file_name";
        return;
    }

    my ($file_name,$path,$suffix) = File::Basename::fileparse($input_file_name,qr{\..*});

    my $file_name_unique_records    = "$path/$file_name\_uniqs$suffix";
    my $file_name_duplicate_records = "$path/$file_name\_dupes$suffix";

    # TO DO!!! test for overwriting of previous Deduper output
    unless( open(UNIQUE_FH,">$file_name_unique_records") )
    {
        warn "Could not open file: $file_name_unique_records: $!";
        return;
    }
    unless ( open(DUPES_FH,">$file_name_duplicate_records" ) )
    {
        warn "Could not open file: $file_name_duplicate_records: $!";
        return;
    }


    my %seen;
    while ( <INPUT_FH> )
    {
        chomp;
        my $current_line = $_;
        
        my $key = _create_key($deduper,$current_line);
        # print("KEY: $key\n");
        
        if ( $seen{$key} )
        {
            print(DUPES_FH $current_line,"\n");
        }
        else
        {
            $seen{$key}++;
            print(UNIQUE_FH $current_line,"\n");
        }
    }
    close(INPUT_FH);
    close(UNIQUE_FH);
    close(DUPES_FH);

}
#-------------------------------------------------------------------------------
# 
sub dedupe_array
{
    my ($deduper,$input_array_ref) = @_;


    my %seen;
    my (@unique,@dupe);
    foreach my $current_line ( @$input_array_ref )
    {
        my $key = _create_key($deduper,$current_line);
        # print("KEY: $key\n");

        if ( $seen{$key} )
        {
            push(@dupe,$current_line);
        }
        else
        {
            $seen{$key}++;
            push(@unique,$current_line);
        }
    }
    return(\@unique,\@dupe);
}
#-------------------------------------------------------------------------------
# 
sub _create_key
{
    my ($deduper,$current_line) = @_;

    my $complete_key = '';
    if ( $deduper->{key} )
    {
        my (@keys) = _get_key_fields($deduper,$current_line);
        $complete_key = _transform_key_fields($deduper,@keys);
    }
    else
    {
        $complete_key = $current_line;
    }
    return($complete_key);
}
#-------------------------------------------------------------------------------
# 

sub _get_key_fields
{
    my ($deduper,$current_line) = @_;

    my @keys;

    if ( $deduper->{field_separator} )
    {

        # The ParseWords module will not handle single quotes within fields, 
        # so add an escape sequence between any apostrophe bounded by a
        # letter on each side. Note that this applies even if there are no
        # quotes in your data, the module needs balanced quotes.        
        if (  $current_line =~ /\w'\w/ )
        {
            # check for names with apostrophes, like O'Reilly
            $current_line =~ s/(\w)'(\w)/$1\\'$2/g;
        }

        # Use ParseWords module to spearate delimited field. 
        # '0' option means don't return any quotes enclosing a field
        my (@field_data) = &Text::ParseWords::parse_line($deduper->{field_separator},0,$current_line);

        
        foreach my $key_number ( sort keys %{$deduper->{key}} )
        {
            my $current_field_data = $field_data[$deduper->{key}->{$key_number}->{field_number} - 1];
            unless ( $current_field_data )
            {
                # A record has less fields then we were expecting, so no
                # point searching for anymore.
                print("Short record\n");
                print("Array indice :",$deduper->{key}->{$key_number}->{field_number} - 1,"\n");
                print("Current line : $current_line\n");

                print("All fields   :", @field_data,"\n");
                last;
                # TO DO, add a warning if user specifies records must have 
                # a full set of fields??
            }

            if ( $deduper->{key}->{$key_number}->{key_length} )
            {
                $current_field_data = substr($current_field_data,0,$deduper->{key}->{$key_number}->{key_length});
            }
            push(@keys,$current_field_data);
        }
    }
    else
    {
        foreach my $key_number ( sort keys %{$deduper->{key}} )
        {
            my $current_field_data = substr($current_line,$deduper->{key}->{$key_number}->{start_pos} - 1,
                $deduper->{key}->{$key_number}->{key_length});
            if ( $current_field_data )
            {
                push(@keys,$current_field_data);
            }
            else
            {
                print("Short record\n");
                print("Current line : $current_line\n");
                last;
                # TO DO, add a warning if user specifies records must have 
                # a full set of fields??
            }
        }
    }
    return(@keys);
}

#-------------------------------------------------------------------------------
# 

sub _transform_key_fields
{
    my ($deduper,@keys) = @_;

    my $complete_key = '';
    
    foreach my $key_number ( sort keys %{$deduper->{key}} )
    {
        my $current_key = $keys[ $key_number - 1 ];

        # Aliases
        if ( $deduper->{key}->{$key_number}->{alias} )
        {
            # QUERY!!! should we allow for case-insensitive aliases???
            if ( $deduper->{key}->{$key_number}->{alias}{$current_key})
            {
                $current_key = $deduper->{key}->{$key_number}->{alias}{$current_key};
            }
        }

        # If this key is case insensitive, fold data to lower case
        if ( $deduper->{key}->{$key_number}->{ignore_case} )
        {
            $current_key = lc($current_key);
        }

        # strip out leading or trailing whitespace
        if ( $deduper->{key}->{$key_number}->{ignore_whitespace} )
        {
            $current_key =~ s/^\s+//;
            $current_key =~ s/\s+$//;
        }


        $complete_key .= $current_key;
        # Add field sepeartor to help in debugging and reporting
        $complete_key .= ':';
    }
    return($complete_key);
}

1;

