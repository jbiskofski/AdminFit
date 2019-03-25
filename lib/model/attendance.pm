package model::attendance;

use strict;
use base 'model::base';
use Sort::Key 'rkeysort';

sub new {

	my ( $n, $dbh ) = @_;

	my $x = {
		dbh => $dbh,
		m   => model::init->new($dbh)
	};

	bless $x;
	return $x;

}

sub get_attendance {

	my ( $x, %pp ) = @_;

	my $sql_where = $x->generate_sql_where(%pp) if scalar keys %pp;
	my $sql_limit = " LIMIT $pp{limit} "        if $pp{limit};

	my $q = $x->get_quote();

	my $sql_date_where = ' AND _a_attendance.date = NOW()::DATE ' if $pp{current_date};
	$sql_date_where = " AND _a_attendance.date = $q->{$pp{date}} " if $pp{date};

	my $sql_between_dates;
	if ( $pp{start_date} && $pp{end_date} ) {
		$sql_between_dates = qq {
	  		  AND (
	  			  _a_attendance.date >= $q->{ $pp{start_date} }
	  			  AND _a_attendance.date < $q->{ $pp{end_date} }::DATE + INTERVAL '1 DAY'
	  		  )
	  	  };
		$sql_date_where = undef;
	}

	my $sql_hour_where = qq {
		AND EXTRACT('HOUR' FROM _a_attendance.time) = EXTRACT('HOUR' FROM NOW())
	} if $pp{current_hour};

	$sql_hour_where = " AND EXTRACT('HOUR' FROM _a_attendance.time) = $pp{hour} " if $pp{hour};

	my $sql_month_where = " AND EXTRACT(MONTH FROM _a_attendance.date) = $pp{month} " if $pp{month};
	my $sql_year_where  = " AND EXTRACT(YEAR FROM _a_attendance.date) = $pp{year} "   if $pp{year};

	my $sql_order = ' ORDER BY _a_attendance.date DESC ';
	$sql_order = qq {
		ORDER BY CLIENTS.lastname1 ASC, CLIENTS.lastname2 ASC,
			 CLIENTS.name ASC,_a_attendance.date DESC
	} if $pp{order_by_client_date_time};

	my $sql = qq {
	SELECT	_a_attendance.client_id,_a_attendance.date,_a_attendance.admin_id,
		ADMINS.name,ADMINS.lastname1,ADMINS.lastname2,
		CLIENTS.name,CLIENTS.lastname1,CLIENTS.lastname2,CLIENTS.is_client,
		ARRAY_AGG(_a_attendance.id),
		ARRAY_AGG(_a_attendance.time),
		ARRAY_AGG(_a_attendance.cancelled),
		ARRAY_AGG(_a_attendance.cancelled_admin_id),
		ARRAY_AGG(_a_attendance.cancelled_notes),
		ARRAY_AGG(CANCELLED_ADMINS.name),
		ARRAY_AGG(CANCELLED_ADMINS.lastname1),
		ARRAY_AGG(CANCELLED_ADMINS.lastname2),
		ARRAY_AGG(_a_attendance.visits_charge_id),
		ARRAY_AGG(_f_charges.creation_date_time),
		ARRAY_AGG(_i_items.name)
	FROM	_a_attendance
	LEFT JOIN _f_charges ON (_f_charges.id = _a_attendance.visits_charge_id)
	LEFT JOIN _i_inventory_sales ON (_i_inventory_sales.id = _f_charges.item_sale_id)
	LEFT JOIN _i_items ON (_i_items.id = _i_inventory_sales.item_id)
	JOIN 	_g_users ADMINS ON ( ADMINS.id = _a_attendance.admin_id )
	JOIN 	_g_users CLIENTS ON ( CLIENTS.id = _a_attendance.client_id )
	LEFT JOIN _g_users CANCELLED_ADMINS ON (
		CANCELLED_ADMINS.id = _a_attendance.cancelled_admin_id
		AND _a_attendance.cancelled = TRUE
	)
	WHERE 	TRUE
	$sql_where
	$sql_date_where
	$sql_hour_where
	$sql_month_where
	$sql_year_where
	$sql_between_dates
	GROUP BY _a_attendance.client_id,_a_attendance.date,_a_attendance.admin_id,
		 ADMINS.name,ADMINS.lastname1,ADMINS.lastname2,
		 CLIENTS.name,CLIENTS.lastname1,CLIENTS.lastname2,CLIENTS.is_client
	$sql_order
	$sql_limit
	};

	my @items;
	my @keys = qw/client_id date admin_id _admin_name _admin_lastname1
	  _admin_lastname2 _client_name _client_lastname1 _client_lastname2 is_client
	  _ARRAY_attendance_ids
	  _ARRAY_times
	  _ARRAY_cancelled
	  _ARRAY_cancelled_admin_ids
	  _ARRAY_cancelled_notes
	  _ARRAY_cancelled_admin_names
	  _ARRAY_cancelled_admin_lastnames1
	  _ARRAY_cancelled_admin_lastnames2
	  _ARRAY_visit_charge_ids
	  _ARRAY_charge_date_times
	  _ARRAY_visits_names
	  /;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;
		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}

		$ii{date} = global::date_time->format_date( $ii{date} );

		foreach my $time ( @{ $ii{_ARRAY_times} } ) {
			$time = global::date_time->format_time($time);
		}

		my $unsorted = global::standard->hashify_arrays(
			keys => [
				'id',                         'time',                       'cancelled',       'cancelled_admin_id', 'cancelled_notes', '_cancelled_admin_name',
				'_cancelled_admin_lastname1', '_cancelled_admin_lastname2', 'visit_charge_id', 'charge_date_time',   'visits_package_name'
			],
			items => [
				$ii{_ARRAY_attendance_ids},   $ii{_ARRAY_times},                 $ii{_ARRAY_cancelled},                  $ii{_ARRAY_cancelled_admin_ids},
				$ii{_ARRAY_cancelled_notes},  $ii{_ARRAY_cancelled_admin_names}, $ii{_ARRAY_cancelled_admin_lastnames1}, $ii{_ARRAY_cancelled_admin_lastnames2},
				$ii{_ARRAY_visit_charge_ids}, $ii{_ARRAY_charge_date_times},     $ii{_ARRAY_visits_names}
			],
			unique => 'id',
		);

		my @sorted = rkeysort { $_->{time} } @{$unsorted};

		foreach my $tt (@sorted) {
			$tt->{charge_date_time} = global::date_time->format_date_time( $tt->{charge_date_time} );
			$tt->{display_cancelled_name} = global::standard->get_person_display_name( $tt->{_cancelled_admin_name}, $tt->{_cancelled_admin_lastname1}, $tt->{_cancelled_admin_lastname2} );
			delete $tt->{_cancelled_admin_name};
			delete $tt->{_cancelled_admin_lastname1};
			delete $tt->{_cancelled_admin_lastname2};
		}

		$ii{times} = \@sorted;

		$ii{display_admin_name}  = global::standard->get_person_display_name( $ii{_admin_name},  $ii{_admin_lastname1},  $ii{_admin_lastname2} );
		$ii{display_client_name} = global::standard->get_person_display_name( $ii{_client_name}, $ii{_client_lastname1}, $ii{_client_lastname2} );
		$ii{date_epoch}          = global::date_time->get_epoch( $ii{date} );

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

