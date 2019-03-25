package global::data;

use strict;
use POSIX 'strftime';

use global::cookies;
use global::date_time;
use view::render;
use model::base;

sub new {

	my ( $n, $r, $dispatch_values ) = @_;

	my $transaction_id = _set_transaction_id();
	my $self_url       = CGI->self_url();

	my $dbh = _dbh_connect( $r, $dispatch_values->{db} );
	return Apache2::Const::OK unless $dbh;

	my $cfg = _configure( $dbh, $dispatch_values );

	my $session_id = global::cookies->eat($dispatch_values);

	# this is needed so we have a way of knowing who ran a bg process and we can log it
	$ENV{SESSION_ID} = $session_id;
	$cfg->{SESSION_ID} = $session_id;

	my $mss     = model::sessions->new($dbh);
	my $session = $mss->get_session($session_id);

	my $system_timezone = strftime( "%Z", localtime() );
	$ENV{TIMEZONE} = $system_timezone unless global::date_time->check_timezone_is_valid();
	_set_timezone($dbh);

	my $x = {
		r              => $r,
		s              => $session,
		p              => {},
		v              => { pre => undef, post => undef, },
		data           => {},
		dbh            => $dbh,
		session_id     => $session_id,
		transaction_id => $transaction_id,
		forward        => undef,
		cookies        => undef,
		status         => [],
		self           => $self_url,
		cfg            => $cfg,
		breadcrumbs    => undef,
		sidebar        => {},
		ttf            => global::ttf->new($dbh),
	};

	$x->{p} = _get_params($dispatch_values);

	if ( $session->{state} ) {
		my $state = JSON::XS->new()->latin1()->decode( $session->{state} );
		push @{ $x->{status} }, @{ $state->{status} } if $state->{status} && scalar @{ $state->{status} };
		$x->{p} = $state->{p} if $state->{p} && scalar keys %{ $state->{p} };
		$mss->clean_session_state($session_id);
	}

	bless $x;
	return $x;

}

sub success {

	my ( $x, $message ) = @_;

	push @{ $x->{status} },
	  {
		code    => 1,
		message => $message,
	  };

}

sub warning {

	my ( $x, $message ) = @_;

	push @{ $x->{status} },
	  {
		code    => 0,
		message => $message,
	  };

}

sub info {

	my ( $x, $message ) = @_;

	push @{ $x->{status} },
	  {
		code    => 2,
		message => $message,
	  };

}

sub notification {

	my ( $x, $message ) = @_;

	push @{ $x->{status} },
	  {
		code    => 3,
		message => $message,
	  };

}

