package controller::membresias;

use strict;
use Sort::Key 'keysort';
use Sort::Key::Multi 'rnrnskeysort';
use base 'controller::membresias::groups';

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

	$d->{data}->{memberships} = $x->{m}->{memberships}->get_memberships();

	my $ctip                = controller::tips->new($d);
	my $free_membership_tip = $ctip->get(
		tip     => 'MEMBERSHIPS-FREE',
		user_id => $d->{s}->{user_id}
	);
	$d->info($free_membership_tip) if $free_membership_tip;

	my $visits_membership_tip = $ctip->get(
		tip     => 'MEMBERSHIPS-VISITS',
		user_id => $d->{s}->{user_id}
	);
	$d->info($visits_membership_tip) if $visits_membership_tip;

	my $usage = $x->{m}->{memberships}->get_usage();

	if ($usage) {

		foreach my $mm ( @{ $d->{data}->{memberships} } ) {
			$mm->{enrollments} = $usage->{ $mm->{id} }->{enrollments};
			$mm->{dependents}  = $usage->{ $mm->{id} }->{dependents};
			$mm->{percentage}  = $usage->{ $mm->{id} }->{percentage};
			$mm->{income}      = $usage->{ $mm->{id} }->{income};
		}

		my @unsorted_usage;
		foreach my $mm ( values %{$usage} ) {
			next unless $mm->{id};
			push @unsorted_usage, $mm;
		}

		my @sorted_usage = keysort { $_->{name} } @unsorted_usage;

		my @enrollment_labels;
		my @enrollment_values;
		my @income_labels;
		my @income_values;

		foreach my $mm (@sorted_usage) {

			if ( $mm->{total} > 0 ) {
				push @enrollment_labels, $mm->{name};
				push @enrollment_values, $mm->{total};
			}

			next if $mm->{is_free_membership} || $mm->{is_visits_membership};

			if ( $mm->{income} > 0 ) {
				push @income_labels, $mm->{name};
				push @income_values, $mm->{income};
			}

		}

		$d->{data}->{charts}->{enrollments} = global::charts->bars(
			values => \@enrollment_values,
			labels => \@enrollment_labels,
			color  => 'blue',
			div_id => 'DIV-MEMBERSHIPS-CHART',
			title  => 'Inscripciones',
		);

		$d->{data}->{charts}->{income} = global::charts->bars(
			monify => 1,
			values => \@income_values,
			labels => \@income_labels,
			color  => 'green',
			div_id => 'DIV-MEMBERSHIPS-INCOME-CHART',
			title  => 'Ingresos',
		);

		my @sorted = rnrnskeysort { $_->{is_default}, $_->{enrollments}, $_->{name} } @{ $d->{data}->{memberships} };
		$d->{data}->{memberships} = \@sorted;

	}

	$d->get_form_validations();
	$x->{v}->render($d);

}

sub x_check_name_availability {

	my ( $x, $d ) = @_;

	my $count = $x->{m}->count(
		where => {
			name => $d->{p}->{name}
		},
		ignore_case => 1,
		table       => '_f_memberships'
	);

	$x->{v}->render_json( { available => $count ? 0 : 1 } );

}

