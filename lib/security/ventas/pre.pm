package security::ventas::pre;

use strict;

sub default {

	my ( $n, %pp ) = @_;

	my %validations = (
		required => [
			{
				input   => 'type_code',
				message => 'Es necesario especificar un tipo de producto/servicio.'
			},
			{
				input   => 'name',
				message => 'Es necesario especificar un nombre.'
			},
			{
				input   => 'amount',
				message => 'Es necesario especificar un precio.'
			},
		],
	);

	return \%validations;

}

sub ver {

	my ( $n, %pp ) = @_;

	my $validations = security::ventas::pre->default();

	return $validations;

}

sub add_inventory_do {

	my ( $n, %pp ) = @_;

	my %validations = (
		required => [
			{
				input   => 'count',
				message => 'Cantidad de articulos inv&aacute;lida.'
			},
		],
		numeric => [
			{
				input   => 'count',
				message => 'Cantidad de articulos inv&aacute;lida.'
			},
		],
	);

	return \%validations;

}

sub remove_inventory_do {

	my ( $n, %pp ) = @_;

	my %validations = (
		required => [
			{
				input   => 'count',
				message => 'Cantidad de articulos inv&aacute;lida.'
			},
		],
		numeric => [
			{
				input   => 'count',
				message => 'Cantidad de articulos inv&aacute;lida.'
			},
		],
		"le_$pp{le}" => [
			{
				input   => 'count',
				message => "El m&aacute;ximo de articulos que se puede restar del inventario es : <b>$pp{le}</b>.",
			},
		],

	);

	return \%validations;

}

1;
