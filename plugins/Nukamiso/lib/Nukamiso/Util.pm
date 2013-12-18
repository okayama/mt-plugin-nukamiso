package Nukamiso::Util;
use strict;
use base qw( Exporter );

our @EXPORT_OK = qw(
    dumper debug debug_query
);

use Data::Dumper;

sub dumper {
    my ( @targets ) = @_;
    my $dump;
    if ( scalar( @targets ) == 1 ) {
        if ( ref( $targets[ 0 ] ) ) {
            $dump = Dumper( $targets[ 0 ] );
        } else {
            $dump = $targets[ 0 ];
        }
    } else {
        $dump = Dumper( \@targets );
    }
    $dump =~ s/\\x{([0-9a-z]+)}/chr(hex($1))/ge;
    return $dump;
}

sub debug {
    my $dump = dumper( @_ ) || '';
    MT->log( 'dump: ' . $dump );
}

sub debug_query {
    my $app = MT->instance();
    my $string = '';
    for my $key ( $app->param ) {
        $string .= $key . ' = ' . join( ', ', $app->param( $key ) ) . "\n";
    }
    MT->log( 'query: ' . $string );
}

1;
