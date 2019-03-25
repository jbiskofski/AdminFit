package controller::usuarios::management;

use strict;

sub _upsert_user {

	my ( $x, $d, %pp ) = @_;

	my $user_id = global::standard->uuid();
	my $is_new  = 1;

	if ( $d->{p}->{id} ) {

		my $user = $x->{m}->{users}->get_users(
			where => { '_g_users.id' => $d->{p}->{id} },
			limit => 1,
		);

		# cant disable/update admin or publico-general users
		if ( $user->{is_permanent} ) {
			$d->warning("No es posible modificar o deshabilitar el cliente $user->{display_name}.");
			return $x->{v}->status($d);
		}

		$user_id = $d->{p}->{id};
		$is_new  = 0;

	}

	my %insert = (
		id         => $user_id,
		active     => 1,
		address    => $d->{p}->{address},
		birthday   => $d->{p}->{birthday},
		city       => $d->{p}->{city},
		email      => $d->{p}->{email},
		lastname1  => $d->{p}->{lastname1},
		lastname2  => $d->{p}->{lastname2},
		name       => $d->{p}->{name},
		nickname   => $d->{p}->{nickname},
		occupation => $d->{p}->{occupation},
		notes      => $d->{p}->{notes},
		state      => $d->{p}->{state},
		telephone  => $d->{p}->{telephone},
		gender     => $d->{p}->{gender},
		zipcode    => $d->{p}->{zipcode} || 0,
	);

	if ( $d->{p}->{webcam_result} && $d->{p}->{webcam_result} =~ /^data:image\/png/ ) {

		my $status = global::io->save_user_image(
			data         => $d->{p}->{webcam_result},
			user_id      => $user_id,
			thumbnail_id => 'users/' . $user_id . '/THUMBNAIL',
			thumbnail_id => 'users/' . $user_id . '/THUMBNAIL',
		);

		if ( $status->{code} ) {
			$insert{has_picture} = 1;
		}
		else {
			$d->warning( $status->{message} );
			return $x->{v}->status($d);
		}

	}

	if ( $pp{is_staff_upsert} ) {
		$insert{is_client} = $d->{p}->{is_client} ? 1 : 0;
		$insert{is_admin}  = $d->{p}->{is_admin}  ? 1 : 0;
		$insert{is_coach}  = $d->{p}->{is_coach}  ? 1 : 0;
	}
	elsif ( $pp{is_client_upsert} ) {

		$insert{is_client} = 1;
		$insert{is_admin}  = 0;
		$insert{is_coach}  = 0;

		$insert{allow_client_access} = 1;

		# all these ifs are just paranoid security
		if (   !$d->{p}->{allow_client_access}
			|| substr( $d->{p}->{username}, 0, 9 ) eq 'DISABLED-'
			|| $d->{p}->{password} ne 'DISABLED' )
		{
			$insert{allow_client_access} = 0;

			# change credentials so that they will never be known
			$d->{p}->{username}  = 'DISABLED-' . global::standard->uuid();
			$d->{p}->{password}  = global::standard->uuid();
			$d->{p}->{_password} = $d->{p}->{password};
		}

	}

	$insert{username} = $d->{p}->{username};

	if ( $d->{p}->{password} ) {

		my $scrypt_password = global::standard->scrypt(
			string => $d->{p}->{password},
			salt   => $user_id,
		);

		$insert{scrypt_password} = $scrypt_password;

	}

	my %details;

	foreach my $dd ( keys %{ $d->{p} } ) {
		next unless $dd =~ /^DD-(\S+)$/;
		$details{$1} = $d->{p}->{$dd};
	}

	if ( scalar keys %details ) {
		my $json_data = JSON::XS->new()->latin1()->encode( \%details );
		$insert{data} = $json_data if $json_data;
	}

	$x->{m}->upsert(
		insert           => \%insert,
		conflict_fields  => ['id'],
		try_update_first => defined $d->{p}->{id},
		table            => '_g_users',
	);

	return {
		id     => $user_id,
		is_new => $is_new,
	};

}

1;
