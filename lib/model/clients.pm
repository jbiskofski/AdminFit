package model::clients;

use strict;
use base 'model::base';
use Sort::Key::Multi 'rnnskeysort';

sub new {

	my ( $n, $dbh ) = @_;

	my $x = {
		dbh => $dbh,
		m   => model::init->new($dbh)
	};

	bless $x;
	return $x;

}

sub get_clients {

	my ( $x, %pp ) = @_;

	my $clients_tmp = $x->{m}->{users}->get_users(
		%pp,
		todays_birthdays   => $pp{todays_birthdays}   || 0,
		upcoming_birthdays => $pp{upcoming_birthdays} || 0,
	);

	return undef unless $clients_tmp;

	my @clients = $pp{limit} == 1 ? ($clients_tmp) : @{$clients_tmp};

	if ( $pp{include_membership} ) {

		my %client_ids = map { $_->{id} => 1 } @clients;

		my $memberships_tmp = $x->{m}->{memberships}->get_client_memberships(
			in => {
				table => '_f_client_memberships',
				field => 'client_id',
				items => [ keys %client_ids ],
			}
		);

		if ($memberships_tmp) {

			my %memberships = map { $_->{client_id} => $_ } @{$memberships_tmp};

			foreach my $cc (@clients) {
				$cc->{membership} = $memberships{ $cc->{id} };
				next unless $cc->{membership}->{responsible_client_id};
				$client_ids{ $cc->{membership}->{responsible_client_id} } = 1;
			}

		}

		if ( $pp{include_debt_details} ) {

			my $details = $x->{m}->{charges}->get_client_debts(
				client_ids                         => [ keys %client_ids ],
				only_membership_debt_details       => $pp{only_membership_debt_details},
				include_debt_details_for_inactives => $pp{include_debt_details_for_inactives},
				specific_month_debt_details        => $pp{specific_month_debt_details},
			);

			if ($details) {
				foreach my $cc (@clients) {
					$cc->{debt}->{membership} = $details->{ $cc->{id} }->{LAST};
					$cc->{debt}->{total}      = $details->{ $cc->{id} }->{DEBT};
					$cc->{visits}             = $details->{ $cc->{id} }->{VISITS};
				}
			}

			my @sorted = rnnskeysort {
				$_->{debt}->{total}, $_->{debt}->{membership}->{days}, $_->{display_name}
			}
			@clients;

			@clients = @sorted;

		}

	}

	if ( $pp{inactive_details} ) {

		my %admin_ids = map { $_->{deactivation_admin_id} => 1 } @clients;

		my $admins_tmp = $x->{m}->{users}->get_users(
			in => {
				table => '_g_users',
				field => 'id',
				items => [ keys %admin_ids ],
			}
		);

		my %admins = map { $_->{id} => global::standard->get_person_display_name( $_->{name}, $_->{lastname1}, $_->{lastname2} ) } @{$admins_tmp};

		foreach my $cc (@clients) {
			$cc->{deactivation_display_admin} = $admins{ $cc->{deactivation_admin_id} };
		}

	}

	return undef unless scalar @clients;
	return $clients[0] if $pp{limit} == 1;
	return \@clients;

}

sub get_total_paying_clients {

	my $x = shift;

	my $q = $x->get_quote();

	my $sql = qq {
	SELECT 	COUNT(*)
	FROM	_g_users
	JOIN	_f_client_memberships ON ( _f_client_memberships.client_id = _g_users.id )
	JOIN 	_f_memberships ON ( _f_memberships.id =_f_client_memberships.membership_id )
	WHERE  	_g_users.active = TRUE
	AND  	_g_users.is_client = TRUE
	AND 	_f_memberships.is_free_membership = FALSE
	};

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );
	my $count = $sth->fetchrow();
	$sth->finish();

	return $count;

}
1;
