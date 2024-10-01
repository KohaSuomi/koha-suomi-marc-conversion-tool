#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use MARC::Record;
use Koha::Biblios;
use C4::Context;
use C4::Biblio qw( ModBiblio GetFrameworkCode);


my $starttimestamp = '';
my $endtimestamp = '';
my $confirm = 0;
my $verbose = 0;
GetOptions(
    'starttimestamp=s' => \$starttimestamp,
    'endtimestamp=s' => \$endtimestamp,
    'confirm' => \$confirm, 
    'verbose' => \$verbose) 
    or die "Usage: $0 --starttimestamp=YYYY-MM-DD --endtimestamp=YYYY-MM-DD [--confirm] [--verbose]\n";

if (!$starttimestamp || !$endtimestamp) {
    die "Usage: $0 --starttimestamp=YYYY-MM-DD --endtimestamp=YYYY-MM-DD [--confirm] [--verbose]\n";
}

my $dbh = C4::Context->dbh;
my $query = "select object from action_logs where module = 'CATALOGUING' and action = 'MODIFY' and info like 'biblio%' and timestamp >= ? and timestamp <= ? group by object having count(object) > 1; ";
print "$query\n";
my $sth = $dbh->prepare($query);
my $res = $sth->execute($starttimestamp, $endtimestamp);
my $count = 0;

while (my $row = $sth->fetchrow_hashref) {
    my $biblionumber = $row->{object};
    my $query = "select marcxml from import_records ir join import_biblios ib on ir.import_record_id = ib.import_record_id where upload_timestamp >= ? and upload_timestamp <= ? and matched_biblionumber = ?;";
    my $sth2 = $dbh->prepare($query);
    my $res2 = $sth2->execute($starttimestamp, $endtimestamp, $biblionumber);
    my $row2 = $sth2->fetchrow_hashref;
    if (!$row2) {
        print "No import_records found for biblionumber $biblionumber\n";
        next;
    }
    print "Biblionumber $biblionumber has multiple MODIFY actions\n";
    if ($confirm) {
        my $biblio = Koha::Biblios->find($biblionumber);
        my $record = $biblio->metadata->record();
        my $success = &ModBiblio($record, $biblionumber, GetFrameworkCode($biblionumber));
        if ($success) {
            print "Updated biblionumber $biblionumber\n";
        } else {
            print "Failed to update biblionumber $biblionumber\n";
        }
    }
    $count++;
}

print "Total: $count\n";