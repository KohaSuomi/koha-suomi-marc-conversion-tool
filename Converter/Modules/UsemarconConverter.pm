package Converter::Modules::UsemarconConverter;

use strict;
use warnings;
use IPC::System::Simple qw(capture);
use File::Path qw(make_path);
use FindBin '$Bin';

sub new {
    my ($class, $params) = @_;
    my $self = {};
    $self->{_params} = $params;
    bless($self, $class);
    return $self;
}

sub verbose {
    my ($self) = @_;
    return $self->{_params}->{verbose};
}

sub convertRecords {
    my ($self, $input_path, $input_file, $usemarcon_config) = @_;

    my $project_root = "$Bin/../..";  # This will give you the project root path

    my $output_path = $input_path."/rda/";
    my $output_file = $input_file.".rda";

    # Create the output directory if it does not exist
    make_path($output_path);

    my $converted_record = capture("$project_root/usemarcon/program/usemarcon", $usemarcon_config, $input_path.$input_file, $output_path.$output_file);
    
    print "$converted_record\n" if $self->verbose;
    return ($output_path, $output_file);
}

1;