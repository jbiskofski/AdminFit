package model::charges;

use strict;
use base 'model::base';
use Sort::Key qw/rnkeysort nkeysort/;
use Sort::Key::Multi 'nskeysort';
use List::Slice 'head';

sub new {

	my ( $n, $dbh ) = @_;

	my $x = {
		dbh => $dbh,
		m   => model::init->new($dbh)
	};

	bless $x;
	return $x;

}

sub get_charges {

	my ( $x, %pp ) = @_;

	my $q = $x->get_quote();

	my $sql_client_where    = " AND _f_charges.client_id = $q->{$pp{client_id}} " if $pp{client_id};
	my $sql_charge_id_where = " AND _f_charges.id = $q->{$pp{charge_id}} "        if $pp{charge_id};
	my $sql_charge_ids_in   = $x->generate_in(
		table => '_f_charges',
		field => 'id',
		items => $pp{charge_ids}
	) if $pp{charge_ids};

	my $sql_transaction_id_where = " AND _f_charges.transaction_id = $q->{$pp{transaction_id}} "
	  if $pp{transaction_id};

	my $sql_client_ids_in = $x->generate_in(
		table => '_f_charges',
		field => 'client_id',
		items => $pp{client_ids}
	) if $pp{client_ids};

	my $month = $pp{month} ? $q->{ $pp{month} } : 'NOW()';
	my $year  = $pp{year}  ? $q->{ $pp{year} }  : 'NOW()';

	my $sql_month_year_where;

	if ( $pp{get_current_month} ) {
		$sql_month_year_where = qq {
			AND (
				_f_charges.year = DATE_PART( 'YEAR', NOW() )
				AND
				_f_charges.month = DATE_PART( 'MONTH', NOW() )
			)
		};
	}

	if ( $pp{year} && $pp{month} ) {
		$sql_month_year_where = qq {
			AND (
				_f_charges.year = $q->{$pp{year}}
				AND
				_f_charges.month = $q->{$pp{month}}
			)
		};
	}

	my $sql_charge_date_where = " AND _f_charges.creation_date_time::DATE = $q->{$pp{date}} " if $pp{date};

	my $sql_type_code_where = " AND _f_charges.type_code = $q->{M} "
	  if $pp{only_membership_charges};

	my $sql_order = qq {
		ORDER BY _f_charges.year DESC,
			 _f_charges.MONTH DESC,
			 _f_charges.type_code ASC
	};

	my $q = $x->get_quote();

	my $sql_between_dates .= qq {
		  AND (
			  _f_charges.creation_date_time >= $q->{ $pp{start_date} }
			  AND _f_charges.creation_date_time < $q->{ $pp{end_date} }::DATE + INTERVAL '1 DAY'
		  )
	  } if $pp{start_date} && $pp{end_date};

	my $sql_not_cancelled = ' AND _f_charges_cancelled.charge_id IS NULL '
	  if $pp{not_cancelled};

	my $sql_cancelled_date_where;
	my $sql_cancelled_between_dates;
	my $LJ_cancelled = ' LEFT ';

	if ( $pp{cancelled} ) {

		$sql_charge_date_where = undef;
		$sql_between_dates     = undef;

		$sql_cancelled_date_where = " AND _f_charges_cancelled.date_time::DATE = $q->{$pp{date}} "
		  if $pp{date};

		$sql_cancelled_between_dates .= qq {
    		  AND (
    			  _f_charges_cancelled.date_time >= $q->{ $pp{start_date} }
    			  AND _f_charges_cancelled.date_time < $q->{ $pp{end_date} }::DATE + INTERVAL '1 DAY'
    		  )
    	  	} if $pp{start_date} && $pp{end_date};

		$LJ_cancelled = undef;

	}

	my $sql_limit = " LIMIT $pp{limit} " if $pp{limit};

	my $sql = qq {
	SELECT 	_f_charges.id,_f_charges.client_id,_f_charges.membership_id,
		_f_charges.year,_f_charges.month,_f_charges.amount,_f_charges.notes,
		_f_charges.creation_date_time,_f_charges.membership_group_id,
		_f_charges.type_code,_f_charges.responsible_client_id,
		_f_memberships.name,RESPONSIBLE.name,RESPONSIBLE.lastname1,RESPONSIBLE.lastname2,
		_i_inventory_sales.id,_i_inventory_sales.item_id,
		_i_inventory_sales.name,_i_inventory_sales.amount,
		_f_debts.discount_amount,_f_debts.paid_amount,
		_f_debts.debit_amount,_f_debts.remaining_amount,
		CLIENTS.name,CLIENTS.lastname1,CLIENTS.lastname2,
		_f_transactions.admin_id,ADMINS.name,ADMINS.lastname1,ADMINS.lastname2,
		_i_items.data,_i_items.is_permanent,_i_items.use_inventory,_i_items.type_code,
		_f_charges_cancelled.charge_amount,_f_charges_cancelled.admin_id,
		_f_charges_cancelled.date_time,_f_charges_cancelled.notes,
		CANCELLED_ADMIN.name,CANCELLED_ADMIN.lastname1,CANCELLED_ADMIN.lastname2,
		_g_client_visits.visits_used,_g_client_visits.visit_number,
		( NOW() > _g_client_visits.visits_expiration_date ),
		_g_client_visits.visits_remaining
	FROM 	_f_charges
	JOIN 	_g_users ON ( _g_users.id = _f_charges.client_id )
	JOIN 	_f_debts ON ( _f_debts.charge_id = _f_charges.id )
	JOIN 	_g_users CLIENTS ON ( CLIENTS.id = _f_charges.client_id )
	LEFT JOIN _f_transactions ON ( _f_transactions.id = _f_charges.transaction_id )
	LEFT JOIN _g_users ADMINS ON ( ADMINS.id = _f_transactions.admin_id )
	LEFT JOIN _f_memberships ON ( _f_memberships.id = _f_charges.membership_id )
	LEFT JOIN _g_users RESPONSIBLE ON ( RESPONSIBLE.id = _f_charges.responsible_client_id )
	LEFT JOIN _i_inventory_sales ON ( _i_inventory_sales.id = _f_charges.item_sale_id )
	LEFT JOIN _i_items ON ( _i_items.id = _i_inventory_sales.item_id )
	LEFT JOIN _g_client_visits ON (
		_g_client_visits.client_id = _f_charges.client_id
		AND _g_client_visits.charge_id = _f_charges.id
		AND _i_items.type_code = 'VISITS'
	)
	$LJ_cancelled JOIN _f_charges_cancelled ON ( _f_charges_cancelled.charge_id = _f_charges.id )
	$LJ_cancelled JOIN _g_users CANCELLED_ADMIN ON ( CANCELLED_ADMIN.id = _f_charges_cancelled.admin_id )
	WHERE 	 TRUE
	$sql_client_where
	$sql_charge_id_where
	$sql_charge_ids_in
	$sql_client_ids_in
	$sql_month_year_where
	$sql_type_code_where
	$sql_charge_date_where
	$sql_between_dates
	$sql_transaction_id_where
	$sql_not_cancelled
	$sql_cancelled_date_where
	$sql_cancelled_between_dates
	$sql_order
	$sql_limit
	};

	my @items;
	my @keys = qw/id client_id membership_id year month
	  amount notes creation_date_time membership_group_id
	  type_code responsible_client_id membership_name
	  responsible_name responsible_lastname1 responsible_lastname2
	  item_sale_id item_id item_name item_amount
	  discount_amount paid_amount debit_amount remaining_amount
	  _client_name _client_lastname1 _client_lastname2
	  admin_id _admin_name _admin_lastname1 _admin_lastname2
	  json_data is_permanent item_use_inventory item_type_code
	  cancelled_charge_amount cancelled_admin_id cancelled_date_time
	  cancelled_notes _cancelled_name _cancelled_lastname1
	  _cancelled_lastname2 visits_used visit_number visits_expired visits_remaining/;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;
		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}

		$ii{creation_date_time} = global::date_time->format_date_time( $ii{creation_date_time} );

		$ii{display_responsible_client_name} = global::standard->get_person_display_name( $ii{responsible_name}, $ii{responsible_lastname1}, $ii{responsible_lastname2} )
		  if $ii{responsible_client_id};

		$ii{admin_display_name} = global::standard->get_person_display_name( $ii{_admin_name}, $ii{_admin_lastname1}, $ii{_admin_lastname2} )
		  if $ii{admin_id};
		$ii{client_display_name} = global::standard->get_person_display_name( $ii{_client_name}, $ii{_client_lastname1}, $ii{_client_lastname2} );

		if ( $ii{json_data} ) {
			$ii{data} = JSON::XS->new()->latin1()->decode( $ii{json_data} );
			$ii{display_item_details} = join( ' ', sort values %{ $ii{data} } );
			delete $ii{json_data};
			delete $ii{data};
		}

		if ( $ii{cancelled_admin_id} ) {
			$ii{cancelled_display_name}    = global::standard->get_person_display_name( $ii{_cancelled_name}, $ii{_cancelled_lastname1}, $ii{_cancelled_lastname2} );
			$ii{cancelled_date_time}       = global::date_time->format_date_time( $ii{cancelled_date_time} );
			$ii{is_cancelled}              = 1;
			$ii{display_cancelled_details} = '<i class="fe fe-user"></i> ' . $ii{cancelled_display_name};
			$ii{display_cancelled_details} .= '<br>' . $ii{cancelled_notes} if $ii{cancelled_notes};
			$ii{cancelled_epoch} = global::date_time->get_epoch( $ii{cancelled_date_time} );
		}

		$ii{concept} = __PACKAGE__->_get_display_concept(
			type_code                       => $ii{type_code},
			membership_name                 => $ii{membership_name},
			responsible_client_id           => $ii{responsible_client_id},
			display_responsible_client_name => $ii{display_responsible_client_name},
			item_name                       => $ii{item_name},
			item_details                    => $ii{display_item_details},
			notes                           => $ii{notes},
			month                           => $ii{month},
			year                            => $ii{year},
		);

		if ( $ii{type_code} eq 'P' ) {
			$ii{is_prepayment}    = 1;
			$ii{remaining_amount} = 0;
		}

		if ( $ii{type_code} eq 'I' ) {
			$ii{display_item_category} = $x->{m}->{inventory}->_get_display_type( $ii{item_type_code} );
		}

		$ii{display_month} = global::date_time->get_display_month( $ii{month} );

		foreach my $key ( keys %ii ) {
			delete $ii{$key} if substr( $key, 0, 1 ) eq '_';
		}

		push @items, \%ii;

	}

	$sth->finish();

	return undef unless scalar @items;

	if ( $pp{include_debt_details} ) {

		my %charge_ids = map { $_->{id} => 1 } @items;
		my $details_tmp = $x->get_charge_debt_details( charge_ids => [ keys %charge_ids ] );

		if ($details_tmp) {
			my %details = map { $_->{charge_id} => $_ } @{$details_tmp};
			foreach my $ch (@items) {
				$ch->{debt_details} = $details{ $ch->{id} };
			}
		}

	}

	return $items[0] if $pp{limit} == 1;
	return \@items;

}

