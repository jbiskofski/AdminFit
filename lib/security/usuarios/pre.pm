package security::usuarios::pre;

use strict;

sub actualizar {

	my ( $n, %pp ) = @_;

	my $client_management_uri = global::ttf->uri( c => 'clientes', m => 'agregar' );

	my %validations = (
		required => [
			{
				input   => 'username',
				message => 'Es necesario especificar un nombre de usuario.'
			},
			{
				input   => 'password',
				message => 'Es necesario especificar una contrase&ntilde;a.',
				ifdef   => 1,
			},
			{
				input   => '_password',
				message => 'Es necesario confirmar la contrase&ntilde;a.',
				ifdef   => 1,
			},
			{
				input   => 'name',
				message => 'Es necesario especificar el nombre.',
			},
			{
				input   => 'lastname1',
				message => 'Es necesario especificar el apellido paterno.',
			},
			{
				input   => 'birthday',
				message => 'Es necesario especificar la fecha de cumplea&ntilde;os.',
			},
		],
		date => [
			{
				input   => 'birthday',
				message => 'Fecha de cumplea&ntilde;os inv&aacute;lida.',
			},
		],
		passwordmatches => [
			{
				input   => 'password',
				message => 'Las contrase&ntilde;as no concuerdan',
				ifdef   => 1,
			}
		],
		javascript => [
			{
				input   => 'check_has_admin_activity()',
				message => qq {
					Es necesario asignar permiso de aministrador o
					entrenador para este tipo de usuario.
					<br>
					Si quieres agregar un cliente ( miembro, socio )
					haz clic aqui :
					<br>
					<br>
					<div class=btn-list>
					<a href=$client_management_uri class="btn btn-secondary">
						<i class="fe fe-users mr-2"></i>
						Administraci&oacute;n de clientes
					</a>
				        </div>
				},
			},
		],
	);

	return \%validations;

}

sub agregar {

	my ( $n, %pp ) = @_;

	my $validations = security::usuarios::pre->actualizar();

	return $validations;

}

sub reactivar {

	my ( $n, %pp ) = @_;

	my %validations = (
		required => [

			{
				input   => 'renewal_day',
				message => 'Es necesario especificar el dia de renovaci&oacute;n de la membres&iacute;a.',
			},
			{
				input   => 'membership_id',
				message => 'Es necesario especificar una membres&iacute;a.',
			},
		],
		javascript => [

			{
				input   => 'check_membership_group()',
				message => qq{
					El cliente que estas intentando agregar se configuro
					como dependiente de una membres&iacute;a grupal.
					Es necesario especificar quien es el responsable por el pago de la membres&iacute;a.
				},
			},
		],

	);

	return \%validations;

}

1;
