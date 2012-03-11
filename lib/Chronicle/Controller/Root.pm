package Chronicle::Controller::Root;
use Moose;
use namespace::autoclean;
use TryCatch;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

Chronicle::Controller::Root - Root Controller for Chronicle

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
	$c->stash->{'template'} = 'mainpage.tt2';
	$c->stash->{'pagetitle'} = 'Excerpts from the Chronicle of Matthew of Edessa';
	$c->forward('View::TT');
}

=head2 text/$id

Display the text, translation, and apparatus for the given text excerpt.

=cut

sub text :Local :Args(1) {
	my( $self, $c, $textid ) = @_;
	my $m = $c->model('Edition');
	my $d = $m->textdata( $textid );
	map { $c->stash->{$_} = $d->{$_} } keys %$d;
	$c->stash->{'template'} = 'editiontext.tt2';
	$c->forward('View::TT');
}

=head2 witness/$wit

Display the source text for the given witness.

=cut

sub witness :Chained('/') :PathPart :CaptureArgs(1) {
	my( $self, $c, $witness ) = @_;
	$c->stash->{'witness'} = $witness;
}

sub wit_display :PathPart('') :Chained('witness') :Args(0) {
	my( $self, $c ) = @_;
	my $wit = delete $c->stash->{'witness'};
	my $m = $c->model('Witness');
	$c->stash->{'pagetitle'} = 'Source view';
	my $textdata = $m->as_html( $wit );
	map { $c->stash->{$_} = $textdata->{$_} } keys %$textdata;
	$c->stash->{'template'} = "witness.tt2";
	$c->forward('View::TT');
}

=head2 witness/$wit/$format

Return the source text for the given witness in the given format.

=cut

sub wit_return :PathPart('') :Chained('witness') :Args(1) {
	my( $self, $c, $format ) = @_;
	my $m = $c->model('Witness');
	my $sub = "as_" . lc($format);
	my $view = 'View::'.uc($format);
	try {
		$c->stash->{'result'} = $m->$sub( $c->stash->{'witness'} );
	} catch ( Text::TEI::Collate::Error $e ) {
		# Something went wrong with the conversion
		$c->response->status(500);
		$c->stash->{'error'} = $e->ident . ' // ' . $e->message;
		$c->stash->{'template'} = 'error.tt2';
		$view = 'View::TT';
	} catch {
		# Something went wrong, maybe bad format specification
		$c->response->status(500);
		$c->stash->{'error'} = "Could not render witness in format $format";
		$c->stash->{'template'} = 'error.tt2';
		$view = 'View::TT';
	}
	$c->forward( $view );
}

=head2 abouttext

=head2 aboutsite

Return the static-but-for-templating page requested.

=cut

sub abouttext :Local :Args(0) {
	my( $self, $c ) = @_;
	$c->stash->{'template'} = 'abouttext.tt2';
	$c->forward('View::TT');
}

sub aboutsite :Local :Args(0) {
	my( $self, $c ) = @_;
	$c->stash->{'template'} = 'aboutsite.tt2';
	$c->forward('View::TT');
}

=head2 default

Standard 404 error page

=cut

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

=head2 auto

Populate the stash with the things our wrapper needs.

=cut

sub auto :Private {
	my( $self, $c ) = @_;
	$c->stash->{'witnesses'} = $c->model('Witness')->get_witlist;
	$c->stash->{'textlist'} = $c->model('Edition')->get_textlist;
}

=cut

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Tara L Andrews

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
