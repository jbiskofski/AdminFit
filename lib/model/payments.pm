package model::payments;

use strict;
use base 'model::base';

sub new {

	my ( $n, $dbh ) = @_;

	my $x = {
		dbh => $dbh,
		m   => model::init->new($dbh)
	};

	bless $x;
	return $x;

}

sub get_payments {

	my ( $x, %pp ) = @_;

	return unless scalar keys %pp;

	my $q = $x->get_quote();

	my $sql_where = $x->generate_sql_where(%pp) if scalar keys %pp;
	my $sql_limit = " LIMIT $pp{limit} "        if $pp{limit};

	my $sql_transaction_id_where = " AND _f_payments.transaction_id = $q->{$pp{transaction_id}} "
	  if $pp{transaction_id};

	my $sql_cancelled_date_where;
	my $sql_cancelled_between_dates;
	my $LJ_cancelled = ' LEFT ';

	if ( $pp{cancelled} ) {

		$sql_cancelled_date_where = " AND _f_payments_cancelled.date_time::DATE = $q->{$pp{date}} "
		  if $pp{date};

		$sql_cancelled_between_dates .= qq {
  		  AND (
  			  _f_payments_cancelled.date_time >= $q->{ $pp{start_date} }
  			  AND _f_payments_cancelled.date_time < $q->{ $pp{end_date} }::DATE + INTERVAL '1 DAY'
  		  )
  	  	} if $pp{start_date} && $pp{end_date};

		$LJ_cancelled = undef;

	}

	my $sql = qq {
	SELECT 	_f_payments.id,_f_payments.transaction_id,_f_payments.charge_id,
		_f_payments.client_id,_f_payments.charge_amount,_f_payments.payment_amount,
		_f_payments.debit_amount,_f_transactions.date_time,_f_transactions.admin_id,
		_f_transactions.client_id,_f_transactions.method_type_code,ADMINS.name,
		ADMINS.lastname1,ADMINS.lastname2,
		CLIENTS.name,CLIENTS.lastname1,CLIENTS.lastname2,
		_f_payments_cancelled.payment_amount,_f_payments_cancelled.debit_amount,
		_f_payments_cancelled.admin_id,
		_f_payments_cancelled.date_time,_f_payments_cancelled.notes,
		CANCELLED_ADMIN.name,CANCELLED_ADMIN.lastname1,CANCELLED_ADMIN.lastname2,
		_f_transactions.notes
	FROM 	_f_payments
	JOIN 	_f_transactions ON ( _f_transactions.id = _f_payments.transaction_id )
	JOIN 	_g_users ADMINS ON ( ADMINS.id = _f_transactions.admin_id )
	JOIN 	_g_users CLIENTS ON ( CLIENTS.id = _f_transactions.client_id )
	$LJ_cancelled JOIN _f_payments_cancelled ON ( _f_payments_cancelled.payment_id = _f_payments.id )
	$LJ_cancelled JOIN _g_users CANCELLED_ADMIN ON ( CANCELLED_ADMIN.id = _f_payments_cancelled.admin_id )
	WHERE 	 TRUE
	$sql_where
	$sql_transaction_id_where
	$sql_cancelled_date_where
	$sql_cancelled_between_dates
	$sql_limit
	};

	my @items;

	my @keys = qw/id transaction_id charge_id client_id
	  charge_amount payment_amount debit_amount date_time admin_id client_id
	  method_type_code _admin_name _admin_lastname1 _admin_lastname2
	  _client_name _client_lastname1 _client_lastname2
	  cancelled_payment_amount cancelled_debit_amount cancelled_admin_id
	  cancelled_date_time cancelled_notes _cancelled_name
	  _cancelled_lastname1 _cancelled_lastname2 transaction_notes/;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;

		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}

		$ii{admin_display_name}  = global::standard->get_person_display_name( $ii{_admin_name},  $ii{_admin_lastname1},  $ii{_admin_lastname2} );
		$ii{client_display_name} = global::standard->get_person_display_name( $ii{_client_name}, $ii{_client_lastname1}, $ii{_client_lastname2} );
		$ii{date_time}           = global::date_time->format_date_time( $ii{date_time} );
		$ii{epoch}               = global::date_time->get_epoch( $ii{date_time} );

		if ( $ii{cancelled_admin_id} ) {
			$ii{cancelled_display_name}    = global::standard->get_person_display_name( $ii{_cancelled_name}, $ii{_cancelled_lastname1}, $ii{_cancelled_lastname2} );
			$ii{cancelled_date_time}       = global::date_time->format_date_time( $ii{cancelled_date_time} );
			$ii{is_cancelled}              = 1;
			$ii{display_cancelled_details} = '<i class="fe fe-user"></i> ' . $ii{cancelled_display_name};
			$ii{display_cancelled_details} .= '<br>' . $ii{cancelled_notes} if $ii{cancelled_notes};
			$ii{cancelled_epoch} = global::date_time->get_epoch( $ii{cancelled_date_time} );
		}

		foreach my $key ( keys %ii ) {
			delete $ii{$key} if substr( $key, 0, 1 ) eq '_';
		}

		$ii{display_method} = $x->_get_display_method(
			method_type_code         => $ii{method_type_code},
			payment_amount           => $ii{payment_amount},
			cancelled_payment_amount => $ii{cancelled_payment_amount},
			debit_amount             => $ii{debit_amount},
			cancelled_debit_amount   => $ii{cancelled_debit_amount},
		);

		push @items, \%ii;

	}

	$sth->finish();

	return undef unless scalar @items;

	if ( $pp{include_charges} ) {

		my %charge_ids = map { $_->{charge_id} => 1 } @items;
		my $charges_tmp = $x->{m}->{charges}->get_charges( charge_ids => [ keys %charge_ids ] );

		if ($charges_tmp) {
			my %charges = map { $_->{id} => $_ } @{$charges_tmp};
			foreach my $pay (@items) {
				$pay->{charge} = $charges{ $pay->{charge_id} };
			}
		}

	}

	return $items[0] if $pp{limit} == 1;
	return \@items;

}

