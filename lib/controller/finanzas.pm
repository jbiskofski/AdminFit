package controller::finanzas;

use strict;
use base 'controller::finanzas::charges';
use base 'controller::finanzas::payments';

use Sort::Key qw/nkeysort rnkeysort keysort/;
use Sort::Key::Multi qw/rnrnrnskeysort nskeysort/;

sub new {

	my ( $n, $d ) = @_;

	my $x = {
		v => view::render->new( $d->{r} ),
		m => model::init->new( $d->{dbh} ),
	};

	bless $x;
	return $x;

}

sub estado_de_cuenta {

	my ( $x, $d ) = @_;

	$d->{data}->{statement} = $x->{m}->{finance}->get_statement(
		aggregate => 1,
		client_id => $d->{p}->{id},
		year      => $d->{p}->{year},
		month     => $d->{p}->{month},
		date      => $d->{p}->{fecha},
	);

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

	$d->{data}->{membership} = $x->{m}->{memberships}->get_client_memberships(
		where => {
			'_f_client_memberships.client_id' => $d->{p}->{id},
		},
		limit => 1,
	) if $d->{data}->{user}->{is_client};

	$d->{data}->{display_month} = global::date_time->get_display_month( $d->{p}->{month} )
	  if $d->{p}->{month};

	$x->{v}->render($d);

}

sub folio {

	my ( $x, $d ) = @_;

	$d->{data}->{transaction} = $x->{m}->{transactions}->get_transactions(
		where => { '_f_transactions.id' => $d->{p}->{id} },
		limit => 1,
	);

	my $payments = $x->{m}->{payments}->get_payments(
		where           => { '_f_payments.transaction_id' => $d->{p}->{id} },
		include_charges => 1,
	);

	my $charges_tmp1 = $x->{m}->{charges}->get_charges( transaction_id => $d->{p}->{id} );

	if ($charges_tmp1) {

		my %charges_tmp2 = map { $_->{id} => $_ } @{$charges_tmp1};

		foreach my $pay ( @{$payments} ) {
			delete $charges_tmp2{ $pay->{charge_id} };
		}

		my @charges = rnkeysort { $_->{amount} } values %charges_tmp2;
		$d->{data}->{remaining_charges} = \@charges;

	}

	my @sorted = rnrnrnskeysort { $_->{charge}->{remaining_amount}, $_->{debit_amount}, $_->{payment_amount}, $_->{charge}->{concept}->{concept} } @{$payments};
	$d->{data}->{payments} = \@sorted;

	$d->{data}->{client} = $x->{m}->{users}->get_users(
		where => {
			'_g_users.id' => $sorted[0]->{client_id},
		},
		limit => 1,
	);

	if ( !$d->{data}->{client}->{active} ) {
		my $ctip = controller::tips->new($d);
		$d->notification(
			$ctip->get(
				tip               => 'DISABLED-USER',
				user_id           => $d->{p}->{id},
				is_client         => $d->{data}->{client}->{is_client},
				no_dismiss_button => 1,
			)
		);
	}

	$x->{v}->render($d);

}

sub cobro {

	my ( $x, $d ) = @_;

	$d->{data}->{charge} = $x->{m}->{finance}->get_statement( charge_id => $d->{p}->{id} );

	$d->success('El cobro no presenta adeudos.')
	  if $d->{data}->{charge}->{remaining_amount} <= 0 && !$d->{data}->{charge}->{is_cancelled};

	$d->{data}->{history} = $x->_generate_charge_history( $d->{data}->{charge} );

	$d->{data}->{client} = $x->{m}->{users}->get_users(
		where => {
			'_g_users.id' => $d->{data}->{charge}->{client_id},
		},
		limit => 1,
	);

	if ( !$d->{data}->{client}->{active} ) {
		my $ctip = controller::tips->new($d);
		$d->notification(
			$ctip->get(
				tip               => 'DISABLED-USER',
				user_id           => $d->{p}->{id},
				is_client         => $d->{data}->{client}->{is_client},
				no_dismiss_button => 1,
			)
		);
	}

	my $general_discounts = $x->{m}->{discounts}->get_discounts(
		where => {
			'_f_discounts.active'    => 1,
			'_f_discounts.type_code' => 'G',
		}
	);

	my @discounts = @{$general_discounts};

	if ( $d->{data}->{charge}->{type_code} eq 'M' ) {
		my $membership_discounts = $x->{m}->{discounts}->get_discounts(
			where => {
				'_f_discounts.active' => 1
			},
			participating_membership_id => $d->{data}->{charge}->{membership_id}
		);
		push @discounts, @{$membership_discounts} if $membership_discounts;
	}

	$d->{data}->{discounts} = \@discounts;
	$d->get_form_validations( le => $d->{data}->{charge}->{remaining_amount} );

	$x->{v}->render($d);

}

