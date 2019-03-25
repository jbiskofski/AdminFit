package security::wods::pre;

use strict;

sub programacion {

	my ( $n, %pp ) = @_;

	my %validations = (
		required => [
			{
				input   => 'date',
				message => 'Es necesario especificar una fecha.'
			},
			{
				input   => 'name',
				message => 'Es necesario especificar un nombre de WOD.'
			},
			{
				input   => 'instructions',
				message => 'Instrucciones invalidas.'
			},
		],
		date => [
			{
				input   => 'date',
				message => 'Fecha de WOD inv&aacute;lida.'
			},
		],
		javascript => [
			{
				input   => 'check_exercises()',
				message => 'El WOD no incluye ejercicios registrables.',
			},
		],

	);

	return \%validations;

}

1;
