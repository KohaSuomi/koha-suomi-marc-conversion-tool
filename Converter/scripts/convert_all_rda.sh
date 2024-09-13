#!/bin/bash

SCRIPT_DIR="/home/jraisa/koha-suomi-marc-conversion-tool/Converter/scripts"
CONVERT_PATH=$1
MATCHER_ID=$2
BIBLIO_FILE=$3
date=$(date +%Y%m%d)

if [ ! -d "$CONVERT_PATH" ]; then
    echo "Input folder does not exist"
    exit 1
fi

if [ -z "$MATCHER_ID" ]; then
    echo "Matcher ID is required"
    exit 1
fi

# Create a new directory with the current date
echo "Creating a new directory with the current date"
mkdir -p "$CONVERT_PATH/$date"

# Run print_marcs.pl
echo "Running print_marcs.pl"
mkdir -p "$CONVERT_PATH/$date/xml"
if [ -z "$BIBLIO_FILE" ]; then
    perl -I $SCRIPT_DIR/../../ $SCRIPT_DIR/print_marcs.pl -p $CONVERT_PATH/$date/xml/ --check_sv --start_file $CONVERT_PATH/start_biblionumber.txt -s 10
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

#echo "Files are located in $CONVERT_PATH/$date/rda"
echo "Importing the files to Koha with the import_records.pl script"

perl -I $SCRIPT_DIR/../../ $SCRIPT_DIR/import_records.pl -d $CONVERT_PATH/$date/rda/  --matcher_id $MATCHER_ID --commit --skip_bb
echo "Import done"