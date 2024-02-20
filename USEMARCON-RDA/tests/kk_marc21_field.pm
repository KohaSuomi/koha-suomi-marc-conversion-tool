package kk_marc21_field;

# Contains string-level stuff
use strict;


require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(controlFieldToString dataFieldToString fieldToString getMaxRelatorTermScore getUnambiguousSubfield scoreRelatorTerm sortRelatorTerms);




sub controlFieldToString($) {
    my ( $fieldAsString ) = @_;
    $fieldAsString =~ s/ /\#/g; # '^' is aleph-style, '#' is validish as well
    return $fieldAsString;
}

sub dataFieldToString($) {
    my ( $fieldAsString ) = @_;
    # Visible indicators:
    $fieldAsString =~ s/^ /#/;
    $fieldAsString =~ s/^(.) /${1}#/;
    # Subfield sepatators:
    $fieldAsString =~ s/\x1F(.)/ ‡$1 /g; 
    return $fieldAsString;
}
    
sub fieldToString($) {
    my ( $fieldAsString ) = @_;
    if ( index($fieldAsString, "\x1F") > -1 ) { # Has subfields
	return dataFieldToString($fieldAsString);
    }
    return controlFieldToString($fieldAsString);
}

sub getUnambiguousSubfield($$) {
    my ( $content, $subfield_code ) = @_;
    if ( $content =~ /\x1F${subfield_code}([^\x1F]+)/ ) {
	my $val = $1;
	if ( $content =~ /\x1F${subfield_code}.*\x1F${subfield_code}/ ) {
	    return undef;
	}
	return $val;
    }
    return undef;
}

sub sequentialToField($) {
    my ( $content ) = @_;

    my $tag;
    my $indicators;
    my $subfields;

    if ( $content =~ /^[0-9]{9} (...)(..) L (.*)$/ ) {
	# NB! Don't send LDR here... It turns into a field...
	$tag = $1;

	$indicators = $2;
	$subfields = $3;
    }
    else { die($content); }

    my $new_content = '';
    if ( $tag !~ /^00/ ) {
	$new_content .= $indicators;
    }
    # Convert legal subfields or all subfields:
    if ( 1 ) {
	$subfields =~ s/\$\$([a-z0-9])/\x1F$1/g; # legal subfields
    }
    else {
	$subfields =~ s/\$\$/\x1F/g; # all subfields
    }
    $new_content .= $subfields;

    return $new_content;
}

sub getSubfield6TagAndIndex($) {
    my ( $content ) = @_;
    if ( $content =~ /^..\x1F6([0-9][0-9][0-9])-([0-9][0-9])($|-|\x1F)/ ) {
	return ( $1, $2 );
    }
    return ( undef, undef );
}

sub getSubfield6Index($) {
    my ( $content ) = @_;
    my ( $tag, $index ) = getSubfield6TagAndIndex($content);
    return $index;
}

sub getSubfield6Tag($) {
    my ( $content ) = @_;
    my ( $tag, $index ) = getSubfield6TagAndIndex($content);
    return $tag;
}

sub removeDuplicateSubfields($$) {
    my ( $orig_content, $relevant_subfield_codes ) = @_;

    my @subfields = split(/\x1F/, $orig_content);
    my %seen;
    my $hits = 0;
    my $new_content = $subfields[0];
    for ( my $i=1; $i < scalar(@subfields); $i++ ) {
	my $value = $subfields[$i];
	# Defined skippable subfields:
	my $skip = 0;
	if ( !defined($relevant_subfield_codes) ) {
	    if ( defined($seen{$value}) ) {
		$skip = 1;
	    }
	}
	else { # only interested in certain subfields
	    my $subfield_code = substr($value, 0, 1);
	    if ( index($relevant_subfield_codes, $subfield_code) > -1 ) {
		if ( defined($seen{$value}) ) {
		    $skip = 1;
		    #die("SF=$subfield_code VAL='$value' TARGET='$relevant_subfield_codes'");
		}	
		
	    }
	    
	}
	# Store non-skippable subfield content:
	if ( !$skip ) {
	    $new_content .= "\x1F".$value;
	    $hits++;
	}
	
	$seen{$value} = 1;
    }
    if ( !$hits ) { return $orig_content; }
    
    return $new_content;
}


