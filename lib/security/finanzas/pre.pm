package security::finanzas::pre;

use strict;

sub cobro {

	my ( $n, %pp ) = @_;

	my %validations = (
		required => [
			{
				input   => 'amount',
				message => 'Es necesario especificar una cantidad de descuento.'
			},
		],
		money => [
			{
				input   => 'amount',
				message => 'El descuento debe ser un valor n&uacute;merico.'
			},
		],
		"le_$pp{le}" => [
			{
				input   => 'amount',
				message => 'El descuento debe ser menor que el restante del cobro : $' . global::ttf->commify( $pp{le} ),
			},
		],

	);

	return \%validations;

}

1;
