=head1 NAME

Text::RecordDeduper - Remove duplicate records from a text file

=head1 SYNOPSIS

    use Text::RecordDeduper;

    my $deduper = new Text::RecordDeduper;

    # Find and remove entire lines that are duplicated
    $deduper->dedupe_file("orig.txt");

    # Dedupe comma seperated records, duplicates defined by several fields
    $deduper->field_separator(',');
    $deduper->add_key(field_number => 1, ignore_case => 1 );
    $deduper->add_key(field_number => 2);

    # Find 'near' dupes by allowing for given name aliases
    my %nick_names = (Bob => 'Robert',Rob => 'Robert');
    my $near_deduper = new Text::RecordDeduper();
    $near_deduper->add_key(field_number => 2, alias => \%nick_names) or die;
    $near_deduper->dedupe_file("names.txt");


=head1 DESCRIPTION

This module allows you to take a text file of records and split it into 
a file of unique and a file of duplicate records.

Records are defined as a set of fields. Fields may be sepearted by spaces, 
commas, tabs or any other delimiter. Records are separated by a new line.

If no options are specifed, a duplicate will be created only when an entire
record is duplicated.

By specifying options a duplicate record is definedby  which fields or parts of 
fields must not occur more than once per record. There are also options to 
ignore white  space and case sensitivity.

Additionally 'near' or 'fuzzy' duplicates can be defined. This is done by creating
aliases, such as Bob => Robert

=head1 Example

Given a text file names.txt with space separated values and duplicates defined 
by the second and third columns:

100 Robert   Smith    
101 Bob      Smith    
102 John     Brown    
103 Jack     White   
104 Bob      Smythe    
105 Robert   Smith    


use Text::RecordDeduper;

my %nick_names = (Bob => 'Robert',Rob => 'Robert');
my $near_dedupes = new Text::RecordDeduper();
$near_dedupes->field_separator(' ');
$near_dedupes->add_key(field_number => 2, alias => \%nick_names) or die;
$near_dedupes->add_key(field_number => 3) or die;
$near_dedupes->dedupe_file("names.txt");

Text::RecordDeduper will produce a file of unique records, F<names_uniqs.txt>

100 Robert   Smith    
102 John     Brown    
103 Jack     White   
104 Bob      Smythe    

and a file of duplicates, F<names_dupes.txt>

101 Bob      Smith    
105 Robert   Smith   

The original file, names.txt is left intact.

=head1 METHODS

=head2 new

The C<new> method creates an instance of a deduping object. This must be
called before any of the following methods are invoked.

=head2 field_separator

Sets the token to use as the field delimiter. Accepts any character as well as
Perl escaped characters such as \t etc.  If this method ins not called the 
deduper assumes you have fixed width fields .

    $deduper->field_separator(',');


=head2 add_key

    $deduper->add_key(field_number => 1, ignore_case => 1 );

=head2 dedupe_file

    $deduper->dedupe_file("orig.txt");


=head1 TO DO

Allow for multi line records
Ignore leading and trailing white space in fields
Add batch mode drive by a config file
Allow user to warn when overwritting output files
Allow user ot customise suffix fo uniq and dupe output files


=head1 SEE ALSO

sort(3), uniq(3)
L<Text::RecordParser>,L<Text::xSV>


=head1 AUTHOR

RecordDeduper was written by Kim Ryan E<lt>kimryan at cpan d o t orgE><gt>


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 Kim Ryan. 


This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.


=cut


package Text::RecordDeduper;
use File::Basename;
use Text::RecordParser;



use 5.008004;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);
our $VERSION = '0.01';

#-------------------------------------------------------------------------------
# Create a new instance of a deduping object. 

sub new
{
    my $class = shift;
    my %args = @_;

    my $dedupe = {};
    bless($dedupe,$class);


    # Default to no separator, until we find otherwise
    $dedupe->{field_separator} = '';

    return ($dedupe);
}
#-------------------------------------------------------------------------------
# Create a new instance of a deduping object. 

