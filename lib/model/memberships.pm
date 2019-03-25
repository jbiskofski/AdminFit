package model::memberships;

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

sub get_memberships {

	my ( $x, %pp ) = @_;

	my $sql_where = $x->generate_sql_where(%pp) if scalar keys %pp;
	my $sql_limit = " LIMIT $pp{limit} "        if $pp{limit};

	my $sql = qq {
	SELECT	_f_memberships.id,_f_memberships.name,_f_memberships.amount,
		_f_memberships.type_code,_f_memberships.group_maximum_members,
		_f_memberships.is_default,_f_memberships.notes,
		_f_memberships.active,_f_memberships.is_permanent,
		_f_memberships.is_free_membership,_f_memberships.is_visits_membership,
		_f_memberships.has_timeframe_limitations,
		_f_memberships.limit_dow_0,_f_memberships.limit_dow_1,_f_memberships.limit_dow_2,
		_f_memberships.limit_dow_3,_f_memberships.limit_dow_4,_f_memberships.limit_dow_5,
		_f_memberships.limit_dow_6,_f_memberships.limit_hour_0,
		_f_memberships.limit_hour_1,_f_memberships.limit_hour_2,_f_memberships.limit_hour_3,
		_f_memberships.limit_hour_4,_f_memberships.limit_hour_5,_f_memberships.limit_hour_6,
		_f_memberships.limit_hour_7,_f_memberships.limit_hour_8,_f_memberships.limit_hour_9,
		_f_memberships.limit_hour_10,_f_memberships.limit_hour_11,_f_memberships.limit_hour_12,
		_f_memberships.limit_hour_13,_f_memberships.limit_hour_14,_f_memberships.limit_hour_15,
		_f_memberships.limit_hour_16,_f_memberships.limit_hour_17,_f_memberships.limit_hour_18,
		_f_memberships.limit_hour_19,_f_memberships.limit_hour_20,_f_memberships.limit_hour_21,
		_f_memberships.limit_hour_22,_f_memberships.limit_hour_23
	FROM	_f_memberships
	WHERE 	TRUE
	$sql_where
	ORDER BY _f_memberships.is_default DESC, _f_memberships.active DESC,_f_memberships.name ASC
	$sql_limit
	};

	my @items;
	my @keys = qw/id name amount type_code group_maximum_members
	  is_default notes active is_permanent is_free_membership
	  is_visits_membership has_timeframe_limitations
	  _limit_dow_0 _limit_dow_1 _limit_dow_2 _limit_dow_3 _limit_dow_4 _limit_dow_5 _limit_dow_6
	  _limit_hour_0 _limit_hour_1 _limit_hour_2 _limit_hour_3 _limit_hour_4 _limit_hour_5
	  _limit_hour_6 _limit_hour_7 _limit_hour_8 _limit_hour_9 _limit_hour_10 _limit_hour_11
	  _limit_hour_12 _limit_hour_13 _limit_hour_14 _limit_hour_15 _limit_hour_16 _limit_hour_17
	  _limit_hour_18 _limit_hour_19 _limit_hour_20 _limit_hour_21 _limit_hour_22 _limit_hour_23/;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;
		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}

		if ( $ii{type_code} eq 'G' ) {
			$ii{display_type} = 'Grupal';
			$ii{display_group_requirements} .= 'M&aacuteximo <b>' . $ii{group_maximum_members} . '</b> clientes.';
		}
		else {
			$ii{display_type} = 'Individual';
		}

		$ii{display_tip} = '$' . global::ttf->commify( $ii{amount} );
		$ii{display_tip} .= '<br>' . $ii{display_type};
		$ii{display_tip} .= '<br>' . $ii{display_group_requirements} if $ii{type_code} eq 'G';
		$ii{display_tip} .= '<br>' . $ii{notes} if $ii{notes};

		if ( $ii{has_timeframe_limitations} ) {
			my %dows;
			my %hours;
			foreach my $key ( keys %ii ) {
				next unless $key =~ /^_limit_(\S+)_(\d+)$/;
				my ( $type, $value ) = ( $1, $2 );
				$dows{ int($value) }  = 1 if $ii{$key} && $type eq 'dow';
				$hours{ int($value) } = 1 if $ii{$key} && $type eq 'hour';
			}
			$ii{limit_dows}  = \%dows;
			$ii{limit_hours} = \%hours;
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

sub get_visit_memberships {

	my ( $x, %pp ) = @_;

	return undef unless $pp{client_ids} || $pp{client_id} || $pp{charge_id};

	my $q = $x->get_quote();

	push @{ $pp{client_ids} }, $pp{client_id} if $pp{client_id} && !$pp{client_ids};

	my $sql_client_id_in = $x->generate_in(
		table => '_g_client_visits',
		field => 'client_id',
		items => $pp{client_ids},
	) if $pp{client_ids} && scalar @{ $pp{client_ids} };

	my $sql_limit = " LIMIT $pp{limit} " if $pp{limit};
	my $sql_charge_id_where = " AND _f_charges.id = $q->{$pp{charge_id}} " if $pp{charge_id};

	my $sql = qq {
	SELECT  _g_client_visits.client_id,_g_client_visits.charge_id,_g_client_visits.visit_number,
		_g_client_visits.visits_expiration_date,_g_client_visits.visits_used,
		_g_client_visits.visits_remaining,
		( NOW() > _g_client_visits.visits_expiration_date ),
		_f_charges_cancelled.charge_id IS NOT NULL,
		_f_charges.amount,_i_items.name,
		EXTRACT(EPOCH FROM _f_charges.creation_date_time)
	FROM	_g_client_visits
	JOIN 	_f_charges ON ( _f_charges.id = _g_client_visits.charge_id )
	JOIN 	_f_client_memberships ON ( _f_client_memberships.client_id = _g_client_visits.client_id )
	JOIN 	_f_memberships ON ( _f_memberships.id = _f_client_memberships.membership_id )
	JOIN 	_i_inventory_sales ON ( _i_inventory_sales.id = _f_charges.item_sale_id )
	JOIN 	_i_items ON ( _i_items.id = _i_inventory_sales.item_id )
	LEFT JOIN _f_charges_cancelled ON ( _f_charges_cancelled.charge_id = _g_client_visits.charge_id )
	WHERE 	_f_memberships.is_visits_membership = TRUE
	$sql_client_id_in
	$sql_charge_id_where
	ORDER BY _f_charges.creation_date_time DESC,_g_client_visits.client_id
	$sql_limit
	};

	my %clients;
	my @keys = qw/client_id charge_id visit_number visits_expiration_date
	  visits_used visits_remaining expired is_cancelled amount item_name epoch/;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;
		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}
		next if $clients{ $ii{client_id} };

		$ii{visits_expiration_date} = global::date_time->format_date( $ii{visits_expiration_date} );
		$clients{ $ii{client_id} } = \%ii;

		$ii{active} = 1;

		if ( $ii{visits_remaining} <= 0 ) {
			$ii{active}           = 0;
			$ii{visits_exhausted} = 1;
		}

		$ii{active} = 0 if $ii{expired} || $ii{is_cancelled};

	}

	$sth->finish();

	return undef unless scalar keys %clients;

	if ( $pp{limit} == 1 ) {
		my @values = values %clients;
		return $values[0];
	}

	return \%clients;

}

