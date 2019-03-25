package model::template_include;

use strict;
use base 'model::base';

sub new {

	my ( $n, $dbh ) = @_;

	my $x = {
		dbh => $dbh,
		m   => model::init->new($dbh)
	};

	bless $x;
	return $x;

}

sub configuracion_menu {

	my ( $x, %pp ) = @_;

	my $sql = qq {
	SELECT 	'STAFF_COUNT',COUNT(*)
	FROM 	_g_users
	WHERE 	_g_users.active = TRUE
	AND 	( _g_users.is_admin = TRUE OR _g_users.is_coach = TRUE )

	UNION

	SELECT 	'DETAIL_COUNT',COUNT(*)
	FROM 	_g_additional_details
	WHERE 	_g_additional_details.active = TRUE

	UNION

	SELECT 	'MEMBERSHIP_COUNT',COUNT(*)
	FROM 	_f_memberships
	WHERE 	_f_memberships.active = TRUE

	UNION

	SELECT 	'DISCOUNT_COUNT',COUNT(*)
	FROM 	_f_discounts
	WHERE 	_f_discounts.active = TRUE
	};

	my %data;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my ( $type, $count ) = $sth->fetchrow() ) {
		$data{$type} = $count;
	}

	$sth->finish();

	return \%data;

}

sub ventas_menu {

	my ( $x, %pp ) = @_;

	my $sql = qq {
	SELECT 	'PRODUCT_COUNT',COUNT(*)
	FROM 	_i_items
	WHERE 	_i_items.active = TRUE
	};

	my %data;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my ( $type, $count ) = $sth->fetchrow() ) {
		$data{$type} = $count;
	}

	$sth->finish();

	return \%data;

}

sub header_notifications {

	my ( $x, %pp ) = @_;

	my $charge_count = $x->{m}->count(
		where => {
			type_code                  => 'M',
			'creation_date_time::DATE' => 'NOW()',
		},
		gt => {
			amount => 0,
		},
		table => '_f_charges',
	);

	my $notification_seen = $x->{m}->count(
		where => {
			user_id => $pp{user_id},
			tip_id  => 'RENOVACIONES-DEL-DIA',
		},
		table => '_g_seen_tips',
	);

	return {
		charge_count      => $charge_count      || 0,
		notification_seen => $notification_seen || 0,
	};

}

1;