sub get_client_debts {

	my ( $x, %pp ) = @_;

	my $sql_client_id_in = $x->generate_in(
		table => '_g_users',
		field => 'id',
		items => $pp{client_ids},
	) if $pp{client_ids};

	my $sql_active_only_where = ' AND _g_users.active = TRUE '
	  if $pp{active_only};

	my $sql_clients_only_where = ' AND _g_users.is_client = TRUE '
	  if $pp{clients_only};

	my $sql_membership_debt_only_where = " AND _f_charges.type_code = 'M' "
	  if $pp{only_membership_debt_details};

	my $sql_specific_month_where;

	if ( $pp{specific_month_debt_details} ) {
		$pp{specific_month_debt_details} =~ /^(\d{4})(\d{2})$/;
		my ( $year, $month ) = ( $1, $2 );
		$sql_specific_month_where = " AND _f_charges.year = $year AND _f_charges.month = $month ";
	}

	my $sql = qq {
	SELECT 	'RENEWAL',_g_users.id,NULL::UUID,_g_users.active,_f_client_memberships.renewal_day,0,0,
		_v_membership_groups.group_id,_v_membership_groups.responsible_client_id,
		_v_membership_groups.is_responsible
	FROM 	_g_users
	JOIN 	_f_client_memberships ON (_f_client_memberships.client_id = _g_users.id)
	LEFT JOIN _v_membership_groups ON (
		_v_membership_groups.client_id = _f_client_memberships.client_id
		AND _v_membership_groups.membership_id = _f_client_memberships.membership_id
	)
	WHERE 	TRUE
	$sql_active_only_where
	$sql_clients_only_where
	$sql_client_id_in

	UNION ALL

	SELECT 	'DEBT',_f_charges.client_id,NULL::UUID,FALSE,0,SUM(_f_debts.remaining_amount),0,
		NULL::UUID,NULL::UUID,FALSE
	FROM 	_f_charges
	JOIN 	_f_debts ON ( _f_debts.charge_id = _f_charges.id )
	JOIN 	_g_users ON (_g_users.id = _f_charges.client_id)
	WHERE 	TRUE
	$sql_active_only_where
	$sql_clients_only_where
	$sql_client_id_in
	$sql_membership_debt_only_where
	$sql_specific_month_where
	GROUP BY _f_charges.client_id

	UNION ALL

	SELECT 	'LAST',LAST_SS.client_id,LAST_SS.CHARGE_ID,FALSE,0,LAST_SS.YEARMONTH,
		LAST_SS.remaining_amount,LAST_SS.membership_group_id,NULL::UUID,FALSE
	FROM (
		SELECT	'LAST',_f_charges.client_id,_f_charges.id AS CHARGE_ID,
			(_f_charges.year::VARCHAR || LPAD(_f_charges.month::VARCHAR, 2, '0') )::INT AS YEARMONTH,
			_f_debts.remaining_amount,_f_charges.membership_group_id,
			RANK() OVER ORDERED_MONTH_MEMBERSHIPS AS LAST_RANK
		FROM 	_f_charges
		JOIN 	_f_memberships ON ( _f_memberships.id = _f_charges.membership_id )
		JOIN 	_f_debts ON ( _f_debts.charge_id = _f_charges.id )
		JOIN 	_g_users ON (_g_users.id = _f_charges.client_id)
		AND 	_f_memberships.is_visits_membership = FALSE
		$sql_active_only_where
		$sql_clients_only_where
		$sql_client_id_in
		$sql_specific_month_where
		AND	_f_charges.type_code = 'M'
         	WINDOW ORDERED_MONTH_MEMBERSHIPS AS (
            		PARTITION BY _f_charges.client_id ORDER BY _f_charges.year DESC,_f_charges.month DESC
		)
	) AS LAST_SS
	WHERE LAST_SS.LAST_RANK = 1

	UNION ALL

	SELECT	'VISITS',_f_client_memberships.client_id,NULL::UUID,FALSE,0,0,0,NULL::UUID,
		NULL::UUID,FALSE
	FROM 	_f_client_memberships
	JOIN 	_f_memberships ON ( _f_memberships.id = _f_client_memberships.membership_id )
	JOIN 	_g_users ON ( _g_users.id = _f_client_memberships.client_id )
	WHERE 	_f_memberships.is_visits_membership = TRUE
	$sql_active_only_where
	$sql_clients_only_where
	$sql_client_id_in
	};

	my @keys = qw/type_code client_id charge_id user_active renewal_day
	  value remaining_amount membership_group_id responsible_client_id is_responsible/;

	my %group_membership_responsible_client_ids;
	my %clients;
	my %visitor_client_ids;
	my @last_charges;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;
		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}

		$visitor_client_ids{ $ii{client_id} } = 1 if $ii{type_code} eq 'VISITS';

		if ( $ii{type_code} eq 'DEBT' ) {
			$clients{ $ii{client_id} }->{ $ii{type_code} } = $ii{value};
		}
		elsif ( $ii{type_code} eq 'RENEWAL' ) {

			$clients{ $ii{client_id} }->{ACTIVE} = $ii{user_active};

			my $is_responsible_for_group_membership = 0;
			my $is_dependent                        = 0;
			my $is_group_membership                 = 0;

			if ( length $ii{membership_group_id} > 4 ) {
				$is_group_membership = 1;
				if ( $ii{is_responsible} ) {
					$is_responsible_for_group_membership = 1;
					$group_membership_responsible_client_ids{ $ii{membership_group_id} } = $ii{responsible_client_id};
				}
				else {
					$is_dependent = 1;
				}
			}

			$clients{ $ii{client_id} }->{RENEWAL}                                     = $ii{renewal_day};
			$clients{ $ii{client_id} }->{LAST}->{is_responsible_for_group_membership} = $is_responsible_for_group_membership;
			$clients{ $ii{client_id} }->{LAST}->{is_dependent}                        = $is_dependent;
			$clients{ $ii{client_id} }->{LAST}->{is_group_membership}                 = $is_group_membership;

		}
		elsif ( $ii{type_code} eq 'LAST' ) {
			$clients{ $ii{client_id} }->{LAST}->{id}                  = $ii{client_id};
			$clients{ $ii{client_id} }->{LAST}->{charge_id}           = $ii{charge_id};
			$clients{ $ii{client_id} }->{LAST}->{year}                = substr( $ii{value}, 0, 4 );
			$clients{ $ii{client_id} }->{LAST}->{month}               = substr( $ii{value}, 4, 2 );
			$clients{ $ii{client_id} }->{LAST}->{remaining_amount}    = $ii{remaining_amount};
			$clients{ $ii{client_id} }->{LAST}->{membership_group_id} = $ii{membership_group_id};
		}

	}

	$sth->finish();

	if ( scalar keys %visitor_client_ids ) {

		my $visit_memberships = $x->{m}->{memberships}->get_visit_memberships( client_ids => [ keys %visitor_client_ids ] );

		foreach my $client_id ( keys %clients ) {

			next unless $visitor_client_ids{$client_id};
			my $visits_package = $visit_memberships->{$client_id}
			  || {
				client_id              => $client_id,
				expired                => 1,
				visit_number           => 0,
				visits_expiration_date => global::date_time->get_yesterday(),
				visits_remaining       => 0,
				visits_used            => 0,
				invalid                => 1,
				no_available_visits    => 1
			  };

			my ( $day, $month, $year ) = split( /\D+/, $visits_package->{visits_expiration_date} );

			$clients{$client_id}->{LAST} = {
				id                                  => $client_id,
				is_dependent                        => 0,
				is_responsible_for_group_membership => 0,
				membership_group_id                 => undef,
				year                                => $year,
				month                               => $month,
				remaining_amount                    => 0,
				is_visits_membership                => 1,
			};

			$clients{$client_id}->{RENEWAL} = $day;
			$clients{$client_id}->{VISITS}  = $visits_package;

		}

	}

	foreach my $client_id ( keys %clients ) {

		my $renewal_day = sprintf( "%02d", $clients{$client_id}->{RENEWAL} );
		$renewal_day = 1 unless $renewal_day && int($renewal_day) > 0;

		my $year             = $clients{$client_id}->{LAST}->{year};
		my $month            = $clients{$client_id}->{LAST}->{month};
		my $remaining_amount = $clients{$client_id}->{LAST}->{remaining_amount};

		my $next_months = global::date_time->get_next_months(
			year     => $year,
			month    => $month,
			get_next => 1,
		);

		# brand new user - first charge
		if ( !$clients{$client_id}->{LAST}->{year} ) {

			my $parts = global::date_time->get_date_time_parts();

			if ( $parts->{day} <= $renewal_day ) {
				$next_months = global::date_time->get_next_months(
					year            => $year,
					month           => $month,
					get_next        => 1,
					subtract_months => 1,
				);
			}

			$year             = $next_months->[0]->{year};
			$month            = $next_months->[0]->{month};
			$remaining_amount = 0;

		}

		my $last_membership_charge_date = $renewal_day . '/' . $month . '/' . $year;
		my $next_membership_charge_date = $renewal_day . '/' . $next_months->[0]->{month} . '/' . $next_months->[0]->{year};

		if ( $clients{$client_id}->{LAST}->{is_visits_membership} ) {
			$next_membership_charge_date = $clients{$client_id}->{RENEWAL} . '/' . $clients{$client_id}->{LAST}->{month} . '/' . $clients{$client_id}->{LAST}->{year};
		}

		my $days_remaining = global::date_time->get_days_between( global::date_time->get_date(), $next_membership_charge_date );

		my $progress_max_days =
		    $days_remaining > 28
		  ? $days_remaining
		  : 28;

		my $progress_pct = int( ( $days_remaining * 100 ) / $progress_max_days );
		my $membership_expired = 0;

		if ( $days_remaining < 1 || $remaining_amount > 0 ) {
			$progress_pct                = 1;
			$membership_expired          = 1;
			$days_remaining              = global::date_time->get_days_between( global::date_time->get_date(), $last_membership_charge_date );
			$next_membership_charge_date = $last_membership_charge_date;
		}

		my $progress_bar_color_class = 'bg-red';

		if ( $days_remaining > 15 ) {
			$progress_bar_color_class = 'bg-green';
		}
		elsif ( $days_remaining > 5 ) {
			$progress_bar_color_class = 'bg-yellow';
		}

		my $display_days = __PACKAGE__->_get_display_days($days_remaining);

		$clients{$client_id}->{LAST} = {
			year                 => $year,
			month                => $month,
			next_year            => $next_months->[0]->{year},
			next_month           => $next_months->[0]->{month},
			days                 => $days_remaining,
			display_days         => $display_days,
			display_next         => global::date_time->get_display_date($next_membership_charge_date),
			display_last         => global::date_time->get_display_date($last_membership_charge_date),
			progress_max_days    => $progress_max_days,
			progress_pct         => $progress_pct,
			expired              => $membership_expired,
			progress_color_class => $progress_bar_color_class,
			membership_group_id  => $clients{$client_id}->{LAST}->{membership_group_id},
			is_dependent         => $clients{$client_id}->{LAST}->{is_dependent},
			is_visits_membership => $clients{$client_id}->{LAST}->{is_visits_membership},
			charge_id            => $clients{$client_id}->{LAST}->{charge_id},
		};

	}

	foreach my $client_id ( keys %clients ) {

		if ( !$clients{$client_id}->{ACTIVE} && !$pp{include_debt_details_for_inactives} ) {
			$clients{$client_id}->{LAST}    = undef;
			$clients{$client_id}->{RENEWAL} = undef;
			next;
		}

		# replace dependent clients LAST info with responsible clients
		if ( length( $clients{$client_id}->{LAST}->{membership_group_id} ) > 8
			&& $clients{$client_id}->{LAST}->{is_dependent} )
		{
			my $group_id             = $clients{$client_id}->{LAST}->{membership_group_id};
			my $resposible_client_id = $group_membership_responsible_client_ids{$group_id};
			if ( length $resposible_client_id > 8 ) {
				$clients{$client_id}->{LAST} = $clients{$resposible_client_id}->{LAST};
				$clients{$client_id}->{LAST}->{is_dependent} = 0;
			}
		}

	}

	return scalar keys %clients ? \%clients : undef;

}

