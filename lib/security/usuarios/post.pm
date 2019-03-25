package security::usuarios::post;

use strict;

sub upsert_do {

	my ( $n, $dbh, $p, $options ) = @_;

	my ( $controller, $method ) = split( /\//, $ENV{REFERER} );
	my $validations = security::usuarios::pre->$method();

	push @{ $validations->{uniqueupdate} },
	  {
		input   => '_g_users.username',
		message => 'Nombre de usuario indisponible.'
	  };

	return $validations;

}

1;
