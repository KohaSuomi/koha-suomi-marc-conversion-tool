#!/bin/bash

SCRIPT_DIR="/home/koha/koha-suomi-marc-conversion-tool/Converter/scripts"
# Default values
CONVERT_PATH=""
MATCHER_ID=""
BIBLIO_FILE=""
COMMIT=0
VERBOSE=0

# Function to display help
show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -p, --path PATH            Specify the convert path"
    echo "  -m, --matcher-id ID        Specify the matcher ID"
    echo "  -b, --biblio-file FILE     Specify the biblio file (optional)"
    echo "  -c, --commit               Commit the changes to the database"
    echo "  -v, --verbose              Enable verbose mode"
    echo "  -h, --help                 Display this help message"
}

# Parse options
while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
  -p | --path )
    shift; CONVERT_PATH=$1
    ;;
  -m | --matcher-id )
    shift; MATCHER_ID=$1
    ;;
  -b | --biblio-file )
    shift; BIBLIO_FILE=$1
    ;;
  -c | --commit )
    COMMIT=1
    ;;
  -v | --verbose )
    VERBOSE=1
    ;;
  -h | --help )
    show_help
    exit 0
    ;;
esac; shift; done
if [[ "$1" == '--' ]]; then shift; fi

# Check for required arguments
if [ -z "$CONVERT_PATH" ] || [ -z "$MATCHER_ID" ]; then
    show_help
    exit 1
fi

date=$(date +%Y%m%d)

# Verbose mode
if [ $VERBOSE -eq 1 ]; then
    echo "CONVERT_PATH: $CONVERT_PATH"
    echo "MATCHER_ID: $MATCHER_ID"
    echo "BIBLIO_FILE: $BIBLIO_FILE"
    echo "Date: $date"
fi

# Create a new directory with the current date
echo "Creating a new directory with the current date"
mkdir -p "$CONVERT_PATH/$date"

# Run print_marcs.pl
echo "Running print_marcs.pl"
mkdir -p "$CONVERT_PATH/$date/xml"
if [ -z "$BIBLIO_FILE" ]; then
    perl -I $SCRIPT_DIR/../../ $SCRIPT_DIR/print_marcs.pl -p $CONVERT_PATH/$date/xml/ --check_sv --start_file $CONVERT_PATH/start_biblionumber.txt
else
    perl -I $SCRIPT_DIR/../../ $SCRIPT_DIR/print_marcs.pl -p $CONVERT_PATH/$date/xml/ --check_sv --biblionumber_file $BIBLIO_FILE
fi

# Run ISBD conversion for fi
mkdir -p "$CONVERT_PATH/$date/isbd"
bash $SCRIPT_DIR/usemarcon_converter.sh $SCRIPT_DIR/../../USEMARCON-ISBD/ma2maisbd0-ks.ini $CONVERT_PATH/$date/xml/ $CONVERT_PATH/$date/isbd/ fi
# Run ISBD conversion for sv
bash $SCRIPT_DIR/usemarcon_converter.sh $SCRIPT_DIR/../../USEMARCON-ISBD/ma2maisbd0-ks.ini $CONVERT_PATH/$date/xml/ $CONVERT_PATH/$date/isbd/ sv
# Run RDA conversion for fi
mkdir -p "$CONVERT_PATH/$date/rda"
bash $SCRIPT_DIR/usemarcon_converter.sh $SCRIPT_DIR/../../USEMARCON-RDA/ma21RDA_bibliografiset_fi.ini $CONVERT_PATH/$date/isbd/ $CONVERT_PATH/$date/rda/ fi
# Run RDA conversion for sv
bash $SCRIPT_DIR/usemarcon_converter.sh $SCRIPT_DIR/../../USEMARCON-RDA/ma21RDA_bibliografiset_sv.ini $CONVERT_PATH/$date/isbd/ $CONVERT_PATH/$date/rda/ sv

if [ $COMMIT -eq 1 ]; then
    echo "Committing the changes to the database"
    perl -I $SCRIPT_DIR/../../ $SCRIPT_DIR/import_records.pl -d $CONVERT_PATH/$date/rda/  --matcher_id $MATCHER_ID --commit --skip_bb
else
    echo "Only add the records to the staging area"
    perl -I $SCRIPT_DIR/../../ $SCRIPT_DIR/import_records.pl -d $CONVERT_PATH/$date/rda/  --matcher_id $MATCHER_ID
fi

echo "Conversion completed"