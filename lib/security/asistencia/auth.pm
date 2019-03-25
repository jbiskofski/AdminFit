package security::asistencia::auth;

use strict;

sub presente_do {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin} || $d->{s}->{is_coach};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub delete_do {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin} || $d->{s}->{is_coach};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub ver {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin} || $d->{s}->{is_coach};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub resumen {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin} || $d->{s}->{is_coach};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

1;