sub _get_display_days {

	my ( $n, $days ) = @_;

	if ( $days < -1 ) {
		return '<small class="text-red">Hace ' . abs($days) . ' d&iacute;as</small>';
	}
	elsif ( $days == -1 ) {
		return qq{<small class="text-red">Ayer</small>};
	}
	elsif ( $days == 0 ) {
		return '<small class="text-red">Hoy</small>';
	}
	elsif ( $days == 1 ) {
		return '<small class="text-red">Ma&ntilde;ana</small>';
	}
	elsif ( $days <= 5 ) {
		return qq{<small class="text-red">$days d&iacute;as</small>};
	}
	elsif ( $days <= 15 ) {
		return qq{<small class="text-orange">$days d&iacute;as</small>};
	}
	elsif ( $days > 15 ) {
		return qq{<small class="text-green">$days d&iacute;as</small>};
	}

}

sub get_charge_debt_details {

	my ( $x, %pp ) = @_;

	return undef unless $pp{charge_ids} || $pp{charge_id};

	my $sql_charge_id_in = $x->generate_in(
		table => '_f_debts',
		field => 'charge_id',
		items => $pp{charge_ids},
		where => 1,
	);

	my $sql = qq {
	SELECT 	_f_debts.charge_id,_f_debts.charge_amount,_f_debts.discount_amount,
		_f_debts.paid_amount,_f_debts.remaining_amount
	FROM 	_f_debts
	$sql_charge_id_in
	};

	my @items;
	my @keys = qw/charge_id charge_amount discount_amount paid_amount remaining_amount/;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;
		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}

		push @items, \%ii;

	}

	$sth->finish();

	return scalar @items ? \@items : undef;

}

