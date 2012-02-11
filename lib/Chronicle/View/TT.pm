package Chronicle::View::TT;

use strict;
use warnings;

use base 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt2',
    INCLUDE_PATH => [
        Chronicle->path_to( 'root', 'src' ),
    ],
    ENCODING => 'utf8',
    WRAPPER => 'wrapper.tt2',
    render_die => 1,
);

=head1 NAME

Chronicle::View::TT - TT View for Chronicle

=head1 DESCRIPTION

TT View for Chronicle.

=head1 SEE ALSO

L<Chronicle>

=head1 AUTHOR

Tara L Andrews

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
