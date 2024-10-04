#!/usr/bin/perl

use strict;
use warnings;
use C4::Context;
use Koha::Import::Records;

my $dbh = C4::Context->dbh;
# Query to find the last imported batch
my $sql = "SELECT MAX(matched_biblionumber) AS matched_biblionumber
           FROM import_batches 
           JOIN import_records ON import_batches.import_batch_id = import_records.import_batch_id
           JOIN import_biblios ON import_records.import_record_id = import_biblios.import_record_id
           WHERE import_status = 'imported' 
           AND file_name LIKE '\%MARCrecordsChunk\%' 
           AND import_batches.upload_timestamp >= DATE_SUB(CURDATE(), INTERVAL 1 DAY) 
           ORDER BY import_biblios.matched_biblionumber DESC";

# Prepare and execute the query
my $sth = $dbh->prepare($sql);
$sth->execute();

# Fetch the result
my ($matched_biblionumber) = $sth->fetchrow_array();
$sth->finish();
$matched_biblionumber = 0 unless $matched_biblionumber;
$matched_biblionumber++;
print $matched_biblionumber;