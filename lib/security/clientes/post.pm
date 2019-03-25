package security::clientes::post;

use strict;

sub upsert_do {

	my ( $controller, $method ) = split( /\//, $ENV{REFERER} );
	return 'NO-VALIDATIONS-REQUIRED' if $method eq 'reactivar';

	my $validations = security::clientes::pre->agregar();

	push @{ $validations->{uniqueupdate} },
	  {
		input   => '_g_users.username',
		message => 'Nombre de usuario indisponible.'
	  };

	return $validations;

}

1;
