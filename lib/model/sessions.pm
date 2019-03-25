package model::sessions;

use strict;
use String::CRC;

use base 'model::base';

sub new {

	my ( $n, $dbh ) = @_;
	my $x = { dbh => $dbh };
	bless $x;
	return $x;

}

sub new_session {

	my ( $x, %pp ) = @_;

	my $q = $x->get_quote();

	my $session_id = global::standard->uuid();
	my $last_touch = time();
	my $user_agent = $ENV{HTTP_USER_AGENT} ? $ENV{HTTP_USER_AGENT} : 'Unspecified';
	my ($user_agent_crc) = crc( $user_agent, 64 );

	my $ip_address = $ENV{HTTP_X_REAL_IP} ? $ENV{HTTP_X_REAL_IP} : '127.0.0.1';

	my $sql = qq {
	$x->{log_tagger}->{start}
	INSERT  INTO _g_sessions (
		id,
		user_id,
		user_agent,
		user_agent_crc,
		ip,
		remember_me
	)
	VALUES	(
		$q->{$session_id},
		$q->{$pp{user_id}},
		$q->{$user_agent},
		$q->{$user_agent_crc},
		$q->{$ip_address},
		$q->{$pp{remember_me}}
	)
	};

	$x->dbh()->do($sql) || die($DBI::errstr);

	return $session_id;

}

sub get_session {

	my ( $x, $session_id ) = @_;

	return undef unless $session_id;

	my $q = $x->get_quote();

	my $sql = qq {
	SELECT	_g_sessions.id,_g_sessions.last_touch,_g_sessions.user_agent,
		_g_sessions.user_agent_crc,_g_sessions.ip,_g_sessions.remember_me,
		_g_sessions.state,_g_sessions.user_id,_g_users.username,
		_g_users.name,_g_users.lastname1,_g_users.lastname2,
		_g_users.has_picture,
		_g_users.has_profile_picture,
		_g_users.is_admin,_g_users.is_coach,_g_users.is_client,
		CASE WHEN _g_sessions.remember_me = TRUE
			THEN
				NOW() < _g_sessions.last_touch + INTERVAL '1 week'
			ELSE
				NOW() < _g_sessions.last_touch + INTERVAL  '20 minutes'
		END
	FROM	_g_sessions
	JOIN	_g_users ON (_g_users.id = _g_sessions.user_id)
	WHERE 	_g_sessions.id = $q->{$session_id}
	AND 	_g_users.active = TRUE
	LIMIT 1
	};

	my %session;
	my @keys = qw/id last_touch user_agent
	  user_agent_crc ip remember_me state user_id username
	  name lastname1 lastname2 has_picture has_profile_picture
	  is_admin is_coach is_client
	  session_active
	  /;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	my @row = $sth->fetchrow();
	for ( my $c = 0 ; $c < scalar(@row) ; $c++ ) {
		$session{ $keys[$c] } = $row[$c];
	}

	$session{display_name} = global::standard->get_person_display_name( $session{name}, $session{lastname1}, $session{lastname2} );
	$session{last_touch} = global::date_time->format_date_time( $session{last_touch} );
	$sth->finish();

	return scalar keys %session ? \%session : undef;

}

sub clean_session_state {

	my ( $x, $session_id ) = @_;

	my $sql = $x->update(
		update => { state => 'NULL' },
		where  => { id    => $session_id },
		table  => '_g_sessions'
	);

	return 1;

}

1;
