package controller::configuracion;

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
	$d->get_form_validations();
	$x->{v}->render($d);

}

sub update_do {

	my ( $x, $d ) = @_;

	$d->{p}->{telephone}
	  ? $x->{m}->upsert(
		insert => {
			key   => 'TELEPHONE',
			value => $d->{p}->{telephone},
		},
		conflict_fields => ['key'],
		table           => '_g_configuration',
	  )
	  : $x->{m}->delete( where => { key => 'TELEPHONE' }, table => '_g_configuration' );

	$d->{p}->{gym_name}
	  ? $x->{m}->upsert(
		insert => {
			key   => 'GYM_NAME',
			value => $d->{p}->{gym_name},
		},
		conflict_fields => ['key'],
		table           => '_g_configuration',
	  )
	  : $x->{m}->delete( where => { key => 'GYM_NAME' }, table => '_g_configuration' );

	if ( $d->{p}->{logo_file} ) {

		my $file = global::io->s3_save(
			dir              => 'conf',
			file_id          => 'MAIN-LOGO',
			file             => $d->{p}->{logo_file},
			verify_image     => 1,
			create_thumbnail => 1,
			resize_image     => [ '400', '800' ],
		);

		if ( !$file->{status} ) {
			$d->warning( $file->{message} );
			return $x->{v}->status($d);
		}

		$x->{m}->upsert(
			insert => {
				key   => 'HAS_MAIN_LOGO',
				value => 1,
			},
			conflict_fields => ['key'],
			table           => '_g_configuration',
		);

	}

	if ( $d->{p}->{medium_logo_file} ) {

		my $file = global::io->s3_save(
			dir              => 'conf',
			file_id          => 'MEDIUM-LOGO',
			file             => $d->{p}->{medium_logo_file},
			create_thumbnail => 1,
			verify_image     => 1,
		);

		if ( !$file->{status} ) {
			$d->warning( $file->{message} );
			return $x->{v}->status($d);
		}

		$x->{m}->upsert(
			insert => {
				key   => 'HAS_MEDIUM_LOGO',
				value => 1,
			},
			conflict_fields => ['key'],
			table           => '_g_configuration',
		);

	}

	if ( $d->{p}->{small_logo_file} ) {

		my $file = global::io->s3_save(
			dir              => 'conf',
			file_id          => 'SMALL-LOGO',
			file             => $d->{p}->{small_logo_file},
			verify_image     => 1,
			create_thumbnail => 1,
		);

		if ( !$file->{status} ) {
			$d->warning( $file->{message} );
			return $x->{v}->status($d);
		}

		$x->{m}->upsert(
			insert => {
				key   => 'HAS_SMALL_LOGO',
				value => 1,
			},
			conflict_fields => ['key'],
			table           => '_g_configuration',
		);

	}

	$d->success('Configuraci&oacute;n actualizada.');
	$d->save_state();

	return $x->{v}->http_redirect( c => 'configuracion', m => 'default' );

}

sub eliminar_logo_do {

	my ( $x, $d ) = @_;

	global::io->s3_delete( 'conf/THUMBNAILS/' . $d->{p}->{which} . '-LOGO' );
	global::io->s3_delete( 'conf/' . $d->{p}->{which} . '-LOGO' );

	if ( $d->{p}->{which} ) {
		global::io->s3_delete( 'conf/400PX/' . $d->{p}->{which} . '-LOGO' );
		global::io->s3_delete( 'conf/800PX/' . $d->{p}->{which} . '-LOGO' );
	}

	$x->{m}->delete(
		where => { key => 'HAS_' . $d->{p}->{which} . '_LOGO' },
		table => '_g_configuration'
	);

	$d->success('Logo eliminado.');
	$d->save_state();

	return $x->{v}->http_redirect( c => 'configuracion', m => 'default' );

}

