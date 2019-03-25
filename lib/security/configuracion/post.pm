package security::configuracion::post;

use strict;

sub detalles_adicionales_upsert_do {

	my ( $n, $dbh, $p, $options ) = @_;

	if ( $p->{type_code} eq 'options' ) {
		my $option_count = grep { /^SO-\d+/ } keys %{$p};
		return {
			status  => 0,
			message => 'El tipo <b>Opciones especificas</b> requiere agregar al menos dos posibles opciones.'
		} unless $option_count;
	}

	my $validations = security::configuracion::pre->detalles_adicionales();
	return $validations;

}

1;
