package security::descuentos::pre;

use strict;

sub default {

	my ( $n, %pp ) = @_;

	my %validations = (
		required => [
			{
				input   => 'name',
				message => 'Es necesario especificar un nombre de descuento.'
			},
		],
		javascript => [
			{
				input   => 'check_membership_options()',
				message => 'Es necesario especificar cuales membres&iacute;as participan en el descuento.',
			},
		],

	);

	return \%validations;

}

sub ver {

	my ( $n, %pp ) = @_;

	my $validations = security::descuentos::pre->default();
	return $validations;

}

1;