sub detalles_adicionales {

	my ( $x, $d ) = @_;

	my $details = $x->{m}->{configuration}->get_additional_details();

	if ($details) {
		$d->{data}->{details}->{users} = [ grep { $_->{for_staff} || $_->{for_clients} } @{$details} ];
		$d->{data}->{details}->{inventory} = [ grep { $_->{for_inventory} } @{$details} ];
	}

	$d->get_form_validations();
	$x->{v}->render($d);

}

sub detalles_adicionales_upsert_do {

	my ( $x, $d ) = @_;

	my %insert = (
		id            => $d->{p}->{id},
		name          => $d->{p}->{name},
		type_code     => $d->{p}->{type_code},
		for_staff     => $d->{p}->{for_staff} || 0,
		for_clients   => $d->{p}->{for_clients} || 0,
		for_inventory => $d->{p}->{for_inventory} || 0,
		required      => $d->{p}->{required} || 0,
	);

	if ( $d->{p}->{type_code} eq 'options' ) {

		my @options;

		foreach my $key ( sort keys %{ $d->{p} } ) {
			next unless $key =~ /^SO-\d+$/;
			push @options, $d->{p}->{$key};
		}

		$insert{options} = \@options;

	}

	if ( $d->{p}->{for_inventory} ) {

		my %inventory_types;
		foreach my $key ( keys %{ $d->{p} } ) {
			next unless $key =~ /^INV-(\S+)$/;
			$inventory_types{$1} = 1;
		}

		$insert{inventory_type_codes} = [ keys %inventory_types ];

	}

	$x->{m}->upsert(
		insert          => \%insert,
		conflict_fields => ['id'],
		table           => '_g_additional_details',
	);

	my $message =
	  $d->{p}->{id}
	  ? 'Detalle adicional actualizado.'
	  : 'Detalle adicional agregado.';

	$d->success($message);
	$d->save_state();

	my $method = $d->{p}->{id} ? 'detalle' : 'detalles-adicionales';

	return $x->{v}->http_redirect(
		c      => 'configuracion',
		method => $method,
		id     => $d->{p}->{id},
	);

}

sub detalle {

	my ( $x, $d ) = @_;

	$d->{data}->{detail} = $x->{m}->{configuration}->get_additional_details(
		where => { '_g_additional_details.id' => $d->{p}->{id} },
		limit => 1,
	);

	$d->get_form_validations();
	$x->{v}->render($d);

}

sub detalles_adicionales_switch_active_do {

	my ( $x, $d ) = @_;

	$x->{m}->update(
		update => { active => $d->{p}->{active} },
		where  => {
			id => $d->{p}->{id}
		},
		table => '_g_additional_details',
	);

	my $message = $d->{p}->{active} ? 'Detalle reactivado.' : 'Detalle desactivado.';
	$d->success($message);
	$d->save_state();

	return $x->{v}->http_redirect(
		c      => 'configuracion',
		method => 'detalle',
		id     => $d->{p}->{id}
	);

}

sub staff {

	my ( $x, $d ) = @_;

	$d->{data}->{staff} = $x->{m}->{users}->get_users(
		where => { '_g_users.active' => 1 },
		or    => {
			'_g_users.is_admin' => 1,
			'_g_users.is_coach' => 1,
		}
	);

	$x->{v}->render($d);

}

sub x_check_detail_name_availability {

	my ( $x, $d ) = @_;

	my $count = $x->{m}->count(
		where => {
			name => $d->{p}->{name}
		},
		ignore_case => 1,
		table       => '_g_additional_details'
	);

	$x->{v}->render_json( { available => $count ? 0 : 1 } );

}

sub reactivar_staff_do {

	my ( $x, $d ) = @_;

	$x->{m}->update(
		update => { active => 1 },
		where  => { id     => $d->{p}->{id} },
		table  => '_g_users',
	);

	$d->success('Miembro de staff reactivado.');
	$d->save_state();

	return $x->{v}->http_redirect(
		c      => 'usuarios',
		method => 'perfil',
		id     => $d->{p}->{id}
	);

}

1;
