package model::discounts;

use strict;
use base 'model::base';

sub new {

	my ( $n, $dbh ) = @_;
	my $x = { dbh => $dbh };
	bless $x;
	return $x;

}

sub get_discounts {

	my ( $x, %pp ) = @_;

	my $sql_where = $x->generate_sql_where(%pp) if scalar keys %pp;
	my $sql_limit = " LIMIT $pp{limit} "        if $pp{limit};

	my $sql = qq {
	SELECT	_f_discounts.id,_f_discounts.name,_f_discounts.amount,
		_f_discounts.type_code,_f_discounts.requirement_type_code,
		_f_discounts.notes,_f_discounts.active,
		_f_discounts.discount_month_duration,_f_discounts.is_permanent,
		ARRAY_AGG( DISTINCT _f_discount_participating_memberships.membership_id ),
		ARRAY_AGG( DISTINCT _f_memberships.name )
	FROM	_f_discounts
	LEFT JOIN _f_discount_participating_memberships ON ( _f_discount_participating_memberships.discount_id = _f_discounts.id )
	LEFT JOIN _f_memberships ON ( _f_memberships.id = _f_discount_participating_memberships.membership_id )
	WHERE 	TRUE
	$sql_where
	GROUP BY _f_discounts.id,_f_discounts.name,_f_discounts.amount,
		 _f_discounts.type_code,_f_discounts.requirement_type_code,
		 _f_discounts.notes,_f_discounts.active,_f_discounts.discount_month_duration,
		 _f_discounts.is_permanent
	ORDER BY _f_discounts.active DESC, UPPER(_f_discounts.name) ASC
	$sql_limit
	};

	my @items;
	my @keys = qw/id name amount type_code requirement_type_code
	  notes active discount_month_duration is_permanent _ARRAY_membership_ids _ARRAY_membership_names/;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;
		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}

		$ii{display_type_code} = $ii{type_code} eq 'G' ? 'General' : 'Membres&iacute;as';

		$ii{display_requirement_type_code} = 'Todas';

		if ( $ii{requirement_type_code} eq 'S' ) {

			$ii{display_requirement_type_code} = 'Especificas';
			my %membership_ids = map { $_ => 1 } @{ $ii{_ARRAY_membership_ids} };
			$ii{membership_ids} = \%membership_ids;

			$ii{participating_memberships} = global::standard->hashify_arrays(
				keys   => [ 'id',                       'name' ],
				unique => 'id',
				items  => [ $ii{_ARRAY_membership_ids}, $ii{_ARRAY_membership_names} ]
			);

			$ii{display_participating_memberships} = join( ', ', sort @{ $ii{_ARRAY_membership_names} } );

		}

		$ii{display_month_duration} = $ii{discount_month_duration} . ' Mes';
		$ii{display_month_duration} .= 'es' if $ii{discount_month_duration} > 1;

		$ii{display_tip} = '-$' . global::ttf->commify( $ii{amount} );
		$ii{display_tip} .= '<br>' . $ii{display_month_duration};

		delete $ii{_ARRAY_membership_ids};
		delete $ii{_ARRAY_membership_names};

		push @items, \%ii;

	}

	$sth->finish();

	return undef unless scalar @items;

	if ( $pp{participating_membership_id} ) {
		my @filtered;
		foreach my $ii (@items) {
			next unless $ii->{type_code} eq 'M';
			next
			  unless $ii->{requirement_type_code} eq 'A'
			  || $ii->{membership_ids}->{ $pp{participating_membership_id} };
			push @filtered, $ii;
		}
		@items = @filtered;
	}

	return $items[0] if $pp{limit} == 1;
	return \@items;

}

