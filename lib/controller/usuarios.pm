package controller::usuarios;

use strict;
use base 'controller::usuarios::management';

sub new {

	my ( $n, $d ) = @_;

	my $x = {
		v => view::render->new( $d->{r} ),
		m => model::init->new( $d->{dbh} ),
	};

	bless $x;
	return $x;

}

sub agregar {

	my ( $x, $d ) = @_;

	$d->{data}->{details} = $x->{m}->{configuration}->get_additional_details(
		where => {
			'_g_additional_details.active'    => 1,
			'_g_additional_details.for_staff' => 1,
		}
	);

	my $validations = $x->{m}->{configuration}->generate_detail_validations( $d->{data}->{details} )
	  if $d->{data}->{details};

	$d->get_form_validations(
		append     => $validations,
		skip_ifdef => [ 'password', '_password' ],
	);

	$x->{v}->render($d);

}

sub actualizar {

	my ( $x, $d ) = @_;

	$d->{data}->{user} = $x->{m}->{users}->get_users(
		where => {
			'_g_users.id' => $d->{p}->{id},
		},
		or => {
			'_g_users.is_admin' => 1,
			'_g_users.is_coach' => 1,
		},
		limit => 1,
	);

	if ( !$d->{data}->{user}->{active} ) {
		my $ctip = controller::tips->new($d);
		$d->notification(
			$ctip->get(
				tip               => 'DISABLED-USER',
				user_id           => $d->{p}->{id},
				is_client         => $d->{data}->{user}->{is_client},
				no_dismiss_button => 1,
			)
		);
	}

	$d->{data}->{details} = $x->{m}->{configuration}->get_additional_details(
		where => {
			'_g_additional_details.active'    => 1,
			'_g_additional_details.for_staff' => 1,
		}
	);

	my $validations = $x->{m}->{configuration}->generate_detail_validations( $d->{data}->{details} )
	  if $d->{data}->{details};

	$d->get_form_validations( append => $validations );

	$x->{v}->render($d);

}

sub x_check_username_availability {

	my ( $x, $d ) = @_;

	my $count = $x->{m}->count(
		where => {
			username => $d->{p}->{username}
		},
		table => '_g_users'
	);

	$x->{v}->render_json( { available => $count ? 0 : 1 } );

}

sub upsert_do {

	my ( $x, $d ) = @_;

	my $user = $x->_upsert_user( $d, is_staff_upsert => 1 );

	my $message = 'Miembro de staff actualizado.';
	my $method  = 'actualizar';

	if ( $user->{is_new} ) {
		$message = 'Miembro de staff agregado.';
		$method  = 'agregar';
	}

	$d->success($message);
	$d->save_state();

	return $x->{v}->http_redirect(
		c      => 'usuarios',
		method => $method,
		id     => $user->{id}
	);

}

sub perfil {

	my ( $x, $d ) = @_;

	$d->{data}->{user} = $x->{m}->{users}->get_users(
		where => {
			'_g_users.id' => $d->{p}->{id},
		},
		or => {
			'_g_users.is_admin' => 1,
			'_g_users.is_coach' => 1,
		},
		limit => 1,
	);

	if ( !$d->{data}->{user}->{active} ) {
		my $ctip = controller::tips->new($d);
		$d->notification(
			$ctip->get(
				tip               => 'DISABLED-USER',
				user_id           => $d->{p}->{id},
				is_client         => $d->{data}->{user}->{is_client},
				no_dismiss_button => 1,
			)
		);
	}

	$d->{data}->{calendar} = $x->{m}->{users}->get_calendar(
		user_id => $d->{p}->{id},
		month   => $d->{p}->{month},
		year    => $d->{p}->{year}
	);

	$d->{data}->{prev_next} = global::date_time->get_prev_next(
		month => $d->{p}->{month},
		year  => $d->{p}->{year}
	);

	$x->{v}->render($d);

}

