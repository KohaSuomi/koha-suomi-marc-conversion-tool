#!/usr/bin/perl

# Copyright 2023 Koha-Suomi Oy
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;

BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

use Getopt::Long;
use XML::LibXML;

use C4::Record qw( marc2marcxml );

use Converter::Modules::Chunker;
use Converter::Modules::UsemarconConverter;

use open ':std', ':encoding(UTF-8)';

sub usage {
    print STDERR <<USAGE;
  Will print all active MARC records in database to
  OUTPUT_DIRECTORY .

  -p --path
  -l --limit
  -v --verbose
  --usemarcon-config

USAGE
    exit $_[0];
}

my ( $help, $config, $path, $limit, $verbose, $usemarcon_config );

GetOptions(
    'h|help'       => \$help,
    'p|path:s'     => \$path,
    'l|limit:i'    => \$limit,
    'v|verbose'  => \$verbose,
    'usemarcon-config:s' => \$usemarcon_config,
) || usage(1);

usage(0) if ($help);

if ( !$path || !-d $path || !-w $path ) {
    print STDERR
"Error: You must specify a valid and writeable directory to dump the print notices in.\n";
    usage(1);
}

if (!$usemarcon_config) {
    print STDERR
"Error: You must specify a valid usemarcon config file.\n";
    usage(1);
}

my $count = 0;
my $chunker = Converter::Modules::Chunker->new(undef, $limit, undef, $verbose);
my $converter = Converter::Modules::UsemarconConverter->new({verbose => $verbose}); # Create a new instance of UsemarconConverter
my $yso_converter = Converter::Modules::YSOConverter->new({verbose => $verbose});

while (my $records = $chunker->getChunkAsMARCRecord(undef, undef)) {
    my $xml = MARC::File::XML::header('UTF-8');
    my $timestamp = POSIX::strftime( "%Y%m%d%H%M%S", localtime );
    $count++;
    my $records_count = 0;
    my $filename = "MARCrecords_".$timestamp."_".$count;

    foreach my $record (@$records) {
        eval {
            #fetch and parse records
            my $marc_xml = marc2marcxml($record, 'UTF-8', C4::Context->preference("marcflavour"));
            my $parser = XML::LibXML->new(recover => 1);
            my $doc = $parser->load_xml(string => $marc_xml);
            my ( $row ) = $doc->findnodes("/*");
            #add records to new xml file
            $xml .= $row."\n";
            $records_count++;
        };
        warn $@ if $@;
    }

    #send file to output directory
    open(my $fh, '>', $path.$filename);
    print $fh $xml;
    close $fh;

    # Convert the output file using Usemarcon
    my ($output_path, $output_file) = $converter->convertRecords($path, $filename, $usemarcon_config);
    
    print "Added ".$records_count." records to file ".$filename.".\n" if $verbose;
    
}