sub get_attendees {

	my $x = shift;

	my $sql = qq {
	SELECT 	COUNT(*)
	FROM	(
		SELECT 	DISTINCT client_id
		FROM 	_a_attendance
		WHERE 	_a_attendance.date = NOW()::DATE
		AND 	_a_attendance.cancelled = FALSE
	) AS SS
	};

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );
	my $count = $sth->fetchrow();
	$sth->finish();

	$count //= 0;

	return $count;

}

sub get_month_summary {

	my ( $x, %pp ) = @_;

	my $parts = global::date_time->get_date_time_parts();

	my $month = $pp{month} || $parts->{month};
	my $year  = $pp{year}  || $parts->{year};
	my $display_month = global::date_time->get_display_month($month);

	my $sql = qq {
	SELECT	EXTRACT(DAY FROM ATTENDANCE_DATE) AS DATE,COUNT(*)
	FROM	(
		SELECT 	DISTINCT _a_attendance.client_id,
			_a_attendance.date AS ATTENDANCE_DATE,_a_attendance.client_id
		FROM 	_a_attendance
		WHERE 	EXTRACT(MONTH FROM _a_attendance.date) = $pp{month}
		AND 	EXTRACT(YEAR FROM _a_attendance.date) = $pp{year}
		AND 	_a_attendance.cancelled = FALSE
	) AS SS
	GROUP BY ATTENDANCE_DATE
	};

	my %days;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );
	while ( my ( $day, $attendance ) = $sth->fetchrow() ) {
		$days{$day} = $attendance;
	}
	$sth->finish();

	return \%days;

}

sub get_user_total_days {

	my ( $x, $user_id ) = @_;

	my $q = $x->get_quote();

	my $sql = qq {
	SELECT 	DISTINCT ON(_a_attendance.date) COUNT(*)
	FROM 	_a_attendance
	WHERE 	_a_attendance.client_id = $q->{$user_id}
	GROUP BY _a_attendance.date
	};

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );
	my $attendance_days = $sth->fetchrow();
	$sth->finish();

	return $attendance_days || 0;

}

1;
