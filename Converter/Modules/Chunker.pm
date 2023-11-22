package Converter::Modules::Chunker;
#!/usr/bin/perl

# Copyright Vaara-kirjastot 2015
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use C4::Record;
use C4::Biblio;

=head SYNOPSIS

    BiblioChunker paginates database access to a large volume of marcxml from the DB.

Loading a large amount of biblios (especially the marcxml-column) at once will have
unexpected consequences. This object paginates a DB access to the biblio-table.

=cut

sub new {
    my ($class, $start, $end, $pageSize, $starting_biblionumber, $verbose) = @_;
    my $self = {};
    $self->{start} = $start || 0;
    $self->{end} = $end || 99999999999;
    $self->{pageSize} = $pageSize  || 100;
    $self->{starting_biblionumber} = $starting_biblionumber || 0;
    $self->{position} = {
        start => $self->{start},
        end => $self->{start} + $self->{pageSize},
        page => 1,
    };
    $self->{verbose} = $verbose || 0;
    bless($self, $class);
    return $self;
}

sub getChunkAsMARCRecord {
    my ($self) = @_;
    my $chunk = $self->_getChunk();
    return $chunk unless $chunk;

    for (my $i=0 ; $i<scalar(@$chunk) ; $i++) {
        my $bi = $chunk->[$i];
        my $marcxml = C4::Biblio::GetXmlBiblio($bi->{biblionumber});
        my $error = "";
        ($error, $chunk->[$i]) = C4::Record::marcxml2marc($marcxml);
        print "ERROR: MARC::Record for biblio $bi->{biblionumber} is broken, skipping...\n" if $error;
        $chunk->[$i]->{biblionumber} = $bi->{biblionumber};
        $chunk->[$i]->{biblioitemnumber} = $bi->{biblioitemnumber};
        $chunk->[$i]->{frameworkcode} = $bi->{frameworkcode};
    }
    return $chunk;
}

sub getChunk {
    my ($self) = @_;
    return $self->_getChunk();
}

sub _getChunk {
    my ($self) = @_;
    my @cc = caller(0);

    if ($self->{verbose} > 0) {
        print ' #'.DateTime->now()->iso8601()."# ".$cc[3]." is getting new chunk ".$self->{position}->{page}.", ".$self->{position}->{start}."-".$self->{position}->{end}." #\n" if $self->{verbose} > 0;
    }

    unless ($self->_isChunkWithinBounds()) {
        return undef;
    }

    my $dbh = C4::Context->dbh();
    my $query = "(SELECT b.biblionumber FROM biblio b ";
    $query .= "WHERE b.biblionumber >= ".$self->{starting_biblionumber} if $self->{starting_biblionumber};
    $query .= " LIMIT ".$self->{position}->{start}.",".$self->{pageSize}.")";

    my $sth = $dbh->prepare($query);
    $sth->execute();
    if ($sth->err) {
        die $cc[3]."():> ".$sth->errstr;
    }
    my $chunk = $sth->fetchall_arrayref({});
    if (ref $chunk eq 'ARRAY' && scalar(@$chunk)) {
        $self->_incrementPosition();
        return $chunk;
    }
    else {
        my $nextAvailableBiblioitemnumber = $self->_getNextId();
        if ($nextAvailableBiblioitemnumber) {
            $self->_incrementPosition($nextAvailableBiblioitemnumber);
            return $self->getChunk();
        }
        else {
            return undef;
        }
    }
    return (ref $chunk eq 'ARRAY' && scalar(@$chunk)) ? $chunk : undef;
}

sub _getPosition {
    my ($self) = @_;
    return ($self->{position}->{start}, $self->{position}->{end});
}
sub _incrementPosition {
    my ($self, $newStart) = @_;
    if ($newStart) {
        $self->{position}->{start} = $newStart;
        $self->{position}->{end}   = $self->{position}->{start} + $self->{pageSize};
    }
    else {
        $self->{position}->{start} += $self->{pageSize};
        $self->{position}->{end}   += $self->{pageSize};
    }
    $self->{position}->{page}++;
}
sub _getNextId {
    my ($self) = @_;

    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare("SELECT MIN(biblionumber) FROM biblio WHERE biblionumber > ?");
    my @pos = $self->_getPosition();
    $sth->execute( $pos[0] );
    if ($sth->err) {
        my @cc = caller(0);
        die $cc[3]."():> ".$sth->errstr;
    }
    my ($biblionumber) = $sth->fetchrow();
    return $biblionumber;
}
sub _isChunkWithinBounds {
    my ($self) = @_;

    if ($self->{end} < $self->{position}->{end}) {
        if ($self->{end} > ($self->{position}->{end} - $self->{pageSize})) {
            $self->{position}->{end} = $self->{end};
            return 1;
        }
        else {
            return 0;
        }
    }
    else {
        return 1;
    }
}
1;
