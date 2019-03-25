package model::users;

use strict;
use base 'model::base';
use Sort::Key 'keysort';

sub new {

	my ( $n, $dbh ) = @_;

	my $x = {
		dbh => $dbh,
		m   => model::init->new($dbh)
	};

	bless $x;
	return $x;

}

sub get_users {

	my ( $x, %pp ) = @_;

	my $sql_where = $x->generate_sql_where(%pp) if scalar keys %pp;
	my $sql_limit = " LIMIT $pp{limit} "        if $pp{limit};

	my $sql_birthday_where;

	$sql_birthday_where = qq {
		AND _g_users.active = TRUE
		AND EXTRACT (
			DOY FROM (
				EXTRACT(DAY FROM _g_users.birthday)::VARCHAR || '/' ||
	                 	EXTRACT(MONTH FROM _g_users.birthday)::VARCHAR || '/'  ||
	                 	EXTRACT(YEAR FROM NOW())::VARCHAR
			 )::DATE
		) - EXTRACT(DOY FROM NOW() ) = 0
	} if $pp{todays_birthdays};

	$sql_birthday_where = qq {
		AND _g_users.active = TRUE
		AND EXTRACT (
			DOY FROM (
				EXTRACT(DAY FROM _g_users.birthday)::VARCHAR || '/' ||
	                 	EXTRACT(MONTH FROM _g_users.birthday)::VARCHAR || '/'  ||
	                 	EXTRACT(YEAR FROM NOW())::VARCHAR
			 )::DATE
		) - EXTRACT(DOY FROM NOW() ) BETWEEN 0 AND 7
	} if $pp{upcoming_birthdays};

	my $sql_order = ' ORDER BY _g_users.active DESC, _g_users.lastname1 ASC, _g_users.lastname2 ASC, _g_users.name ASC ';

	my $sql = qq {
	SELECT	_g_users.id,_g_users.username,_g_users.strikes,_g_users.suspended_date_time,
		_g_users.create_date_time,_g_users.create_date_time::DATE,
		_g_users.active,_g_users.scrypt_password,
		_g_users.password_recovery_enabled,_g_users.email,_g_users.name,
		_g_users.lastname1,_g_users.lastname2,_g_users.birthday,
		_g_users.is_admin,_g_users.is_coach,_g_users.is_client,
		_g_users.address,_g_users.city,_g_users.state,_g_users.zipcode,
		_g_users.notes,_g_users.telephone,_g_users.has_picture,_g_users.has_profile_picture,
		_g_users.data,
		_g_users.nickname,_g_users.occupation,
		DATE_PART( 'YEAR', AGE(_g_users.birthday) ) AS BIRTHDAY,
		_g_users.allow_client_access,_g_users.gender,_g_users.is_permanent,
		_g_users.deactivation_date_time,_g_users.deactivation_admin_id
	FROM	_g_users
	WHERE 	TRUE
	$sql_where
	$sql_birthday_where
	$sql_order
	$sql_limit
	};

	my @items;
	my @keys = qw/id username strikes suspended_date_time
	  create_date_time create_date active scrypt_password password_recovery_enabled
	  email name lastname1 lastname2 birthday is_admin is_coach is_client
	  address city state zipcode notes telephone has_picture has_profile_picture
	  json_data nickname occupation age allow_client_access
	  gender is_permanent deactivation_date_time deactivation_admin_id/;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;
		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}

		$ii{create_date_time}    = global::date_time->format_date_time( $ii{create_date_time} );
		$ii{create_date}         = global::date_time->format_date( $ii{create_date} );
		$ii{suspended_date_time} = global::date_time->format_date_time( $ii{suspended_date_time} );
		$ii{birthday}            = global::date_time->format_date( $ii{birthday} );

		$ii{display_name} = global::standard->get_person_display_name( $ii{name}, $ii{lastname1}, $ii{lastname2} );
		$ii{data}         = JSON::XS->new()->latin1()->decode( $ii{json_data} );
		$ii{telephone}    = undef if !$ii{telephone} || $ii{telephone} eq '0000-00-00-00';
		$ii{is_staff}     = 1 if $ii{is_admin} || $ii{is_coach};

		$ii{deactivation_date_time} = global::date_time->format_date_time( $ii{deactivation_date_time} )
		  if $ii{deactivation_date_time};

		push @items, \%ii;

	}

	$sth->finish();

	return undef unless scalar @items;
	return $items[0] if $pp{limit} == 1;
	return \@items;

}

