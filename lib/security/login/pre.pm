package security::login::pre;

use strict;

sub default {

	my ( $n, %pp ) = @_;

	my %validations = (
		required => [
			{
				input   => 'username',
				message => 'Es necesario especificar un nombre de usuario.'
			},
			{
				input   => 'password',
				message => 'Es necesario especificar una contrase&ntilde;a.',
			},
		],
	);

	return \%validations;

}

1;
