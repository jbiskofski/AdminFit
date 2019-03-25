package security::asistencia::pre;

use strict;

sub ver {

	my ( $n, %pp ) = @_;

	my %validations = (
		required => [
			{
				input   => 'date',
				message => 'Fecha inv&aacute;lida.'
			},
			{
				input   => 'hour',
				message => 'Hora inv&aacute;lida.'
			},
		],
		date => [
			{
				input   => 'date',
				message => 'Fecha inv&aacute;lida.'
			},
		],
		numeric => [
			{
				input   => 'hour',
				message => 'Hora inv&aacute;lida.'
			},
		],
	);

	return \%validations;

}

1;
