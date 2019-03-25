package controller::ventas;

use strict;
use base 'controller::ventas::standard';

use Sort::Key qw/rnkeysort nkeysort/;
use Clone 'clone';

sub new {

	my ( $n, $d ) = @_;

	my $x = {
		v => view::render->new( $d->{r} ),
		m => model::init->new( $d->{dbh} ),
	};

	bless $x;
	return $x;

}

sub default {

	my ( $x, $d ) = @_;

	my $details = $x->{m}->{configuration}->get_additional_details(
		where => {
			'_g_additional_details.active'        => 1,
			'_g_additional_details.for_inventory' => 1,
		}
	);

	my $validations;

	if ($details) {

		$validations = $x->{m}->{configuration}->generate_detail_validations($details);

		my %inventory_type_details;

		foreach my $dd ( @{$details} ) {
			foreach my $type ( keys %{ $dd->{inventory_types} } ) {
				push @{ $inventory_type_details{$type} },
				  {
					id        => $dd->{id},
					name      => $dd->{name},
					type_code => $dd->{type_code},
					required  => $dd->{required},
					options   => $dd->{options}
				  };
			}
		}

		$d->{data}->{inventory_type_details} = \%inventory_type_details;

	}

	$d->{data}->{products} = $x->{m}->{inventory}->get_products(
		order_by_inventory => 1,
		get_debt_totals    => 1,
	);

	$d->{data}->{total_inventory_items} = 0;

	if ( $d->{data}->{products} ) {

		my @inventory;
		my @sales;
		my @daily_labels;
		my @daily_sales;

		$d->{data}->{total_membership_income} = 0;
		$d->{data}->{total_month_income}      = 0;
		my $month_product_sales = $x->{m}->{inventory}->get_timeframe_sales( get_current_month => 1 );

		foreach my $prod ( @{ $d->{data}->{products} } ) {
			$d->{data}->{total_month_income} += $month_product_sales->{products}->{ $prod->{id} };
			push @sales, { $prod->{name} => $month_product_sales->{products}->{ $prod->{id} } || 0 };
			next unless $prod->{use_inventory};
			$d->{data}->{total_inventory_items} += $prod->{inventory}->{TOTAL};
			push @inventory, { $prod->{name} => $prod->{inventory}->{TOTAL} };
		}

		$d->{data}->{charts}->{inventory} = global::charts->pie(
			title  => 'Inventario',
			color  => 'blue',
			values => \@inventory,
			div_id => 'DIV-INVENTORY-CHART',
			others => 7,
		) if $d->{data}->{total_inventory_items};

		if ( $d->{data}->{total_month_income} ) {

			$d->{data}->{charts}->{sales} = global::charts->pie(
				monify => 1,
				title  => 'Ventas',
				color  => 'green',
				values => \@sales,
				div_id => 'DIV-SALES-CHART',
				others => 7,
			) if scalar @sales;

			foreach my $dd ( @{ $month_product_sales->{dates} } ) {
				my ( $day, $month, $year ) = split( /\D+/, $dd->{date} );
				push @daily_labels, $day;
				push @daily_sales, $dd->{total} || 0;
			}

			$d->{data}->{charts}->{daily_sales} = global::charts->lines(
				monify => 1,
				color  => 'green',
				values => \@daily_sales,
				labels => \@daily_labels,
				div_id => 'DIV-DAILY-SALES-CHART',
				title  => 'Ventas',
			);

		}

	}

	$d->info('No se han agregado productos.') unless $d->{data}->{products};

	$d->get_form_validations( append => $validations );

	$x->{v}->render($d);

}

