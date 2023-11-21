#!/usr/bin/perl
use strict;
use warnings;
use Converter::Modules::KohaImporter;
use File::Basename;
use Getopt::Long;

# Command line options
my $help = 0;
my $dir = '';
my $record_type = 'biblio';
my $encoding = 'UTF-8';
my $commit = 0;
my $revert = 0;
my $verbose = 0;
my $matcher_id = 0;

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
    print "  --verbose\t\t\tVerbose output\n";
    print "  --matcher_id\t\t\tMatcher ID\n";
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

# Create a new instance of KohaImporter
my $koha_importer = Converter::Modules::KohaImporter->new({
    record_type => $record_type,
    encoding => $encoding,
    commit => $commit,
    revert => $revert,
    verbose => $verbose,
    matcher_id => $matcher_id,
});

# Open the directory
opendir(my $dh, $dir) or die "Cannot open directory: $!";

# Read files
while (my $filename = readdir $dh) {
    # Skip if not a file
    next if -d "$dir/$filename";

    print "Processing file: $filename\n";

    # Full path to the file
    my $file_path = "$dir/$filename";

    # Import the file
    $koha_importer->importRecords($file_path);
}

# Close the directory
closedir $dh;