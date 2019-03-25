package controller::finanzas::charges;

use strict;
use Sort::Key qw/nkeysort rnkeysort/;

sub charge_client_membership {

	my ( $x, %pp ) = @_;

	my $membership = $x->{m}->{memberships}->get_client_memberships(
		where => {
			'_f_client_memberships.client_id' => $pp{client_id},
			'_g_users.active'                 => 1,
		},
		limit => 1,
	);

	return undef unless $membership;

	my $need_to_charge = $x->_check_renewal_day_passed( renewal_day => $membership->{renewal_day} );
	$need_to_charge = 1 if $pp{charge_now};

	return { no_charge => 1 } unless $need_to_charge;

	unless ( $pp{month} || $pp{year} ) {
		my $parts = global::date_time->get_date_time_parts();
		$pp{month} = $parts->{month};
		$pp{year}  = $parts->{year};
	}

	my $charge_exists = $x->{m}->{charges}->get_charges(
		month                   => $pp{month},
		year                    => $pp{year},
		only_membership_charges => 1,
		client_id               => $pp{client_id},
		limit                   => 1,
		not_cancelled           => 1,
	);

	return {
		existing => 1,
		id       => $charge_exists->{id}
	} if $charge_exists;

	$membership->{amount} = $pp{override_amount}
	  if $pp{override_amount} && $pp{override_amount} > 0;

	my $charge_id = $x->insert_charge(
		creation_date => $pp{creation_date},
		month         => $pp{month},
		year          => $pp{year},
		client_id     => $pp{client_id},
		membership    => $membership,
		notes         => $pp{notes},
		type_code     => 'M',
	);

	return {
		new        => 1,
		existing   => 0,
		id         => $charge_id,
		membership => $membership,
	};

}

sub _check_renewal_day_passed {

	my ( $x, %pp ) = @_;

	my $today = global::date_time->get_date_time_parts();
	return $today->{day} >= $pp{renewal_day} ? 1 : 0;

}

sub charge_sale_item {

	my ( $x, $d, %pp ) = @_;

	my $product = $x->{m}->{inventory}->get_products(
		where => { '_i_items.id' => $pp{item_id} },
		limit => 1,
	);

	if ( $product->{use_inventory} && ( !$product->{inventory} || !$product->{inventory}->{TOTAL} ) ) {
		$d->warning("El producto seleccionado : <b>$product->{name}</b>, no tiene disponibilidad en inventario.");
		return $x->{v}->status($d);
	}

	if ( $product->{type_code} eq 'VISITS' ) {

		my $membership = $x->{m}->{memberships}->get_client_memberships(
			where => {
				'_f_client_memberships.client_id' => $pp{client_id},
			},
			limit => 1,
		);

		if ( !$membership->{is_visits_membership} ) {
			$d->warning('Los paquetes de visitas solo se le pueden vender a clientes con la membres&iacute;a de VISITAS.');
			return $x->{v}->status($d);
		}

		my $visits_package = $x->{m}->{memberships}->get_visit_memberships(
			client_id => $pp{client_id},
			limit     => 1
		);

		if ( $visits_package->{active} ) {
			$d->warning('El cliente seleccionado ya tiene un paquete de visitas activo.');
			return $x->{v}->status($d);
		}

	}

	my $item_sale_id = global::standard->uuid();

	$product->{name} = $pp{concept} if $pp{concept} && length $pp{concept} > 0;

	$product->{amount} = $pp{override_amount}
	  if $pp{override_amount} && $pp{override_amount} > 0;

	my %insert = (
		id            => $item_sale_id,
		admin_id      => $pp{admin_id},
		item_id       => $pp{item_id},
		name          => $product->{name},
		amount        => $product->{amount},
		use_inventory => $product->{use_inventory},
	);

	$insert{transaction_id} = $pp{transaction_id} if $pp{transaction_id};

	$x->{m}->insert(
		insert => \%insert,
		table  => '_i_inventory_sales',
	);

	my $charge_id = $x->insert_charge(
		client_id              => $pp{client_id},
		type_code              => 'I',
		item_sale_id           => $item_sale_id,
		amount                 => $product->{amount},
		year                   => $pp{year},
		month                  => $pp{month},
		notes                  => $pp{notes},
		is_visits_package      => $pp{is_visits_package},
		visit_number           => $pp{visit_number},
		visits_expiration_date => $pp{visits_expiration_date},
		transaction_id         => $pp{transaction_id},
	);

	return $charge_id ? $charge_id : undef;

}

sub insert_charge {

	my ( $x, %pp ) = @_;

	my $year  = $pp{year}  ? $pp{year}  : "DATE_PART( 'YEAR', NOW() )";
	my $month = $pp{month} ? $pp{month} : "DATE_PART( 'MONTH', NOW() )";

	my %insert = (
		client_id => $pp{client_id},
		year      => $year,
		month     => $month,
		type_code => $pp{type_code},
	);

	if ( $pp{type_code} eq 'I' ) {
		$insert{amount}       = $pp{amount};
		$insert{item_sale_id} = $pp{item_sale_id};

		if ( $pp{is_visits_package} ) {
			$insert{visit_number}           = $pp{visit_number};
			$insert{visits_expiration_date} = $pp{visits_expiration_date};
		}

	}
	elsif ( $pp{type_code} eq 'M' ) {

		$insert{amount}        = $pp{membership}->{amount};
		$insert{membership_id} = $pp{membership}->{membership_id};

		if ( $pp{membership}->{type_code} eq 'G' ) {
			$insert{membership_group_id}   = $pp{membership}->{membership_group_id};
			$insert{responsible_client_id} = $pp{membership}->{responsible_client_id};
		}

	}
	elsif ( $pp{type_code} eq 'P' ) {
		$insert{amount} = 0;
	}
	else {
		global::standard->inspect("unknown charge type_code $pp{type_code}");
	}

	$insert{id}                 = global::standard->uuid();
	$insert{notes}              = $pp{notes} if $pp{notes} && length $pp{notes};
	$insert{creation_date_time} = $pp{creation_date} . ' ' . global::date_time->get_time() if $pp{creation_date};
	$insert{transaction_id}     = $pp{transaction_id} if $pp{transaction_id};

	my $rows = $x->{m}->insert(
		insert => \%insert,
		table  => '_f_charges',
	);

	return undef unless $rows;
	return $insert{id};

}

