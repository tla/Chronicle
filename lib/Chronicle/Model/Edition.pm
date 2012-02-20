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
	my @words;
	foreach my $app ( $xpc->findnodes( 'descendant::tei:app' ) ) {
		my @process_apps;
		my @app_words;
		## Cope with apparatus criticus and notes. Need to anchor on
		## an apparatus that has a lemma.
		if( $xpc->exists( 'tei:lem/tei:w', $app ) ) {
			push( @process_apps, $app );
			my $curr = $app;
			while( $curr ) {
				my $next = $xpc->find( 'following-sibling::tei:app[1]', $curr )->pop;
				if( ref($next) ne 'XML::LibXML::Element' 
					|| $xpc->exists( 'tei:lem/tei:w', $next ) ) {
					last;
				} else {
					push( @process_apps, $next );
					$curr = $next;
				}
			}
			push( @app_words, compose_app_html( $xpc, @process_apps ) );
		} 
		
		## Cope with apparatus siglorum
		foreach my $signpost ( $xpc->findnodes( 'tei:rdg/tei:witStart | tei:rdg/tei:witEnd | tei:rdg/tei:lacunaStart | tei:rdg/tei:lacunaEnd', $app ) ) {
			# Spit out a witness start/end marker. Start markers before the words,
			# end markers after the words.
			# Get the witnesses of the enclosing rdg element
			my @wits = _parse_wit_string( $signpost->parentNode->getAttribute('wit') );
			my $note;
			my $prepend;
			if( $signpost->nodeName eq 'witStart' ) {
				$note = "Beginning of text for witness(es)";
				$prepend = 1;
			} elsif( $signpost->nodeName eq 'witEnd' ) {
				$note = "End of text for witness(es)";
			} elsif( $signpost->nodeName eq 'lacunaStart' ) {
				$note = "Lacuna begins for witness(es)";
				$prepend = 1;
			} elsif( $signpost->nodeName eq 'lacunaEnd' ) {
				$note = "Lacuna ends for witness(es)";
			}
			$note = join( ' ', $note, @wits );
			my $marker = "<span class=\"appsiglorum\" onclick=\"showNote('', '$note')\">\x{2020}</span>";
			$prepend ? unshift( @app_words, $marker ) : push( @app_words, $marker );
		}
		push( @words, @app_words );
	}
	return join( ' ', @words );
}

sub compose_app_html {
	my( $xpc, @apps ) = @_;
	my @words;

	# Get the aggregate lemma and make the list of unique readings for 
	# the included apps.
	my @lemma;
	my %wit_rdgs;
	my @appnotes;
	foreach my $app ( @apps ) {
		foreach my $w ( $xpc->findnodes( 'tei:lem/tei:w', $app ) ) {
			push( @lemma, $w->textContent );
		}

		# Collect the readings and notes
		foreach my $rdg ( $xpc->findnodes( 'tei:lem | tei:rdg', $app ) ) {
			my @rdgtext;
			foreach my $w ( $xpc->findnodes( 'tei:w', $rdg ) ) {
				push( @rdgtext, $w->textContent );
			}
			foreach my $wit ( _parse_wit_string( $rdg->getAttribute('wit') ) ) {
				push( @{$wit_rdgs{$wit}}, @rdgtext );
			}
		}
		foreach my $note_el( $xpc->findnodes( 'tei:note', $app ) ) {
			my $notetext = $note_el->textContent();
			$notetext =~ s!'!\\'!g;
			push( @appnotes, $notetext );
		}
	}

	my $lemmatext = join( ' ', @lemma );
	my %readings;
	foreach my $wit ( keys %wit_rdgs ) {
		my $rdgtext = join( ' ', @{$wit_rdgs{$wit}} );
		# Don't list the lemma witnesses
		next if $rdgtext eq $lemmatext;
		# Strip punctuation
		$rdgtext =~ s/[[:punct:]]//g;
		# Fill in something for omissions
		$rdgtext = '(omitted)' unless $rdgtext;
		push( @{$readings{$rdgtext}}, $wit );
	}
	
	# Collect the notes
	my %notes;
	
	
	# Arrange the readings into our JS arguments
	# Function will be:
	# showApparatus( lemmatext, [ reading, wit, wit ], [ reading, wit, wit ], ... )
	# showNote( note1, note2, ... )
	my @spanclass;
	my @jsfuncts;
	if( keys %readings ) {
		my @js_arguments = ( "'$lemmatext'" );
		foreach my $rdgtext ( keys %readings ) {
			my @listargs = ( $rdgtext );
			push( @listargs, @{$readings{$rdgtext}} );
			my $listrep = join( ', ', map { "'$_'" } @listargs );
			push( @js_arguments, "[ $listrep ]" );
		}
		push( @spanclass, 'lemma' );
		push( @jsfuncts, sprintf( 'showApparatus( %s )', join( ',', @js_arguments ) ) );
		push( @jsfuncts, '$(this).addClass(\'selectedlemma\')' );
	}
	if( @appnotes ) {
		my @js_arguments = map { "'$_'" } @appnotes;
		push( @spanclass, 'editnote' );
		push( @jsfuncts, sprintf( 'showNote( %s )', join( ',', @js_arguments ) ) );
	}
	if( @jsfuncts ) {
		my $spanclasstag = sprintf( 'class="%s"', join( ' ', @spanclass ) );
		my $spanjstag = sprintf( 'onclick="%s"', join( ';', @jsfuncts ) );
		push( @words, "<span $spanclasstag $spanjstag>$lemmatext</span>" );
	} else {
		push( @words, $lemmatext ) if $lemmatext;
	}
		
	return @words;
}

sub _parse_wit_string {
	my( $witstr ) = @_;
	return () unless $witstr;
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
