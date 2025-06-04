#!/bin/bash

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

# Check if CONVERT_PATH is set
if [ -z "$CONVERT_PATH" ]; then
    echo "Error: CONVERT_PATH is required."
    show_help
    exit 1
fi

# Check if /usr/local/bin/ksbackup --indices is running
if pgrep -f "/usr/local/bin/ksbackup --indices" > /dev/null; then
    echo "/usr/local/bin/ksbackup --indices is running. Exiting."
    exit 1
fi
# Check if /usr/local/bin/dumpdb is running
if pgrep -f "/usr/local/bin/dumpdb" > /dev/null; then
    echo "/usr/local/bin/dumpdb is running. Exiting."
    exit 1
fi
# Check if rebuild_elasticsearch.pl is running
if pgrep -f "rebuild_elasticsearch.pl" > /dev/null; then
    echo "rebuild_elasticsearch.pl is running. Exiting."
    exit 1
fi

USER_HOME_DIR=$(eval echo ~$USER)
SCRIPT_DIR="$USER_HOME_DIR/koha-suomi-marc-conversion-tool/Converter/scripts"
date=$(date +%Y%m%d)


# Create a new directory with the current date
echo "Creating a new directory with the current date"
mkdir -p "$CONVERT_PATH/$date"

# Run print_marcs.pl
echo "Running print_marcs.pl"
mkdir -p "$CONVERT_PATH/$date/xml"
if [ -z "$BIBLIO_FILE" ]; then
    perl -I $SCRIPT_DIR/../../ $SCRIPT_DIR/print_marcs.pl -p $CONVERT_PATH/$date/xml/ --check_sv --start_file $CONVERT_PATH/start_biblionumber.txt -s 500
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

echo "Files are located in $CONVERT_PATH/$date/rda/"

if [ -z "$MATCHER_ID" ]; then
    echo "Error: MATCHER_ID is required."
    show_help
    exit 1
fi

echo "Importing the files to Koha"
if [ "$COMMIT" = true ]; then
    perl -I $SCRIPT_DIR/../../ $SCRIPT_DIR/import_records.pl -d $CONVERT_PATH/$date/rda/ --matcher_id $MATCHER_ID --commit --skip_bb
else
    perl -I $SCRIPT_DIR/../../ $SCRIPT_DIR/import_records.pl -d $CONVERT_PATH/$date/rda/ --matcher_id $MATCHER_ID
fi
