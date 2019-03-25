package security::buscar::auth;

use strict;

sub x_default {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin} || $d->{s}->{is_coach};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

1;