sub get_client_memberships {

	my ( $x, %pp ) = @_;

	my $sql_where = $x->generate_sql_where(%pp) if scalar keys %pp;
	my $sql_limit = " LIMIT $pp{limit} "        if $pp{limit};

	my $sql_renewal_filters = " AND _f_client_memberships.renewal_day = DATE_PART( 'DAY', NOW() ) "
	  if $pp{get_todays_renewals};

	my $sql_specific_day_filters = " AND _f_client_memberships.renewal_day = $pp{specific_day_renewals} "
	  if $pp{specific_day_renewals};

	my $sql = qq {
	SELECT 	_f_client_memberships.client_id,_f_client_memberships.membership_id,
		_f_client_memberships.renewal_day,_f_memberships.name,
		_f_memberships.amount,_f_memberships.type_code,
		_g_users.has_picture,_g_users.has_profile_picture,
		_g_users.name,_g_users.lastname1,_g_users.lastname2,
		_f_memberships.is_free_membership,_f_memberships.is_visits_membership,
		_f_memberships.has_timeframe_limitations,
		_f_memberships.limit_dow_0,_f_memberships.limit_dow_1,_f_memberships.limit_dow_2,
		_f_memberships.limit_dow_3,_f_memberships.limit_dow_4,_f_memberships.limit_dow_5,
		_f_memberships.limit_dow_6,_f_memberships.limit_hour_0,
		_f_memberships.limit_hour_1,_f_memberships.limit_hour_2,_f_memberships.limit_hour_3,
		_f_memberships.limit_hour_4,_f_memberships.limit_hour_5,_f_memberships.limit_hour_6,
		_f_memberships.limit_hour_7,_f_memberships.limit_hour_8,_f_memberships.limit_hour_9,
		_f_memberships.limit_hour_10,_f_memberships.limit_hour_11,_f_memberships.limit_hour_12,
		_f_memberships.limit_hour_13,_f_memberships.limit_hour_14,_f_memberships.limit_hour_15,
		_f_memberships.limit_hour_16,_f_memberships.limit_hour_17,_f_memberships.limit_hour_18,
		_f_memberships.limit_hour_19,_f_memberships.limit_hour_20,_f_memberships.limit_hour_21,
		_f_memberships.limit_hour_22,_f_memberships.limit_hour_23,
		_g_users.active
	FROM 	_f_client_memberships
	JOIN 	_f_memberships ON ( _f_memberships.id = _f_client_memberships.membership_id )
	JOIN 	_g_users ON ( _g_users.id = _f_client_memberships.client_id )
	WHERE 	TRUE
	$sql_where
	$sql_renewal_filters
	$sql_specific_day_filters
	$sql_limit
	};

	my @items;
	my %group_membership_ids;

	my @keys = qw/client_id membership_id renewal_day
	  name amount type_code has_picture has_profile_picture
	  client_name client_lastname1 client_lastname2
	  is_free_membership is_visits_membership has_timeframe_limitations
	  _limit_dow_0 _limit_dow_1 _limit_dow_2 _limit_dow_3 _limit_dow_4 _limit_dow_5 _limit_dow_6
	  _limit_hour_0 _limit_hour_1 _limit_hour_2 _limit_hour_3 _limit_hour_4 _limit_hour_5
	  _limit_hour_6 _limit_hour_7 _limit_hour_8 _limit_hour_9 _limit_hour_10 _limit_hour_11
	  _limit_hour_12 _limit_hour_13 _limit_hour_14 _limit_hour_15 _limit_hour_16 _limit_hour_17
	  _limit_hour_18 _limit_hour_19 _limit_hour_20 _limit_hour_21 _limit_hour_22 _limit_hour_23
	  user_active/;

	my %client_display_names;
	my %visits_membership_client_ids;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;

		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}

		$group_membership_ids{ $ii{membership_id} } = 1 if $ii{type_code} eq 'G';
		$ii{display_client_name} = global::standard->get_person_display_name( $ii{client_name}, $ii{client_lastname1}, $ii{client_lastname2} );
		$client_display_names{ $ii{client_id} } = $ii{display_client_name};
		$visits_membership_client_ids{ $ii{client_id} } = 1 if $ii{is_visits_membership};

		if ( $ii{has_timeframe_limitations} ) {
			my %dows;
			my %hours;
			foreach my $key ( keys %ii ) {
				next unless $key =~ /^_limit_(\S+)_(\d+)$/;
				my ( $type, $value ) = ( $1, $2 );
				$dows{ int($value) }  = 1 if $ii{$key} && $type eq 'dow';
				$hours{ int($value) } = 1 if $ii{$key} && $type eq 'hour';
			}
			$ii{limit_dows}  = \%dows;
			$ii{limit_hours} = \%hours;
		}

		foreach my $key ( keys %ii ) {
			delete $ii{$key} if substr( $key, 0, 1 ) eq '_';
		}

		push @items, \%ii;

	}

	$sth->finish();

	return undef unless scalar @items;

	if ( scalar keys %group_membership_ids ) {

		my $groups_tmp = $x->get_groups(
			in => {
				table => '_f_membership_groups',
				field => 'membership_id',
				items => [ keys %group_membership_ids ],
			}
		);

		if ($groups_tmp) {

			my %groups;
			my %group_membership_dependents = map { $_->{membership_group_id} => $_->{dependents} } @{$groups_tmp};

			foreach my $gg ( @{$groups_tmp} ) {

				$groups{ $gg->{membership_id} . ':' . $gg->{responsible_client_id} } = {
					membership_group_id                 => $gg->{membership_group_id},
					responsible_client_id               => $gg->{responsible_client_id},
					is_responsible_for_group_membership => 1,
				};

				$client_display_names{ $gg->{responsible_client_id} } = $gg->{display_name};

				if ( $gg->{dependents} && scalar @{ $gg->{dependents} } ) {
					foreach my $dd ( @{ $gg->{dependents} } ) {
						next unless $dd->{id};
						$groups{ $gg->{membership_id} . ':' . $dd->{id} } = {
							membership_group_id                 => $gg->{membership_group_id},
							responsible_client_id               => $gg->{responsible_client_id},
							is_responsible_for_group_membership => 0,
						};
					}
				}

			}

			foreach my $ii (@items) {

				next unless $ii->{type_code} eq 'G';

				my $key = $ii->{membership_id} . ':' . $ii->{client_id};
				$ii->{membership_group_id} = $groups{$key}->{membership_group_id};

				if ( $groups{$key}->{responsible_client_id} eq $ii->{client_id} ) {
					$ii->{is_responsible_for_group_membership} = 1;
				}
				else {
					$ii->{is_dependant}                        = 1;
					$ii->{is_responsible_for_group_membership} = 0;
					$ii->{amount}                              = 0;
				}

				$ii->{display_responsible_client_name} = $client_display_names{ $groups{$key}->{responsible_client_id} };

				$ii->{responsible_client_id} = $groups{$key}->{responsible_client_id};
				$ii->{dependents} = $group_membership_dependents{ $ii->{membership_group_id} } || undef;

			}

		}

	}

	@items = grep { $_->{is_responsible_for_group_membership} || $_->{type_code} ne 'G' } @items
	  if $pp{only_group_owners};

	return $items[0] if $pp{limit} == 1;
	return \@items;

}

