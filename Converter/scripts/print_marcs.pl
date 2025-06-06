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
use Try::Tiny;

use C4::Record qw( marc2marcxml );

use Converter::Modules::Chunker;

use open ':std', ':encoding(UTF-8)';

sub usage {
    print STDERR <<USAGE;
  Will print all active MARC records in database to
  OUTPUT_DIRECTORY .

  -p  --path           Where to print files.
  -l  --limit          How many records are printed (for testing purposes).
  -s  --size           Size of record chunk.
  -b  --biblionumber   Start from specific biblionumber.
  -v  --verbose        Make this script more talkative.
  -h  --help           This help message.
  --biblionumber_file  File containing biblionumbers to print.
  --check_sv           Check if record is in swedish and print to separate file.
  --no_rda             Do not print RDA records.
  --start_file         Start biblionumber from file.

USAGE
    exit $_[0];
}

my ( $help, $config, $path, $limit, $pagesize, $biblionumber, $verbose, @biblionumbers, $biblionumber_file, $check_sv, $no_rda, $start_file );

GetOptions(
    'h|help'             => \$help,
    'p|path:s'           => \$path,
    'l|limit:i'          => \$limit,
    's|size:i'           => \$pagesize,
    'b|biblionumber:i'   => \$biblionumber,
    'v|verbose'          => \$verbose,
    'biblionumber_file:s'=> \$biblionumber_file,
    'check_sv'           => \$check_sv,
    'no_rda'             => \$no_rda,
    'start_file:s'       => \$start_file,

) || usage(1);

usage(0) if ($help);

if ( !$path || !-d $path || !-w $path ) {
    print STDERR
"Error: You must specify a valid and writeable directory to dump the print notices in.\n";
    usage(1);
}

if ( $biblionumber_file && -e $biblionumber_file ) {
    open( my $fh, '<', $biblionumber_file );
    while ( my $line = <$fh> ) {
        chomp $line;
        push @biblionumbers, $line;
    }
    close $fh;
}

if ($start_file) {
    open( my $fh, '<', $start_file );
    while ( my $line = <$fh> ) {
        chomp $line;
        $biblionumber = $line;
    }
    close $fh;
}

my $count = 0;
my $chunker = Converter::Modules::Chunker->new(undef, $limit, $pagesize, $biblionumber, $verbose, @biblionumbers);
my $last_biblionumber = 0;
my $batch_size = 1;
my $batch_count = 0;

while (my $records = $chunker->getChunkAsMARCRecord(undef, undef)) {
    last if $batch_count >= $batch_size;
    my $xml = MARC::File::XML::header('UTF-8');
    my $sv_xml = MARC::File::XML::header('UTF-8');
    my $timestamp = POSIX::strftime( "%Y%m%d%H%M%S", localtime );
    $count++;
    my $records_count = 0;
    my $sv_records_count = 0;
    my $filecount = sprintf( "%05d", $count );
    my $filename = $timestamp."_MARCrecordsChunk_fi.xml";
    my $svFileName = $timestamp."_MARCrecordsChunk_sv.xml";
    foreach my $record (@$records) {
        try {
            #fetch and parse records
            $record->{metadata} = deleteNullFields($record->{metadata});
            my $marc_xml = marc2marcxml($record->{metadata}, 'UTF-8', C4::Context->preference("marcflavour"));
            my $parser = XML::LibXML->new(recover => 1);
            my $doc = $parser->load_xml(string => $marc_xml);
            my ( $row ) = $doc->findnodes("/*");
            #add records to new xml file
            return if $no_rda && checkRDARecord($record->{metadata});
            if ($check_sv && svRecord($record->{metadata})) {
                $sv_xml .= $row."\n";
                $sv_records_count++;
            } else {
                $xml .= $row."\n";
                $records_count++;
            }
            $last_biblionumber = $record->{biblionumber}++;
        }
        catch {
            warn $@ if $@;
        };
    }
    $xml .= MARC::File::XML::footer('UTF-8');
    $sv_xml .= MARC::File::XML::footer('UTF-8');
    if($records_count > 0) {
        #send file to output directory
        open(my $fh, '>', $path.$filename);
        print $fh $xml;
        close $fh;
        print "Added ".$records_count." records to file ".$filename.".\n" if $verbose;
    }

    #send file to output directory
    if($sv_records_count > 0) {
        open(my $fh, '>', $path.$svFileName);
        print $fh $sv_xml;
        close $fh;
        print "Added ".$sv_records_count." swedish records to file ".$svFileName.".\n" if $verbose;
    }
    $batch_count++;
}

if ($start_file && $last_biblionumber) {
    print "Writing last biblionumber $last_biblionumber to file $start_file\n" if $verbose;
    open(my $fh, '>', $start_file);
    print $fh $last_biblionumber;
    close $fh;
}

sub primary_language {
    my ($record) = @_;
    my $f008 = $record->field('008');
    my $primaryLanguage = 'OTH';

    if( $f008 && substr($f008->data(), 35, 3) && ( substr($f008->data(), 35, 3) =~ /(.*[a-zA-Z]){3}/ )) {
        $primaryLanguage = substr($f008->data(), 35, 3);
    } elsif ( $record->subfield('041', 'a') && ( $record->subfield('041', 'a') =~ /(.*[a-zA-Z]){3}/ ) ) {
        $primaryLanguage = $record->subfield('041', 'a');
    }

    return $primaryLanguage;
}

sub cataloging_language {
    my ($record) = @_;
    my $f008 = $record->field('008');
    my $catalogingLanguage = 'OTH';

    if( $record->subfield('040', 'b') && ( $record->subfield('040', 'b') =~ /(.*[a-zA-Z]){3}/ ) ) {
        $catalogingLanguage = $record->subfield('040', 'b');
    }

    return $catalogingLanguage;
}

sub leader_06 {
    my ($record) = @_;
    my $leader_06 = '';

    if (substr($record->leader(), 6, 1) && ( substr($record->leader(), 6, 1) =~ /[a-zA-Z]/ )) {
        $leader_06 = substr($record->leader(), 6, 1);
    }

    return $leader_06;
}

sub svRecord {
    my ($record) = @_;
    my $svRecord = 0;

    if (primary_language($record) eq 'swe' && leader_06($record) eq 'a') {
        $svRecord = 1;
    } elsif (cataloging_language($record) eq 'swe') {
        $svRecord = 1;
    }

    return $svRecord;
}

sub deleteNullFields {
    my ($record) = @_;
    my @fields = $record->fields();
    foreach my $field (@fields) {
        my @subfields = $field->subfields();
        foreach my $subfield (@subfields) {
            if ($subfield->[1] eq '') {
                $field->delete_subfield(code => $subfield->[0]);
            }
        }
        if (!$field->is_control_field() && !$field->subfields()) {
            $record->delete_field($field);
        }
    }
    return $record;
}

sub checkRDARecord {
    my ($record) = @_;
    my $f040 = $record->field('040');
    my $f338 = $record->field('338');
    my $rda = 0;

    if ($f040) {
        my @subfields = $f040->subfields();
        foreach my $subfield (@subfields) {
            if ($subfield->[0] eq 'e' && $subfield->[1] eq 'rda') {
                $rda = 1;
            }
        }
    }

    if ($f338) {
        my @subfields = $f338->subfields();
        foreach my $subfield (@subfields) {
            if ($subfield->[0] eq 'a') {
                $rda = 1;
            }
        }
    }
    #print "RDA record found, ". $record->subfield('999', 'c') ."\n" if $rda && $verbose;
    return $rda;
}