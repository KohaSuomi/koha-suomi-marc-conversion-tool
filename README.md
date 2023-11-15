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
# Run RDA conversion to bibliografic records

```shell

~/koha-suomi-marc-conversion-tool/usemarcon/program/usemarcon ../../USEMARCON-RDA/ma21RDA_bibliografiset.ini INPUTFILE OUTPUTFILE

```

# Run RDA conversion to authority records

```shell

~/koha-suomi-marc-conversion-tool/usemarcon/program/usemarcon ../../USEMARCON-RDA/ma21RDA_auktoriteetit.ini INPUTFILE OUTPUTFILE

```