sub upsert_do {

	my ( $x, $d ) = @_;

	my $is_update = 1 if $d->{p}->{id};

	if ($is_update) {

		my $product = $x->{m}->{inventory}->get_products(
			where => { '_i_items.id' => $d->{p}->{id} },
			limit => 1,
		);

		if ( $product->{is_permanent} ) {
			$d->warning('No es posible modificar o deshabilitar el adeudo general.');
			return $x->{v}->status($d);
		}

	}

	$d->{p}->{amount} =~ s/,//;

	my %insert = (
		id            => $d->{p}->{id},
		type_code     => $d->{p}->{type_code},
		name          => $d->{p}->{name},
		amount        => $d->{p}->{amount},
		use_inventory => $d->{p}->{use_inventory} || 0,
	);

	$insert{active} = 1 if !$d->{p}->{id};

	$insert{use_inventory} = 0
	  if $d->{p}->{type_code} eq 'SERVICES' || $d->{p}->{type_code} eq 'ENROLLMENTS';

	if ( $d->{p}->{type_code} eq 'VISITS' ) {
		$insert{visit_number}      = $d->{p}->{visit_number};
		$insert{expiration_number} = $d->{p}->{expiration_number};
		$insert{expiration_unit}   = $d->{p}->{expiration_unit};
	}

	my %details;

	foreach my $dd ( keys %{ $d->{p} } ) {
		next unless $dd =~ /^DD-(\S+)$/;
		$details{$1} = $d->{p}->{$dd};
	}

	if ( scalar keys %details ) {
		my $json_data = JSON::XS->new()->latin1()->encode( \%details );
		$insert{data} = $json_data if $json_data;
	}

	$x->{m}->upsert(
		insert          => \%insert,
		conflict_fields => ['id'],
		table           => '_i_items',
	);

	my $message =
	  $d->{p}->{id}
	  ? 'Producto actualizado.'
	  : 'Producto agregado.';

	$d->success($message);
	$d->save_state();

	my $method = $d->{p}->{id} ? 'ver' : 'default';

	return $x->{v}->http_redirect(
		c  => 'ventas',
		m  => $method,
		id => $d->{p}->{id},
	);

}

sub x_check_name_availability {

	my ( $x, $d ) = @_;

	my $count = $x->{m}->count(
		where => {
			name => $d->{p}->{name}
		},
		ignore_case => 1,
		table       => '_i_items'
	);

	$x->{v}->render_json( { available => $count ? 0 : 1 } );

}

sub ver {

	my ( $x, $d ) = @_;

	$d->{data}->{product} = $x->{m}->{inventory}->get_products(
		where => { '_i_items.id' => $d->{p}->{id} },
		limit => 1,
	);

	my $details = $x->{m}->{configuration}->get_additional_details(
		where => {
			'_g_additional_details.active'        => 1,
			'_g_additional_details.for_inventory' => 1,
		}
	);

	$d->{data}->{debts} = $x->{m}->{charges}->get_item_debt_details( inventory_item_id => $d->{p}->{id} );

	my $validations;

	if ($details) {

		$validations = $x->{m}->{configuration}->generate_detail_validations($details);

		my %inventory_type_details;

		foreach my $dd ( @{$details} ) {
			foreach my $type ( keys %{ $dd->{inventory_types} } ) {
				push @{ $inventory_type_details{$type} },
				  {
					id        => $dd->{id},
					name      => $dd->{name},
					type_code => $dd->{type_code},
					required  => $dd->{required},
					options   => $dd->{options}
				  };
			}
		}

		$d->{data}->{inventory_type_details} = \%inventory_type_details;

	}

	$d->{data}->{history} = $x->{m}->{inventory}->get_history(
		item_id => $d->{p}->{id},
		limit   => 11
	);

	my $sales = $x->{m}->{inventory}->get_timeframe_sales(
		item_id           => $d->{p}->{id},
		get_current_month => 1,
	);

	if ( $sales && scalar @{ $sales->{dates} } ) {

		my @daily_labels;
		my @daily_sales;

		foreach my $dd ( @{ $sales->{dates} } ) {
			push @daily_labels, $dd->{date};
			push @daily_sales, $dd->{total} || 0;
		}

		$d->{data}->{charts}->{daily_sales} = global::charts->lines(
			monify => 1,
			color  => 'yellow',
			values => \@daily_sales,
			labels => \@daily_labels,
			div_id => 'DIV-DAILY-SALES-CHART',
			title  => 'Ventas',
		);

	}

	$d->get_form_validations( method => 'add_inventory_do' );
	$d->get_form_validations( method => 'remove_inventory_do', le => $d->{data}->{product}->{inventory}->{TOTAL} );
	$d->get_form_validations( append => $validations );

	$x->{v}->render($d);

}

