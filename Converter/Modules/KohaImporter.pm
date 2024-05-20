package Converter::Modules::KohaImporter;

use strict;
use warnings;
use C4::Context;
use C4::ImportBatch qw(
    RecordsFromMARCXMLFile
    RecordsFromISO2709File
    RecordsFromMarcPlugin
    BatchStageMarcRecords
    BatchCommitRecords
    BatchRevertRecords
    BatchFindDuplicates
    SetImportBatchMatcher
    SetImportBatchOverlayAction
    SetImportBatchNoMatchAction
    SetImportBatchItemAction
);
use C4::Matcher;

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

sub record_type {
    my ($self) = @_;
    return $self->{_params}->{record_type} || 'biblio';
}

sub encoding {
    my ($self) = @_;
    return $self->{_params}->{encoding} || 'UTF-8';
}

sub matcher_id {
    my ($self) = @_;
    return $self->{_params}->{matcher_id};
}

sub overlay_action {
    my ($self) = @_;
    return $self->{_params}->{overlay_action} || 'replace';
}

sub nomatch_action {
    my ($self) = @_;
    return $self->{_params}->{nomatch_action} || 'ignore';
}

sub item_action {
    my ($self) = @_;
    return $self->{_params}->{item_action} || 'ignore';
}

sub commit {
    my ($self) = @_;
    return $self->{_params}->{commit};
}

sub revert {
    my ($self) = @_;
    return $self->{_params}->{revert};
}

sub dbh {
    my ($self) = @_;
    return C4::Context->dbh;
}

sub importRecords {
    my ($self, $input_file) = @_;

    my $marc_modification_template = '';
    my $comments                   = '';
    my $parse_items                = 0;
    my $num_valid                  = 0;
    my $num_items                  = 0;
    my $errors                     = 0;

    my ( $batch_id, @import_errors, $marcrecords );
    $batch_id = $self->findImportedBatchByFileName($input_file);
    unless ($batch_id) {
        print "Staging records...\n";
        ( $errors, $marcrecords ) =
                C4::ImportBatch::RecordsFromMARCXMLFile( $input_file, $self->encoding );
        
        # Stage records for import
        ( $batch_id, $num_valid, $num_items, @import_errors ) = BatchStageMarcRecords(
                $self->record_type,          $self->encoding,
                $marcrecords,                $input_file,
                $marc_modification_template, $comments,
                '',                          $parse_items,
                0,                           100,
                \&print_progress
            );
        
        my $num_with_matches = $self->matchRecords($batch_id, $self->matcher_id);

        print "Records with matches: $num_with_matches\n" if $self->verbose;
    } 

    if ($self->commit) {
        # Import staged records into catalog
        print "Committing records...\n";
        my $committed = $self->commitRecords($batch_id);
        return 0 unless $committed;
    }

    if ($self->revert) {
        # Revert staged records from catalog
        print "Reverting records...\n";
        my $reverted = $self->revertRecords($batch_id);
        return 0 unless $reverted;
    }

    if ($self->verbose) {
        print "Batch ID: $batch_id\n";
        print "Number of valid records: $num_valid\n";
        print "Number of items: $num_items\n";
        print "Number of errors: ".Data::Dumper::Dumper($errors)."\n";
        print "Errors: ".Data::Dumper::Dumper(@import_errors)."\n\n";
    }

    return $batch_id;
}

sub matchRecords {
    my ($self, $batch_id) = @_;

    my $matcher = C4::Matcher->fetch($self->matcher_id);
    my $num_with_matches = 0;
    my $checked_matches  = 0;
    my $matcher_failed   = 0;
    my $matcher_code     = "";
    if (defined $matcher) {
        $matcher_code    = $matcher->code();
        $num_with_matches =
            BatchFindDuplicates($batch_id, $matcher, 10, 50, \&print_progress);
        SetImportBatchMatcher($batch_id, $self->matcher_id);
        SetImportBatchOverlayAction($batch_id, $self->overlay_action);
        SetImportBatchNoMatchAction($batch_id, $self->nomatch_action);
        SetImportBatchItemAction($batch_id, $self->item_action);
    }

    return $num_with_matches;
}

sub commitRecords {
    my ($self, $batch_id) = @_;

    # Import staged records into catalog
    my ($num_added, $num_updated, $num_items_added, $num_items_updated, $num_ignored)
        = BatchCommitRecords({
            batch_id => $batch_id,
            framework => '',
            progress_interval => 100,
            progress_callback => \&print_progress
        });

    # Print verbose information
    print "Records imported: $num_added\n" if $self->verbose;
    print "Records updated: $num_updated\n" if $self->verbose;
    print "Items added: $num_items_added\n" if $self->verbose;
    print "Items updated: $num_items_updated\n" if $self->verbose;
    print "Records ignored: $num_ignored\n" if $self->verbose;
    unless ($num_added || $num_updated) {
        print "No records imported or updated\n";
        return 0;
    } else {
        return 1;
    }
}

sub revertRecords {
    my ($self, $batch_id) = @_;

    # Revert staged records from catalog
    my ($num_deleted, $num_errors, $num_reverted, $num_items_deleted, $num_ignored) = BatchRevertRecords($batch_id);

    # Print verbose information
    if ($self->verbose) {
        print "Records reverted: $num_reverted\n";
        print "Number of deleted records: $num_deleted\n";
        print "Number of errors: $num_errors\n";
        print "Number of items deleted: $num_items_deleted\n";
        print "Number of ignored records: $num_ignored\n";
    }
    unless ($num_reverted) {
        print "No records reverted\n";
        return 0;
    } else {
        return 1;
    }
}


sub findImportedBatchByFileName {
    my ($self, $file_name) = @_;

    my $sth = $self->dbh->prepare("SELECT import_batch_id FROM import_batches WHERE file_name = ?");
    $sth->execute($file_name);
    my ($batch_id) = $sth->fetchrow_array();
    $sth->finish();

    return $batch_id;
}

sub print_progress {
    my $recs = shift;
    print "... processed $recs records\n";
}

1;