package security::configuracion::pre;

use strict;

sub detalles_adicionales {

	my ( $n, %pp ) = @_;

	my %validations = (
		required => [
			{
				input   => 'name',
				message => 'Es necesario especificar un nombre.'
			},
		],
		javascript => [
			{
				input   => 'check_has_options()',
				message => 'El tipo <b>Opciones especificas</b> requiere agregar al menos dos posibles opciones.',
			},
			{
				input   => 'check_usage_types()',
				message => 'Es necesario especificar el uso para este detalle adicional. ( Staff, clientes, inventario )',
			},
			{
				input   => 'check_inventory_types()',
				message => 'Es necesario especificar los tipos de art&iacute;culos de inventario para los que se utilizar&aacute; el detalle adicional.',
			},
		],
	);

	return \%validations;

}

sub detalle {

	my ( $n, %pp ) = @_;

	my $validations = security::configuracion::pre->detalles_adicionales();

	return $validations;

}

sub default {

	my ( $n, %pp ) = @_;

	my %validations = (
		required => [
			{
				input   => 'gym_name',
				message => 'Es necesario especificar un nombre de gimasio.'
			},
		],
	);

	return \%validations;

}

1;