sub upsert_do {

	my ( $x, $d ) = @_;

	my $is_update = 1 if $d->{p}->{id};

	if ($is_update) {

		my $membership = $x->{m}->{memberships}->get_memberships(
			where => { '_f_memberships.id' => $d->{p}->{id} },
			limit => 1,
		);

		if ( $membership->{is_permanent} ) {
			$d->warning('No es posible modificar o deshabilitar la membres&iacute;a gratuita.');
			return $x->{v}->status($d);
		}

	}

	$d->{p}->{amount} =~ s/,//;

	my %insert = (
		id                        => $d->{p}->{id},
		name                      => $d->{p}->{name},
		amount                    => $d->{p}->{amount},
		notes                     => $d->{p}->{notes},
		has_timeframe_limitations => 0,
	);

	for ( my $c = 0 ; $c <= 6 ; $c++ ) {
		$insert{ 'limit_dow_' . $c } = 0;
	}
	for ( my $c = 0 ; $c <= 23 ; $c++ ) {
		$insert{ 'limit_hour_' . $c } = 0;
	}

	if ( $d->{p}->{has_timeframe_limitations} ) {
		foreach my $pp ( keys %{ $d->{p} } ) {
			next unless $pp =~ /^TLIM_(\S+)_(\d+)$/;
			my ( $type, $value ) = ( $1, $2 );
			$insert{ 'limit_' . lc($type) . '_' . int($value) } = 1;
		}
		$insert{has_timeframe_limitations} = 1;
	}

	unless ( $d->{p}->{id} ) {

		$insert{type_code}  = $d->{p}->{type_code} || 'I';
		$insert{active}     = 1;
		$insert{is_default} = 0;

		$insert{group_maximum_members} =
		    $d->{p}->{type_code} eq 'G'
		  ? $d->{p}->{group_maximum_members}
		  : 0;

	}

	$x->{m}->upsert(
		insert          => \%insert,
		conflict_fields => ['id'],
		table           => '_f_memberships',
	);

	my $message =
	  $d->{p}->{id}
	  ? 'Membres&iacute;a actualizada.'
	  : 'Membres&iacute;a agregada.';

	$d->success($message);
	$d->save_state();

	my $method = $d->{p}->{id} ? 'ver' : 'default';

	return $x->{v}->http_redirect(
		c  => 'membresias',
		m  => $method,
		id => $d->{p}->{id},
	);

}

sub switch_default_do {

	my ( $x, $d ) = @_;

	$x->{m}->update(
		update => { is_default => 0 },
		table  => '_f_memberships',
	);

	$x->{m}->update(
		update => { is_default => 1 },
		where  => {
			id => $d->{p}->{id}
		},
		table => '_f_memberships',
	);

	$d->success('Se ha cambiado la membres&iacute;a principal.');
	$d->save_state();

	return $x->{v}->http_redirect( c => 'membresias', m => 'default' );

}

sub ver {

	my ( $x, $d ) = @_;

	$d->{data}->{membership} = $x->{m}->{memberships}->get_memberships(
		where => { '_f_memberships.id' => $d->{p}->{id} },
		limit => 1,
	);

	if ( $d->{data}->{membership}->{is_free_membership} ) {
		my $ctip                = controller::tips->new($d);
		my $free_membership_tip = $ctip->get(
			tip               => 'MEMBERSHIPS-FREE',
			user_id           => $d->{s}->{user_id},
			always_show       => 1,
			no_dismiss_button => 1,
		);
		$free_membership_tip .= '<br>Esta membres&iacute;a no puede ser modificada o deshabilitada.';
		$d->info($free_membership_tip);
	}

	if ( $d->{data}->{membership}->{is_visits_membership} ) {
		my $ctip                  = controller::tips->new($d);
		my $visits_membership_tip = $ctip->get(
			tip               => 'MEMBERSHIPS-VISITS',
			user_id           => $d->{s}->{user_id},
			always_show       => 1,
			no_dismiss_button => 1,
		);
		$visits_membership_tip .= '<br><br>Esta membres&iacute;a no puede ser modificada o deshabilitada.';
		$d->info($visits_membership_tip);
	}

	$d->{data}->{enrollments} = $x->{m}->{memberships}->get_client_memberships(
		where => {
			'_f_client_memberships.membership_id' => $d->{p}->{id},
			'_g_users.active'                     => 1
		},
		only_group_owners => 1
	);

	$d->info('No se han encontrado inscripciones a esta membres&iacute;a.')
	  unless $d->{data}->{enrollments};

	$d->info(
		qq{
		Se han encontrado inscripciones activas a la membres&iacute;a, aun cuando esta deshabilitada.
		<br>
		Se les seguir&aacute; cobrando a los clientes inscritos pero ya no es posible utilizarla con clientes nuevos.
	 }
	) if $d->{data}->{enrollments} && !$d->{data}->{membership}->{active};

	if ( $d->{data}->{membership}->{type_code} eq 'G' && $d->{data}->{enrollments} ) {

		my $dependent_count = 0;

		foreach my $ee ( @{ $d->{data}->{enrollments} } ) {
			next unless $ee->{dependents};
			$dependent_count += scalar @{ $ee->{dependents} };
		}

		$d->{data}->{dependent_count} = $dependent_count || 0;

	}

	$d->get_form_validations();

	$x->{v}->render($d);

}