sub confirmar_desactivacion {

	my ( $x, $d ) = @_;

	$d->{data}->{user} = $x->{m}->{users}->get_users(
		where => {
			'_g_users.id' => $d->{p}->{id},
		},
		limit => 1,
	);

	if ( $d->{data}->{user}->{is_permanent} ) {
		$d->warning('El usuario seleccionado no puede ser desactivado.');
		return $x->{v}->status($d);
	}

	if ( !$d->{data}->{user}->{active} ) {
		my $ctip = controller::tips->new($d);
		$d->notification(
			$ctip->get(
				tip               => 'DISABLED-USER',
				user_id           => $d->{p}->{id},
				is_client         => $d->{data}->{user}->{is_client},
				no_dismiss_button => 1,
			)
		);
	}

	if ( $d->{data}->{user}->{is_client} ) {

		$d->{data}->{membership} = $x->{m}->{memberships}->get_client_memberships(
			where => {
				'_f_client_memberships.client_id' => $d->{p}->{id},
			},
			limit => 1,
		);

		if (   $d->{data}->{membership}->{type_code} eq 'G'
			&& $d->{data}->{membership}->{is_responsible_for_group_membership}
			&& $d->{data}->{membership}->{dependents}
			&& scalar @{ $d->{data}->{membership}->{dependents} } )
		{

			my $group_uri = global::ttf->uri(
				c  => 'membresias',
				m  => 'grupo',
				id => $d->{data}->{membership}->{membership_group_id},
			);

			my $message = qq {
			El usuario seleccionado no puede ser deshabilitado o eliminado ya que es el responsable de la
			membres&iacute;a grupal de otros miembros.
			<br>
			Para eliminar el usuario primero es necesario deshabilitar o eliminar a los dependientes.
			<br>
			<br>
			<a href="$group_uri" class="btn btn-secondary btn-sm">
				<i class="fe fe-users mr-2"></i>
				Administrar grupo de miembros
			</a>
			};
			$d->info($message);
			return $x->{v}->status($d);

		}

	}

	$x->{v}->render($d);

}

sub reactivar {

	my ( $x, $d ) = @_;

	$d->{data}->{user} = $x->{m}->{users}->get_users(
		where => {
			'_g_users.id' => $d->{p}->{id},
		},
		limit => 1,
	);

	if ( $d->{data}->{user}->{active} ) {
		$d->warning('El usuario especificado ya esta activo.');
		return $x->{v}->status($d);
	}

	if ( $d->{data}->{user}->{is_client} ) {

		$d->{data}->{memberships} = $x->{m}->{memberships}->get_memberships();

		$d->{data}->{membership} = $x->{m}->{memberships}->get_client_memberships(
			where => {
				'_f_client_memberships.client_id' => $d->{p}->{id},
			},
			limit => 1,
		);

		$d->{data}->{group} = $x->{m}->{memberships}->get_groups(
			where => { '_f_membership_groups.id' => $d->{data}->{membership}->{membership_group_id} },
			limit => 1
		) if $d->{data}->{membership}->{is_responsible_for_group_membership};

		if ( $d->{data}->{membership}->{type_code} eq 'G'
			&& !$d->{data}->{membership}->{is_responsible_for_group_membership} )
		{

			my $cmb    = controller::membresias->new($d);
			my $groups = $cmb->get_membership_possible_groups(
				membership_id                => $d->{data}->{membership}->{membership_id},
				selected_group_membership_id => $d->{data}->{membership}->{membership_group_id},
				exclude_client_id            => $d->{p}->{id},
			);

			$d->{data}->{JSON_possible_membership_groups} = JSON::XS->new()->latin1()->encode($groups);

		}

		$d->{data}->{charge_months} = global::date_time->get_prev_next();
		$d->{data}->{charge_months}->{current} = global::date_time->get_date_time_parts();
		$d->get_form_validations();

	}

	$x->{v}->render($d);

}

sub desactivar_usuario_do {

	my ( $x, $d ) = @_;

	my $user = $x->{m}->{users}->get_users(
		where => {
			'_g_users.id' => $d->{p}->{id},
		},
		limit => 1,
	);

	if ( $user->{is_permanent} ) {
		$d->warning('El usuario seleccionado no puede ser desactivado.');
		return $x->{v}->status($d);
	}

	if ( !$user->{active} ) {
		$d->warning('El usuario seleccionado ya esta deshabilitado.');
		return $x->{v}->status($d);
	}

	$x->{m}->delete( where => { user_id => $d->{p}->{id} }, table => '_g_sessions' );

	$x->{m}->update(
		update => {
			active                 => 0,
			deactivation_date_time => global::date_time->get_date_time(),
			deactivation_admin_id  => $d->{s}->{user_id},
		},
		where => { id => $d->{p}->{id} },
		table => '_g_users',
	);

	if ( $user->{is_client} ) {

		# if this client was a dependent of a group and now has their own membership
		# we need to remove them from the other group
		$x->{m}->delete(
			where => {
				dependent_client_id => $user->{id}
			},
			table => '_f_membership_group_dependents'
		);

		$d->success('Usuario desactivado.');
		$d->save_state();

		return $x->{v}->http_redirect(
			c      => 'clientes',
			method => 'perfil',
			id     => $user->{id}
		);

	}
	else {

		$d->success('Miembro de staff desactivado.');
		$d->save_state();

		return $x->{v}->http_redirect(
			c      => 'usuarios',
			method => 'perfil',
			id     => $user->{id}
		);

	}

	global::standard->inspect( 'ERROR', __FILE__, __LINE__ );

}

