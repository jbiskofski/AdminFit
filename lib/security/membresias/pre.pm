package security::membresias::pre;

use strict;

sub default {

	my ( $n, %pp ) = @_;

	my %validations = (
		required => [
			{
				input   => 'name',
				message => 'Es necesario especificar un nombre de membres&iacute;a.'
			},
		],
		money => [

			{
				input   => 'amount',
				message => 'Es necesario especificar un precio.',
			},
		],
		javascript => [
			{
				input   => 'check_group_options()',
				message => qq {
					Es necesario especificar un n&uacute;mero
					de clientes ( Mayor igual a dos ) para membres&iacute;as grupales.
				},
			},
		],

	);

	return \%validations;

}

sub ver {

	my ( $n, %pp ) = @_;

	my $validations = security::membresias::pre->default();
	return $validations;

}

1;