sub get_groups {

	my ( $x, %pp ) = @_;

	my $sql_where = $x->generate_sql_where(%pp) if scalar keys %pp;
	my $sql_limit = " LIMIT $pp{limit} "        if $pp{limit};

	my $q = $x->get_quote();

	my $sql_exclude_dependent_client_id;
	my $sql_exclude_group_owner_id;

	if ( $pp{exclude_client_id} ) {
		$sql_exclude_dependent_client_id = " WHERE _f_membership_group_dependents.dependent_client_id <> $q->{$pp{exclude_client_id}} ";
		$sql_exclude_group_owner_id      = " AND _f_membership_groups.responsible_client_id <> $q->{$pp{exclude_client_id}} ";
	}

	my $sql = qq {
	SELECT  _f_membership_groups.id,_f_membership_groups.membership_id,
		_f_membership_groups.responsible_client_id,
		_g_users.lastname1,_g_users.lastname2,
		_g_users.name,_g_users.nickname,_g_users.has_picture,
		_g_users.has_profile_picture,
		_f_memberships.group_maximum_members,
		_f_memberships.type_code,
		_f_memberships.name,
		ARRAY_AGG( DEPENDENTS.CLIENT_ID ),
		ARRAY_AGG( DEPENDENTS.NAME ),
		ARRAY_AGG( DEPENDENTS.LASTNAME1 ),
		ARRAY_AGG( DEPENDENTS.LASTNAME2 ),
		ARRAY_AGG( DEPENDENTS.HAS_PROFILE_PICTURE ),
		ARRAY_AGG( DEPENDENTS.HAS_PICTURE )
	FROM 	_f_membership_groups
	JOIN    _f_memberships ON ( _f_memberships.id = _f_membership_groups.membership_id )
	JOIN 	_f_client_memberships ON (
		_f_client_memberships.client_id = _f_membership_groups.responsible_client_id
		AND _f_client_memberships.membership_id = _f_membership_groups.membership_id
	)
	JOIN	_g_users ON ( _g_users.id = _f_membership_groups.responsible_client_id )
	LEFT JOIN (
		SELECT 	_f_membership_group_dependents.membership_group_id AS GROUP_ID,
			_f_membership_group_dependents.dependent_client_id AS CLIENT_ID,
			_g_users.name AS NAME,
			_g_users.lastname1 AS LASTNAME1,
			_g_users.lastname2 AS LASTNAME2,
			_g_users.has_profile_picture AS HAS_PROFILE_PICTURE,
			_g_users.has_picture AS HAS_PICTURE
		FROM 	_f_membership_group_dependents
		JOIN 	_g_users ON ( _g_users.id = _f_membership_group_dependents.dependent_client_id AND _g_users.active = TRUE )
		$sql_exclude_dependent_client_id
	) AS DEPENDENTS ON ( DEPENDENTS.GROUP_ID = _f_membership_groups.id )
	WHERE _g_users.active = TRUE
	$sql_where
	$sql_exclude_group_owner_id
	GROUP BY _f_membership_groups.id,_f_membership_groups.membership_id,
		 _f_membership_groups.responsible_client_id,
		 _g_users.lastname1,_g_users.lastname2,
		 _g_users.name,_g_users.nickname,_g_users.has_picture,
		 _g_users.has_profile_picture,
		 _f_memberships.group_maximum_members,
		 _f_memberships.type_code,
		 _f_memberships.name
	$sql_limit
	};

	my @items;
	my @keys = qw/membership_group_id membership_id responsible_client_id
	  lastname1 lastname2 name nickname has_picture has_profile_picture
	  group_maximum_members type_code membership_name
	  _ARRAY_dependent_client_id
	  _ARRAY_dependent_client_name
	  _ARRAY_dependent_client_lastname1
	  _ARRAY_dependent_client_lastname2
	  _ARRAY_dependent_client_has_profile_picture
	  _ARRAY_dependent_client_has_picture
	  /;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;
		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}

		if ( $ii{type_code} eq 'G' ) {

			$ii{dependents} = global::standard->hashify_arrays(
				keys  => [ 'id', 'name', 'lastname1', 'lastname2', 'has_profile_picture', 'has_picture' ],
				items => [
					$ii{_ARRAY_dependent_client_id},        $ii{_ARRAY_dependent_client_name},                $ii{_ARRAY_dependent_client_lastname1},
					$ii{_ARRAY_dependent_client_lastname2}, $ii{_ARRAY_dependent_client_has_profile_picture}, $ii{_ARRAY_dependent_client_has_picture},
				],
				unique => 'id',
			);

			$ii{dependent_client_count}      = 1;
			$ii{available_dependent_clients} = $ii{group_maximum_members};

			if ( $ii{dependents} ) {

				foreach my $dd ( @{ $ii{dependents} } ) {
					$dd->{display_name} = global::standard->get_person_display_name( $dd->{name}, $dd->{lastname1}, $dd->{lastname2} );
				}

				$ii{dependent_client_count} += scalar @{ $ii{dependents} };

			}

			$ii{available_dependent_clients} -= $ii{dependent_client_count};

		}

		$ii{display_name} = global::standard->get_person_display_name( $ii{name}, $ii{lastname1}, $ii{lastname2} );

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

