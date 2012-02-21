package Chronicle::Model::Witness;
use Moose;
use MooseX::Types::Path::Class qw/ Dir File /;
use File::Basename qw/ fileparse /;
use Text::TEI::Collate::Manuscript;
use XML::LibXML;
use XML::LibXML::XPathContext;
use namespace::autoclean;

extends 'Catalyst::Model';

has 'sourcedir' => (
	is => 'ro',
	isa => Dir,
	coerce => 1,
	required => 1,
	);
	
has 'sigilmap' => (
	isa => 'HashRef[XML::LibXML::Document]',
	traits => ['Hash'],
	default => sub { {} },
	handles => {
		add_text => 'set',
		textobj => 'get',
		sigla => 'keys',
		},
	);
	
has 'sigilnamemap' => (
	isa => 'HashRef[Str]',
	traits => ['Hash'],
	default => sub { {} },
	handles => {
		add_textname => 'set',
		textname => 'get',
		witpairs => 'kv',
		},
	);
		
sub BUILD {
	my $self = shift;
	# Read all the files in sourcedir, get their sigla, and add to sigilmap.
	while( my $file = $self->sourcedir->next ) {
		$self->_add_to_maps( $file );
	}
}

sub get_witlist {
	my $self = shift;
	my $ret = [];
	foreach my $pair ( sort { $a->[0] cmp $b->[0] } $self->witpairs ) {
		push( @$ret, { 'sigil' => $pair->[0], 'name' => $pair->[1] } );
	}
	return $ret;
}

sub _add_to_maps {
	my( $self, $file ) = @_;
	my( $fn, $fp, $fs ) = fileparse( $file->absolute, qr/\.[^.]*/ );
	return unless $fs eq '.xml';
	my $parser = XML::LibXML->new();
	my $doc = $parser->parse_file( "$file" );
	my $xpc = _xpc_for_el( $doc->documentElement );
	my $sigil = $xpc->findvalue( '//tei:msDesc/attribute::xml:id' );
	my $textname = sprintf( "%s, %s %s", 
		$xpc->findvalue( '//tei:msIdentifier/tei:settlement' ),
		$xpc->findvalue( '//tei:msIdentifier/tei:repository' ),
		$xpc->findvalue( '//tei:msIdentifier/tei:idno' ) );
	$self->add_text( $sigil, $doc );
	$self->add_textname( $sigil, $textname );
}

sub as_html {
	my( $self, $sigil ) = @_;
	my $textroot = $self->textobj( $sigil );
	# Sigil and name, that's easy
	my $return_hash = { 'textsigil' => $sigil,
		'textidentifier' => $self->textname( $sigil ) };
	my $xpc = _xpc_for_el( $textroot );
	# Description blurb also not too hard
	$return_hash->{'textdescription'} = join( '',
		map { $_->toString } $xpc->findnodes( '//tei:msDesc/tei:p' ) );
	# Now comes the fun part - parse the body.
	$return_hash->{'textcontent'} = _html_transform( 
		$xpc->findnodes( '/tei:TEI/tei:text/tei:body' ),
		$xpc->exists( '//tei:cb' ) );
	return $return_hash;
}

sub as_json {
	my( $self, $sigil ) = @_;
	my $msobj = Text::TEI::Collate::Manuscript->new( 
		'sourcetype' => 'xmldesc',
		'source' => $self->textobj( $sigil )->documentElement,
		);
	return $msobj->tokenize_as_json();
}

sub as_tei {
	my( $self, $sigil ) = @_;
	return $self->textobj( $sigil )->toString(1);
}

