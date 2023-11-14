# koha-suomi-marc-conversion-tool
Marc conversion tool

# Install USEMARCON

1. sudo apt install libtool automake autoconf
2. ./buildconf.sh
3. cd pcre/
3. ./configure --enable-utf8 --enable-unicode-properties --disable-shared --disable-cpp
4. make && make install