sub get_item_debt_totals {

	my ( $x, %pp ) = @_;

	return undef unless $pp{inventory_item_ids} && scalar @{ $pp{inventory_item_ids} };

	my $sql_inventory_item_id_in = $x->generate_in(
		table => '_i_inventory_sales',
		field => 'item_id',
		items => $pp{inventory_item_ids},
		where => 1,
	);

	my $sql = qq {
	SELECT 	_i_inventory_sales.item_id,SUM(_f_debts.remaining_amount)
	FROM 	_f_debts
	JOIN 	_f_charges ON ( _f_charges.id = _f_debts.charge_id )
	JOIN 	_i_inventory_sales ON ( _i_inventory_sales.id = _f_charges.item_sale_id )
	$sql_inventory_item_id_in
	GROUP BY _i_inventory_sales.item_id
	};

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	my %inventory_item_debts;

	while ( my ( $id, $amount ) = $sth->fetchrow() ) {
		$inventory_item_debts{$id} = $amount;
	}

	$sth->finish();

	return scalar keys %inventory_item_debts ? \%inventory_item_debts : undef;

}

sub get_item_debt_details {

	my ( $x, %pp ) = @_;

	my $q = $x->get_quote();

	my $sql = qq {
	SELECT 	_f_charges.client_id,_g_users.name,_g_users.lastname1,_g_users.lastname2,
		_g_users.has_picture,_g_users.has_profile_picture,SUM(_f_debts.remaining_amount)
	FROM 	_f_debts
	JOIN 	_f_charges ON ( _f_charges.id = _f_debts.charge_id )
	JOIN 	_g_users ON (_g_users.id = _f_charges.client_id)
	JOIN 	_i_inventory_sales ON ( _i_inventory_sales.id = _f_charges.item_sale_id )
	WHERE 	_i_inventory_sales.item_id = $q->{$pp{inventory_item_id}}
	AND 	_f_debts.remaining_amount > 0
	GROUP BY _f_charges.client_id,_g_users.name,_g_users.lastname1,_g_users.lastname2,
		 _g_users.has_picture,_g_users.has_profile_picture
	};

	my @items;
	my $total_debt = 0;

	my @keys = qw/client_id _name _lastname1 _lastname2 has_picture has_profile_picture debt/;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;
		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}

		$ii{display_name} = global::standard->get_person_display_name( $ii{_name}, $ii{_lastname1}, $ii{_lastname2} );

		foreach my $key ( keys %ii ) {
			delete $ii{$key} if substr( $key, 0, 1 ) eq '_';
		}

		$total_debt += $ii{debt};

		push @items, \%ii;

	}

	$sth->finish();

	return scalar @items
	  ? {
		clients => \@items,
		total   => $total_debt
	  }
	  : undef;

}

