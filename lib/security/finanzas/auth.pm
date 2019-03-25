package security::finanzas::auth;

use strict;

sub estado_de_cuenta {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin} || $d->{s}->{is_coach};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub cobro {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin} || $d->{s}->{is_coach};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub add_discount_do {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub delete_payment_do {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub delete_discount_do {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub resumen {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub folio {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub delete_charge_do {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub mes {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

1;
