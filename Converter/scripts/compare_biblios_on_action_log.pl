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
my $sth = $dbh->prepare("SELECT marcxml, upload_timestamp FROM import_records WHERE DATE(upload_timestamp) >= ?");
my $res = $sth->execute($date);
my $count = 0;

while (my $row = $sth->fetchrow_hashref) {
    my $marcxml = MARC::Record::new_from_xml($row->{marcxml}, 'UTF-8');
    my $biblionumber = $marcxml->field('999')->subfield('c');
    my $log = Koha::ActionLogs->search(
        {
            module => 'CATALOGUING',
            action => 'MODIFY',
            object => $biblionumber,
            timestamp => { -between => [ $date.' 06:00:00', $row->{upload_timestamp} ] },
        },
    )->unblessed;
    
    if (scalar(@$log) > 1) {
        foreach my $log_entry (@$log) {
            print "Biblionumber: $biblionumber, Timestamp: $log_entry->{timestamp}\n";
            $count++;
        }
    }
}

print "Total: $count\n";