sub get_expiring {

	my ( $x, %pp ) = @_;

	my $debts = $x->get_client_debts(
		active_only  => 1,
		clients_only => 1,
	);

	return undef unless $debts;

	my $memberships_tmp = $x->{m}->{memberships}->get_client_memberships(
		in => {
			table => '_f_client_memberships',
			field => 'client_id',
			items => [ keys %{$debts} ],
		}
	);

	if ($memberships_tmp) {

		my %memberships = map { $_->{client_id} => $_ } @{$memberships_tmp};

		# we dont want clients with free memberships ( visits, gratuito, etc )
		foreach my $client_id ( keys %{$debts} ) {
			my $membership = $memberships{$client_id};
			delete $debts->{$client_id} if $membership->{is_free_membership} || $membership->{is_visits_membership};
		}

	}

	return undef unless $debts && scalar keys %{$debts};

	my $total_debt        = 0;
	my $clients_with_debt = 0;
	my @expiring_tmp;
	my %seen_groups;

	foreach my $client_id ( keys %{$debts} ) {

		my $debt       = $debts->{$client_id}->{DEBT};
		my $membership = $debts->{$client_id}->{LAST};

		$total_debt += $debt if $debt > 0;
		$clients_with_debt++ if $debt > 0;

		next if $membership->{membership_group_id} && $seen_groups{ $membership->{membership_group_id} };
		next if $debts->{$client_id}->{LAST}->{is_dependent};
		next unless defined( $membership->{days} ) && $membership->{days} >= 0;

		$seen_groups{ $membership->{membership_group_id} } = 1 if $membership->{membership_group_id};
		$membership->{id} = $client_id;
		push @expiring_tmp, $membership;

	}

	my @expiring_sorted = nskeysort { $_->{days}, $_->{id} } @expiring_tmp;
	my @expiring = head $pp{days}, @expiring_sorted;

	my %client_ids = map { $_->{id} => 1 } @expiring;

	my $clients_tmp = $x->{m}->{clients}->get_clients(
		in => {
			table => '_g_users',
			field => 'id',
			items => [ keys %client_ids ],
		}
	);

	my %clients = map { $_->{id} => $_ } @{$clients_tmp};

	foreach my $ee (@expiring) {
		$ee->{client} = $clients{ $ee->{id} };
	}

	return {
		clients_with_debt => $clients_with_debt,
		total_debt        => sprintf( "%.2f", $total_debt ),
		expiring          => \@expiring,
	};

}

