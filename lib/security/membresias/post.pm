package security::membresias::post;

use strict;

sub upsert_do {

	my ( $n, $dbh, $p, $options ) = @_;

	my ( $controller, $method ) = split( /\//, $ENV{REFERER} );

	my $validations = security::membresias::pre->$method();

	push @{ $validations->{uniqueupdate} },
	  {
		input   => '_f_memberships.name',
		message => 'Nombre de membres&iacute;a indisponible.'
	  };

	return $validations;

}

1;