sub get_charge_discounts {

	my ( $x, %pp ) = @_;

	my $q = $x->get_quote();

	return unless scalar keys %pp;
	my $sql_where = $x->generate_sql_where(%pp) if scalar keys %pp;
	my $sql_limit = " LIMIT $pp{limit} "        if $pp{limit};

	my $sql_date_where = " AND _f_charge_discounts.date_time::DATE = $q->{$pp{date}} " if $pp{date};

	my $sql_between_dates .= qq {
		  AND (
			  _f_charge_discounts.date_time >= $q->{ $pp{start_date} }
			  AND _f_charge_discounts.date_time < $q->{ $pp{end_date} }::DATE + INTERVAL '1 DAY'
		  )
	  } if $pp{start_date} && $pp{end_date};

	my $sql_cancelled_date_where;
	my $sql_cancelled_between_dates;
	my $LJ_cancelled = ' LEFT ';

	if ( $pp{cancelled} ) {

		$sql_date_where    = undef;
		$sql_between_dates = undef;

		$sql_cancelled_date_where = " AND _f_charge_discounts_cancelled.date_time::DATE = $q->{$pp{date}} "
		  if $pp{date};

		$sql_cancelled_between_dates .= qq {
    		  AND (
    			  _f_charge_discounts_cancelled.date_time >= $q->{ $pp{start_date} }
    			  AND _f_charge_discounts_cancelled.date_time < $q->{ $pp{end_date} }::DATE + INTERVAL '1 DAY'
    		  )
    	  	} if $pp{start_date} && $pp{end_date};

		$LJ_cancelled = undef;

	}

	my $sql_not_cancelled = ' AND _f_charge_discounts_cancelled.charge_discount_id IS NULL '
	  if $pp{not_cancelled};

	my $sql_client_id_where = " AND _f_charges.client_id = $q->{$pp{client_id}} " if $pp{client_id};

	my $sql = qq {
	SELECT 	_f_charge_discounts.id,_f_charge_discounts.charge_id,_f_charge_discounts.discount_id,
		_f_charge_discounts.discount_name,_f_charge_discounts.discount_amount,
		_f_charge_discounts.original_amount,_f_charge_discounts.post_discount_amount,
		_f_charge_discounts.date_time,_f_charge_discounts.notes,
		_f_charge_discounts.admin_id,ADMINS.name,ADMINS.lastname1,ADMINS.lastname2,
		_f_charges.client_id,CLIENTS.name,CLIENTS.lastname1,CLIENTS.lastname2,
		_f_charge_discounts_cancelled.discount_amount,_f_charge_discounts_cancelled.admin_id,
		_f_charge_discounts_cancelled.date_time,_f_charge_discounts_cancelled.notes,
		CANCELLED_ADMIN.name,CANCELLED_ADMIN.lastname1,CANCELLED_ADMIN.lastname2
	FROM 	_f_charge_discounts
	JOIN 	_f_charges ON ( _f_charges.id = _f_charge_discounts.charge_id )
	JOIN 	_g_users ADMINS ON ( ADMINS.id = _f_charge_discounts.admin_id )
	JOIN 	_g_users CLIENTS ON ( CLIENTS.id = _f_charges.client_id )
	$LJ_cancelled JOIN _f_charge_discounts_cancelled
		ON ( _f_charge_discounts_cancelled.charge_discount_id = _f_charge_discounts.id )
	$LJ_cancelled JOIN _g_users CANCELLED_ADMIN ON ( CANCELLED_ADMIN.id = _f_charge_discounts_cancelled.admin_id )
	WHERE 	 TRUE
	$sql_date_where
	$sql_between_dates
	$sql_cancelled_date_where
	$sql_cancelled_between_dates
	$sql_not_cancelled
	$sql_client_id_where
	$sql_where
	ORDER BY _f_charge_discounts.date_time DESC
	$sql_limit
	};

	my @items;
	my @keys = qw/id charge_id discount_id discount_name discount_amount
	  original_amount post_discount_amount date_time discount_notes
	  admin_id _admin_name _admin_lastname1 _admin_lastname2
	  client_id _client_name _client_lastname1 _client_lastname2
	  cancelled_discount_amount cancelled_admin_id cancelled_date_time
	  cancelled_notes _cancelled_name _cancelled_lastname1 _cancelled_lastname2
	  /;

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

		push @items, \%ii;

	}

	$sth->finish();

	return undef unless scalar @items;
	return $items[0] if $pp{limit} == 1;
	return \@items;

}

sub get_day_total {

	my ( $x, %pp ) = @_;

	my $sql = qq {
	SELECT 	SUM(_f_charge_discounts.discount_amount)
	FROM 	_f_charge_discounts
	WHERE 	_f_charge_discounts.date_time::DATE = NOW()::DATE;
	};

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );
	my $amount = $sth->fetchrow();
	$sth->finish();

	$amount //= 0;

	return $amount;

}