sub _html_transform {
	my( $element, $usecolumns ) = @_;
	my %span_map = (
		'add' => 'addition',
		'del' => 'deletion',
		'abbr|num' => 'number',
		'hi' => 'highlight',
		'ex' => 'expansion',
		'expan' => 'expansion',
		);
	my @return_words;
	## NONRECURSING ELEMENTS
	if( $element->nodeType == XML_TEXT_NODE ) {
		my $text = $element->data;
		$text =~ s/^\s+//gs;
		$text =~ s/\s+$//gs;
		push( @return_words, $text );
	} elsif( $element->nodeName eq 'w' ) {
		# Simple word, just the text content.
		push( @return_words, $element->textContent . ' ' );
	} elsif( $element->nodeName eq 'lb' ) {
		push( @return_words, '<br/>' );
	} elsif( $element->nodeName eq 'damage' ) {
		my $len = $element->getAttribute('extent');
		push( @return_words, 'X' x $len );

		
	## RECURSING ELEMENTS
	} elsif( $element->nodeName =~ /^(body|seg|subst|num)$/ ) {
		# No wrapping, just pass-through
		@return_words = map { _html_transform( $_, $usecolumns ) } $element->childNodes;
		# but if it's a segword, put in a space.
		push( @return_words, ' ' ) if $element->nodeName eq 'seg';
	} elsif( $element->nodeName eq 'div' ) {
		# Section marker, then recurse
		my $secnum = $element->hasAttribute('n') ? $element->getAttribute('n') : '';
		push( @return_words, sprintf( "<div class=\"section\">\x{A7} %s</div>", $secnum ) );
		push( @return_words, map { _html_transform( $_, $usecolumns ) } $element->childNodes );
		
	} elsif( exists $span_map{$element->nodeName} ) {
		# Span wrapping
		my $spantype = $span_map{$element->nodeName};
		push( @return_words, "<span class=\"$spantype\">" );
		push( @return_words, map { _html_transform( $_, $usecolumns ) } $element->childNodes );
		push( @return_words, '</span>' );
		
	} elsif( $element->nodeName eq 'p' ) {
		# Paragraph wrapping
		push( @return_words, '<p>' );
		push( @return_words, map { _html_transform( $_, $usecolumns ) } $element->childNodes );
		push( @return_words, '</p>' );
		
	} elsif( $element->nodeName eq 'abbr' 
		&& $element->parentNode->nodeName eq 'num' ) {
		# A special case
		push( @return_words, "<span class=\"number\">" );
		push( @return_words, map { _html_transform( $_, $usecolumns ) } $element->childNodes );
		push( @return_words, '</span>' );
		

	## OTHER ELEMENTS
	} elsif( $element->nodeName eq 'pb' ) {
		# Now we get to the more complicated one.
		# Close the preceding paragraph if necessary, then a div, then reopen
		# a paragraph if necessary.
		my $xpc = _xpc_for_el( $element );
		my $midpg = $xpc->exists( 'ancestor::tei:p' );
		push( @return_words, '</p>' ) if $midpg;
		push( @return_words, '</td></tr></table>' ) if $usecolumns;
		push( @return_words, '<div class="pagenum">' );
		push( @return_words, $element->getAttribute('n') );
		push( @return_words, '</div>' );
		push( @return_words, '<table class="pagecolumn"><tr><td class="left">' )
			if $usecolumns;
		push( @return_words, '<p class="followpg">' ) if $midpg;
	} elsif( $element->nodeName eq 'cb' ) {
		## usecolumns had better be 1.
		my $xpc = _xpc_for_el( $element );
		my $midpg = $xpc->exists( 'ancestor::tei:p' );
		push( @return_words, '</p>' ) if $midpg;
		push( @return_words, '</td><td class="right">' );
		push( @return_words, '<p class="followpg">' ) if $midpg;
	}
	
	return join( '', @return_words );
}
sub _xpc_for_el {
	my $el = shift;
	my $xpc = XML::LibXML::XPathContext->new( $el );
	$xpc->registerNs( 'tei', 'http://www.tei-c.org/ns/1.0' );
	return $xpc;
}	

=head1 NAME

Chronicle::Model::Witness - Catalyst Model

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
