#!/usr/bin/perl
use strict;
use warnings;
use Converter::Modules::KohaImporter;
use File::Basename;
use Getopt::Long;
use POSIX qw(strftime);
use Time::Piece;
use Time::Seconds qw( ONE_DAY ONE_HOUR );

# Command line options
my $help = 0;
my $dir = '';
my $record_type = 'biblio';
my $encoding = 'UTF-8';
my $commit = 0;
my $revert = 0;
my $verbose = 0;
my $matcher_id = 0;
my $batch_size = 0;
my $skip_records_from_broadcast_biblios = 0;
my $next_day = localtime;
$next_day += ONE_DAY;
my $stop_time = $next_day->strftime("%Y-%m-%d")." 04:00:00";


# Get command line options
GetOptions(
    'h|help' => \$help,
    'dir=s' => \$dir,
    'record_type=s' => \$record_type,
    'encoding=s' => \$encoding,
    'commit' => \$commit,
    'revert' => \$revert,
    'v|verbose' => \$verbose,
    'matcher_id=i' => \$matcher_id,
    'batch_size=i' => \$batch_size,
    'skip_bb' => \$skip_records_from_broadcast_biblios,
);

# Print help
if ($help) {
    print "Usage: $0 [options]\n";
    print "Options:\n";
    print "  -h, --help\t\t\tPrint this help\n";
    print "  --dir\t\t\tDirectory to import\n";
    print "  --record_type\t\tRecord type (biblio or auth)\n";
    print "  --encoding\t\t\tEncoding of the files\n";
    print "  --commit\t\t\tCommit the records\n";
    print "  --revert\t\t\tRevert the records\n";
    print "  --verbose\t\t\tVerbose output\n";
    print "  --matcher_id\t\t\tMatcher ID\n";
    print "  --batch_size\t\t\tBatch size\n";
    print "  --skip_bb\t\t\tSkip records from broadcast biblios\n";
    exit 0;
}

# Check if the directory exists
if (!$dir) {
    print "Error: You must specify a directory to import\n";
    exit 1;
}

if (!-d $dir) {
    print "Error: Directory $dir does not exist\n";
    exit 1;
}

if ($skip_records_from_broadcast_biblios && !$matcher_id) {
    print "Error: You must specify a matcher ID when skipping records from broadcast biblios\n";
    exit 1;
}

# Create a new instance of KohaImporter
my $koha_importer = Converter::Modules::KohaImporter->new({
    record_type => $record_type,
    encoding => $encoding,
    commit => $commit,
    revert => $revert,
    verbose => $verbose,
    matcher_id => $matcher_id,
    skip_records_from_broadcast_biblios => $skip_records_from_broadcast_biblios,
});

# Open the directory
opendir(my $dh, $dir) or die "Cannot open directory: $!";

my $count = 0;

# Read files in timestamp order
my @files = sort {
    my ($a_time) = $a =~ /(\d{14})/;
    my ($b_time) = $b =~ /(\d{14})/;
    $a_time cmp $b_time;
} grep { /^\d{14}/ } readdir $dh;

# Process files in timestamp order
foreach my $filename (@files) {
    # Skip if not a file
    my $current_time = strftime "%Y-%m-%d %H:%M:%S", localtime;
    if ($current_time gt $stop_time) {
        last;
    }
    next if -d "$dir/$filename";

    # Check if the file exists in the processed directory
    if (-e "$dir/processed/$filename") {
        print "Skipping already processed file: $filename\n";
        next;
    }

    print "Processing file: $filename\n";
    # Full path to the file
    my $file_path = "$dir/$filename";
    # Import the file
    my $batch_id = $koha_importer->importRecords($file_path);
    # Move the file to the processed directory
    move_file($file_path);
    next unless $batch_id;
    $count++;
    last if $count == $batch_size && $batch_size > 0;
}

# Close the directory
closedir $dh;

print "Processed $count files\n";

sub move_file {
    my ($file) = @_;
    my $filename = basename($file);
    my $new_dir = "$dir/processed";
    mkdir $new_dir unless -d $new_dir;
    my $new_file = "$new_dir/$filename";
    rename $file, $new_file or die "Cannot move file: $!";
    print "Moved $file to $new_file\n";
}