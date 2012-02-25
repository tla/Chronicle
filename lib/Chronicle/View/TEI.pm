package Chronicle::View::TEI;
use Moose;
use namespace::autoclean;
use Encode qw( decode_utf8 );

extends 'Catalyst::View';

sub process {
	my( $self, $c ) = @_;
	$c->res->content_type( 'application/xml' );
	$c->res->content_encoding( 'UTF-8' );
	$c->res->output( decode_utf8( $c->stash->{result}->toString(1) ) );
}

=head1 NAME

Chronicle::View::TEI - Catalyst View

=head1 DESCRIPTION

Catalyst View.

=head1 AUTHOR

Tara Andrews

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