sub get_client_group {

	my ( $x, %pp ) = @_;

	return undef unless $pp{client_id};

	my $q = $x->get_quote();

	my $sql = qq {
	SELECT 	TRUE,_f_membership_groups.id,_f_membership_groups.membership_id
	FROM 	_f_membership_groups
	WHERE 	_f_membership_groups.responsible_client_id = $q->{$pp{client_id}}

	UNION ALL

	SELECT 	FALSE,_f_membership_group_dependents.membership_group_id,_f_membership_groups.membership_id
	FROM 	_f_membership_group_dependents
	JOIN 	_f_membership_groups ON ( _f_membership_groups.id = _f_membership_group_dependents.membership_group_id )
	WHERE 	_f_membership_group_dependents.dependent_client_id = $q->{$pp{client_id}}

	LIMIT 1
	};

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );
	my ( $is_responsible_for_group_membership, $membership_group_id, $membership_id ) = $sth->fetchrow();
	$sth->finish();

	return undef unless $membership_group_id;

	my $group = $x->get_groups(
		where => {
			'_f_membership_groups.id' => $membership_group_id
		},
		limit => 1,
	);

	return {
		is_responsible_for_group_membership => $is_responsible_for_group_membership,
		membership_group_id                 => $membership_group_id,
		membership_id                       => $membership_id,
	};

}

