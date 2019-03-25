package model::inventory;

use strict;
use base 'model::base';

use Sort::Key::Multi 'rnskeysort';

sub new {

	my ( $n, $dbh ) = @_;

	my $x = {
		dbh => $dbh,
		m   => model::init->new($dbh)
	};

	bless $x;
	return $x;

}

sub get_products {

	my ( $x, %pp ) = @_;

	my $sql_where = $x->generate_sql_where(%pp) if scalar keys %pp;
	my $sql_limit = " LIMIT $pp{limit} "        if $pp{limit};

	my $sql = qq {
	SELECT	_i_items.id,_i_items.type_code,_i_items.name,
		_i_items.amount,_i_items.use_inventory,_i_items.data,
		_i_items.active,_i_items.is_permanent,_i_items.visit_number,
		_i_items.expiration_number,_i_items.expiration_unit,
		_i_inventory_totals.add,
		_i_inventory_totals.out,
		_i_inventory_totals.sell,
		_i_inventory_totals.available
	FROM	_i_items
	LEFT JOIN _i_inventory_totals ON ( _i_inventory_totals.item_id = _i_items.id )
	WHERE 	TRUE
	$sql_where
	ORDER BY _i_items.active DESC,_i_items.use_inventory DESC,_i_items.name ASC
	$sql_limit
	};

	my %inventory_item_ids;
	my @items;
	my @keys = qw/id type_code name amount use_inventory
	  _json_data active is_permanent visit_number
	  expiration_number expiration_unit
	  _inventory_add _inventory_out _inventory_sell _inventory_available/;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;

		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}

		$ii{display_type} = __PACKAGE__->_get_display_type( $ii{type_code} );

		$ii{data} = JSON::XS->new()->latin1()->decode( $ii{_json_data} );

		$inventory_item_ids{ $ii{id} } = 1 if $ii{use_inventory} && $ii{active};

		if ( $ii{type_code} eq 'VISITS' ) {
			$ii{visits_expiration_date} = global::date_time->get_expiration_date(
				number => $ii{expiration_number},
				unit   => $ii{expiration_unit}
			);
		}

		if ( $ii{use_inventory} ) {
			$ii{inventory}->{ADD}   = $ii{_inventory_add};
			$ii{inventory}->{OUT}   = $ii{_inventory_out};
			$ii{inventory}->{TOTAL} = $ii{_inventory_available};
		}

		$ii{inventory}->{SELL} = $ii{_inventory_sell};

		foreach my $key ( keys %ii ) {
			delete $ii{$key} if substr( $key, 0, 1 ) eq '_';
		}

		push @items, \%ii;

	}

	$sth->finish();

	return undef unless scalar @items;

	if ( $pp{get_debt_totals} ) {
		my $item_debts = $x->{m}->{charges}->get_item_debt_totals( inventory_item_ids => [ keys %inventory_item_ids ] );
		map { $_->{total_debt} = $item_debts->{ $_->{id} } } @items
		  if $item_debts;
	}

	if ( $pp{only_items_with_inventory} ) {

		my @filtered;

		foreach my $ii (@items) {
			next if $ii->{use_inventory} && !$ii->{inventory}->{TOTAL};
			push @filtered, $ii;
		}

		return undef unless scalar @filtered;

		@items = @filtered;

	}

	if ( $pp{order_by_inventory} ) {
		my @sorted = rnskeysort { $_->{inventory}->{TOTAL}, $_->{name} } @items;
		@items = @sorted;
	}

	if ( $pp{order_by_sales} ) {
		my @sorted = rnskeysort { $_->{inventory}->{SELL}, $_->{name} } @items;
		@items = @sorted;
	}

	return $items[0] if $pp{limit} == 1;
	return \@items;

}

sub _get_display_type {

	my ( $n, $type_code ) = @_;

	my %display_type_codes = (
		VISITS      => 'Paquete de visitas',
		FOOD        => 'Bebidas y alimentos',
		SUPPLEMENTS => 'Suplementos',
		CLOTHING    => 'Ropa',
		SHOES       => 'Tenis',
		EQUIPMENT   => 'Equipo',
		SERVICES    => 'Servicios',
		ENROLLMENTS => 'Inscripciones',
		OTHER       => 'Otros'
	);

	return $display_type_codes{$type_code};

}

