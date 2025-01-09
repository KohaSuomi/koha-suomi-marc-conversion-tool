#!/bin/bash

show_help() {
    echo "Usage: $(basename "$0") [-h] [-d DIRECTORY] [-b BIBLIO_FILE]"
    echo
    echo "Options:"
    echo "  -h                Show this help message and exit"
    echo "  -d DIRECTORY      Directory to convert"
    echo "  -b BIBLIO_FILE    Optional biblionumber file"
}

# Default values
CONVERT_PATH=""
BIBLIO_FILE=""

# Parse command line options
while getopts "hd:b:" opt; do
    case ${opt} in
        h )
            show_help
            exit 0
            ;;
        d )
            CONVERT_PATH=$OPTARG
            ;;
        b )
            BIBLIO_FILE=$OPTARG
            ;;
        \? )
            echo "Invalid option: -$OPTARG" >&2
            show_help
            exit 1
            ;;
        : )
            echo "Option -$OPTARG requires an argument." >&2
            show_help
            exit 1
            ;;
    esac
done

# Check if the required DIRECTORY argument is provided
if [ -z "$CONVERT_PATH" ]; then
    echo "Error: Directory to convert is required."
    show_help
    exit 1
fi
USER_HOME_DIR=$(eval echo ~$USER)
SCRIPT_DIR="$USER_HOME_DIR/koha-suomi-marc-conversion-tool/Converter/scripts"
YSO_DIR="$USER_HOME_DIR/koha-suomi-marc-conversion-tool/yso-marcbib"
date=$(date +%Y%m%d)

# Create a new directory with the current date
echo "Creating a new directory with the current date"
mkdir -p "$CONVERT_PATH/$date"

# Run print_marcs.pl
echo "Running print_marcs.pl"
mkdir -p "$CONVERT_PATH/$date/xml"
if [ -z "$BIBLIO_FILE" ]; then
    perl -I $SCRIPT_DIR/../../ $SCRIPT_DIR/print_marcs.pl -p $CONVERT_PATH/$date/xml/
else
    perl -I $SCRIPT_DIR/../../ $SCRIPT_DIR/print_marcs.pl -p $CONVERT_PATH/$date/xml/ --biblionumber_file $BIBLIO_FILE
fi

# Run YSO conversion
rm -r "$CONVERT_PATH/$date/yso"
cd $YSO_DIR
python3 $YSO_DIR/yso_converter.py -id $CONVERT_PATH/$date/xml/ -od $CONVERT_PATH/$date/yso/ -f marcxml --all_languages --field_links <<EOF
1
EOF


echo "Files are located in $CONVERT_PATH/$date/yso"
echo "Import the files to Koha with the import_records.pl script"

cd $USER_HOME_DIR
exit 0