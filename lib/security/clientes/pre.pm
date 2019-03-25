package security::clientes::pre;

use strict;

sub agregar {

	my ( $n, %pp ) = @_;

	my $validations = security::usuarios::pre->agregar();

	my @javascript_validations =
	  grep { $_->{input} ne 'check_has_admin_activity()' } @{ $validations->{javascript} };

	$validations->{javascript} = \@javascript_validations;

	push @{ $validations->{required} },
	  {
		input   => 'renewal_day',
		message => 'Es necesario especificar el dia de renovaci&oacute;n de la membres&iacute;a.',
	  };

	push @{ $validations->{required} },
	  {
		input   => 'membership_id',
		message => 'Es necesario especificar una membres&iacute;a.',
	  };

	push @{ $validations->{javascript} }, {
		input   => 'check_membership_group()',
		message => qq{
			El cliente que estas intentando agregar se configuro
			como dependiente de una membres&iacute;a grupal.
			Es necesario especificar quien es el responsable por el pago de la membres&iacute;a.
		},
	};

	return $validations;

}

sub actualizar {

	my ( $n, %pp ) = @_;

	my $validations = security::clientes::pre->agregar();

	my @javascript_validations =
	  grep { $_->{input} ne 'check_has_admin_activity()' } @{ $validations->{javascript} };

	$validations->{javascript} = \@javascript_validations;

	return $validations;

}

1;