sub get_inventory {

	my ( $x, %pp ) = @_;

	my $sql = qq {
	SELECT	SUM(_i_inventory_totals.available)
	FROM	_i_inventory_totals
	JOIN 	_i_items ON (_i_items.id = _i_inventory_totals.item_id)
	WHERE 	_i_items.use_inventory = TRUE
	AND 	_i_items.active = TRUE
	};

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );
	my $available_inventory = $sth->fetchrow();
	return $available_inventory || 0;

}

sub get_history {

	my ( $x, %pp ) = @_;

	return undef unless $pp{item_id};

	my $q                      = $x->get_quote();
	my $sql_add_item_id_where  = " AND _i_inventory_add.item_id = $q->{$pp{item_id}} ";
	my $sql_out_item_id_where  = " AND _i_inventory_out.item_id = $q->{$pp{item_id}} ";
	my $sql_sale_item_id_where = " AND _i_inventory_sales.item_id = $q->{$pp{item_id}} ";

	my $ADD_sql_date_where;
	my $OUT_sql_date_where;
	my $SALES_sql_date_where;

	if ( $pp{start_date} && $pp{end_date} ) {
		$ADD_sql_date_where = qq {
	  		  AND (
	  			  _i_inventory_add.date_time >= $q->{ $pp{start_date} }
	  			  AND _i_inventory_add.date_time < $q->{ $pp{end_date} }::DATE + INTERVAL '1 DAY'
	  		  )
	  	  };
	}
	elsif ( $pp{date} ) {
		$ADD_sql_date_where = " AND _i_inventory_add.date_time::DATE = $q->{$pp{date}} ";
	}
	elsif ( $pp{current_date} ) {
		$ADD_sql_date_where = ' AND _i_inventory_add.date_time = NOW()::DATE ';
	}

	if ($ADD_sql_date_where) {
		$OUT_sql_date_where   = $ADD_sql_date_where;
		$SALES_sql_date_where = $ADD_sql_date_where;
		$OUT_sql_date_where =~ s/_i_inventory_add/_i_inventory_out/g;
		$SALES_sql_date_where =~ s/_i_inventory_add\.date_time/_f_charges\.creation_date_time/g;
	}

	my $sql_limit = ' LIMIT ' . $pp{limit} if $pp{limit};

	my %items;

	my $sql = qq {
	SELECT	'IN',_i_inventory_add.item_id,_i_inventory_add.count,
		_i_inventory_add.date_time AS INVENTORY_DATE_TIME,_i_inventory_add.admin_id,
		_g_users.name,_g_users.lastname1,_g_users.lastname2,_i_inventory_add.notes,
		_i_inventory_add.cancelled_charge_id,_f_charges.client_id,_f_charges_cancelled.notes,
		CLIENTS.name,CLIENTS.lastname1,CLIENTS.lastname2,0,0,0,0,FALSE
	FROM	_i_inventory_add
	JOIN 	_g_users ON ( _g_users.id = _i_inventory_add.admin_id )
	LEFT JOIN _f_charges_cancelled ON ( _f_charges_cancelled.charge_id = _i_inventory_add.cancelled_charge_id )
	LEFT JOIN _f_charges ON (
		_f_charges.id = _f_charges_cancelled.charge_id
		AND _f_charges.id = _i_inventory_add.cancelled_charge_id
	)
	LEFT JOIN _g_users CLIENTS ON ( CLIENTS.id = _f_charges.client_id )
	WHERE TRUE
	$sql_add_item_id_where
	$ADD_sql_date_where

	UNION ALL

	SELECT	'OUT',_i_inventory_out.item_id,_i_inventory_out.count,
		_i_inventory_out.date_time,_i_inventory_out.admin_id,
		_g_users.name,_g_users.lastname1,_g_users.lastname2,_i_inventory_out.notes,
		NULL,NULL,NULL,NULL,NULL,NULL,0,0,0,0,FALSE
	FROM	_i_inventory_out
	JOIN 	_g_users ON ( _g_users.id = _i_inventory_out.admin_id )
	WHERE TRUE
	$sql_out_item_id_where
	$OUT_sql_date_where

	UNION ALL

	SELECT	'SALE',_i_inventory_sales.item_id,1,_f_charges.creation_date_time,
		_i_inventory_sales.admin_id,_g_users.name,_g_users.lastname1,_g_users.lastname2,
		NULL,_f_charges.id,_f_charges.client_id,NULL,
		CLIENTS.name,CLIENTS.lastname1,CLIENTS.lastname2,
		_f_debts.charge_amount,_f_debts.discount_amount,_f_debts.paid_amount,
		_f_debts.remaining_amount,_f_charges_cancelled.charge_id IS NOT NULL
	FROM	_i_inventory_sales
	JOIN 	_f_charges ON ( _f_charges.item_sale_id = _i_inventory_sales.id )
	LEFT JOIN _f_charges_cancelled ON ( _f_charges_cancelled.charge_id = _f_charges.id )
	JOIN 	_f_debts ON ( _f_debts.charge_id = _f_charges.id )
	JOIN 	_g_users ON ( _g_users.id = _i_inventory_sales.admin_id )
	JOIN 	_g_users CLIENTS ON ( CLIENTS.id = _f_charges.client_id )
	WHERE TRUE
	$sql_sale_item_id_where
	$SALES_sql_date_where

	ORDER BY INVENTORY_DATE_TIME DESC
	$sql_limit
	};

	my @items;
	my @keys = qw/type_code id count date_time admin_id _name
	  _lastname1 _lastname2 notes charge_id client_id
	  cancelled_notes _client_name _client_lastname1 _client_lastname2
	  charge_amount discount_amount paid_amount remaining_amount is_cancelled/;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;

		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}

		$ii{display_name}        = global::standard->get_person_display_name( $ii{_name},        $ii{_lastname1},        $ii{_lastname2} );
		$ii{client_display_name} = global::standard->get_person_display_name( $ii{_client_name}, $ii{_client_lastname1}, $ii{_client_lastname2} );
		$ii{date_time}           = global::date_time->format_date_time( $ii{date_time} );
		$ii{is_return} = 1 if $ii{type_code} eq 'IN' && length $ii{charge_id};

		foreach my $key ( keys %ii ) {
			delete $ii{$key} if substr( $key, 0, 1 ) eq '_';
		}

		push @items, \%ii;

	}

	$sth->finish();

	return scalar @items ? \@items : undef;

}

