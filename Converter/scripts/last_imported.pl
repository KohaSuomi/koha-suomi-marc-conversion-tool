#!/usr/bin/perl

use strict;
use warnings;
use C4::Context;
use Koha::Import::Records;

my $dbh = C4::Context->dbh;
# Query to find the last imported batch
my $sql = "SELECT import_batch_id, upload_timestamp 
           FROM import_batches 
           WHERE import_status = 'imported' 
           AND file_name LIKE '\%MARCrecordsChunk\%' 
           AND upload_timestamp >= DATE_SUB(CURDATE(), INTERVAL 1 DAY) 
           ORDER BY upload_timestamp DESC 
           LIMIT 1";

# Prepare and execute the query
my $sth = $dbh->prepare($sql);
$sth->execute();

# Fetch the result
my ($import_batch_id, $upload_timestamp) = $sth->fetchrow_array();
my $import_records = Koha::Import::Records->search({
        import_batch_id => $import_batch_id,
    });

# Loop through the records
my $next_biblionumber = 0;
while ( my $record = $import_records->next ) {
    # Do something with the record
    my $matched_biblionumber = $record->import_biblio->matched_biblionumber;
    if ($matched_biblionumber) {
        $next_biblionumber = $matched_biblionumber;
    }
}
# Clean up
$sth->finish();
$next_biblionumber++;
print $next_biblionumber;