package Converter::Modules::YSOConverter;

use strict;
use warnings;
use IPC::System::Simple qw(capture);
use File::Path qw(make_path);

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
    my ($self, $input_path, $input_file) = @_;

    # Call yso_converter.py script using capture
    my $output_path = $input_path."/yso/";
    make_path($output_path);
    my $output_file = $input_file.".yso";
    my $result = capture("python3 ../../yso-marcbib/yso_converter.py -i ".$input_path.$input_file." -o ".$output_path.$output_file." -f marcxml --all_languages --write_all");

    if ($result) {
        print "Records converted successfully\n" if $self->verbose;
        return ($output_path, $output_file);
    } else {
        warn "Error occurred during conversion\n";
        return;
    }

    
}

1;