sub switch_active_do {

	my ( $x, $d ) = @_;

	my $membership = $x->{m}->{memberships}->get_memberships(
		where => { '_f_memberships.id' => $d->{p}->{id} },
		limit => 1,
	);

	if ( $membership->{is_permanent} ) {
		$d->warning('No es posible modificar o deshabilitar la membres&iacute;a gratuita.');
		return $x->{v}->status($d);
	}

	if ( $membership->{is_default} && !$d->{p}->{active} ) {
		$d->warning('No es posible desactivar la membres&iacute;a principal. Designa otra membres&iacute;a como principal primero.');
		return $x->{v}->status($d);
	}

	$x->{m}->update(
		update => { active => $d->{p}->{active} },
		where  => {
			id => $d->{p}->{id}
		},
		table => '_f_memberships',
	);

	my $message = $d->{p}->{active} ? 'Membres&iacute;a reactivada.' : 'Membres&iacute;a desactivada.';
	$d->success($message);
	$d->save_state();

	return $x->{v}->http_redirect(
		c      => 'membresias',
		method => 'ver',
		id     => $d->{p}->{id}
	);

}

sub x_get_membership_possible_groups {

	my ( $x, $d ) = @_;

	my $membership = $x->{m}->{memberships}->get_client_memberships(
		where => {
			'_f_client_memberships.client_id' => $d->{p}->{client_id},
			'_g_users.active'                 => 1,
			'_f_memberships.active'           => 1,
		},
		limit => 1,
	) if $d->{p}->{client_id};

	my $groups = $x->get_membership_possible_groups(
		membership_id                => $d->{p}->{membership_id},
		selected_group_membership_id => $membership->{membership_group_id},
		exclude_client_id            => $d->{p}->{client_id},
	);

	return $x->{v}->render_json($groups) if $groups;
	return $x->{v}->render_json( [] );

}

sub grupo {

	my ( $x, $d ) = @_;

	$d->{data}->{group} = $x->{m}->{memberships}->get_groups(
		where => { '_f_membership_groups.id' => $d->{p}->{id} },
		limit => 1,
	);

	$d->info('Hay espacios disponibles en esta membres&iacute;a.') if $d->{data}->{group}->{available_dependent_clients};

	$d->{data}->{membership} = $x->{m}->{memberships}->get_memberships(
		where => { '_f_memberships.id' => $d->{data}->{group}->{membership_id} },
		limit => 1,
	);

	$x->{v}->render($d);

}

sub switch_group_owner_do {

	my ( $x, $d ) = @_;

	my $group = $x->{m}->{memberships}->get_groups(
		where => { '_f_membership_groups.id' => $d->{p}->{id} },
		limit => 1,
	);

	$x->{m}->delete(
		where => {
			membership_group_id => $d->{p}->{id},
			dependent_client_id => $d->{p}->{client_id},
		},
		table => '_f_membership_group_dependents'
	);

	$x->{m}->insert(
		insert => {
			membership_group_id => $d->{p}->{id},
			dependent_client_id => $group->{responsible_client_id},
		},
		no_id_column => 1,
		table        => '_f_membership_group_dependents'
	);

	$x->{m}->update(
		update => {
			responsible_client_id => $d->{p}->{client_id}
		},
		where => {
			id => $d->{p}->{id}
		},
		table => '_f_membership_groups'
	);

	$d->success('Grupo actualizado.');
	$d->save_state();

	return $x->{v}->http_redirect(
		controller => 'membresias',
		method     => 'grupo',
		id         => $d->{p}->{id}
	);

}

sub resumen {

	my ( $x, $d ) = @_;

	if ( ( $d->{p}->{start_date} && $d->{p}->{end_date} )
		&& $d->{p}->{start_date} eq $d->{p}->{end_date} )
	{
		$d->{p}->{fecha}      = $d->{p}->{start_date};
		$d->{p}->{start_date} = undef;
		$d->{p}->{end_date}   = undef;
	}

	$d->{p}->{fecha} //= global::date_time->get_date();
	my $date = $d->{p}->{fecha};

	$d->{data}->{multi_day_search} = 0;

	$d->{data}->{summary} = $x->{m}->{memberships}->get_summary( date => $d->{p}->{fecha} );

	$d->info('No se han encontrado resultados &uacute;tilizando la b&uacute;squeda especificada.')
	  if !$d->{data}->{summary};

	$x->{v}->render($d);

}

1;
