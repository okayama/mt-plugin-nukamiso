package Nukamiso::Tags;
use strict;

use Nukamiso::Util qw( dumper );

sub _hdlr_dump {
    my ( $ctx, $args ) = @_;
    if ( $args->{ all } ) {
        return '<pre>' . dumper( $ctx ) . '</pre>';
    } elsif ( $args->{ stash } ) {
        return '<pre>' . dumper( $ctx->{ __stash } ) . '</pre>';
    } else {
        return '<pre>' . dumper( $ctx->{ __stash }{ vars } ) . '</pre>';
    }
}

1;
