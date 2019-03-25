package security::login::post;

use strict;

sub login_do {

	my ( $n, $dbh, $p, $options ) = @_;
	my $validations = security::login::pre->default();
	return $validations;

}

1;
