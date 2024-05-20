#!/bin/bash

SCRIPT_DIR="$(dirname "$0")"
CONVERT_PATH=$1
date=$(date +%Y%m%d)

# Check if the input folder exists
if [ ! -d "$CONVERT_PATH" ]; then
    echo "Input folder does not exist"
    exit 1
fi

# Create a new directory with the current date
echo "Creating a new directory with the current date"
mkdir -p "$CONVERT_PATH/$date"

# Run print_marcs.pl
echo "Running print_marcs.pl"
mkdir -p "$CONVERT_PATH/$date/xml"
perl -I $SCRIPT_DIR/../../ $SCRIPT_DIR/print_marcs.pl -p $CONVERT_PATH/$date/xml/ --check_sv

# Run ISBD conversion for fi
mkdir -p "$CONVERT_PATH/$date/isbd"
bash $SCRIPT_DIR/usemarcon_converter.sh $SCRIPT_DIR/../../USEMARCON-ISBD/ma2maisbd0.ini $CONVERT_PATH/$date/xml/ $CONVERT_PATH/$date/isbd/ fi
# Run ISBD conversion for sv
bash $SCRIPT_DIR/usemarcon_converter.sh $SCRIPT_DIR/../../USEMARCON-ISBD/ma2maisbd0.ini $CONVERT_PATH/$date/xml/ $CONVERT_PATH/$date/isbd/ sv
# Run RDA conversion for fi
mkdir -p "$CONVERT_PATH/$date/rda"
bash $SCRIPT_DIR/usemarcon_converter.sh $SCRIPT_DIR/../../USEMARCON-RDA/ma21RDA_bibliografiset.ini $CONVERT_PATH/$date/isbd/ $CONVERT_PATH/$date/rda/ fi
# Run RDA conversion for sv
bash $SCRIPT_DIR/usemarcon_converter.sh $SCRIPT_DIR/../../USEMARCON-RDA/ma21RDA_bibliografiset_sv.ini $CONVERT_PATH/$date/isbd/ $CONVERT_PATH/$date/rda/ sv

echo "Conversion completed"
echo "Files are located in $CONVERT_PATH/$date/rda"
echo "Import the files to Koha with the import_records.pl script"