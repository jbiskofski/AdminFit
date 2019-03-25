package security::descuentos::post;

use strict;

sub upsert_do {

	my ( $n, $dbh, $p, $options ) = @_;

	if ( $p->{requirement_type_code} eq 'S' ) {
		my $option_count = grep { /^MM-\S+/ } keys %{$p};
		return {
			status  => 0,
			message => 'Es necesario especificar cuales membres&iacute;as participan en el descuento.',
		} unless $option_count;
	}

	my ( $controller, $method ) = split( /\//, $ENV{REFERER} );

	my $validations = security::descuentos::pre->$method();

	push @{ $validations->{uniqueupdate} },
	  {
		input   => '_f_discounts.name',
		message => 'Nombre de descuento indisponible.'
	  };

	return $validations;

}

1;