sub get_usage {

	my $x = shift;

	my $enrollments_tmp = $x->get_client_memberships(
		where             => { '_g_users.active' => 1 },
		only_group_owners => 1,
	);

	return undef unless $enrollments_tmp;

	my %usage;
	my $total_enrollments;

	foreach my $ee ( @{$enrollments_tmp} ) {
		if ( !$usage{id} ) {
			$usage{ $ee->{membership_id} }->{id}                   = $ee->{membership_id};
			$usage{ $ee->{membership_id} }->{name}                 = $ee->{name};
			$usage{ $ee->{membership_id} }->{amount}               = $ee->{amount};
			$usage{ $ee->{membership_id} }->{is_free_membership}   = $ee->{is_free_membership};
			$usage{ $ee->{membership_id} }->{is_visits_membership} = $ee->{is_visits_membership};
		}
		$usage{ $ee->{membership_id} }->{enrollments}++;
		$total_enrollments++;
		next unless $ee->{type_code} eq 'G';
		next unless $ee->{dependents};
		$usage{ $ee->{membership_id} }->{dependents} += scalar @{ $ee->{dependents} };
		$total_enrollments += scalar @{ $ee->{dependents} };
	}

	foreach my $membership_id ( keys %usage ) {
		$usage{$membership_id}->{enrollments} = $usage{$membership_id}->{enrollments} || 0;
		$usage{$membership_id}->{dependents}  = $usage{$membership_id}->{dependents}  || 0;
		$usage{$membership_id}->{total}       = ( $usage{$membership_id}->{enrollments} + $usage{$membership_id}->{dependents} );
		$usage{$membership_id}->{percentage} = int( ( ( $usage{$membership_id}->{enrollments} + $usage{$membership_id}->{dependents} ) * 100 / $total_enrollments ) + 0.5 );
		$usage{$membership_id}->{income} = sprintf( "%.2f", ( $usage{$membership_id}->{enrollments} * $usage{$membership_id}->{amount} ) );
		$usage{$membership_id}->{income} = 0 unless $usage{$membership_id}->{income} > 0;
	}

	return \%usage;

}

