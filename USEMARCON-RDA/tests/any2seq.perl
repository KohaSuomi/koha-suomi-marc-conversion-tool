#!/usr/bin/perl -w -I.
use strict;
use nvolk_marc_record;

my $tmp =$/;
undef $/;
my $input = <>;
$/ = $tmp;

if ( $input ) {
    my $marc_record = new nvolk_marc_record($input);

    print $marc_record->toAlephSequential();
}