sub add_discount_do {

	my ( $x, $d ) = @_;

	my $charge = $x->{m}->{finance}->get_statement( charge_id => $d->{p}->{id} );

	if ( $charge->{type_code} eq 'P' ) {
		$d->warning('No es posible agregar un descuento a un prepago.');
		return $x->{v}->status($d);
	}

	my $discount = $x->{m}->{discounts}->get_discounts(
		where => {
			'_f_discounts.id'     => $d->{p}->{discount_id},
			'_f_discounts.active' => 1
		},
		limit => 1,
	);

	my $charge = $x->{m}->{finance}->get_statement( charge_id => $d->{p}->{id} );
	my $post_discount_amount = ( $charge->{remaining_amount} - $d->{p}->{amount} );

	my $cdd = controller::descuentos->new($d);
	$cdd->discount_charge(
		charge_id            => $d->{p}->{id},
		discount_id          => $d->{p}->{discount_id},
		discount_name        => $discount->{name},
		discount_amount      => $d->{p}->{amount},
		original_amount      => $charge->{remaining_amount},
		post_discount_amount => $post_discount_amount,
		admin_id             => $d->{s}->{user_id},
		notes                => $d->{p}->{notes},
	);

	$d->success('Descuento agregado.');

	$d->{p} = { id => $d->{p}->{id} };
	$d->save_state();

	return $x->{v}->http_redirect(
		c      => 'finanzas',
		method => 'cobro',
		id     => $d->{p}->{id},
	);

}

sub delete_payment_do {

	my ( $x, $d ) = @_;

	my $payment = $x->{m}->{payments}->get_payments(
		where           => { '_f_payments.id' => $d->{p}->{id} },
		include_charges => 1,
		limit           => 1
	);

	if ( $payment->{charge}->{type_code} eq 'P' ) {
		$d->warning('No es posible cancelar un prepago.');
		return $x->{v}->status($d);
	}

	$x->cancel_payment(
		payment_id => $d->{p}->{id},
		admin_id   => $d->{s}->{user_id},
		notes      => $d->{p}->{notes},
	);

	$d->{p} = undef;
	$d->success('Pago eliminado.');
	$d->save_state();

	return $x->{v}->http_redirect(
		c      => 'finanzas',
		method => 'cobro',
		id     => $payment->{charge_id},
	);

}

sub delete_discount_do {

	my ( $x, $d ) = @_;

	my $discount = $x->{m}->{discounts}->get_charge_discounts( where => { '_f_charge_discounts.id' => $d->{p}->{id} }, limit => 1 );

	my $cdd = controller::descuentos->new($d);

	$cdd->cancel_discount(
		discount_id => $d->{p}->{id},
		admin_id    => $d->{s}->{user_id},
		notes       => $d->{p}->{notes},
	);

	$d->{p} = undef;
	$d->success('Descuento eliminado.');
	$d->save_state();

	return $x->{v}->http_redirect(
		c      => 'finanzas',
		method => 'cobro',
		id     => $discount->{charge_id},
	);

}

