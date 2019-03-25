package global::cookies;

use strict;
use String::CRC;
no warnings 'uninitialized';

sub eat {

	# IE6 repeats cookie names, and sometimes they have empty values,
	# this is how we deal with this
	my $session_id = undef;
	my @cookies = split( /\;/, $ENV{HTTP_COOKIE} );

	foreach my $cc (@cookies) {

		my ( $key, $value ) = split( /=/, $cc );
		$key =~ s/\s+//g;
		next unless $key =~ /_sid/;
		next unless $value;

		my ( $cookie_customer_crc, @uuid ) = split( /-/, $value );
		my ($customer_crc) = crc( $ENV{CUSTOMER}, 64 );

		next unless $customer_crc == $cookie_customer_crc;
		$session_id = join( '-', @uuid );

		return $session_id;

	}

	return undef;

}

sub bake {

	my ( $n, $session_id ) = @_;

	my $customer_id = $ENV{CUSTOMER};
	my ($customer_crc) = crc( $customer_id, 64 );

	my $cookie_value = $customer_crc . '-' . $session_id;

	my $cookie1 = CGI::Cookie->new(
		-name     => '_sid1',
		-value    => $cookie_value,
		-expires  => '+2y',
		-httponly => 1
	);

	my $cookie2 = CGI::Cookie->new(
		-name     => '_sid2',
		-value    => $cookie_value,
		-expires  => '+3y',
		-httponly => 1
	);

	return [ $cookie1, $cookie2 ];

}

sub burn {

	my $cookie1 = CGI::Cookie->new(
		-name     => '_sid1',
		-value    => 0,
		-expires  => '-2y',
		-httponly => 1
	);

	my $cookie2 = CGI::Cookie->new(
		-name     => '_sid2',
		-value    => 0,
		-expires  => '-3y',
		-httponly => 1
	);

	return [ $cookie1, $cookie2 ];

}

1;
