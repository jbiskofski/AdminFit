package security::membresias::auth;

use strict;

sub default {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin} || $d->{s}->{is_coach};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub x_check_name_availability {

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

sub switch_default_do {

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

sub x_get_membership_possible_groups {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub grupo {

	my ( $n, $d ) = @_;

	return 'INVALID-SESSION' unless security::auth->check_valid_session( $d->{dbh}, $d->{s} );
	return 'AUTHENTICATION-ERROR' unless $d->{s}->{is_admin};
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub switch_group_owner_do {

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

1;