sub _configure {

	my ( $dbh, $dispatch_values ) = @_;

	my $mcf = model::configuration->new($dbh);
	my $cfg = $mcf->get_configuration();

	my ( $controller, $method ) = split( /\//, $dispatch_values->{accessing} );

	$cfg->{ACCESSING_CONTROLLER} = $controller;
	$cfg->{ACCESSING_METHOD}     = $method;
	$cfg->{ACCESSING}            = $dispatch_values->{accessing};
	$cfg->{REFERER}              = $dispatch_values->{referer};
	$cfg->{DB_NAME}              = $dispatch_values->{db};
	$cfg->{CUSTOMER}             = $dispatch_values->{customer};

	$cfg->{S3_STORAGE_RESOURCE_PREFIX} = 'https://s3.amazonaws.com';
	$cfg->{S3_STORAGE_RESOURCE_BUCKET} = 'adminfit';

	foreach my $key ( keys %{$cfg} ) {
		$ENV{ uc($key) } = $cfg->{$key};
	}

	global::standard->inspect('MISSING CONFIGURATION VALUE : TIMEZONE') unless $ENV{TIMEZONE};

	return $cfg;

}

sub _dbh_connect {

	my ( $r, $database_name ) = @_;

	my $dbh;
	eval { $dbh = DBI->connect( "dbi:Pg:dbname=$database_name", 'pgsql' ) };

	# for whatever crazy reason, we were not able to connect to the database,
	# this is very bad it probably means the database server for this customer has failed
	if ( !$dbh ) {

		my $vvr = view::render->new($r);

		return $vvr->status(
			{
				status => [
					{
						code    => 0,
						message => 'Se ha detectado un error de conectividad con la base de datos, consulte al adminstrador.',

					}
				]
			}
		);

	}

	my $q = model::base->get_quote();

	$dbh->do("SELECT $q->{$ENV{TRANSACTION_ID}} AS __TRANSACTION_ID__");
	$dbh->do("SET datestyle = 'ISO,DMY'")       || die($DBI::errstr);
	$dbh->do("SET CLIENT_ENCODING TO 'LATIN9'") || die($DBI::errstr);

	return $dbh;

}

sub _set_timezone {

	my $dbh = shift;
	my $q   = model::base->get_quote();
	$dbh->do("SET TIME ZONE $q->{$ENV{TIMEZONE}}") || die($DBI::errstr);

}

sub _get_params {

	my $dispatch_values = shift;

	my %params;
	$params{__MAINPARAM__} = $dispatch_values->{main_param} if $dispatch_values->{main_param};

	my $cgi = CGI->new();

	foreach my $key ( $cgi->param() ) {

		die "*** error param repeated : $key" if $params{$key};

		my $value = $cgi->param($key);

		if ( $key =~ /^BOOL-(\S+)$/ ) {
			$value = 1 if $cgi->param($key);
			$key = $1;
		}

		$params{$key} = $value;

	}

	return \%params;

}

sub _set_transaction_id {

	my $transaction_id = global::standard->uuid();
	$ENV{TRANSACTION_ID} = $transaction_id;

	return $transaction_id;

}

sub get_form_validations {

	my ( $x, %pp ) = @_;

	my ( $controller, $method ) = split( /\//, $x->{cfg}->{ACCESSING} );
	my $class = 'security::' . $controller . '::pre';
	$method = $pp{method} if $pp{method};
	my $validations = $class->$method(%pp);
	die "$class provides no pre validations" unless $validations;

	if ( $pp{append} ) {

		push @{ $validations->{required} }, @{ $pp{append}->{required} }
		  if $pp{append}->{required}
		  && scalar @{ $pp{append}->{required} };

		push @{ $validations->{numeric} }, @{ $pp{append}->{numeric} }
		  if $pp{append}->{numeric}
		  && scalar @{ $pp{append}->{numeric} };

		push @{ $validations->{date} }, @{ $pp{append}->{date} }
		  if $pp{append}->{date}
		  && scalar @{ $pp{append}->{date} };

	}

	if ( $pp{skip_ifdef} && scalar @{ $pp{skip_ifdef} } ) {
		my %skip_ifdef_fields = map { $_ => 1 } @{ $pp{skip_ifdef} };
		foreach my $type ( keys %{$validations} ) {
			foreach my $vv ( @{ $validations->{$type} } ) {
				next unless $skip_ifdef_fields{ $vv->{input} };
				delete $vv->{ifdef};
			}
		}
	}

	if ( $pp{method} ) {
		$x->{v}->{ 'pre_' . $pp{method} } = security::forms->transform_pre( $validations, \%pp );
		return 1;
	}

	return $x->{v}->{pre} = security::forms->transform_pre( $validations, \%pp );

}

sub save_state {

	my $x = shift;

	return undef unless $x->{session_id};

	my $clean_params = global::standard->remove_file_params( $x->{p} );

	if ($clean_params) {
		foreach my $key ( keys %{$clean_params} ) {
			delete $clean_params->{$key} if $key =~ /password/;
		}
	}

	my $json_state = JSON::XS->new()->latin1()->encode(
		{
			p      => $clean_params,
			status => $x->{status}
		}
	);

	my $q = model::base->get_quote();

	my $sql = qq {
	UPDATE 	_g_sessions
	SET 	state = $q->{$json_state}
	WHERE 	id = $q->{$x->{session_id}}
	};

	$x->{dbh}->do($sql) || die $DBI::errstr;
	return 1;

}

1;