sub _generate_charge_history {

	my ( $n, $charge ) = @_;

	my @history;

	if ( $charge->{discounts} ) {
		map { $_->{type_code} = 'DISCOUNT' } @{ $charge->{discounts} };
		push @history, @{ $charge->{discounts} };
	}

	if ( $charge->{payments} ) {
		map { $_->{type_code} = 'PAYMENT' } @{ $charge->{payments} };
		push @history, @{ $charge->{payments} };
	}

	return undef unless scalar @history;

	my @sorted = nkeysort { $_->{epoch} } @history;

	return \@sorted;

}

sub add_new_charge {

	my ( $x, $d, %pp ) = @_;

	my $charge_id;

	if ( $pp{type_code} eq 'M' ) {

		my $result = $x->charge_client_membership(
			client_id       => $pp{client_id},
			override_amount => $pp{amount},
			notes           => $pp{notes},
			year            => $pp{year},
			month           => $pp{month},
			charge_now      => 1,
		);

		if ( $result->{existing} ) {
			$d->warning('La membres&iacute;a del cliente ya fue cobrada para el mes seleccionado.');
			return $x->{v}->status($d);
		}

		if (   $result->{membership}->{type_code} eq 'G'
			&& $result->{membership}->{is_responsible_for_group_membership}
			&& $result->{membership}->{dependents}
			&& scalar @{ $result->{membership}->{dependents} } )
		{

			# if were charging the main responsible for payment user, we need to charge
			# their dependents zero also
			foreach my $dep ( @{ $result->{membership}->{dependents} } ) {
				$x->charge_client_membership(
					client_id  => $dep->{id},
					year       => $pp{year},
					month      => $pp{month},
					charge_now => 1,
				);
			}

		}

		$charge_id = $result->{id};

	}
	elsif ( $pp{type_code} eq 'I' ) {

		my $product = $x->{m}->{inventory}->get_products(
			where => {
				'_i_items.is_permanent' => 1,
				'_i_items.type_code'    => 'OTHER',
			},
			limit => 1,
		);

		$charge_id = $x->charge_sale_item(
			$d,
			transaction_id  => $pp{transaction_id},
			client_id       => $pp{client_id},
			admin_id        => $pp{admin_id},
			item_id         => $product->{id},
			override_amount => $pp{amount},
			notes           => $pp{notes},
			concept         => $pp{concept},
			year            => $pp{year},
			month           => $pp{month},
		);

	}
	elsif ( $pp{type_code} eq 'P' ) {

		$charge_id = $x->insert_charge(
			client_id      => $pp{client_id},
			type_code      => 'P',
			amount         => 0,
			year           => $pp{year},
			month          => $pp{month},
			notes          => $pp{notes},
			transaction_id => $pp{transaction_id},
		);

	}
	else {
		global::standard->inspect("unknown charge type_code $pp{type_code}");
	}

	return $charge_id ? $charge_id : undef;

}

sub cancel_charge {

	my ( $x, %pp ) = @_;

	my $charge = $x->{m}->{finance}->get_statement( charge_id => $pp{charge_id} );

	$x->{m}->upsert(
		insert => {
			charge_id     => $pp{charge_id},
			charge_amount => $charge->{amount},
			admin_id      => $pp{admin_id},
			notes         => $pp{notes},
		},
		conflict_fields => ['charge_id'],
		table           => '_f_charges_cancelled',
	);

	my $yesterday = global::date_time->get_yesterday();

	$x->{m}->update(
		update => {
			amount                 => 0,
			visits_expiration_date => $yesterday,
		},
		where => {
			id => $pp{charge_id},
		},
		table => '_f_charges',
	);

	if ( $charge->{type_code} eq 'I' && $charge->{item_use_inventory} && $pp{return_to_inventory} ) {
		$x->{m}->insert(
			insert => {
				item_id             => $charge->{item_id},
				count               => 1,
				admin_id            => $pp{admin_id},
				cancelled_charge_id => $pp{charge_id},
			},
			no_id_column => 1,
			table        => '_i_inventory_add',
		);
	}

	return 1;

}

sub charge_dependent_same_owner_memberships {

	my ( $x, %pp ) = @_;

	my $membership = $x->{m}->{memberships}->get_client_memberships(
		where => {
			'_f_client_memberships.client_id' => $pp{client_id},
		},
		limit => 1,
	);

	global::standard->inspect('charge_dependent_same_owner_memberships') if !$membership;

	return undef
	  if $membership->{type_code} ne 'G'
	  || $membership->{is_responsible_for_group_membership}
	  || !$membership->{responsible_client_id};

	my $group_owner_charges = $x->{m}->{charges}->get_charges(
		only_membership_charges => 1,
		client_id               => $membership->{responsible_client_id},
	);

	return undef unless $group_owner_charges;

	foreach my $ch ( @{$group_owner_charges} ) {
		$x->charge_client_membership(
			client_id       => $pp{client_id},
			month           => $ch->{month},
			year            => $ch->{year},
			charge_now      => 1,
			override_amount => 0,
		);

	}

	return scalar @{$group_owner_charges} || 0;

}

1;
