package controller::tips::standard;

use strict;

sub accept_notification {

	my ( $x, %pp ) = @_;

	$x->{m}->upsert(
		insert => {
			tip_id  => $pp{tip_id},
			user_id => $pp{user_id}
		},
		conflict_fields => [ 'tip_id', 'user_id' ],
		table           => '_g_seen_tips',
	);

	return 1;

}

sub _disabled_user {

	my ( $x, %pp ) = @_;

	my $reactivate_user_uri = global::ttf->uri( c => 'usuarios', m => 'reactivar', id => $pp{user_id} );

	my $tip = qq{
	<span><b>Usuario deshabilitado</b></span>
	<span style="float:right">
		<a href="$reactivate_user_uri" class="btn btn-success btn-sm">
			<i class="fe fe-user-check mr-2"></i>
			Reactivar
		</a>
	};

	if ( $pp{is_client} ) {

		my $delete_user_uri = global::ttf->uri( c => 'usuarios', m => 'confirmar_desactivacion', id => $pp{user_id} );

		$tip .= qq {
			&nbsp;
			<a href="$delete_user_uri" class="btn btn-danger btn-sm">
				<i class="fe fe-x mr-2"></i>
				Eliminar
			</a>
		};

	}

	$tip .= '</span>';

	return $tip;

}

sub _memberships_free {

	my ( $x, %pp ) = @_;

	my $tip = qq{
	Tip : Membres&iacute;a <b>GRATUITA</b>.
	<br>
	<br>
	Sirve para personas que no pagan mensualidad ( Familiares, Ayudantes, Inscripciones temporales o de prueba ).
	<br>
	Este tipo de usuarios se pueden dar de alta con la membres&iacute;a gratuita
	para llevar el control de sus compras y resultados.
	};

	return $tip;

}

sub _memberships_visits {

	my $sales_uri = global::ttf->uri( c => 'ventas', m => 'default' );

	my $tip = qq{
	Tip : Membres&iacute;a <b>VISITAS</b>.
	<br>
	<br>
	Esta sirve para personas que en lugar de pagar mensualidad, pagan paquetes de visitas.
	( 15 visitas en un mes, 1 visita individual, etc )
	<br>
	Para agregar paquetes de visitas haz clic aqui.
	&nbsp;
	<a href="$sales_uri" class="btn btn-primary btn-sm">
		<i class="fe fe-shopping-cart mr-2"></i>
		Ventas
	</a>
	};

	return $tip;

}

sub _inactive_debt_users {

	my $tip = qq{
	Tip : <b>Clientes deshabilitados con adeudo.</b>
	<br>
	<br>
	Se han encontrado clientes deshabilitados con adeudos pendientes.
	Los usuarios en esta situaci&oacute;n se muestran en la siguiente lista.
	Para quitarlos de esta lista es necesario cancelar sus cobros pendientes.
	};

	return $tip;

}

sub _users_publico_general {

	my $tip = qq{
	Tip : <b>PUBLICO GENERAL</b>.
	<br>
	<br>
	Este cliente sirve para registrar ventas a personas que no son miembros.
	( Clientes en periodo de prueba, Personas externas al gimnasio, etc ).
	};

	return $tip;

}

1;
