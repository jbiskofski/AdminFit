package global::start;

# application entry point. main data structure is created and correct method is dispatched.

use strict;
use Apache2::Const -compile => qw/OK SERVER_ERROR/;

use global::data;
use global::standard;
use security::auth;

sub handler {

	my $r = shift;

	my $dispatch_values = __PACKAGE__->_get_dispatch_values();
	my $referer_dispatch_values = __PACKAGE__->_get_dispatch_values( referer => 1 );
	$dispatch_values->{referer} = $referer_dispatch_values->{accessing};

	my $d = global::data->new( $r, $dispatch_values );
	return Apache2::Const::OK unless $d;

	my $auth = security::auth->new( $d, $dispatch_values );
	return Apache2::Const::OK unless $auth->authorize() eq 'SECURITY-AUTH-VALIDATION-OK';

	__PACKAGE__->dispatch( $d, $dispatch_values );

}

sub dispatch {

	my ( $n, $d, $dispatch_values ) = @_;

	$d->{dbh}->begin_work() || die($DBI::errstr) unless $ENV{DISABLE_TRANSACTIONS};

	# disable this until we have a reason to need it
	# __PACKAGE__->log( $d->{dbh}, $dispatch_values, $d->{s}, $d->{p} );

	eval {
		my $controller = $dispatch_values->{class}->new($d);
		my $method     = $dispatch_values->{method};
		$controller->$method($d);
	};

	if ($@) {

		$d->{dbh}->rollback() || die($DBI::errstr) unless $ENV{DISABLE_TRANSACTIONS};

		return Apache2::Const::OK if $@ =~ /INTERNAL-DEBUG-DIE/;
		$d->warning('Se ha producido un error. Consulte al administrador.');

		if ( $ENV{DEVEL_MODE} ) {
			$d->{data}->{status_large_details} = $dispatch_values->{class} . '->' . $dispatch_values->{method} . '()';
			$d->{data}->{status_small_details} = $@;
		}

		my $vvr = view::render->new( $d->{r} );
		$vvr->status($d);
		return Apache2::Const::OK;

	}

	$d->{dbh}->commit() unless $ENV{DISABLE_TRANSACTIONS};
	return Apache2::Const::OK;

}

sub _get_dispatch_values {

	my ( $n, %pp ) = @_;

	my $cgi            = CGI->new();
	my $uri_to_process = $cgi->http('X_ORIGINAL_URI');

	if ( $pp{referer} ) {
		$ENV{HTTP_REFERER} =~ /\S+$ENV{SERVER_NAME}([^\?]+)/;
		$uri_to_process = $1;
	}

	my ( $n, $customer, $controller, $method, $main_param ) = split( /\//, $uri_to_process );

	( $controller, $method ) = ( 'login', 'default' ) if !$controller && !$method;
	$controller = 'inicio'  unless $controller;
	$method     = 'default' unless $method;

	$method =~ s/-/_/g;

	return {
		customer   => lc($customer),
		controller => lc($controller),
		method     => lc($method),
		main_param => lc($main_param),
		class      => "controller::$controller",
		accessing  => "$controller/$method",
		require    => 'controller/' . $controller . '.pm',
		db         => 'adminfit_' . uc($customer),
	};

}

sub log {

	my ( $n, $dbh, $dispatch_values, $session, $params ) = @_;

	my $ip_address = '127.0.0.1';

	if ( $ENV{HTTP_X_REAL_IP} && $ENV{HTTP_X_REAL_IP} =~ /^\d+\.\d+\.\d+\.\d+$/ ) {
		$ip_address = $ENV{HTTP_X_REAL_IP};
	}
	elsif ( $ENV{REMOTE_ADDR} && $ENV{REMOTE_ADDR} =~ /^\d+\.\d+\.\d+\.\d+$/ ) {
		$ip_address = $ENV{REMOTE_ADDR};
	}

	# we only log session activity
	return unless $session->{id};

	my $json_params = __PACKAGE__->_get_json_clean_file_params($params);
	my $sql         = 'INSERT INTO _g_logs ( controller, method, params, ip, session_id, user_id ) VALUES (?,?,?,?,?,?)';
	my $sth         = $dbh->prepare($sql);
	$sth->execute( $dispatch_values->{controller}, $dispatch_values->{method}, $json_params, $ip_address, $session->{id}, $session->{user_id} );
	$sth->finish();

}

sub _get_json_clean_file_params {

	my ( $n, $params ) = @_;

	my %clean;

	foreach my $pp ( keys %{$params} ) {

		# dont log passwords
		next if $pp =~ /password/;
		next if $pp eq 'api_key';

		# clean file handles
		$clean{$pp} = ref( $params->{$pp} ) eq 'Fh'
		  || ref( $params->{$pp} ) eq 'CGI::File::Temp' ? 'FILEHANDLE' : $params->{$pp};
	}

	return '{}' unless scalar keys %clean;
	return JSON::XS->new()->latin1()->encode( \%clean );

}

1;