sub inactivos {

	my ( $x, $d ) = @_;

	my %where = ( '_g_users.active' => 0 );
	$where{'_g_users.deactivation_date_time::DATE'} = $d->{p}->{fecha} if $d->{p}->{fecha};

	$d->{data}->{inactive} = $x->{m}->{clients}->get_clients(
		where                => \%where,
		inactive_details     => 1,
		include_membership   => 1,
		include_debt_details => 1,
	);

	$d->{data}->{deleted_users} = $x->{m}->{users}->get_deleted_users( date => $d->{p}->{fecha} );

	$d->info('No se han encontrado usuarios deshabilitados.') unless $d->{data}->{inactive} || $d->{data}->{deleted_users};

	$x->{v}->render($d);

}

sub eliminar_cliente_do {

	my ( $x, $d ) = @_;

	my $user = $x->{m}->{clients}->get_clients(
		where                => { '_g_users.id' => $d->{p}->{id} },
		include_membership   => 1,
		include_debt_details => 1,
		limit                => 1,
	);

	if ( $user->{is_permanent} ) {
		$d->warning('El usuario seleccionado no puede ser eliminado.');
		return $x->{v}->status($d);
	}

	if ( !$user->{is_client} ) {
		$d->warning('Solo se puede eliminar a clientes, no miembros de staff.');
		return $x->{v}->status($d);
	}

	my $total_attendance_days = $x->{m}->{attendance}->get_user_total_days( $d->{p}->{id} );

	$x->{m}->insert(
		insert => {
			id                    => $d->{p}->{id},
			name                  => $user->{name},
			lastname1             => $user->{lastname1},
			lastname2             => $user->{lastname2},
			admin_id              => $d->{s}->{user_id},
			notes                 => $d->{p}->{notes},
			total_debt_amount     => $user->{debt}->{total},
			total_attendance_days => $total_attendance_days,
			membership_name       => $user->{membership}->{name},
		},
		table => '_g_deleted_users',
	);

	my $delete_sql = qq {
		DELETE FROM _a_attendance WHERE client_id = '$d->{p}->{id}';
		DELETE FROM _f_payments WHERE client_id = '$d->{p}->{id}';
		DELETE FROM _f_debts WHERE charge_id in (
			SELECT id FROM _f_charges WHERE client_id = '$d->{p}->{id}'
		);
		DELETE FROM _f_charges WHERE client_id = '$d->{p}->{id}';
		DELETE FROM _i_inventory_sales WHERE transaction_id in (
			SELECT id FROM _f_transactions WHERE client_id = '$d->{p}->{id}'
		);
		DELETE FROM _f_charges WHERE client_id = '$d->{p}->{id}';
		DELETE FROM _f_client_memberships WHERE client_id = '$d->{p}->{id}';
		DELETE FROM _f_membership_group_dependents WHERE dependent_client_id = '$d->{p}->{id}';
		DELETE FROM _f_balances WHERE client_id = '$d->{p}->{id}';
		DELETE FROM _f_transactions WHERE client_id = '$d->{p}->{id}';
		DELETE FROM _g_users WHERE id = '$d->{p}->{id}';
		DELETE FROM _g_sessions WHERE user_id = '$d->{p}->{id}';
	};

	$x->{m}->{dbh}->do($delete_sql) || $DBI::errstr;

	$d->success('Usuario eliminado.');
	$d->{p} = undef;
	$d->save_state();

	return $x->{v}->http_redirect(
		c      => 'clientes',
		method => 'default',
	);

}

1;
