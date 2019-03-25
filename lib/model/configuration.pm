package model::configuration;

use strict;
use base 'model::base';

sub new {

	my ( $n, $dbh ) = @_;
	my $x = { dbh => $dbh };
	bless $x;
	return $x;

}

sub get_configuration {

	my $x = shift;

	my %configuration;

	my $sql = 'SELECT _g_configuration.key,_g_configuration.value FROM _g_configuration';

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my ( $key, $value ) = $sth->fetchrow() ) {
		$configuration{$key} = $value;
	}

	$sth->finish();

	return \%configuration;

}

sub get_additional_details {

	my ( $x, %pp ) = @_;

	my $sql_where = $x->generate_sql_where(%pp) if scalar keys %pp;
	my $sql_limit = " LIMIT $pp{limit} "        if $pp{limit};

	my $sql = qq {
	SELECT	_g_additional_details.id,_g_additional_details.name,
		_g_additional_details.type_code,
		_g_additional_details.active,
		_g_additional_details.required,
		_g_additional_details.for_staff,
		_g_additional_details.for_clients,
		_g_additional_details.for_inventory,
		_g_additional_details.inventory_type_codes,
		_g_additional_details.options
	FROM	_g_additional_details
	WHERE 	TRUE
	$sql_where
	ORDER BY _g_additional_details.active DESC,
	 	 _g_additional_details.name ASC
	$sql_limit
	};

	my @items;
	my @keys = qw/id name type_code active required
	  for_staff for_clients for_inventory _inventory_type_codes options/;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;

		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}

		if ( $ii{type_code} eq 'text' ) {
			$ii{display_type} = 'Texto';
		}
		elsif ( $ii{type_code} eq 'numeric' ) {
			$ii{display_type} = 'N&uacute;merico';
		}
		elsif ( $ii{type_code} eq 'date' ) {
			$ii{display_type} = 'Fecha';
		}
		elsif ( $ii{type_code} eq 'options' ) {
			$ii{display_type} = 'Opciones especificas';
		}

		if ( $ii{for_inventory} ) {

			my %inventory_display_names = (
				'FOOD'        => 'Bebidas y alimentos',
				'SUPPLEMENTS' => 'Suplementos',
				'CLOTHING'    => 'Ropa',
				'SHOES'       => 'Tenis',
				'EQUIPMENT'   => 'Equipo',
				'SERVICES'    => 'Servicios',
				'ENROLLMENTS' => 'Inscripciones',
				'OTHER'       => 'Otros',
			);

			my %inventory_types = map { $_ => $inventory_display_names{$_} } @{ $ii{_inventory_type_codes} };
			$ii{inventory_types} = \%inventory_types;

		}

		delete $ii{_inventory_type_codes};
		push @items, \%ii;

	}

	$sth->finish();

	return undef unless scalar @items;
	return $items[0] if $pp{limit} == 1;
	return \@items;

}

sub generate_detail_validations {

	my ( $x, $details ) = @_;

	return unless $details;

	my @required;
	my @numeric;
	my @date;

	foreach my $dd ( @{$details} ) {

		if ( $dd->{required} ) {

			push @required,
			  {
				input   => 'DD-' . $dd->{id},
				message => "El campo : <b>$dd->{name}</b> es obligatorio.",
			  };
		}

		if ( $dd->{type_code} eq 'numeric' ) {

			push @numeric,
			  {
				input   => 'DD-' . $dd->{id},
				ifdef   => !$dd->{required},
				message => "El campo : <b>$dd->{name}</b> solo puede incluir numeros o decimales.",
			  };
		}

		if ( $dd->{type_code} eq 'date' ) {

			push @date,
			  {
				input   => 'DD-' . $dd->{id},
				ifdef   => !$dd->{required},
				message => "El campo : <b>$dd->{name}</b> contiene una fecha inv&aacute;lida.",
			  };
		}

	}

	return undef unless scalar @required || scalar @numeric || scalar @date;

	return {
		required => \@required,
		numeric  => \@numeric,
		date     => \@date,
	};

}

1;