sub search {

	my ( $x, %pp ) = @_;

	my $q = $x->get_quote();

	my $sql = qq {
	SELECT	_g_users.id,_g_users.active,_g_users.name,_g_users.lastname1,_g_users.lastname2,
		_g_users.nickname,_g_users.has_picture,_g_users.has_profile_picture,
		_g_users.is_admin,_g_users.is_coach,_g_users.is_client,
		SIMILARITY( _g_users.search_vectors, $q->{$pp{search}} ) AS RANKING
	FROM	_g_users
	WHERE 	_g_users.search_vectors ILIKE $q->{'%' . $pp{search} . '%'}
	ORDER BY RANKING
	LIMIT 5
	};

	my @items;
	my @keys = qw/id active name lastname1 lastname2 nickname
	  has_picture has_profile_picture
	  is_admin is_coach is_client ranking/;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;
		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}

		my $display_name = global::standard->get_person_display_name( $ii{name}, $ii{lastname1}, $ii{lastname2} );
		$display_name .= ' ( ' . $ii{nickname} . ' )' if $ii{nickname};

		my $is_staff = $ii{is_admin} || $ii{is_coach} ? 1 : 0;

		my $image_tag = global::ttf->avatar(
			id                  => $ii{id},
			has_profile_picture => $ii{has_profile_picture},
			has_picture         => $ii{has_picture},
			name                => $display_name,
			small               => 1,
		);

		push @items,
		  {
			id        => $ii{id},
			active    => $ii{active},
			image_tag => $image_tag,
			name      => $display_name,
			is_staff  => $is_staff,
			is_client => $ii{is_client},
		  };

	}

	$sth->finish();

	return scalar @items ? \@items : undef;

}

sub get_birthdays {

	my $x = shift;

	my $users = $x->get_users( upcoming_birthdays => 1 );

	return {
		today    => undef,
		upcoming => undef,
	} unless $users;

	my @today;
	my @upcoming;

	my $date_parts = global::date_time->get_date_time_parts();

	foreach my $uu ( @{$users} ) {

		my $parts = global::date_time->get_date_time_parts( $uu->{birthday} );

		if ( $parts->{month} == $date_parts->{month} && $parts->{day} == $date_parts->{day} ) {
			push @today, $uu;
		}
		else {
			push @upcoming, $uu;
		}

	}

	return {
		today    => \@today,
		upcoming => \@upcoming,
	};

}

sub get_calendar {

	my ( $x, %pp ) = @_;

	my $parts = global::date_time->get_date_time_parts();

	my $month = $pp{month} || $parts->{month};
	my $year  = $pp{year}  || $parts->{year};
	my $display_month = global::date_time->get_display_month($month);

	my $calendar = global::date_time->get_calendar(
		month => $month,
		year  => $year,
	);

	my $attendance_tmp = $x->{m}->{attendance}->get_attendance(
		where => { '_a_attendance.client_id' => $pp{user_id} },
		month => $month,
		year  => $year,
	);

	my $payments = $x->{m}->{payments}->get_client_month_payments(
		user_id       => $pp{user_id},
		payment_month => $month,
		payment_year  => $year,
	);

	my %attendance;
	my %totals;

	if ($attendance_tmp) {
		foreach my $aa ( @{$attendance_tmp} ) {
			my ($day) = split( /\D+/, $aa->{date} );
			$day = int($day);
			$attendance{$day} = scalar @{ $aa->{times} } || 0;
			$totals{attendance_days}++ if $attendance{$day};
			$totals{attendance_total} += $attendance{$day};

		}
	}

	foreach my $ww ( @{$calendar} ) {
		foreach my $dd ( @{$ww} ) {
			my $day = int( $dd->{day} );
			$dd->{data}->{attendance}  = $attendance{$day} || 0;
			$dd->{data}->{payments}    = $payments->{$day};
			$dd->{data}->{renewal_day} = 1 if $pp{renewal_day} == $day;
			$totals{payments} += $payments->{$day}->{total};
		}
	}

	return {
		weeks         => $calendar,
		month         => $month,
		display_month => $display_month,
		year          => $year,
		totals        => \%totals,
	};

}

