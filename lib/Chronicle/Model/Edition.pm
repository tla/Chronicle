package Chronicle::Model::Edition;
use Moose;
use MooseX::Types::Path::Class qw/ Dir File /;
use XML::LibXML;
use XML::LibXML::XPathContext;
use namespace::autoclean;


extends 'Catalyst::Model';

has 'sourcefile' => (
	is => 'ro',
	isa => File,
	coerce => 1,
	required => 1,
	);

has 'textlist' => (
	isa => 'HashRef[XML::LibXML::Element]',
	traits => ['Hash'],
	handles => {
		add_text => 'set',
		textxml => 'get',
		texts => 'keys',
		textpairs => 'kv',
		},
	);
	
sub BUILD {
	my $self = shift;
	my $parser = XML::LibXML->new();
	my $docroot = $parser->parse_file( $self->sourcefile )->documentElement;
	my $xpc = _xpc_for_el( $docroot );
	foreach my $textel ( $xpc->findnodes( '//tei:text[@xml:id]' ) ) {
		$self->add_text( $textel->getAttribute('xml:id'), $textel );
	}
}

sub textname {
	my( $self, $sigil ) = @_;
	my $xpc = _xpc_for_el( $self->textxml( $sigil ) );
	return $xpc->findvalue( 'descendant::tei:head' );
}

sub get_textlist {
	my $self = shift;
	my $ret = [];
	foreach my $pair ( sort { $a->[0] cmp $b->[0] } $self->textpairs ) {
		my $xpc = _xpc_for_el( $pair->[1] );
		push( @$ret, { 'id' => $pair->[0], 'name' => $self->textname( $pair->[0] ) } );
	}
	return $ret;
}

# Return a list of { original: str, translation: str } for each paragraph in the text.
sub paragraphs {
	my( $self, $textid ) = @_;
	my $textel = $self->textxml( $textid );
	my $xpc = _xpc_for_el( $textel );
	my @paragraphs;
	foreach my $pgel ( $xpc->findnodes( './/tei:p[@xml:id]' ) ) {
		my $pgid = $pgel->getAttribute( 'xml:id' );
		$DB::single = 1;
		my( $pgcorr ) = $xpc->findnodes( ".//tei:p[\@corresp = \"#$pgid\"]" );
		my $pgdata = {
			'original' => $self->process_original( $pgel ),
			'translation' => $self->process_translation( $pgcorr ),
			};
		push( @paragraphs, $pgdata );
	}
	return \@paragraphs;
}

sub process_original {
	my( $self, $pgel ) = @_;
	my $xpc = _xpc_for_el( $pgel );
	my $note_ctr = 1;
	my @words;
	foreach my $app ( $xpc->findnodes( 'descendant::tei:app' ) ) {
		if( $xpc->exists( 'tei:lem', $app ) ) {
			my @lemma;
			# Process the lemma and any apparatus
			foreach my $w ( $xpc->findnodes( 'tei:lem/tei:w', $app ) ) {
				push( @lemma, $w->textContent );
			}
			my $lemmatext = join( ' ', @lemma );
			# Does the lemma have sibling rdgs? If so, we need to make an apparatus.
			if( $lemmatext && $xpc->exists( 'tei:rdg', $app ) ) {
				my %readings;
				# Collect the readings
				foreach my $rdg ( $xpc->findnodes( 'tei:rdg', $app ) ) {
					my @rdgtext;
					foreach my $w ( $xpc->findnodes( 'tei:w', $rdg ) ) {
						push( @rdgtext, $w->textContent );
					}
					my @wits = _parse_wit_string( $rdg->getAttribute('wit') );
					$readings{join(' ', @rdgtext )} = \@wits;
				}
				## TODO Look ahead for empty lemmata
				# Arrange the readings into our JS arguments
				# Function will be:
				# showApparatus( lemmatext, [ reading, wit, wit ], [ reading, wit, wit ], ... )
				my @js_arguments = ( 'showApparatus(', "'$lemmatext'," );
				foreach my $rdgtext ( keys %readings ) {
					my @listargs = ( $rdgtext );
					push( @listargs, @{$readings{$rdgtext}} );
					my $listrep = join( ', ', map { "'$_'" } @listargs );
					push( @js_arguments, "[ $listrep ]" );
				}
				push( @js_arguments, ');' );
				push( @words, sprintf( '<span class="lemma" onClick="%s">%s</span>',
					join( ' ', @js_arguments ), $lemmatext ) );
			} else {
				push( @words, $lemmatext ) if $lemmatext;
			}
		} else {
			# This must be a witStart or witEnd - add some sigil plus apparatus.
			# TODO add onClick to show the content
			push( @words, "<span class=\"witborder\">\x{2020}</span>" );
		}
		## Process notes
		if( $xpc->exists( 'tei:note', $app ) ) {
			foreach my $note_el ( $xpc->findnodes( 'tei:note', $app ) ) {
				my $spantag = 'span class="editnote" onclick="showNote(\'';
				my $notetext = $note_el->textContent();
				$notetext =~ s!'!\\'!g;
				$spantag .= $notetext . '\')"';
				push( @words, "<$spantag>$note_ctr</span>");
				$note_ctr++;
			}
		}
	}
	return join( ' ', @words );
}

sub _parse_wit_string {
	my @wits = split( /\s+/, $_[0] );
	map { s/^\#// } @wits;
	return @wits;
}

sub process_translation {
	my( $self, $pgel ) = @_;
	my $xpc = _xpc_for_el( $pgel );
	my @words;
	foreach my $cn ( $pgel->childNodes ) {
		if( $cn->nodeType == XML_TEXT_NODE ) {
			push( @words, $cn->data() );
		} elsif( $cn->nodeName eq 'term' ) {
			push( @words, '<span class="term">' . $cn->textContent . '</span>' );
		} elsif( $cn->nodeName eq 'note' ) {
			push( @words, '<span class="footnote">*</span>' );
		}
	}
	return join( ' ', @words );
}
		
sub _xpc_for_el {
	my $el = shift;
	my $xpc = XML::LibXML::XPathContext->new( $el );
	$xpc->registerNs( 'tei', 'http://www.tei-c.org/ns/1.0' );
	return $xpc;
}	

=head1 NAME

Chronicle::Model::Edition - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=head1 AUTHOR

Tara L Andrews

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