sub _get_display_method {

	my ( $x, %pp ) = @_;

	my %methods = (
		CASH     => 'Efectivo',
		CARD     => 'Cr&eacute;dito / D&eacute;bito',
		TRANSFER => 'Transferencia',
		DEBIT    => 'Saldo a favor',
	);

	my @display_methods;
	push @display_methods, $methods{ $pp{method_type_code} } if $pp{payment_amount} > 0 || $pp{cancelled_payment_amount} > 0;
	push @display_methods, 'Saldo a favor' if $pp{debit_amount} > 0 || $pp{cancelled_debit_amount} > 0;

	return join( ', ', @display_methods );

}

sub get_last_payments {

	my ( $x, %pp ) = @_;

	my $sql = qq {
	SELECT 	_f_transactions.date_time::DATE,SUM(_f_payments.payment_amount)
	FROM 	_f_payments
	JOIN 	_f_transactions ON (_f_transactions.id = _f_payments.transaction_id)
	WHERE 	_f_transactions.date_time::DATE > NOW() - INTERVAL '$pp{days}' DAY
	GROUP BY _f_transactions.date_time::DATE
	};

	my %date_amounts;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my ( $date, $amount ) = $sth->fetchrow() ) {
		$date = global::date_time->format_date($date);
		$date_amounts{$date} = $amount;
	}

	$sth->finish();

	my $past_date = global::date_time->get_past_date( $pp{days} );
	my $date      = global::date_time->get_date();
	my $range     = global::date_time->get_dates_between( $past_date, $date );

	my @dates;

	foreach my $dd ( @{$range} ) {
		push @dates, { $dd => $date_amounts{$dd} || 0 };
	}

	return \@dates;

}