sub get_month_enrollments {

	my ( $x, %pp ) = @_;

	my %days;

	my $parts = global::date_time->get_date_time_parts();

	my $month = $pp{month} || $parts->{month};
	my $year  = $pp{year}  || $parts->{year};
	my $display_month = global::date_time->get_display_month($month);

	my $sql = qq {
	SELECT 	EXTRACT(DAY FROM _g_users.create_date_time),ARRAY_AGG(DISTINCT _g_users.id)
	FROM 	_g_users
	WHERE 	_g_users.is_client = TRUE
	AND 	EXTRACT(MONTH FROM _g_users.create_date_time) = $month
	AND 	EXTRACT(YEAR FROM _g_users.create_date_time) = $year
	GROUP BY EXTRACT(DAY FROM _g_users.create_date_time)
	};

	my $total_enrollments = 0;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );
	while ( my ( $day, $client_ids ) = $sth->fetchrow() ) {
		$days{ int($day) } = $client_ids;
		$total_enrollments += scalar @{$client_ids};
	}
	$sth->finish();

	return undef unless scalar keys %days;
	return {
		total => $total_enrollments,
		days  => \%days
	};

}

sub get_dropouts {

	my ( $x, %pp ) = @_;

	my %days;

	my $parts = global::date_time->get_date_time_parts();

	my $month = $pp{month} || $parts->{month};
	my $year  = $pp{year}  || $parts->{year};
	my $display_month = global::date_time->get_display_month($month);

	my $sql = qq {
	SELECT 	EXTRACT(DAY FROM _g_users.deactivation_date_time::DATE),ARRAY_AGG(DISTINCT _g_users.id)
	FROM 	_g_users
	WHERE 	_g_users.is_client = TRUE
	AND 	_g_users.active = FALSE
	AND 	EXTRACT(MONTH FROM _g_users.deactivation_date_time::DATE) = $month
	AND 	EXTRACT(YEAR FROM _g_users.deactivation_date_time::DATE) = $year
	GROUP BY EXTRACT(DAY FROM _g_users.deactivation_date_time::DATE)

	UNION

	SELECT 	EXTRACT(DAY FROM _g_deleted_users.date_time::DATE),ARRAY_AGG(DISTINCT _g_deleted_users.id)
	FROM 	_g_deleted_users
	WHERE 	EXTRACT(MONTH FROM _g_deleted_users.date_time::DATE) = $month
	AND 	EXTRACT(YEAR FROM _g_deleted_users.date_time::DATE) = $year
	GROUP BY EXTRACT(DAY FROM _g_deleted_users.date_time::DATE)
	};

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );
	while ( my ( $day, $client_ids ) = $sth->fetchrow() ) {

		if ( $days{ int($day) } ) {
			$days{ int($day) } = [ @{ $days{ int($day) } }, @{$client_ids} ];
		}
		else {
			$days{ int($day) } = $client_ids;
		}

	}
	$sth->finish();

	return undef unless scalar keys %days;
	return \%days;

}

sub get_deleted_users {

	my ( $x, %pp ) = @_;

	my $q = $x->get_quote();

	my $sql_where = $x->generate_sql_where(%pp) if scalar keys %pp;
	my $sql_date_where = " AND _g_deleted_users.date_time::DATE = $q->{$pp{date}} " if $pp{date};

	my $sql = qq {
        SELECT	_g_deleted_users.id,_g_deleted_users.name,_g_deleted_users.lastname1,
		_g_deleted_users.lastname2,_g_deleted_users.notes,_g_deleted_users.date_time,
		_g_deleted_users.total_debt_amount,_g_deleted_users.total_attendance_days,
		_g_deleted_users.membership_name,
		_g_users.name,_g_users.lastname1,_g_users.lastname2,_g_users.create_date_time::DATE
        FROM 	_g_deleted_users
	JOIN 	_g_users ON (_g_users.id = _g_deleted_users.admin_id)
        WHERE   TRUE
	$sql_where
	$sql_date_where
	ORDER BY _g_deleted_users.date_time DESC
        };

	my @items;
	my @keys = qw/id name lastname1 lastname2 notes date_time
	  total_debt_amount total_attendance_days membership_name
	  admin_name admin_lastname1 admin_lastname2 create_date/;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;
		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}

		$ii{is_deleted_user}    = 1;
		$ii{display_name}       = global::standard->get_person_display_name( $ii{name}, $ii{lastname1}, $ii{lastname2} );
		$ii{admin_display_name} = global::standard->get_person_display_name( $ii{admin_name}, $ii{admin_lastname1}, $ii{admin_lastname2} );
		$ii{date_time}          = global::date_time->format_date_time( $ii{date_time} );
		$ii{create_date}        = global::date_time->format_date( $ii{create_date} );

		push @items, \%ii;

	}

	$sth->finish();

	return undef unless scalar @items;
	return $items[0] if $pp{limit} == 1;
	return \@items;

}
1;
