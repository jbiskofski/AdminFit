package controller::login;

use strict;

sub new {

	my ( $n, $d ) = @_;

	my $x = {
		v => view::render->new( $d->{r} ),
		m => model::init->new( $d->{dbh} ),
	};

	bless $x;
	return $x;

}

sub default {

	my ( $x, $d ) = @_;

	if ( $d->{s}->{id} ) {

		my $session = $x->{m}->{sessions}->get_session( $d->{s}->{id} );

		if ( $session && $session->{session_active} ) {
			return $x->{v}->http_redirect( c => 'inicio', method => 'default' ) if $session->{is_admin};
			return $x->{v}->http_redirect( c => 'clientes', method => 'hehehe' );
		}

		$x->{m}->delete(
			where => { id => $d->{s}->{id} },
			table => '_g_sessions'
		);

		delete $d->{s};

	}

	$d->get_form_validations();
	$d->{cookies} = global::cookies->burn( $d->{r} );
	$d->success('Sesi&oacute;n finalizada.') if $d->{p}->{bye};
	$x->{v}->render($d);

}

sub login_do {

	my ( $x, $d ) = @_;

	my $user = $x->{m}->{users}->get_users(
		where => {
			'_g_users.username' => $d->{p}->{username},
			'_g_users.active'   => 1,
		},
		limit => 1,
	);

	unless ($user) {
		$d->warning("Usuario inv&aacute;lido : <b>$d->{p}->{username}</b>.");
		return $x->{v}->status($d);
	}

	my $scrypt_param_password = global::standard->scrypt(
		string => $d->{p}->{password},
		salt   => $user->{id}
	);

	if ( $user->{strikes} > 2 ) {

		my $seconds_remaining = global::date_time->compare_date_time( global::date_time->get_date_time(), $user->{suspended_date_time} );

		if ( $seconds_remaining > 0 ) {
			my $minutes_remaining = int( $seconds_remaining / 60 );
			$d->warning("Cuenta de usuario suspendida. Ser&aacute; rehabiliatada en $minutes_remaining minuto(s).");
			return $x->{v}->status($d);
		}
		else {
			# remove user suspension
			$x->{m}->update(
				update => {
					strikes             => 0,
					suspended_date_time => 'NULL',
				},
				where => {
					id => $user->{id},
				},
				table => '_g_users',
			);

			$user->{strikes} = 0;

		}

	}

	if ( $user->{id} && ( $scrypt_param_password ne $user->{scrypt_password} ) ) {

		$user->{strikes}++;

		if ( $user->{strikes} > 2 ) {

			# suspend user
			$x->{m}->update(
				update => {
					strikes             => 3,
					suspended_date_time => "NOW() + INTERVAL '10 MINUTES'",
				},
				where => {
					id => $user->{id},
				},
				table => '_g_users',
			);

			$d->warning("Contrase&ntilde;a de usuario <b>$d->{p}->{username}</b> inv&aacute;lida. La cuenta ha sido suspendida por 10 minutos.");
			return $x->{v}->status($d);

		}
		else {

			# add strike
			$x->{m}->update(
				update => {
					strikes             => $user->{strikes},
					suspended_date_time => 'NULL',
				},
				where => {
					id => $user->{id},
				},
				table => '_g_users',
			);

			my $strikes_left = ( 3 - $user->{strikes} );
			my $intentos_plural = $strikes_left == 1 ? 'intento restante' : 'intentos restantes';
			$d->warning("Contrase&ntilde;a de usuario <b>$d->{p}->{username}</b> inv&aacute;lida. $strikes_left $intentos_plural.");
			return $x->{v}->status($d);

		}

		return $x->default($d);

	}
	elsif ( $user->{id} && $scrypt_param_password eq $user->{scrypt_password} ) {

		# reactivate account in case its suspended
		$x->{m}->update(
			update => {
				strikes             => 0,
				suspended_date_time => 'NULL',
			},
			where => {
				id => $user->{id},
			},
			table => '_g_users',
		);

		my $session_id = $x->{m}->{sessions}->new_session(
			user_id             => $user->{id},
			auth                => $user->{auth},
			username            => $user->{username},
			lastname            => $user->{lastname},
			name                => $user->{name},
			language_preference => $user->{language_preference},
			remember_me         => $d->{p}->{remember_me} || 0,
		);

		my $delete_cookies = global::cookies->burn();
		my $cookies        = global::cookies->bake($session_id);

		$d->{r}->err_headers_out->add( 'Set-Cookie' => $delete_cookies->[0] );
		$d->{r}->err_headers_out->add( 'Set-Cookie' => $delete_cookies->[1] );
		$d->{r}->err_headers_out->add( 'Set-Cookie' => $cookies->[0] );
		$d->{r}->err_headers_out->add( 'Set-Cookie' => $cookies->[1] );

		$d->{session_id} = $session_id;

		$d->success('Se ha iniciado sesi&oacute;n.');
		$d->save_state();

		return $x->{v}->http_redirect( c => 'inicio', m => 'default' );

	}

}

sub logout_do {

	my ( $x, $d ) = @_;

	my $delete_cookies = global::cookies->burn();
	$d->{r}->err_headers_out->add( 'Set-Cookie' => $delete_cookies->[0] );
	$d->{r}->err_headers_out->add( 'Set-Cookie' => $delete_cookies->[1] );
	$x->{m}->delete( where => { id => $d->{s}->{id} }, table => '_g_sessions' ) if $d->{s}->{id};
	return $x->{v}->http_redirect( c => 'login', m => 'default', bye => 1 );

}

1;
