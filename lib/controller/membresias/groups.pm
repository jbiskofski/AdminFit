package controller::membresias::groups;

use strict;

sub _setup_membership_group {

	my ( $x, $d, %pp ) = @_;

	my $current_group = $x->{m}->{memberships}->get_client_group( client_id => $pp{client_id} );

	if ($current_group) {

		if ( $current_group->{membership_id} ne $pp{membership_id} ) {

			# this happens when we change a client from one group membership, to another group membership
			$x->{m}->update(
				update => {
					membership_id => $pp{membership_id}
				},
				where => { id => $current_group->{membership_group_id} },
				table => '_f_membership_groups',
			);
		}

		if ( $current_group->{is_responsible_for_group_membership} && !$pp{is_responsible_for_group_membership} ) {

			$x->{m}->update(
				update => {
					membership_group_id => $pp{membership_group_id}
				},
				where => { client_id => $pp{client_id} },
				table => '_f_charges',
			);

			$x->{m}->update(
				update => {
					membership_group_id => $pp{membership_group_id}
				},
				where => { membership_group_id => $current_group->{membership_group_id} },
				table => '_f_charges',
			);

			$x->{m}->delete(
				where => { id => $current_group->{membership_group_id} },
				table => '_f_membership_groups'
			);

		}
		elsif ( !$current_group->{is_responsible_for_group_membership} && $pp{is_responsible_for_group_membership} ) {

			# this client is now responsible for paying for a new group

			# delete them as a dependent from the group they were in
			$x->{m}->delete(
				where => { dependent_client_id => $pp{client_id} },
				table => '_f_membership_group_dependents'
			);

			# create new group
			$x->{m}->insert(
				insert => {
					membership_id         => $pp{membership_id},
					responsible_client_id => $pp{client_id},
				},
				table => '_f_membership_groups',
			);

		}

		if (  !$pp{is_responsible_for_group_membership}
			&& $current_group->{membership_group_id} ne $pp{membership_group_id} )
		{

			# this client is now a dependent of a new group
			$x->_add_dependent_to_membership_group(
				$d,
				dependent_client_id => $pp{client_id},
				membership_group_id => $pp{membership_group_id},
			);

		}

	}
	else {

		if ( $pp{is_responsible_for_group_membership} ) {

			# create new group
			$x->{m}->insert(
				insert => {
					membership_id         => $pp{membership_id},
					responsible_client_id => $pp{client_id},
				},
				table => '_f_membership_groups',
			);

		}
		else {

			$x->_add_dependent_to_membership_group(
				$d,
				dependent_client_id => $pp{client_id},
				membership_group_id => $pp{membership_group_id},
			);

		}

	}

	return 1;

}

sub get_membership_possible_groups {

	my ( $x, %pp ) = @_;

	my $groups_tmp = $x->{m}->{memberships}->get_groups(
		where => {
			'_f_membership_groups.membership_id' => $pp{membership_id},
			'_g_users.active'                    => 1,
		},
		exclude_client_id => $pp{exclude_client_id},
	);

	return undef if !$groups_tmp;

	my @groups;

	foreach my $gg ( @{$groups_tmp} ) {

		next unless $gg->{available_dependent_clients};

		my $image_tag = global::ttf->avatar(
			id                  => $gg->{responsible_client_id},
			has_profile_picture => $gg->{has_profile_picture},
			has_picture         => $gg->{has_picture},
			name                => $gg->{display_name},
			small               => 1,
		);

		push @groups,
		  {
			id                     => $gg->{membership_group_id},
			name                   => $gg->{display_name},
			image_tag              => $image_tag,
			display_available_text => $gg->{available_dependent_clients} . ' de ' . $gg->{group_maximum_members} . ' lugares disponibles.',
			selected               => $gg->{membership_group_id} eq $pp{selected_group_membership_id} ? 1 : 0,
		  };

	}

	return \@groups;

}

sub _add_dependent_to_membership_group {

	my ( $x, $d, %pp ) = @_;

	# add this client as a dependent to an existing group
	my $group_details = $x->{m}->{memberships}->get_groups(
		where => {
			'_f_membership_groups.id' => $pp{membership_group_id},
		},
		limit => 1,
	);

	# we already checked this but make sure again, in case two admins are adding clients
	# at the same time
	unless ( $group_details->{available_dependent_clients} ) {
		$d->warning('No hay lugares disponibles en la membres&iacute;a grupal seleccionada.');
		return $x->{v}->status($d);
	}

	$x->{m}->delete(
		where => { dependent_client_id => $pp{dependent_client_id} },
		table => '_f_membership_group_dependents'
	);

	$x->{m}->insert(
		insert => {
			membership_group_id => $pp{membership_group_id},
			dependent_client_id => $pp{dependent_client_id},
		},
		no_id_column => 1,
		table        => '_f_membership_group_dependents',
	);

}

1;