sub get_day_total {

	my ( $x, %pp ) = @_;

	my $sql = qq {
	SELECT 	SUM(_f_charges.amount)
	FROM 	_f_charges
	WHERE 	_f_charges.creation_date_time::DATE = NOW()::DATE;
	};

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );
	my $amount = $sth->fetchrow();
	$sth->finish();

	$amount //= 0;

	return $amount;

}

sub _get_display_concept {

	my ( $n, %pp ) = @_;

	$pp{notes} =~ s/\s+/ /g;
	$pp{notes} =~ s/\s+$//;

	if ( $pp{type_code} eq 'M' ) {

		$pp{membership_name} =~ s/\s+/ /g;
		$pp{membership_name} =~ s/\s+$//;

		my %concept = (
			concept => 'Membres&iacute;a : ' . global::date_time->get_display_month( $pp{month} ) . ' ' . $pp{year},
			details => $pp{notes} || $pp{membership_name},
		);

		$concept{display_responsible_client_name} = $pp{display_responsible_client_name}
		  if $pp{responsible_client_id};

		return \%concept;

	}
	elsif ( $pp{type_code} eq 'I' ) {

		$pp{item_name} =~ s/\s+/ /g;
		$pp{item_name} =~ s/\s+$//g;

		$pp{item_details} =~ s/\s+/ /g;
		$pp{item_details} =~ s/\s+$//g;

		my $details = $pp{item_details};
		$details .= ' ' . $pp{notes} if $pp{notes};

		return {
			concept => $pp{item_name},
			details => $details,
		};

	}
	elsif ( $pp{type_code} eq 'P' ) {

		my $details = $pp{notes} if $pp{notes};

		return {
			concept => 'Prepago',
			details => $details,
		};

	}
	else {
		global::standard->inspect( 'need-to-implement', \%pp, __FILE__, __LINE__ );
	}

}