sub field_separator
{
    my $dedupe = shift;

    my ($field_separator) = @_;
    # add error checking here
    $dedupe->{field_separator} = $field_separator;

    return($dedupe);
}
#-------------------------------------------------------------------------------
#  
sub add_key
{
    my $dedupe = shift;
    my %args = @_;


    my $key_number;
    if ( $args{field_number} )
    {
        if ( $dedupe->{field_separator} )
        {
            # extract the column number which will form the index for all following properties
            $key_number = $args{field_number};
            delete($args{field_number});
        }
        else
        {
            warn "Cannot use field_number on fixed width lines";
            return;
        }
    }
    elsif ( $args{start_pos} )
    {
        if ( $dedupe->{field_separator} )
        {
            warn "Cannot use start_pos on character separated records";
            return;
        }
        else
        {
            if ( $args{key_length} )
            {
                # TO DO, test for out of bounds or overlapping keys here!!!
                # how to know maximum line length?
                $key_number = $args{start_pos};
                delete($args{start_pos});
            }
            else
            {
                warn "No key_length defined for start_pos: $args{start_pos}";
                return;
            }
        }
    }

    foreach my $current_key (keys %args)
    {
        $dedupe->{key}{$key_number}{$current_key} = $args{$current_key};
    }
    return ($dedupe);
}
#-------------------------------------------------------------------------------
# 
sub dedupe_file
{
    my ($dedupe,$input_file_name) = @_;

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

    my $record_parser;
    # Initialise Record Parser object if needed
    if ( $dedupe->{field_separator} )
    {
        $record_parser = Text::RecordParser->new;
        $record_parser->field_separator($dedupe->{field_separator});
    }


    my %seen;
    while ( <INPUT_FH> )
    {
        chomp;
        my $current_line = $_;
        
        my $key = _create_key($dedupe,$record_parser,$current_line);
        print("KEY: $key\n");
        
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
sub _create_key
{
    my ($dedupe,$record_parser,$current_line) = @_;

    my $complete_key = '';
    if ( $dedupe->{key} )
    {
        my (@keys) = _get_key_fields($dedupe,$record_parser,$current_line);
        $complete_key = _transform_key_fields($dedupe,@keys);
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
    my ($dedupe,$record_parser,$current_line) = @_;

    my @keys;

    if ( $dedupe->{field_separator} )
    {
        # Escape pipe symbol so it does not mean alternation
        # $field_separator eq '|' and $field_separator = '\|';

        # TO DO!!! text::xsv ???       
        # my (@field_data) = split(/$field_separator/,$current_line);
        $record_parser->data($current_line);
        my (@field_data) = $record_parser->fetchrow_array;



        # TO DO, test for column number out of bounds
        foreach my $field_number ( sort keys %{$dedupe->{key}} )
        {
            my $current_field_data = $field_data[$field_number - 1];
            unless ( $current_field_data )
            {
                warn("Too many columns specified");
                return;
            }

            if ( $dedupe->{key}->{$field_number}->{key_length} )
            {
                $current_field_data = substr($current_field_data,0,$dedupe->{key}->{$field_number}->{key_length});
            }
            push(@keys,$current_field_data);
        }
    }
    else
    {
        foreach my $field_number ( sort keys %{$dedupe->{key}} )
        {
            push(@keys,substr($current_line,$field_number - 1,$dedupe->{key}->{$field_number}->{key_length}));
        }
    }
    return(@keys);
}

#-------------------------------------------------------------------------------
# 

sub _transform_key_fields
{
    my ($dedupe,@keys) = @_;

    my $complete_key = '';
    
    foreach my $field_number ( sort keys %{$dedupe->{key}} )
    {
        my $current_key = $keys[ $field_number - 1 ];

        # Aliases
        if ( $dedupe->{key}->{$field_number}->{alias} )
        {
            # QUERY!!! should we allow for case-insensitive aliases???
            if ( $dedupe->{key}->{$field_number}->{alias}{$current_key} )
            {
                $current_key = $dedupe->{key}->{$field_number}->{alias}{$current_key};
            }
        }

        # If this key is case insensitive, fold data to lower case
        if ( $dedupe->{key}->{$field_number}->{ignore_case} )
        {
            $current_key = lc($current_key);
        }

        # TO DO, ignote trailing white space???

        $complete_key .= $current_key;
        # Add field sepeartor to help in debugging and reporting
        $complete_key .= ':';
    }
    return($complete_key);
}

1;