sub get_timeframe_sales {

	my ( $x, %pp ) = @_;

	my %products;
	my %sales;

	my $q = $x->get_quote();
	my $sql_item_id_where = " AND _i_inventory_sales.item_id = $q->{$pp{item_id}} " if $pp{item_id};

	my $sql_date_where;

	if ( $pp{get_current_month} ) {
		$sql_date_where = qq {
			AND _f_charges.month = EXTRACT(MONTH FROM NOW())
			AND _f_charges.year = EXTRACT(YEAR FROM NOW())
		};
	}
	elsif ( $pp{start_date} && $pp{end_date} ) {
		$sql_date_where = qq {
	  		  AND (
	  			  _f_charges.creation_date_time >= $q->{ $pp{start_date} }
	  			  AND _f_charges.creation_date_time < $q->{ $pp{end_date} }::DATE + INTERVAL '1 DAY'
	  		  )
	  	  };
	}
	elsif ( $pp{date} ) {
		$sql_date_where = " AND _f_charges.creation_date_time::DATE = $q->{$pp{date}} ";
	}

	my $sql = qq {
	SELECT	_i_inventory_sales.item_id,_f_charges.creation_date_time::DATE,
		SUM(_f_charges.amount)
	FROM	_i_inventory_sales
	JOIN 	_f_charges ON (_f_charges.item_sale_id = _i_inventory_sales.id)
	JOIN 	_f_payments ON (_f_payments.charge_id = _f_charges.id)
	WHERE  	TRUE
	$sql_item_id_where
	$sql_date_where
	AND NOT EXISTS (
		SELECT 	1
		FROM 	_f_payments_cancelled
		WHERE 	_f_payments_cancelled.payment_id = _f_payments.id
	)
	GROUP BY _i_inventory_sales.item_id,_f_charges.creation_date_time::DATE
	};

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );
	while ( my ( $item_id, $date, $sales ) = $sth->fetchrow() ) {

		# dont format the date here so that perl sort keys works correctly
		$sales{$date}       += $sales;
		$products{$item_id} += $sales;
	}
	$sth->finish();

	return undef unless scalar keys %sales;
	my @dates      = sort keys %sales;
	my $first_date = $dates[0];
	my $last_date  = $dates[-1];
	my $all_dates  = global::date_time->get_dates_between( $first_date, $last_date );

	my @dates;

	foreach my $dd ( @{$all_dates} ) {
		my ( $day, $month, $year ) = split( /\D+/, $dd );
		my $date = $year . '-' . $month . '-' . $day;
		push @dates,
		  {
			date  => $dd,
			total => $sales{$date} || 0,
		  };
	}

	return { products => \%products, dates => \@dates };

}

1;