sub resumen {

	my ( $x, $d ) = @_;

	if ( ( $d->{p}->{start_date} && $d->{p}->{end_date} )
		&& $d->{p}->{start_date} eq $d->{p}->{end_date} )
	{
		$d->{p}->{fecha}      = $d->{p}->{start_date};
		$d->{p}->{start_date} = undef;
		$d->{p}->{end_date}   = undef;
	}

	$d->{p}->{fecha} = global::date_time->get_date()
	  unless $d->{p}->{fecha} || $d->{p}->{start_date} || $d->{p}->{end_date};

	$d->{data}->{transactions} = $x->{m}->{transactions}->get_transactions(
		client_id     => $d->{p}->{client_id},
		date          => $d->{p}->{fecha},
		start_date    => $d->{p}->{start_date},
		end_date      => $d->{p}->{end_date},
		not_cancelled => 1,
	);

	$d->{data}->{multi_day_search} = $d->{p}->{start_date} && $d->{p}->{end_date} ? 1 : 0;

	if ( $d->{data}->{transactions} ) {

		my $paid     = 0;
		my $concepts = 0;

		my %concepts_tmp;
		my %methods_tmp;
		my %dt_tmp;

		foreach my $tt ( @{ $d->{data}->{transactions} } ) {

			foreach my $ch ( @{ $tt->{charges} } ) {
				$concepts_tmp{ $ch->{concept}->{concept} } += $ch->{paid_amount} + $ch->{debit_amount};
			}

			$paid                                   += $tt->{payment_amount};
			$concepts                               += $tt->{payment_count};
			$methods_tmp{ $tt->{method_type_code} } += $tt->{payment_amount};

			my @vv = split( /\D+/, $tt->{date_time} );
			my $key = $d->{data}->{multi_day_search} ? $vv[2] . '/' . $vv[1] . '/' . $vv[0] : $vv[3];
			$dt_tmp{$key} += $tt->{payment_amount};

		}

		if ( scalar keys %concepts_tmp ) {

			my @concepts;

			foreach my $cc ( keys %concepts_tmp ) {
				push @concepts, { $cc => $concepts_tmp{$cc} };
			}

			$d->{data}->{charts}->{concepts} = global::charts->pie(
				monify => 1,
				title  => 'Conceptos',
				color  => 'blue',
				values => \@concepts,
				div_id => 'DIV-CONCEPT-DISTRIBUTION-CHART',
				others => 7,
			);

		}

		if ( scalar keys %methods_tmp ) {

			my @methods;

			foreach my $mm ( keys %methods_tmp ) {

				# this doesnt/SHOULDNT do any sql queries, it just transforms txt
				my $display_method = $x->{m}->{payments}->_get_display_method(
					method_type_code => $mm,
					payment_amount   => 1,
				);

				push @methods, { $display_method => $methods_tmp{$mm} };

			}

			$d->{data}->{charts}->{methods} = global::charts->pie(
				monify => 1,
				title  => 'Metodos',
				color  => 'green',
				values => \@methods,
				div_id => 'DIV-METHOD-DISTRIBUTION-CHART',
				others => 7,
			);

		}

		if ( scalar keys %dt_tmp ) {

			my @labels;
			my @values;

			foreach my $dt ( sort keys %dt_tmp ) {
				if ( $d->{data}->{multi_day_search} ) {
					my ( $year, $month, $day ) = split( /\D+/, $dt );
					push @labels, "$month/$day";
				}
				else {
					push @labels, $dt . ':00';
				}
				push @values, $dt_tmp{$dt};
			}

			$d->{data}->{charts}->{dts} = global::charts->bars(
				monify => 1,
				values => \@values,
				labels => \@labels,
				color  => 'red-light',
				div_id => 'DIV-DT-DISTRIBUTION-CHART',
				title  => 'Ingresos',
			);

		}

		$d->{data}->{totals}->{transactions} = {
			paid     => $paid     || 0,
			concepts => $concepts || 0,
		};

	}

	$d->{data}->{charges} = $x->{m}->{charges}->get_charges(
		client_id     => $d->{p}->{client_id},
		date          => $d->{p}->{fecha},
		start_date    => $d->{p}->{start_date},
		end_date      => $d->{p}->{end_date},
		not_cancelled => 1,
	);

	if ( $d->{data}->{charges} ) {

		my $charged          = 0;
		my $discounted       = 0;
		my $paid             = 0;
		my $debit            = 0;
		my $remaining_amount = 0;

		my %inventory_items_tmp;
		my %item_categories_tmp;

		foreach my $ch ( @{ $d->{data}->{charges} } ) {
			$charged          += $ch->{amount};
			$discounted       += $ch->{discount_amount};
			$paid             += $ch->{paid_amount};
			$debit            += $ch->{debit_amount};
			$remaining_amount += $ch->{remaining_amount};

			if ( $ch->{type_code} eq 'I' ) {

				if ( !$inventory_items_tmp{ $ch->{item_id} } ) {
					$inventory_items_tmp{ $ch->{item_id} } = {
						id       => $ch->{item_id},
						name     => $ch->{item_name},
						category => $ch->{display_item_category},
						sales    => 0,
						amount   => 0,
					};
				}

				if ( !$item_categories_tmp{ $ch->{item_type_code} } ) {
					$item_categories_tmp{ $ch->{item_type_code} } = {
						name   => $ch->{display_item_category},
						sales  => 0,
						amount => 0,
					};
				}

				$inventory_items_tmp{ $ch->{item_id} }->{sales}++;
				$inventory_items_tmp{ $ch->{item_id} }->{amount} += $ch->{paid_amount};

				$item_categories_tmp{ $ch->{item_type_code} }->{sales}++;
				$item_categories_tmp{ $ch->{item_type_code} }->{amount} += $ch->{paid_amount};

			}

		}

		if ( scalar keys %inventory_items_tmp ) {
			my @inventory_items = keysort { $_->{name} } values %inventory_items_tmp;
			$d->{data}->{inventory_items} = \@inventory_items;
			my @item_categories = keysort { $_->{name} } values %item_categories_tmp;
			$d->{data}->{item_categories} = \@item_categories;
		}

		$d->{data}->{totals}->{charges} = {
			charged          => $charged          || 0,
			discounted       => $discounted       || 0,
			paid             => $paid             || 0,
			debit            => $debit            || 0,
			remaining_amount => $remaining_amount || 0,
		};

	}

	$d->{data}->{discounts} = $x->{m}->{discounts}->get_charge_discounts(
		client_id     => $d->{p}->{client_id},
		date          => $d->{p}->{fecha},
		start_date    => $d->{p}->{start_date},
		end_date      => $d->{p}->{end_date},
		not_cancelled => 1,
	);

	if ( $d->{data}->{discounts} ) {

		my $discounted = 0;

		foreach my $dd ( @{ $d->{data}->{discounts} } ) {
			$discounted += $dd->{discount_amount};
		}

		$d->{data}->{totals}->{discounts} = { discounted => $discounted || 0, };

	}

	my $cancelled_charges = $x->{m}->{charges}->get_charges(
		date       => $d->{p}->{fecha},
		start_date => $d->{p}->{start_date},
		end_date   => $d->{p}->{end_date},
		cancelled  => 1,
	);

	my $cancelled_payments = $x->{m}->{payments}->get_payments(
		date       => $d->{p}->{fecha},
		start_date => $d->{p}->{start_date},
		end_date   => $d->{p}->{end_date},
		cancelled  => 1,
	);

	my $cancelled_discounts = $x->{m}->{discounts}->get_charge_discounts(
		date       => $d->{p}->{fecha},
		start_date => $d->{p}->{start_date},
		end_date   => $d->{p}->{end_date},
		cancelled  => 1,
	);

	my @cancelled = rnkeysort { $_->{cancelled_epoch} } @{$cancelled_charges}, @{$cancelled_payments}, @{$cancelled_discounts};

	$d->{data}->{cancelled} = \@cancelled;

	if ( $d->{p}->{client_id} ) {

		$d->{data}->{user} = $x->{m}->{users}->get_users(
			where => {
				'_g_users.id' => $d->{p}->{client_id},
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

	}

	my $ctip = controller::tips->new($d);

	$ctip->accept_notification(
		tip_id  => 'RENOVACIONES-DEL-DIA',
		user_id => $d->{s}->{user_id}
	) if $d->{p}->{'ok-notificacion'};

	$x->{v}->render($d);

}

sub delete_charge_do {

	my ( $x, $d ) = @_;

	my $charge = $x->{m}->{finance}->get_statement( charge_id => $d->{p}->{id} );

	if ( $charge->{type_code} eq 'P' ) {
		$d->warning('No es posible cancelar un prepago.');
		return $x->{v}->status($d);
	}

	if ( $charge->{discounts} && scalar @{ $charge->{discounts} } ) {

		my $cdd = controller::descuentos->new($d);

		foreach my $disc ( @{ $charge->{discounts} } ) {
			$cdd->cancel_discount(
				discount_id => $disc->{id},
				admin_id    => $d->{s}->{user_id},
				notes       => 'COBRO CANCELADO. ' . $d->{p}->{notes},
			);
		}

	}

	if ( $charge->{payments} && scalar @{ $charge->{payments} } ) {
		foreach my $pay ( @{ $charge->{payments} } ) {
			$x->cancel_payment(
				payment_id => $pay->{id},
				admin_id   => $d->{s}->{user_id},
				notes      => $d->{p}->{notes},
			);
		}
	}

	$x->cancel_charge(
		charge_id           => $d->{p}->{id},
		admin_id            => $d->{s}->{user_id},
		notes               => $d->{p}->{notes},
		return_to_inventory => $d->{p}->{return_to_inventory},
	);

	$d->{p} = { id => $d->{p}->{id} };
	$d->success('Cobro eliminado.');
	$d->save_state();

	return $x->{v}->http_redirect(
		c      => 'finanzas',
		method => 'cobro',
		id     => $d->{p}->{id},
	);

}

sub mes {

	my ( $x, $d ) = @_;

	$d->{data}->{calendar} = $x->{m}->{finance}->get_calendar(
		month => $d->{p}->{month},
		year  => $d->{p}->{year},
	);

	$d->{data}->{prev_next} = global::date_time->get_prev_next(
		month => $d->{p}->{month},
		year  => $d->{p}->{year}
	);

	my $parts = global::date_time->get_date_time_parts();

	my $is_previous_month_report = 0;
	my $report_year_month        = $parts->{year} . $parts->{month};

	if ( $d->{p}->{month} && $d->{p}->{year} ) {

		my $current_year_month   = $parts->{year} . $parts->{month};
		my $requested_year_month = $d->{p}->{year} . $d->{p}->{month};

		if ( $requested_year_month < $current_year_month ) {
			$is_previous_month_report = 1;
			$report_year_month        = $d->{p}->{year} . $d->{p}->{month};
		}

	}

	my $pending_renewal_clients_unsorted = $x->{m}->{clients}->get_clients(
		in => {
			table  => '_g_users',
			field  => 'id',
			negate => 1,
			items  => [ @{ $d->{data}->{calendar}->{enrollment_client_ids} }, @{ $d->{data}->{calendar}->{remembership_client_ids} } ]
		},
		where => {
			'_g_users.is_client' => 1,
			'_g_users.active' => 1,
		},
		lt => {
			'_g_users.create_date_time' => '01/' . $d->{data}->{prev_next}->{next}->{month} . '/' . $d->{data}->{prev_next}->{next}->{year}
		},
		include_membership                 => 1,
		include_debt_details               => 1,
		only_membership_debt_details       => 1,
		specific_month_debt_details        => $report_year_month,
		positive_amount_memberships_only   => 1,
	);

	if ($pending_renewal_clients_unsorted) {

		# only include users who actually owe a postive amount OR who have yet to be charged for this months membership
		my @include_clients;

		foreach my $cc ( @{$pending_renewal_clients_unsorted} ) {

			# client has a zero amount membership ( visits, free, etc )
			# next unless $cc->{membership}->{amount} > 0;

			my $year_month = $cc->{debt}->{membership}->{year} . $cc->{debt}->{membership}->{month};

			# we only care about this months membership debts
			if ($is_previous_month_report) {
				my $report_year_month = $d->{p}->{year} . $d->{p}->{month};
				next unless $year_month == $report_year_month;
				next unless $cc->{debt}->{total} > 0;
				push @include_clients, $cc;
				next;
			}
			else {
				my $next_year_month   = $cc->{debt}->{membership}->{next_year} . $cc->{debt}->{membership}->{next_month};
				my $report_year_month = $parts->{year} . $parts->{month};

				next unless $year_month == $report_year_month || $next_year_month == $report_year_month;
				next unless $cc->{membership}->{amount} > 0;

				if ( $next_year_month == $report_year_month ) {

					# this fool still owes last months shit
					next if $cc->{debt}->{total} > 0;

					# this client will owe us this month before it ends
					push @include_clients, $cc;
					next;
				}

				if ( $cc->{debt}->{total} > 0 ) {
					push @include_clients, $cc;
					next;
				}

			}

		}

		foreach my $cc (@include_clients) {
			$d->{data}->{pending_membership_amount} += $cc->{membership}->{amount};
		}

		my @pending_renewal_clients_sorted = nskeysort { $_->{membership}->{renewal_day}, $_->{display_name} } @include_clients;
		$d->{data}->{pending_renewal_clients} = \@pending_renewal_clients_sorted;

	}

	my @labels;
	my @payment_values;
	my @attendance_values;
	my @enrollment_values;
	my @dropout_values;
	my @remembership_values;

	foreach my $ww ( @{ $d->{data}->{calendar}->{weeks} } ) {
		foreach my $dd ( @{$ww} ) {
			next unless $dd->{day};
			push @labels,              $dd->{day};
			push @payment_values,      $dd->{data}->{payments} || 0;
			push @attendance_values,   $dd->{data}->{attendance} || 0;
			push @enrollment_values,   $dd->{data}->{enrollments} || 0;
			push @dropout_values,      $dd->{data}->{dropouts} || 0;
			push @remembership_values, $dd->{data}->{rememberships} || 0;
		}
	}

	$d->{data}->{charts}->{payments} = global::charts->lines(
		monify => 1,
		color  => 'green',
		values => \@payment_values,
		labels => \@labels,
		div_id => 'DIV-DAILY-PAYMENTS-CHART',
		title  => 'Ingresos',
	);

	$d->{data}->{charts}->{enrollments} = global::charts->lines(
		multi  => [ 'Inscripciones',     'Renovaciones',        'Bajas' ],
		colors => [ 'blue',              'gray',                'red' ],
		values => [ \@enrollment_values, \@remembership_values, \@dropout_values ],
		labels => \@labels,
		div_id => 'DIV-DAILY-ENROLLMENTS-CHART',
	);

	$d->{data}->{charts}->{attendance} = global::charts->lines(
		multi  => ['Asistencia'],
		colors => ['red'],
		values => [ \@attendance_values ],
		labels => \@labels,
		div_id => 'DIV-DAILY-ATTENDANCE-CHART',
	);

	my $transactions = $x->{m}->{transactions}->get_transactions(
		client_id => $d->{p}->{client_id},
		month     => $d->{data}->{calendar}->{month},
		year      => $d->{data}->{calendar}->{year},
	);

	if ($transactions) {

		my %concepts_tmp;
		my %methods_tmp;

		foreach my $tt ( @{$transactions} ) {

			foreach my $ch ( @{ $tt->{charges} } ) {
				$concepts_tmp{ $ch->{concept}->{concept} } += $ch->{paid_amount} + $ch->{debit_amount};
			}

			$methods_tmp{ $tt->{method_type_code} } += $tt->{payment_amount};

		}

		if ( scalar keys %concepts_tmp ) {

			my @concepts;

			foreach my $cc ( keys %concepts_tmp ) {
				push @concepts, { $cc => $concepts_tmp{$cc} };
			}

			$d->{data}->{charts}->{concepts} = global::charts->pie(
				monify => 1,
				title  => 'Conceptos',
				color  => 'blue',
				values => \@concepts,
				div_id => 'DIV-CONCEPTS-CHART',
				others => 7,
			);

		}

		if ( scalar keys %methods_tmp ) {

			my @methods;

			foreach my $mm ( keys %methods_tmp ) {

				# this doesnt/SHOULDNT do any sql queries, it just transforms txt
				my $display_method = $x->{m}->{payments}->_get_display_method(
					method_type_code => $mm,
					payment_amount   => 1,
				);

				push @methods, { $display_method => $methods_tmp{$mm} };

			}

			$d->{data}->{charts}->{methods} = global::charts->pie(
				monify => 1,
				title  => 'Metodos',
				color  => 'green',
				values => \@methods,
				div_id => 'DIV-METHODS-CHART',
			);

		}

	}

	$x->{v}->render($d);

}

1;