sub get_concept_distribution {

	my ( $x, %pp ) = @_;

	my $q = $x->get_quote();

	my $sql = qq {
	SELECT 	_f_charges.type_code,_i_items.name,SUM(_f_charges.amount),SUM(_f_payments.payment_amount)
	FROM 	_f_charges
	LEFT JOIN _f_payments ON ( _f_payments.charge_id = _f_charges.id AND _f_charges.type_code = 'P' )
	LEFT JOIN _i_inventory_sales ON ( _i_inventory_sales.id = _f_charges.item_sale_id )
	LEFT JOIN _i_items ON ( _i_items.id = _i_inventory_sales.item_id )
	WHERE 	TRUE
	AND 	_f_charges.creation_date_time::DATE = $q->{$pp{date}}
	GROUP BY _f_charges.type_code,_i_items.name
	};

	my @items;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my ( $type_code, $item_name, $total, $prepayment_amount ) = $sth->fetchrow() ) {

		if ( $type_code eq 'P' ) {
			$item_name = 'Prepago';
			$total     = $prepayment_amount;
		}
		elsif ( $type_code eq 'M' ) {
			$item_name = 'Membres&iacute;as';
		}

		push @items, { $item_name => $total };

	}

	$sth->finish();
	return scalar @items ? \@items : undef;

}

1;