# Use same values as in marc-record-validators (file melinda/src/sortFields.js)
my %escore;
# work/teos
$escore{'säveltäjä'} = 100; $escore{'composer'} = 100;
$escore{'kompositör'} = 100; $escore{'tonsättare'} = 100; # Should we fix tonsättare->kompositör?
$escore{'kirjoittaja'} = 99; $escore{'author'} = 99; $escore{'författare'} = 99;
$escore{'sarjakuvantekijä'} = 99;
$escore{'taiteilija'} = 98;
$escore{'sanoittaja'} = 90;
$escore{'käsikirjoittaja'} = 90;
$escore{'säveltäjä (ekspressio)'} = 87;
$escore{'kokoaja'} = 85;
$escore{'respondentti'} = 85;
# expression:
$escore{'toimittaja'} = 80; $escore{'editor'} = 80; $escore{'redaktör'} = 80;
$escore{'sovittaja'} = 80; $escore{'arranger'} = 80; $escore{'arrangör'} = 80;
$escore{'kuvittaja'} = 75;
$escore{'editointi'} = 71; # for music, editor/toimittaja is another thing...
$escore{'kääntäjä'} = 70;
$escore{'lukija'} = 61;
# manisfestation:
$escore{'esittäjä'} = 60;
$escore{'näyttelijä'} = 60;
$escore{'sopraano'} = 59;
$escore{'johtaja'} = 50; # orkesterinjohtaja
$escore{'musiikkiohjelmoija'} = 45;
$escore{'päätoimittaja'} = 43;
$escore{'tuottaja'} = 42;
$escore{'kustantaja'} = 41;
$escore{'julkaisija'} = 40;
$escore{'muu'} = 0;

sub getSupportedRelatorTermArray() {
    return sort keys %escore;
}


sub scoreRelatorTerm($) {
    my $relator_term = shift();
    if ( defined($escore{$relator_term}) ) {
	return $escore{$relator_term};
    }
    else {
	print STDERR "TODO: relator term '$relator_term' needs to be scored!\n";
	#die($relator_term);
	return 1;
    }
    return 0;
}

sub tag2relator_term_subfield_code($) {
    my ( $tag ) = @_;
    if ( $tag =~ /^[1678][01]0$/ ) { return 'e'; }
    if ( $tag =~ /^[1678]11$/ ) { return 'j'; }
    return undef;
}

sub sortRelatorTerms($$) {
    my ( $content, $tag ) = @_;

    my $sf_code = &tag2relator_term_subfield_code($tag);
    if ( !defined($sf_code) ) { return $content; }
    
    my @subfields = split(/\x1F/, $content);

    for ( my $i=1; $i < $#subfields; $i++ ) {
        if ( $subfields[$i] =~ /^${sf_code}((?:[a-z]|ä)+)([,\.]?)$/ ) {
            my $content1 = $1;
            my $separator1 = $2;
            my $score1 = kk_marc21_field::scoreRelatorTerm($content1);

            for ( my $j=$i+1; $j <= $#subfields; $j++ ) {
                if ( $subfields[$j]  =~ /^${sf_code}((?:[a-z]|ä|ö)+)([,\.]?)$/ ) {
                    my $content2 = $1;
                    my $separator2 = $2;
                    my $score2 = kk_marc21_field::scoreRelatorTerm($content2);

                    if ( $score2 > $score1 ) {
                        print STDERR "SWAP $i/'", $subfields[$i], "' <=> $j/'", $subfields[$j], "'\n";
                        my $tmp = $subfields[$i];
                        $subfields[$i] = $sf_code.$content2.$separator1;
                        $subfields[$j] = $sf_code.$content1.$separator2;

                        $content1 = $content2;
                        $score1 = $score2;
                    }
                }
            }
        }
    }
    return join("\x1F", @subfields);
}

sub getMaxRelatorTermScore($$) {
    my ( $content, $tag ) = @_;

    
    my $sf_code = &tag2relator_term_subfield_code($tag);
    if ( !defined($sf_code) ) { return 0; }
    
    my @subfields = split(/\x1F/, $content);

    my $max_score = 0;
    for ( my $i=0; $i < scalar(@subfields); $i++ ) {
        if ( $subfields[$i] =~ /^${sf_code}((?:[a-z]|ä)+)([,\.]?)$/ ) {
            my $relator_term = $1;
            my $curr_score = kk_marc21_field::scoreRelatorTerm($relator_term);
	    if ( $curr_score > $max_score ) {
		$max_score = $curr_score;
	    }
        }
    }
    #print STDERR fieldToString($content), " MAX $max_score\n";
    return $max_score;
}

1;
