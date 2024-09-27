#!/bin/bash

# Function to display help
show_help() {
    echo "Usage: $(basename \"$0\") [-h] [-p CONVERT_PATH] [-b BIBLIO_FILE] [-i] [-m MATCHER_ID]"
    echo
    echo "Options:"
    echo "  -h                Display this help message."
    echo "  -p CONVERT_PATH   Path to the folder containing files to convert."
    echo "  -b BIBLIO_FILE    Optional biblionumber file."
    echo "  -i                Import the converted files to Koha."
    echo "  -m                Matcher id for the import."
}

# Default values
CONVERT_PATH=""
BIBLIO_FILE=""
IMPORT=false
MATCHER_ID=""

# Parse command line options
while getopts ":hp:b:im:" opt; do
    case ${opt} in
        h )
            show_help
            exit 0
            ;;
        p )
            CONVERT_PATH=$OPTARG
            ;;
        b )
            BIBLIO_FILE=$OPTARG
            ;;
        i )
            IMPORT=true
            ;;
        m )
            MATCHER_ID=$OPTARG
            ;;
        \? )
            echo "Invalid option: -$OPTARG" 1>&2
            show_help
            exit 1
            ;;
        : )
            echo "Invalid option: -$OPTARG requires an argument" 1>&2
            show_help
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

# Check if CONVERT_PATH is set
if [ -z "$CONVERT_PATH" ]; then
    echo "Error: CONVERT_PATH is required."
    show_help
    exit 1
fi

# Check if IMPORT and MATCHER_ID are set
if [ "$IMPORT" = true ] && [ -z "$MATCHER_ID" ]; then
    echo "Error: MATCHER_ID is required when importing the files."
    show_help
    exit 1
fi

HOME_DIR="/home/koha/koha-suomi-marc-conversion-tool"
SCRIPT_DIR="$HOME_DIR/Converter/scripts"
date=$(date +%Y%m%d)


# Create a new directory with the current date
echo "Creating a new directory with the current date"
mkdir -p "$CONVERT_PATH/$date"

# Run print_marcs.pl
echo "Running print_marcs.pl"
mkdir -p "$CONVERT_PATH/$date/xml"
if [ -z "$BIBLIO_FILE" ]; then
    perl -I $HOME_DIR $SCRIPT_DIR/print_marcs.pl -p $CONVERT_PATH/$date/xml/ --check_sv
else
    perl -I $HOME_DIR $SCRIPT_DIR/print_marcs.pl -p $CONVERT_PATH/$date/xml/ --check_sv --biblionumber_file $BIBLIO_FILE
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


# Import the files to Koha
if [ "$IMPORT" = true ]; then
    echo "Importing the files to Koha"
    perl -I $SCRIPT_DIR/../../ $SCRIPT_DIR/import_records.pl -d $CONVERT_PATH/$date/rda/ --matcher_id $MATCHER_ID --commit --skip_bb
else
    echo "To stage the files to Koha, run the following command:"
    echo "perl -I $HOME_DIR $SCRIPT_DIR/import_records.pl -d $CONVERT_PATH/$date/rda/ --matcher_id $MATCHER_ID <matcher_id>"
fi