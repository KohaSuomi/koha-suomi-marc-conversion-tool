# koha-suomi-marc-conversion-tool
Marc conversion tool

# Install USEMARCON

```shell
sudo apt install libtool automake autoconf
./buildconf.sh
cd pcre/
./configure --enable-utf8 --enable-unicode-properties --disable-shared --disable-cpp
make && make install
```
# Run conversions

1. Print marcxml records to files
```shell
perl -I ~/koha-suomi-marc-conversion-tool/ ~/koha-suomi-marc-conversion-tool/Converter/scripts/print_marcs.pl -p <OUTPUT_PATH>
```
1. Convert with usemarcon
```shell
~/koha-suomi-marc-conversion-tool/Converter/scripts/usemarcon_converter.sh ~/koha-suomi-marc-conversion-tool/USEMARCON-ISBD/ma2maisbd0.ini <INPUT_PATH> <OUTPUT_PATH>
```
```shell
~/koha-suomi-marc-conversion-tool/Converter/scripts/usemarcon_converter.sh ~/koha-suomi-marc-conversion-tool/USEMARCON-RDA/ma21RDA_bibliografiset.ini <INPUT_PATH> <OUTPUT_PATH>
```
1. Stage records to Koha 
```shell
perl -I ~/koha-suomi-marc-conversion-tool/ ~/koha-suomi-marc-conversion-tool/Converter/scripts/import_records.pl -d <INPUT_PATH> --matcher_id <number> -v
```