sub get_concept_distribution {

	my ( $x, %pp ) = @_;

	my $q = $x->get_quote();

	my $sql = qq {
	SELECT 	_f_charges.type_code,_i_items.name,SUM(_f_payments.payment_amount)
	FROM 	_f_payments
	JOIN 	_f_charges ON ( _f_charges.id = _f_payments.charge_id )
	JOIN 	_f_transactions ON ( _f_transactions.id = _f_payments.transaction_id )
	LEFT JOIN _i_inventory_sales ON ( _i_inventory_sales.id = _f_charges.item_sale_id )
	LEFT JOIN _i_items ON ( _i_items.id = _i_inventory_sales.item_id )
	WHERE 	TRUE
	AND 	_f_transactions.date_time::DATE = $q->{$pp{date}}
	GROUP BY _f_charges.type_code,_i_items.name
	};

	my @items;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my ( $type_code, $item_name, $total ) = $sth->fetchrow() ) {
		$item_name = 'Membres&iacute;as' if $type_code eq 'M';
		$item_name = 'Prepago'           if $type_code eq 'P';
		push @items, { $item_name => $total };
	}

	$sth->finish();

	return scalar @items ? \@items : undef;

}

sub get_client_month_payments {

	my ( $x, %pp ) = @_;

	my $q = $x->get_quote();

	my $sql_client_id_where = " AND _f_transactions.client_id = $q->{$pp{user_id}} " if $pp{user_id};

	my %new_enrollment_client_ids = map { $_ => 1 } @{ $pp{new_enrollment_client_ids} } if $pp{new_enrollment_client_ids};

	my $sql_month_where;

	if ( $pp{payment_month} && $pp{payment_year} ) {
		$sql_month_where = qq {
			AND EXTRACT(MONTH FROM _f_transactions.date_time) = $q->{$pp{payment_month}}
			AND EXTRACT(YEAR FROM _f_transactions.date_time) = $q->{$pp{payment_year}}
		};
	}
	elsif ( $pp{charge_month} && $pp{charge_year} ) {
		$sql_month_where = qq {
			AND _f_charges.month = $q->{$pp{charge_month}}
			AND _f_charges.year = $q->{$pp{charge_year}}
		};
	}

	my $sql = qq {
	SELECT 	EXTRACT(DAY FROM _f_transactions.date_time),
		SUM(_f_payments.payment_amount),
		ARRAY_AGG(_f_charges.client_id),
		ARRAY_AGG(_f_charges.type_code),
		ARRAY_AGG(
			EXTRACT(YEAR FROM _f_transactions.date_time) = _f_charges.year
			AND
			EXTRACT(MONTH FROM _f_transactions.date_time) = _f_charges.month
		)
	FROM 	_f_transactions
	JOIN 	_f_payments ON ( _f_payments.transaction_id = _f_transactions.id )
	JOIN 	_f_charges ON ( _f_charges.id = _f_payments.charge_id )
	WHERE 	TRUE
	$sql_month_where
	$sql_client_id_where
	GROUP BY EXTRACT(DAY FROM _f_transactions.date_time)
	};

	my @items;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	my %days;

	while ( my ( $day, $total, $ARRAY_client_ids, $ARRAY_type_codes, $ARRAY_same_month_bools ) = $sth->fetchrow() ) {

		my $rememberships_tmp = global::standard->hashify_arrays(
			keys  => [ 'client_id',       'type_code',       'is_same_month_bool' ],
			items => [ $ARRAY_client_ids, $ARRAY_type_codes, $ARRAY_same_month_bools ],
		);

		my @rememberships;

		if ( $pp{payment_month} && $pp{payment_year} ) {
			@rememberships = grep { $_->{type_code} eq 'M' && $_->{is_same_month_bool} } @{$rememberships_tmp};
		}
		elsif ( $pp{charge_month} && $pp{charge_year} ) {
			@rememberships = grep { $_->{type_code} eq 'M' && !$new_enrollment_client_ids{ $_->{client_id} } } @{$rememberships_tmp};
		}

		my %remembership_client_ids = map { $_->{client_id} => 1 } @rememberships;

		my $is_membership_payment = scalar @rememberships ? 1 : 0;

		$days{$day} = {
			total                    => $total,
			membership_payment_count => scalar @rememberships,
			is_membership_payment    => $is_membership_payment,
			remembership_client_ids  => [ keys %remembership_client_ids ],
		};
	}

	$sth->finish();

	return \%days;

}

1;
