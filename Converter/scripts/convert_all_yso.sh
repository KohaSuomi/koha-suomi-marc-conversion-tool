#!/bin/bash

show_help() {
    echo "Usage: $(basename "$0") [-h] [-d DIRECTORY] [-b BIBLIO_FILE] [-m MATCHER_ID] [-c]"
    echo
    echo "Options:"
    echo "  -h                Show this help message and exit"
    echo "  -d DIRECTORY      Directory to convert"
    echo "  -b BIBLIO_FILE    Optional biblionumber file"
    echo "  -m MATCHER_ID     Matcher id for the import"
    echo "  -c                Commit the changes to the database"
}

# Default values
CONVERT_PATH=""
BIBLIO_FILE=""
MATCHER_ID=""
COMMIT=false

# Parse command line options
while getopts "hd:b:m:c" opt; do
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
        m )
            MATCHER_ID=$OPTARG
            ;;
        c )
            COMMIT=true
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
    perl -I $SCRIPT_DIR/../../ $SCRIPT_DIR/print_marcs.pl -p $CONVERT_PATH/$date/xml/ --start_file $CONVERT_PATH/start_biblionumber.txt -s 500
else
    perl -I $SCRIPT_DIR/../../ $SCRIPT_DIR/print_marcs.pl -p $CONVERT_PATH/$date/xml/ --biblionumber_file $BIBLIO_FILE
fi

#rm -r "$CONVERT_PATH/$date/yso"
cd $YSO_DIR
for file in $CONVERT_PATH/$date/xml/*.xml
do
    if [ ! -f "$file" ]; then
        echo "No files to process"
        exit 1
    fi
    # Get the filename without the path
    filename=$(basename "$file")

    # Set the input and output file paths
    INPUT_FILE="$file"
    python3 $YSO_DIR/yso_converter.py -i $CONVERT_PATH/$date/xml/$filename -o $CONVERT_PATH/$date/yso/$filename -f marcxml --field_links

    # Rename the processed file
    mv "$INPUT_FILE" "${INPUT_FILE%.xml}.processed"

    echo "Conversion completed for $filename"
done

echo "Files are located in $CONVERT_PATH/$date/yso"

echo "Importing the files to Koha"
if [ "$COMMIT" = true ]; then
    perl -I $SCRIPT_DIR/../../ $SCRIPT_DIR/import_records.pl -d $CONVERT_PATH/$date/yso/ --matcher_id $MATCHER_ID --commit --skip_bb
else
    perl -I $SCRIPT_DIR/../../ $SCRIPT_DIR/import_records.pl -d $CONVERT_PATH/$date/yso/ --matcher_id $MATCHER_ID
fi

cd $USER_HOME_DIR
exit 0