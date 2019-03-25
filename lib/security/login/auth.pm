package security::login::auth;

use strict;

sub default {

	my ( $n, $d ) = @_;
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub login_do {

	my ( $n, $d ) = @_;

	return 'POST-VALIDATE-ERROR' unless security::forms->validate_post($d) eq 'POST-VALIDATIONS-OK';
	return 'SECURITY-METHOD-VALIDATION-OK';

}

sub logout_do {

	my ( $n, $d ) = @_;
	return 'SECURITY-METHOD-VALIDATION-OK';

}

1;
