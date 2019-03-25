package security::auth;

use strict;

sub new {

	my ( $n, $d, $dispatch_values ) = @_;

	my $x = {
		d               => $d,
		dispatch_values => $dispatch_values
	};

	bless $x;
	return $x;

}

sub authorize {

	my $x = shift;

	my $status = undef;
	my $class  = 'security::' . $x->{dispatch_values}->{controller} . '::auth';
	my $method = $x->{dispatch_values}->{method};

	eval { $status = $class->$method( $x->{d} ) };

	return 'SECURITY-AUTH-VALIDATION-OK' if $status eq 'SECURITY-METHOD-VALIDATION-OK';

	my $message = 'Se ha producido un error. Consulte al administrador.';

	if ( $status eq 'INVALID-SESSION' ) {
		$message = 'Su sesi&oacute;n ha expirado.';
		$x->{d}->{data}->{status_link} = {
			display => 'Iniciar una nueva sesi&oacute;n',
			uri     => global::ttf->uri( c => 'login', m => 'logout_do' ),
			icon    => 'log-in',
		};
	}
	elsif ( $ENV{DEVEL_MODE} ) {
		$x->{d}->{data}->{status_large_details} = $class;
		$x->{d}->{data}->{status_small_details} = $@ if $@;
		$x->{d}->{data}->{status_small_details} .= $status if $status;
	}

	my $vvr = view::render->new( $x->{d}->{r} );
	$x->{d}->warning($message);

	$vvr->status( $x->{d} );

	return 0;

}

sub check_valid_session {

	my ( $n, $dbh, $s ) = @_;

	return 0 unless $s->{id};
	my $mss = model::sessions->new($dbh);

	if ( $s->{session_active} ) {

		$mss->update(
			update => { last_touch => 'NOW()' },
			where  => { id         => $s->{id} },
			table  => '_g_sessions'
		);
		return 1;

	}

	$mss->delete( where => { id => $s->{id} }, table => '_g_sessions' );
	return 0;

}

1;