sub get_month_status {

	my ( $x, %pp ) = @_;

	my $sql = qq {
	SELECT YEAR,MONTH,STATUS,COUNT(*)
	FROM (
		SELECT 	_f_charges.year AS YEAR,_f_charges.month AS MONTH,
			CASE WHEN _f_debts.remaining_amount > 0 THEN 'PENDING' ELSE 'PAID' END AS STATUS
		FROM 	_f_debts
		JOIN 	_f_charges ON (_f_charges.id = _f_debts.charge_id)
		JOIN 	_g_users ON (_g_users.id = _f_charges.client_id)
		JOIN 	_f_memberships ON ( _f_memberships.id = _f_charges.membership_id )
		LEFT JOIN _v_membership_groups ON ( _v_membership_groups.client_id = _g_users.id )
		WHERE 	_f_charges.type_code = 'M'
		AND 	_f_memberships.is_free_membership = FALSE
		AND 	_f_memberships.is_visits_membership = FALSE
		AND 	_f_charges.year = EXTRACT('YEAR' FROM NOW())
		AND 	_f_charges.month = EXTRACT('MONTH' FROM NOW())
		AND 	(
				_f_debts.charge_amount > 0
				OR
				( _f_memberships.type_code = 'G' AND _v_membership_groups.is_responsible = FALSE )
		)
		AND 	_f_charges.client_id NOT IN (
			SELECT 	_g_users.id
			FROM 	_g_users
			WHERE EXTRACT('YEAR' FROM _g_users.create_date_time) = EXTRACT('YEAR' FROM NOW())
			AND   EXTRACT('MONTH' FROM _g_users.create_date_time) = EXTRACT('MONTH' FROM NOW())
		)
	) AS SS
	GROUP BY SS.YEAR,SS.MONTH,SS.STATUS

	UNION ALL

	SELECT 	0,0,'EXPECTED',SUM(_f_memberships.amount)
	FROM 	_f_client_memberships
	JOIN 	_g_users ON ( _g_users.id = _f_client_memberships.client_id )
	JOIN 	_f_memberships ON ( _f_memberships.id = _f_client_memberships.membership_id )
	WHERE 	_g_users.active = TRUE
	AND 	_g_users.is_client = TRUE
	AND 	_f_memberships.is_free_membership = FALSE
	AND 	_f_memberships.is_visits_membership = FALSE
	AND NOT EXISTS (
		SELECT 	1
		FROM 	_f_membership_group_dependents
		WHERE 	_f_membership_group_dependents.dependent_client_id = _g_users.id
	)
	};

	my %totals;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );
	while ( my ( $year, $month, $status, $value ) = $sth->fetchrow() ) {
		$totals{$status} += $value || 0;
		next if $status eq 'EXPECTED';
		$month = sprintf( "%02d", $month );
		$totals{ $year . '-' . $month }->{$status} = $value || 0;
	}
	$sth->finish();

	$totals{TOTAL} = $totals{PAID} + $totals{PENDING};

	return \%totals;

}

