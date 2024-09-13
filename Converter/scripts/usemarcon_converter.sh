#!/bin/bash

SCRIPT_DIR="$(dirname "$0")"

# Path to the usemarcon program
USEMARCON_PATH="$SCRIPT_DIR/../../usemarcon/program/usemarcon"
USEMARCON_CONFIG=$1

# Check if the usemarcon program exists
if [ ! -f "$USEMARCON_PATH" ]; then
    echo "usemarcon program does not exist"
    exit 1
fi

# Check if the usemarcon config file exists
if [ ! -f "$USEMARCON_CONFIG" ]; then
    echo "usemarcon config file does not exist"
    exit 1
fi

# Input folder
INPUT_FOLDER=$2

# Check if the input folder exists
if [ ! -d "$INPUT_FOLDER" ]; then
    echo "Input folder does not exist"
    exit 1
fi

# Output folder
OUTPUT_FOLDER=$3

# Create the output folder if it doesn't exist
mkdir -p "$OUTPUT_FOLDER"

LANGUAGE=$4

# Check if the language is set
if [ -z "$LANGUAGE" ]; then
    echo "Language is not set, fi or sv"
    exit 1
fi

# Loop through each file in the input folder
for file in "$INPUT_FOLDER"/*_"$LANGUAGE".xml
do
    if [ ! -f "$file" ]; then
        echo "No files to process"
        exit 1
    fi
    # Get the filename without the path
    filename=$(basename "$file")

    # Set the input and output file paths
    INPUT_FILE="$file"
    OUTPUT_FILE="$OUTPUT_FOLDER/$filename"

    # Run usemarcon
    $USEMARCON_PATH $USEMARCON_CONFIG $INPUT_FILE $OUTPUT_FILE

    # rename the processed file
    mv $INPUT_FILE $INPUT_FILE.processed

    echo "Conversion completed for $filename"
done