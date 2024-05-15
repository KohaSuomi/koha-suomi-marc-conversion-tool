#!/bin/bash

project_dir=$HOME/github/USEMARCON-RDA
usemarcon_command=usemarcon
usemarcon_ini_file=$project_dir/sv_ma21RDA_bibliografiset.ini
usemarcon_input_file=/tmp/input4usemarcon$$.mrc # input file will be copy-converted to this file
usemarcon_output_file=/tmp/usemarcon_output$$.mrc # input file will be copy-converted to this file
echo Testataan...

rm -fv *.output

for i in swe*.seq; do
    echo Process test for $i

    $project_dir/tests/any2marc.perl $i > $usemarcon_input_file 2>/dev/null
    
    $usemarcon_command $usemarcon_ini_file $usemarcon_input_file $usemarcon_output_file > /dev/null 2>/dev/null
    if [ ! -e $use_marcon_output_file ]; then
        echo ERROR
        exit;
    fi

    $project_dir/tests/any2seq.perl $usemarcon_output_file | perl -pe 's/(LDR   L) .....(.........)..../$1 XXXXX${2}XXXX/;' > $i.processed
    diff $i.target $i.processed

done