sub get_summary {

	my ( $x, %pp ) = @_;

	$pp{date} //= global::date_time->get_date();
	my ( $day, $month, $year ) = split( /\D+/, $pp{date} );

	my $q = $x->get_quote();

	my $remembership_users;

	my $new_enrollments = $x->{m}->{users}->get_users(
		where => {
			'_g_users.create_date_time::DATE' => $pp{date},
			'_g_users.is_client'              => 1,
		}
	);

	my $sql = qq {
	SELECT 	_f_transactions.client_id
	FROM 	_f_transactions
	JOIN 	_f_payments ON (_f_payments.transaction_id = _f_transactions.id)
	JOIN 	_f_charges ON (_f_charges.id = _f_payments.charge_id)
	JOIN 	_f_debts ON ( _f_debts.charge_id = _f_charges.id )
	JOIN 	_g_users ON (_g_users.id = _f_charges.client_id)
	WHERE 	_f_charges.type_code = 'M'
	AND 	_g_users.is_client = TRUE
	AND 	_f_charges.month = EXTRACT(MONTH FROM $q->{$pp{date}}::DATE)
	AND 	_f_charges.year = EXTRACT(YEAR FROM $q->{$pp{date}}::DATE)
	AND 	_f_debts.remaining_amount = 0
	AND 	_f_transactions.date_time::DATE = $q->{$pp{date}}
	AND 	_f_charges.client_id NOT IN (
		SELECT 	_g_users.id
		FROM 	_g_users
		WHERE 	EXTRACT(MONTH FROM _g_users.create_date_time) = $q->{$month}
		AND 	EXTRACT(YEAR FROM _g_users.create_date_time)  = $q->{$year}
	)
	};

	my @items;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );
	my %remembership_client_ids;

	while ( my $client_id = $sth->fetchrow() ) {
		$remembership_client_ids{$client_id} = 1;
	}

	$sth->fetchrow();

	if ( scalar keys %remembership_client_ids ) {

		$remembership_users = $x->{m}->{users}->get_users(
			in => {
				table => '_g_users',
				field => 'id',
				items => [ keys %remembership_client_ids ],
			},
		);

	}

	return undef unless $new_enrollments || $remembership_users;

	return {
		new_enrollments    => $new_enrollments,
		remembership_users => $remembership_users,
	};

}

1;
