package global::loader;

use strict;
use CGI;
use Try::Tiny;
use Apache2::Const -compile => qw(OK SERVER_ERROR);
use view::api;
use security::log;
use JSON::XS;

# uri application dispatcher - tries to figure out through regular expressions
# what class should be loaded, and which of its methods should be executed.

sub new {

	my $x = {};
	bless($x);
	return ($x);

}

sub dispatch {

	my ( $x, $d ) = @_;

	my $dv     = $x->_dispatch_values();
	my $class  = $dv->{class};
	my $method = $dv->{method};
	my $app;

	try {
		if ( !$ENV{DISABLE_TRANSACTIONS} ) {
			$d->{dbh}->begin_work() || die($DBI::errstr);
		}

		require $dv->{require};
		$app = $dv->{class}->new($d);
		my $probably_mod_perl_status_code = $app->$method($d);

		if ( !$ENV{DISABLE_TRANSACTIONS} ) {
			$d->{dbh}->commit();
		}

		my $security_log = security::log->new( $d->{dbh} );
		my $request_size = 0;
		eval { $request_size = length( JSON::XS->new()->latin1()->encode( $d->{data} ) ) };
		$security_log->set_request_size( transaction_id => $d->{tid}, request_size => $request_size );
		return $probably_mod_perl_status_code;
	}
	catch {

		my $error_id = global::standard->short_unique_id();

		# jquery.algebraix should catch this header
		$d->{r}->err_headers_out->set( 'X-Error-Code' => $error_id );

		if ( !$ENV{DISABLE_TRANSACTIONS} ) {
			global::standard->log_inspect( $DBI::errstr, $_ );
			$d->{dbh}->rollback() || die($DBI::errstr);
		}

		# dont send email if were developing
		if ( $d->{self} =~ /abacix\.net/ ) {

			# inspects and errors will only be displayed if this header is set
			$d->{r}->err_headers_out->set( 'X-Error-Display' => 1 );

			if ( $_ =~ /^ERROR:/ ) {
				print "Content-type: text/plain\n\n$_\n\nTRANSACTION_ID $ENV{TRANSACTION_ID}\n\n";
			}
			elsif ( $_ !~ /^debug\s/ ) {
				print "Content-type: text/html\n\n$_\n\n";
			}
			return Apache2::Const::OK;

		}
		else {

			return Apache2::Const::SERVER_ERROR if $_ =~ /sysopen/;
			return Apache2::Const::SERVER_ERROR if $_ =~ /sendmail.*exit 19200/;
			return Apache2::Const::SERVER_ERROR if $_ =~ /^ModPerl::Util::exit/;
			return Apache2::Const::SERVER_ERROR if $_ =~ /Software caused connection abort/;
			return Apache2::Const::SERVER_ERROR if $_ =~ /Apache2 IO write/;
			return Apache2::Const::SERVER_ERROR if $_ =~ /inspect2/;
			return Apache2::Const::SERVER_ERROR if $_ =~ /inspect/;
			return                              if $ENV{WEB_BASE} =~ /testing/;
			return                              if $ENV{WEB_BASE} =~ /abacix/;

			global::support_tickets->log_error_report(
				error    => $_,
				error_id => $error_id,
				params   => $d->{p},
				url      => "$ENV{WEB_BASE}/$dv->{auth}/$dv->{module}/$dv->{method}/",
				user_id  => $d->{s}->{user_id},
				username => $d->{s}->{username},
				browser  => $ENV{HTTP_USER_AGENT},
				referer  => $ENV{HTTP_REFERER},
			);

			return Apache2::Const::OK;

		}

	}

}

# dispatch_values - parses requested url and returns module, method, require, auth, etc.

sub _dispatch_values {

	my $x = shift;

	my $cgi  = CGI->new();
	my $self = $cgi->self_url();

	my $r = {
		is_api      => 0,
		module      => undef,
		method      => undef,
		require     => undef,
		accessing   => undef,
		class       => undef,
		http_method => undef,
	};

	$r->{is_api} = 1 if $self =~ /^http.*:\/\/[^\/]+\/api/;
	$self =~ s/^.*\/(bin|api)([^\?]*)\?*.*/$2/;

	my @extract = ( split( /\//, $self ) );

	$r->{auth}   = $extract[1] ? $extract[1] : 'g';
	$r->{module} = $extract[2] ? $extract[2] : 'start';
	$r->{method} = $extract[3] ? $extract[3] : 'default';
	$r->{require}     = "controller/$r->{auth}/$r->{module}.pm";
	$r->{class}       = "controller::$r->{auth}::$r->{module}";
	$r->{accessing}   = $r->{auth} . '_' . $r->{module} . '_' . $r->{method};
	$r->{http_method} = $cgi->request_method();

	return ($r);

}

1;
