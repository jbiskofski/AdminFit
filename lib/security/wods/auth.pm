package security::wods::auth;

use strict;

sub programacion {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin} || $d->{s}->{is_coach};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub mes {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin} || $d->{s}->{is_coach};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub upsert_do {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin};
	return 'POST-VALIDATE-ERROR'  unless security::forms->validate_post($d) eq 'POST-VALIDATIONS-OK';

	return 'SECURITY-METHOD-VALIDATION-OK';

}

1;