sub get_history {

	my ( $x, %pp ) = @_;

	return undef unless $pp{discount_id};

	my $q = $x->get_quote();

	my $sql_discount_id_where = " AND _f_charge_discounts.discount_id = $q->{$pp{discount_id}} ";

	my $sql_date_where;
	my $sql_cancelled_date_where;

	if ( $pp{start_date} && $pp{end_date} ) {
		$sql_date_where = qq {
	  		  AND (
	  			  _f_charge_discounts.date_time >= $q->{ $pp{start_date} }
	  			  AND _f_charge_discounts.date_time < $q->{ $pp{end_date} }::DATE + INTERVAL '1 DAY'
	  		  )
	  	  };
	}
	elsif ( $pp{date} ) {
		$sql_date_where = " AND _f_charge_discounts.date_time::DATE = $q->{$pp{date}} ";
	}
	elsif ( $pp{current_date} ) {
		$sql_date_where = ' AND _f_charge_discounts.date_time = NOW()::DATE ';
	}

	if ($sql_date_where) {
		$sql_cancelled_date_where = $sql_date_where;
		$sql_cancelled_date_where =~ s/_f_charge_discounts/_f_charge_discounts_cancelled/g;
	}

	my $sql_limit = ' LIMIT ' . $pp{limit} if $pp{limit};

	my $sql = qq {
	SELECT	'DISCOUNT',_f_charge_discounts.id,_f_charge_discounts.charge_id,_f_charge_discounts.discount_name,
		_f_charge_discounts.original_amount,_f_charge_discounts.post_discount_amount,
		_f_charge_discounts.date_time DISCOUNT_DATE_TIME,_f_charge_discounts.admin_id,
		_f_charge_discounts.notes,_f_charges.client_id,_g_users.name,_g_users.lastname1,
		_g_users.lastname2,ADMINS.name,ADMINS.lastname1,ADMINS.lastname2
	FROM	_f_charge_discounts
	JOIN 	_f_charges ON (_f_charges.id = _f_charge_discounts.charge_id)
	JOIN 	_g_users ON ( _g_users.id = _f_charges.client_id )
	JOIN 	_g_users ADMINS ON ( ADMINS.id = _f_charge_discounts.admin_id )
	WHERE TRUE
	$sql_discount_id_where
	$sql_date_where

	UNION ALL

	SELECT	'CANCELLED',_f_charge_discounts.id,_f_charge_discounts.charge_id,_f_charge_discounts.discount_name,
		_f_charge_discounts.original_amount,_f_charge_discounts.post_discount_amount,
		_f_charge_discounts_cancelled.date_time,_f_charge_discounts_cancelled.admin_id,
		_f_charge_discounts_cancelled.notes,_f_charges.client_id,_g_users.name,_g_users.lastname1,
		_g_users.lastname2,ADMINS.name,ADMINS.lastname1,ADMINS.lastname2
	FROM	_f_charge_discounts_cancelled
	JOIN 	_f_charge_discounts ON (_f_charge_discounts.id = _f_charge_discounts_cancelled.charge_discount_id)
	JOIN 	_f_charges ON (_f_charges.id = _f_charge_discounts.charge_id)
	JOIN 	_g_users ON ( _g_users.id = _f_charges.client_id )
	JOIN 	_g_users ADMINS ON ( ADMINS.id = _f_charge_discounts.admin_id )
	WHERE TRUE
	$sql_discount_id_where
	$sql_cancelled_date_where

	ORDER BY DISCOUNT_DATE_TIME DESC
	$sql_limit
	};

	my @items;
	my @keys = qw/type_code id charge_id discount_name _original_amount _post_discount_amount
	  date_time admin_id notes client_id _client_name _client_lastname1 _client_lastname2
	  _admin_name _admin_lastname1 _admin_lastname2/;

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

		$ii{discount_amount} = $ii{_original_amount} - $ii{_post_discount_amount};

		foreach my $key ( keys %ii ) {
			delete $ii{$key} if substr( $key, 0, 1 ) eq '_';
		}

		push @items, \%ii;

	}

	$sth->finish();

	return scalar @items ? \@items : undef;

}

sub get_timeframe_discounts {

	my ( $x, %pp ) = @_;

	my %discounts;
	my %amounts;

	my $q = $x->get_quote();
	my $sql_item_id_where = " AND _f_charge_discounts.discount_id = $q->{$pp{discount_id}} " if $pp{discount_id};

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
	SELECT	_f_charge_discounts.discount_id,_f_charges.creation_date_time::DATE,
		SUM(_f_charge_discounts.original_amount - _f_charge_discounts.post_discount_amount)
	FROM	_f_charge_discounts
	JOIN 	_f_charges ON (_f_charges.id = _f_charge_discounts.charge_id)
	WHERE  	TRUE
	$sql_item_id_where
	$sql_date_where
	AND NOT EXISTS (
		SELECT 	1
		FROM 	_f_charge_discounts_cancelled
		WHERE 	_f_charge_discounts_cancelled.charge_discount_id = _f_charge_discounts.id
	)
	GROUP BY _f_charge_discounts.discount_id,_f_charges.creation_date_time::DATE
	};

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );
	while ( my ( $discount_id, $date, $amount ) = $sth->fetchrow() ) {

		# dont format the date here so that perl sort keys works correctly
		$amounts{$date}          += $amount;
		$discounts{$discount_id} += $amount;
	}
	$sth->finish();

	return undef unless scalar keys %amounts;
	my @dates      = sort keys %amounts;
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
			total => %amounts{$date} || 0,
		  };
	}

	return { products => \%discounts, dates => \@dates };

}

1;
