package model::search;

use strict;
use base 'model::base';
use Sort::Key 'rnkeysort';

sub new {

	my ( $n, $dbh ) = @_;

	my $x = {
		dbh => $dbh,
		m   => model::init->new($dbh)
	};

	bless $x;
	return $x;

}

sub search {

	my ( $x, %pp ) = @_;

	return undef unless $pp{search};

	my $users = $x->_search_users( $pp{search} );
	my $items = $x->_search_items( $pp{search} );

	return undef unless $users || $items;

	my @unsorted;
	push @unsorted, @{$users} if $users;
	push @unsorted, @{$items} if $items;

	my @sorted = rnkeysort { $_->{ranking} } @unsorted;
	my $max_limit = scalar @sorted >= 5 ? 4 : scalar @sorted;

	return [ @sorted[ 0 .. $max_limit ] ];

}

sub _search_items {

	my ( $x, $search ) = @_;

	my $q = $x->get_quote();

	my $sql = qq {
	SELECT	_i_items.id,_i_items.type_code,_i_items.name,_i_items.active,
		SIMILARITY( _i_items.name, $q->{$search} ) AS RANKING
	FROM	_i_items
	WHERE 	_i_items.name ILIKE $q->{'%' . $search . '%'}
	ORDER BY RANKING
	LIMIT 5
	};

	my @items;
	my @keys = qw/id type_code name active ranking/;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;
		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}

		$ii{display_type} = $x->{m}->{inventory}->_get_display_type( $ii{type_code} );
		$ii{type_code}    = 'INVENTORY';

		push @items, \%ii;

	}

	$sth->finish();

	return scalar @items ? \@items : undef;

}

sub _search_users {

	my ( $x, $search ) = @_;

	my $q = $x->get_quote();

	my $sql = qq {
	SELECT	_g_users.id,_g_users.active,_g_users.name,_g_users.lastname1,_g_users.lastname2,
		_g_users.nickname,_g_users.has_picture,_g_users.has_profile_picture,
		_g_users.is_admin,_g_users.is_coach,_g_users.is_client,
		SIMILARITY( _g_users.search_vectors, $q->{$search} ) AS RANKING,
		_f_membership_groups.responsible_client_id
	FROM	_g_users
	LEFT JOIN _f_membership_group_dependents ON ( _f_membership_group_dependents.dependent_client_id = _g_users.id )
	LEFT JOIN _f_membership_groups ON ( _f_membership_groups.id = _f_membership_group_dependents.membership_group_id )
	WHERE 	_g_users.active = TRUE
	AND 	_g_users.search_vectors ILIKE $q->{'%' . $search . '%'}
	ORDER BY RANKING
	LIMIT 5
	};

	my %user_ids;
	my @items;

	my @keys = qw/id active name lastname1 lastname2 nickname
	  has_picture has_profile_picture
	  is_admin is_coach is_client ranking responsible_client_id/;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;
		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}

		my $display_name = global::standard->get_person_display_name( $ii{name}, $ii{lastname1}, $ii{lastname2} );
		$display_name .= ' ( ' . $ii{nickname} . ' )' if $ii{nickname};

		my $type_code = $ii{is_admin} || $ii{is_coach} ? 'STAFF' : 'CLIENT';

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
			ranking   => $ii{ranking},
			type_code => $type_code,
		  };

		$user_ids{ $ii{id} } = 1;
		$user_ids{ $ii{responsible_client_id} } = 1 if length $ii{responsible_client_id} > 8;

	}

	$sth->finish();

	return undef unless scalar @items;

	my $details = $x->{m}->{charges}->get_client_debts( client_ids => [ keys %user_ids ] );

	if ($details) {
		foreach my $ii (@items) {
			next unless $user_ids{ $ii->{id} };
			$ii->{membership} = $details->{ $ii->{id} }->{LAST};
			$ii->{debt_total} = $details->{ $ii->{id} }->{DEBT};
		}
	}

	my $attendance_tmp = $x->{m}->{attendance}->get_attendance(
		in => {
			table => '_a_attendance',
			field => 'client_id',
			items => [ keys %user_ids ],
		},
		where => {
			'_a_attendance.date' => 'NOW()',
		}
	);

	if ($attendance_tmp) {
		my %attendance = map { $_->{client_id} => scalar @{ $_->{times} } || 0 } @{$attendance_tmp};
		foreach my $ii (@items) {
			$ii->{attendance_today_count} = $attendance{ $ii->{id} } || 0;
		}
	}

	return \@items;

}

1;