sub switch_active_do {

	my ( $x, $d ) = @_;

	my $product = $x->{m}->{inventory}->get_products(
		where => { '_i_items.id' => $d->{p}->{id} },
		limit => 1,
	);

	if ( $product->{is_permanent} ) {
		$d->warning('No es posible modificar o deshabilitar el adeudo general.');
		return $x->{v}->status($d);
	}

	$x->{m}->update(
		update => { active => $d->{p}->{active} },
		where  => {
			id => $d->{p}->{id}
		},
		table => '_i_items',
	);

	my $message = $d->{p}->{active} ? 'Producto reactivado.' : 'Producto desactivado.';
	$d->success($message);
	$d->save_state();

	return $x->{v}->http_redirect(
		c      => 'ventas',
		method => 'ver',
		id     => $d->{p}->{id}
	);

}

sub add_inventory_do {

	my ( $x, $d ) = @_;

	$x->{m}->insert(
		insert => {
			item_id  => $d->{p}->{id},
			count    => int( $d->{p}->{count} ),
			admin_id => $d->{s}->{user_id},
			notes    => $d->{p}->{notes},
		},
		no_id_column => 1,
		table        => '_i_inventory_add',
	);

	$d->success('Inventario actualizado.');
	$d->save_state();

	my ( $controller, $method ) = split( /\//, $ENV{REFERER} );
	$d->{p}->{id} = undef unless $method eq 'ver';

	return $x->{v}->http_redirect(
		c      => 'ventas',
		method => $method,
		id     => $d->{p}->{id},
	);

}

sub remove_inventory_do {

	my ( $x, $d ) = @_;

	$x->{m}->insert(
		insert => {
			item_id  => $d->{p}->{id},
			count    => int( $d->{p}->{count} ),
			admin_id => $d->{s}->{user_id},
			notes    => $d->{p}->{notes},
		},
		no_id_column => 1,
		table        => '_i_inventory_out',
	);

	$d->success('Inventario actualizado.');
	$d->save_state();

	my ( $controller, $method ) = split( /\//, $ENV{REFERER} );
	$d->{p}->{id} = undef unless $method eq 'ver';

	return $x->{v}->http_redirect(
		c      => 'ventas',
		method => $method,
		id     => $d->{p}->{id},
	);

}

sub punto_de_venta {

	my ( $x, $d ) = @_;

	my $statement = $x->{m}->{finance}->get_statement( client_id => $d->{p}->{id} );

	$d->{data}->{balance} = $statement->{balance} if $statement->{balance}->{balance} > 0;
	$d->{data}->{pending} = __PACKAGE__->_get_pending_charges_from_statement( statement => $statement ) if $statement;

	if ( $d->{data}->{pending} ) {
		$d->{data}->{total_pending_amount} = 0;
		foreach my $pending ( @{ $d->{data}->{pending} } ) {
			$d->{data}->{total_pending_amount} += $pending->{remaining_amount};
		}
	}

	$d->{data}->{user} = $x->{m}->{users}->get_users(
		where => {
			'_g_users.id' => $d->{p}->{id},
		},
		limit => 1,
	);

	if ( !$d->{data}->{user}->{active} ) {
		my $ctip = controller::tips->new($d);
		$d->notification(
			$ctip->get(
				tip               => 'DISABLED-USER',
				user_id           => $d->{p}->{id},
				is_client         => $d->{data}->{user}->{is_client},
				no_dismiss_button => 1,
			)
		);
	}

	my %product_options = (
		where => { '_i_items.active' => 1 },
		gt    => { '_i_items.amount' => 0 },
		not   => {
			'_i_items.is_permanent' => 1,
			'_i_items.type_code'    => 'VISITS'
		},
		order_by_sales            => 1,
		only_items_with_inventory => 1,
	);

	if ( $d->{data}->{user}->{is_client} ) {

		$d->{data}->{membership} = $x->{m}->{memberships}->get_client_memberships(
			where => {
				'_f_client_memberships.client_id' => $d->{p}->{id},
			},
			limit => 1,
		);

		if (   !$d->{data}->{membership}->{is_dependant}
			&& !$d->{data}->{membership}->{is_free_membership}
			&& !$d->{data}->{membership}->{is_visits_membership} )
		{
			$d->{data}->{discounts} = $x->{m}->{discounts}->get_discounts(
				where                       => { '_f_discounts.active' => 1 },
				participating_membership_id => $d->{data}->{membership}->{membership_id}
			);
		}

		if ( $d->{data}->{discounts} ) {

			my $last_membership_charge = $x->{m}->{charges}->get_charges(
				client_id               => $d->{p}->{id},
				only_membership_charges => 1,
				limit                   => 1,
				include_debt_details    => 1,
			);

			my $subtract_months = 1 if $last_membership_charge->{debt_details}->{paid_amount} == 0;

			foreach my $dd ( @{ $d->{data}->{discounts} } ) {

				my $next_months = global::date_time->get_next_months(
					year            => $last_membership_charge->{year},
					month           => $last_membership_charge->{month},
					subtract_months => $subtract_months,
					get_next        => $dd->{discount_month_duration},
				);

				next unless $next_months;
				$dd->{next_months} = $next_months;

				my @next_displays = map { $_->{display_month} . ' ' . $_->{year} } @{$next_months};
				$dd->{display_next_months} = join( ', ', @next_displays );

			}

		}

		if ( $d->{data}->{membership}->{is_visits_membership} ) {
			$d->{data}->{visits_package} = $x->{m}->{memberships}->get_visit_memberships(
				client_id => $d->{p}->{id},
				limit     => 1
			);
			if ( $d->{data}->{visits_package}->{active} ) {
				$d->{data}->{client_already_has_visits} = 1;
			}
			else {
				delete $product_options{not}->{'_i_items.type_code'};
			}
		}

	}

	$d->{data}->{products} = $x->{m}->{inventory}->get_products(%product_options);

	if ( $d->{data}->{products} ) {
		my %totals;
		foreach my $prod ( @{ $d->{data}->{products} } ) {
			$totals{ $prod->{type_code} }++;
			$totals{ALL}++;
		}
		$d->{data}->{product_totals} = \%totals;
	}

	my $months = $x->_get_client_possible_months(
		client_id              => $d->{p}->{id},
		mark_membership_months => $d->{data}->{user}->{is_client},
	);

	$d->{data}->{months}                  = $months->{months};
	$d->{data}->{has_charged_memberships} = $months->{has_charged_memberships};

	$x->{v}->render($d);

}

sub process_payments_do {

	my ( $x, $d ) = @_;

	my $items = JSON::XS->new()->latin1()->decode( $d->{p}->{JSON_cart_items} );

	my $payment_amount = 0;
	my @debts;
	my @products;
	my @discounts;
	my @new_charges;
	my @prepayments;
	my @payment_inserts;

	foreach my $ii ( @{$items} ) {
		next if $ii->{type_code} eq 'DEBT' && $ii->{amount} <= 0;
		$payment_amount += $ii->{amount};
		push @debts,       $ii if $ii->{type_code} eq 'DEBT';
		push @products,    $ii if $ii->{type_code} eq 'PRODUCT';
		push @discounts,   $ii if $ii->{type_code} eq 'DISCOUNT';
		push @new_charges, $ii if $ii->{type_code} eq 'NEW';
		push @prepayments, $ii if $ii->{type_code} eq 'PRE';
	}

	my $cff = controller::finanzas->new($d);
	my $cdd = controller::descuentos->new($d);

	my $transaction_id = global::standard->uuid();

	$x->{m}->insert(
		insert => {
			id               => $transaction_id,
			admin_id         => $d->{s}->{user_id},
			client_id        => $d->{p}->{client_id},
			payment_amount   => $payment_amount,
			debit_amount     => $d->{p}->{debit_amount} || 0,
			method_type_code => $d->{p}->{method_type_code},
			notes            => $d->{p}->{notes},
		},
		table => '_f_transactions',
	);

	if ( scalar @new_charges ) {

		foreach my $nch (@new_charges) {

			my ( $year, $month ) = split( /_/, $nch->{ym} );

			$nch->{id} = $cff->add_new_charge(
				$d,
				transaction_id => $transaction_id,
				admin_id       => $d->{s}->{user_id},
				type_code      => $nch->{new_charge_type_code},
				client_id      => $d->{p}->{client_id},
				amount         => $nch->{original_amount},
				concept        => $nch->{concept},
				notes          => $nch->{notes},
				year           => $year,
				month          => $month,
			);

		}

	}

	if ( scalar @prepayments ) {

		foreach my $pre (@prepayments) {

			my $parts = global::date_time->get_date_time_parts();

			$pre->{id} = $cff->add_new_charge(
				$d,
				transaction_id => $transaction_id,
				type_code      => 'P',
				client_id      => $d->{p}->{client_id},
				amount         => 0,
				concept        => 'Prepago',
				notes          => $pre->{notes},
				year           => $parts->{year},
				month          => $parts->{month},
			);

		}

	}

	my %charge_ids;

	if ( scalar @products ) {

		my %product_ids = map { $_->{id} => 1 } @products;

		my $products_tmp = $x->{m}->{inventory}->get_products(
			in => {
				table => '_i_items',
				field => 'id',
				items => [ keys %product_ids ]
			},
			where => { '_i_items.active' => 1 },
		);

		my %products = map { $_->{id} => $_ } @{$products_tmp};

		my @quantity_products;

		foreach my $prod (@products) {

			# the total amount we want to pay for the full quantity of items
			my $total_quantity_payment_amount = $prod->{amount};
			my $product                       = $products{ $prod->{id} };

			for ( my $c = 0 ; $c < $prod->{quantity} ; $c++ ) {

				my $prod_copy = clone($prod);
				$prod_copy->{original_amount}   = $product->{amount};
				$prod_copy->{original_quantity} = $prod->{quantity};
				$prod_copy->{quantity}          = 1;

				if ( $total_quantity_payment_amount >= $prod_copy->{original_amount} ) {
					$prod_copy->{amount} = $prod_copy->{original_amount};
					$total_quantity_payment_amount -= $prod_copy->{amount};
				}
				elsif ( $total_quantity_payment_amount > 0 ) {
					$prod_copy->{amount} = $total_quantity_payment_amount;
					$total_quantity_payment_amount = 0;
				}
				else {
					$prod_copy->{amount} = 0;
					$total_quantity_payment_amount = 0;
				}

				push @quantity_products, $prod_copy;
			}

		}

		@products = @quantity_products;

		foreach my $prod (@products) {

			my $product = $products{ $prod->{id} };

			my $charge_id = $cff->charge_sale_item(
				$d,
				admin_id               => $d->{s}->{user_id},
				transaction_id         => $transaction_id,
				client_id              => $d->{p}->{client_id},
				item_id                => $prod->{id},
				is_visits_package      => ( $product->{type_code} eq 'VISITS' ),
				visit_number           => $product->{visit_number} || 0,
				visits_expiration_date => $prod->{visits_expiration_date},
			);

			$charge_ids{$charge_id} = 1;

			push @payment_inserts,
			  {
				id             => global::standard->uuid(),
				transaction_id => $transaction_id,
				charge_id      => $charge_id,
				client_id      => $d->{p}->{client_id},
				charge_amount  => $product->{amount},
				payment_amount => $prod->{amount},
				debit_amount   => 0,
			  }
			  if $prod->{amount};

		}

	}

	my $membership = $x->{m}->{memberships}->get_client_memberships(
		where => {
			'_f_client_memberships.client_id' => $d->{p}->{client_id},
		},
		limit => 1,
	);

	if ( scalar @discounts ) {

		my %discount_ids = map { $_->{id} => 1 } @discounts;

		my $discounts_tmp = $x->{m}->{discounts}->get_discounts(
			in => {
				table => '_f_discounts',
				field => 'id',
				items => [ keys %discount_ids ]
			},
			where                       => { '_f_discounts.active' => 1 },
			participating_membership_id => $membership->{membership_id}
		);

		my %discounts = map { $_->{id} => $_ } @{$discounts_tmp};

		my $last_membership_charge = $x->{m}->{charges}->get_charges(
			client_id               => $d->{p}->{client_id},
			only_membership_charges => 1,
			limit                   => 1,
			include_debt_details    => 1,
		);

		my $subtract_months = 1 if $last_membership_charge->{debt_details}->{paid_amount} == 0;

		foreach my $dd (@discounts) {

			my $total_payment_amount = $dd->{amount};
			my $discount             = $discounts{ $dd->{id} };

			my $next_months = global::date_time->get_next_months(
				year            => $last_membership_charge->{year},
				month           => $last_membership_charge->{month},
				subtract_months => $subtract_months,
				get_next        => $discount->{discount_month_duration},
			);

			foreach my $ym ( @{$next_months} ) {

				my $new_charge = $cff->charge_client_membership(
					client_id  => $d->{p}->{client_id},
					charge_now => 1,
					month      => $ym->{month},
					year       => $ym->{year},
				);

				# charge zero to each dependent
				if (   $membership->{type_code} eq 'G'
					&& $membership->{is_responsible_for_group_membership}
					&& $membership->{dependents}
					&& scalar @{ $membership->{dependents} } )
				{
					foreach my $dep ( @{ $membership->{dependents} } ) {
						$cff->charge_client_membership(
							client_id  => $dep->{id},
							charge_now => 1,
							month      => $ym->{month},
							year       => $ym->{year},
						);
					}
				}

				$charge_ids{ $new_charge->{id} } = 1;

				my $post_discount_amount = ( $membership->{amount} - $discount->{amount} );

				$cdd->discount_charge(
					charge_id            => $new_charge->{id},
					discount_id          => $dd->{id},
					discount_name        => $discount->{name},
					discount_amount      => $discount->{amount},
					original_amount      => $membership->{amount},
					post_discount_amount => $post_discount_amount,
					admin_id             => $d->{s}->{user_id},
				);

				my $item_payment_amount = 0;

				if ( $total_payment_amount >= $post_discount_amount ) {
					$item_payment_amount = $post_discount_amount;
					$total_payment_amount -= $post_discount_amount;
				}
				else {
					$item_payment_amount  = $total_payment_amount;
					$total_payment_amount = 0;
				}

				next unless $item_payment_amount;

				push @payment_inserts,
				  {
					id             => global::standard->uuid(),
					transaction_id => $transaction_id,
					charge_id      => $new_charge->{id},
					client_id      => $d->{p}->{client_id},
					charge_amount  => $membership->{amount},
					payment_amount => $item_payment_amount,
					debit_amount   => 0,
				  }
				  if $item_payment_amount;

			}

		}

	}

	my $statement = $x->{m}->{finance}->get_statement( client_id => $d->{p}->{client_id} );
	my $available_balance = $statement->{balance}->{balance} =~ /\d+/ ? $statement->{balance}->{balance} : 0;

	if ( $d->{p}->{debit_amount} && $d->{p}->{debit_amount} > 0 ) {

		if ( $d->{p}->{debit_amount} > $available_balance ) {
			$d->warning('Se ha detectado un error. El saldo a favor con el que se intento pagar ya no esta disponible.');
			return $x->{v}->status($d);
		}

		$payment_amount -= $d->{p}->{debit_amount};

	}

	if ( scalar @debts || scalar @new_charges || scalar @prepayments ) {

		my $pending_charges_tmp = $x->_get_pending_charges_from_statement( statement => $statement );
		my %pending = map { $_->{id} => $_ } @{$pending_charges_tmp};

		foreach my $db ( @debts, @new_charges, @prepayments ) {

			my $charge_amount = $pending{ $db->{id} }->{amount};
			$charge_amount = $db->{amount} if $db->{type_code} eq 'PRE';

			$charge_ids{ $db->{id} } = 1;

			push @payment_inserts,
			  {
				id             => global::standard->uuid(),
				transaction_id => $transaction_id,
				charge_id      => $db->{id},
				client_id      => $d->{p}->{client_id},
				charge_amount  => $charge_amount,
				payment_amount => $db->{amount},
				debit_amount   => 0,
			  }
			  if $db->{amount};

		}

	}

	if ( $d->{p}->{debit_amount} && $d->{p}->{debit_amount} > 0 ) {

		# we want to first pay in full all charges that we can, staring with the most expensive
		# thing. after that we want to pay the cheapest available thing
		# for example say we have 20 debit, and the following amount : 5, 20, 25, 18, 200
		# the resulting order we want is :
		# 20, 18, 5, 25, 200
		#     DEBIT^LIMIT

		my @less_than_debit = grep { $_->{payment_amount} <= 20 } @payment_inserts;
		my @less_than_debit_sorted = rnkeysort { $_->{payment_amount} } @less_than_debit;

		my @more_than_debit = grep { $_->{payment_amount} > 20 } @payment_inserts;
		my @more_than_debit_sorted = nkeysort { $_->{payment_amount} } @more_than_debit;

		my @sorted = ( @less_than_debit_sorted, @more_than_debit_sorted );

		foreach my $pay (@sorted) {

			if ( $d->{p}->{debit_amount} >= $pay->{payment_amount} ) {
				$pay->{debit_amount} = $pay->{payment_amount};
				$d->{p}->{debit_amount} -= $pay->{payment_amount};
				$pay->{payment_amount} = 0;
			}
			elsif ( $d->{p}->{debit_amount} > 0 ) {
				$pay->{debit_amount} = $d->{p}->{debit_amount};
				$pay->{payment_amount} -= $pay->{debit_amount};
				$d->{p}->{debit_amount} = 0;
			}
			else {
				$pay->{debit_amount} = 0;
				$d->{p}->{debit_amount} = 0;
			}

		}

		@payment_inserts = @sorted;

	}

	if ( scalar keys %charge_ids ) {

		my @transaction_charge_inserts;

		foreach my $charge_id ( keys %charge_ids ) {
			push @transaction_charge_inserts,
			  {
				transaction_id => $transaction_id,
				charge_id      => $charge_id,
			  };
		}

		$x->{m}->bulk_insert(
			items => \@payment_inserts,
			table => '_f_payments'
		) if scalar @payment_inserts;

	}

	$d->success('Se han registrado los pagos del cliente.');

	$d->{p} = { id => $d->{p}->{client_id} };
	$d->save_state();

	return $x->{v}->http_redirect(
		c      => 'ventas',
		method => 'punto-de-venta',
		id     => $d->{p}->{id},
	);

}

sub historial {

	my ( $x, $d ) = @_;

	if ( !$d->{p}->{start_date} && !$d->{p}->{end_date} && !$d->{p}->{fecha} ) {
		$d->{p}->{start_date} = global::date_time->get_past_date(21);
		$d->{p}->{end_date}   = global::date_time->get_date();
	}

	if ( ( $d->{p}->{start_date} && $d->{p}->{end_date} )
		&& $d->{p}->{start_date} eq $d->{p}->{end_date} )
	{
		$d->{p}->{fecha}      = $d->{p}->{start_date};
		$d->{p}->{start_date} = undef;
		$d->{p}->{end_date}   = undef;
	}

	$d->{p}->{fecha} //= global::date_time->get_date();

	$d->{data}->{history} = $x->{m}->{inventory}->get_history(
		item_id    => $d->{p}->{id},
		date       => $d->{p}->{fecha},
		start_date => $d->{p}->{start_date},
		end_date   => $d->{p}->{end_date},
	);

	if ( $d->{data}->{history} ) {

		foreach my $hh ( @{ $d->{data}->{history} } ) {
			if ( $hh->{type_code} eq 'IN' && $hh->{is_return} ) {
				$d->{data}->{totals}->{returns} += $hh->{count};
			}
			elsif ( $hh->{type_code} eq 'IN' ) {
				$d->{data}->{totals}->{in} += $hh->{count};
			}
			elsif ( $hh->{type_code} eq 'OUT' ) {
				$d->{data}->{totals}->{out} += $hh->{count};
			}
			elsif ( $hh->{type_code} eq 'SALE' ) {
				$d->{data}->{totals}->{sales_amount}    += $hh->{paid_amount};
				$d->{data}->{totals}->{discount_amount} += $hh->{discount_amount};
				$d->{data}->{totals}->{sales_count}     += $hh->{count} unless $hh->{is_cancelled};
			}
		}

		my $sales = $x->{m}->{inventory}->get_timeframe_sales(
			item_id    => $d->{p}->{id},
			date       => $d->{p}->{fecha},
			start_date => $d->{p}->{start_date},
			end_date   => $d->{p}->{end_date},
		);

		if ( $sales && scalar @{ $sales->{dates} } ) {

			my @daily_labels;
			my @daily_sales;

			foreach my $dd ( @{ $sales->{dates} } ) {
				push @daily_labels, $dd->{date};
				push @daily_sales, $dd->{total} || 0;
			}

			$d->{data}->{charts}->{daily_sales} = global::charts->lines(
				monify => 1,
				color  => 'yellow',
				values => \@daily_sales,
				labels => \@daily_labels,
				div_id => 'DIV-DAILY-SALES-CHART',
				title  => 'Ventas',
			);

		}

	}
	else {
		$d->info('No se han encontrado movimientos utilizando la b&uacute;squeda especificada.');
	}

	$x->{v}->render($d);

}

1;
