package security::ventas::post;

use strict;

sub upsert_do {

	my ( $n, $dbh, $p, $options ) = @_;

	my $validations = security::ventas::pre->default();

	push @{ $validations->{uniqueupdate} },
	  {
		input   => '_i_items.name',
		message => 'Nombre de producto indisponible.'
	  };

	return $validations;

}

1;
