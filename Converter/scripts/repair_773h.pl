#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use MARC::Record;
use Koha::Biblios;
use C4::Context;
use C4::Biblio qw( ModBiblio GetFrameworkCode);


my $date = '';
my $confirm = 0;
my $verbose = 0;
GetOptions(
    'date=s' => \$date, 
    'confirm' => \$confirm, 
    'verbose' => \$verbose) 
    or die "Usage: $0 --date=YYYY-MM-DD [--confirm] [--verbose]\n";

if (!$date) {
    die "Usage: $0 --date=YYYY-MM-DD [--confirm] [--verbose]\n";
}


my $dbh = C4::Context->dbh;
my $sth = $dbh->prepare("SELECT marcxml, marcxml_old FROM import_records WHERE DATE(upload_timestamp) = ?") or die $dbh->errstr;
$sth->execute($date) or die $dbh->errstr;
my $count = 0;
while (my $row = $sth->fetchrow_hashref) {
    next if !$row->{marcxml} || !$row->{marcxml_old};
    my $marcxml = MARC::Record::new_from_xml($row->{marcxml}, 'UTF-8');
    my $marcxml_old = MARC::Record::new_from_xml($row->{marcxml_old}, 'UTF-8');
    if ($marcxml->field('773')) {
        my $field_773 = $marcxml->field('773');
        my $field_773_old = $marcxml_old->field('773');
        if (!$field_773->subfield('h') && $field_773_old->subfield('h')) {
            my $biblionumber = $marcxml->field('999')->subfield('c');
            my $biblio = Koha::Biblios->find($biblionumber);
            my $record = $biblio->metadata->record();
            if ($record->field('773')->subfield('h')) {
                print "Biblionumber $biblionumber already has 773h: " . $record->field('773')->subfield('h') . "\n";
                next;
            }
            if ($record->field('773')->subfield('w') eq $field_773_old->subfield('w')) {
                $record->field('773')->replace_with($field_773_old);
                print "Appended: " . $record->as_formatted() . "\n" if $verbose;
                if ($confirm) {
                    my $frameworkcode = GetFrameworkCode($biblionumber);
                    my $success = &ModBiblio($record, $biblionumber, $frameworkcode);
                    if ($success) {
                        print "Updated biblionumber $biblionumber\n";
                    } else {
                        print "Failed to update biblionumber $biblionumber\n";
                    }
                }
                $count++;
            } else {
                print "$biblionumber 773w mismatch: " . $field_773_old->subfield('w') . " != " . $record->field('773')->subfield('w') . "\n";
            }
        }
    }
}

$sth->finish;

print "Total records: $count\n";