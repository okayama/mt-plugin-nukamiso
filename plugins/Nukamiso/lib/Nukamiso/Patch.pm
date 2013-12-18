package Nukamiso::Patch;
use strict;

no warnings qw( redefine );

use Encode;
use Nukamiso::Util qw( dumper );

require Data::ObjectDriver::Driver::DBI;
*Data::ObjectDriver::Driver::DBI::fetch = sub {
    my $driver = shift;
    my($rec, $class, $orig_terms, $orig_args) = @_;

    if ($Data::ObjectDriver::RESTRICT_IO) {
        use Data::Dumper;
        die "Attempted DBI I/O while in restricted mode: fetch() " . Dumper($orig_terms, $orig_args);
    }

    my ($sql, $bind, $stmt) = $driver->prepare_fetch($class, $orig_terms, $orig_args);

    my @bind;
    my $map = $stmt->select_map;
    for my $col (@{ $stmt->select }) {
        push @bind, \$rec->{ $map->{$col} };
    }

    my $dbh = $driver->r_handle($class->properties->{db});
    $driver->start_query($sql, $stmt->{bind});

    my $sth = $orig_args->{no_cached_prepare} ? $dbh->prepare($sql) : $driver->_prepare_cached($dbh, $sql);
# PATCH
#    $sth->execute(@{ $stmt->{bind} });
eval {
    $sth->execute(@{ $stmt->{bind} });
};
if ( $@ ) {
    my $sql_built = build_sql( $sql, $stmt->{ bind } );
    my $e = 'ERROR: ' . $@ . "\nSQL: $sql_built\n";
    MT->log( $e );
    use Carp;
    die Carp::confess();
}
# /PATCH
    $sth->bind_columns(undef, @bind);

    # need to slurp 'offset' rows for DBs that cannot do it themselves
    if (!$driver->dbd->offset_implemented && $orig_args->{offset}) {
        for (1..$orig_args->{offset}) {
            $sth->fetch;
        }
    }

    return $sth;
};

sub build_sql {
    my ( $sql, $bind ) = @_;
    if ( ref( $bind ) eq 'ARRAY' ) {
        my @bind_c = @$bind;
        if ( scalar @$bind > 0 ) {
            while( defined( my $value = shift @bind_c ) ) {
                $value = Encode::decode_utf8( $value );
                $value =~ /^[0-9]+$/
                    ? $sql =~ s/(.*?)\?/$1$value/
                    : $sql =~ s/(.*?)\?/$1'$value'/;
            }
        }
    }
    return $sql;
}

require MT::ObjectDriver::Driver::DBI;
my $_start_query = *MT::ObjectDriver::Driver::DBI::start_query{CODE};
*MT::ObjectDriver::Driver::DBI::start_query = sub {
    my $driver = shift;
    my ( $sql, $bind ) = @_;
    if ( $MT::DebugMode && $MT::DebugMode & 4 ) {
        $sql =~ s/\r?\n/ /g;
# PATCH
#        warn "QUERY: $sql";
        if ( $sql !~ /\?/ ) {
            warn "QUERY: $sql";
        } else {
            my $sql_built = build_sql( $sql, $bind );
            if ( $sql_built ne $sql ) {
                if ( $sql_built !~ /\?/ ) {
                    warn "QUERY: $sql_built";
                } else {
                    warn "QUERY MAYBE(see also BIND): $sql_built";
                    warn "BIND: " . dumper( $bind );
                }
            } else {
                if ( ref( $bind ) eq 'HASH' ) {
                    my %bind_c = %$bind;
                    for my $key ( keys %bind_c ) {
                        my $value = $bind_c{ $key };
                        $bind_c{ $key } = Encode::decode_utf8( $value );
                    }
                    warn "QUERY(see also BIND): $sql";
                    warn "BIND: " . dumper( \%bind_c );
                } else {
                    warn "QUERY(see also BIND): $sql";
                    warn "BIND: " . dumper( $bind );
                }
            }
        }
        if ( ref( MT->instance() ) eq 'MT::App::CMS' ) {
            my $app = MT->instance();
            if ( $app->param( 'motto' ) || $app->param( 'mottomotto' ) || $app->param( 'mottomottomotto' ) ) {
                my $limit = $app->param( 'mottomottomotto' )
                                ? 15
                                : $app->param( 'mottomotto' )
                                    ? 10
                                    : 5;
                use Data::Dumper;
                for ( my $i = 1; $i <= $limit; $i++ ) {
                    if ( my @caller = caller( $i ) ) {
                        warn "  TRACE $i: "  . $caller[ 3 ] . ' from ' . $caller[ 1 ] . ' line ' . $caller[ 2 ] . '.';
                    }
                }
            }
        }
# /PATCH
    }
    require Data::ObjectDriver;
    return Data::ObjectDriver::start_query( $driver, @_);
};

1;
