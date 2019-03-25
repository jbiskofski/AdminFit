package security::ventas::auth;

use strict;

sub default {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub upsert_do {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin};
	return 'POST-VALIDATE-ERROR'  unless security::forms->validate_post($d) eq 'POST-VALIDATIONS-OK';
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub x_check_name_availability {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub ver {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub switch_active_do {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub add_inventory_do {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub remove_inventory_do {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub punto_de_venta {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub process_payments_do {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub historial {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

1;
