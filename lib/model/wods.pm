package model::wods;

use strict;
use base 'model::base';

use Sort::Key qw/keysort rnkeysort/;
use Sort::Key::Multi qw/rsrnrnskeysort rnrnskeysort rnrnkeysort rsrnkeysort/;

sub new {

	my ( $n, $dbh ) = @_;

	my $x = {
		dbh => $dbh,
		m   => model::init->new($dbh)
	};

	bless $x;
	return $x;

}

sub get_calendar {

	my ( $x, %pp ) = @_;

	my $parts = global::date_time->get_date_time_parts();

	my $month = $pp{month} || $parts->{month};
	my $year  = $pp{year}  || $parts->{year};
	my $display_month = global::date_time->get_display_month($month);

	my $calendar = global::date_time->get_calendar(
		month => $month,
		year  => $year,
	);

	my $wods_tmp = $x->get_wods( month => $pp{month}, year => $pp{year} );
	my %wods;

	foreach my $wod ( @{$wods_tmp} ) {
		my ($day) = split( /\D+/, $wod->{date} );
		push @{ $wods{$day} }, $wod;
	}

	foreach my $ww ( @{$calendar} ) {
		foreach my $dd ( @{$ww} ) {
			next unless $dd->{day};
			next unless $wods{ $dd->{day} } && ref( $wods{ $dd->{day} } ) eq 'ARRAY';
			$dd->{data}->{wod_count} = scalar @{ $wods{ $dd->{day} } };
		}
	}

	return {
		weeks         => $calendar,
		display_month => $display_month,
		year          => $year,
		daily         => \%wods
	};

}

sub get_wods {

	my ( $x, %pp ) = @_;

	my $SQL_date_where = qq {
		AND 	EXTRACT(MONTH FROM _w_wods.date) = $pp{month}
		AND 	EXTRACT(YEAR FROM _w_wods.date) = $pp{year}
	} if $pp{month} && $pp{year};

	my $sql = qq {
	SELECT	_w_wods.id,_w_wods.date,_w_wods.name,_w_wods.type_code,
		_w_wods.coach_id,_g_users.name,_g_users.lastname1,_g_users.lastname2,
		_w_wods.creation_date_time,_w_wods.instructions
	FROM 	_w_wods
	JOIN 	_g_users ON ( _g_users.id = _w_wods.coach_id )
	WHERE 	TRUE
	$SQL_date_where
	};

	my @items;
	my @keys = qw/id date name type_code coach_id _coach_name
	  _coach_lastname1 _coach_lastname2 creation_date_time instructions/;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;

		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}

		$ii{coach_display_name} = global::standard->get_person_display_name( $ii{_coach_name}, $ii{_coach_lastname1}, $ii{_coach_lastname2} );
		$ii{creation_date_time} = global::date_time->format_date_time( $ii{creation_date_time} );
		$ii{date}               = global::date_time->format_date( $ii{date} );

		foreach my $key ( keys %ii ) {
			delete $ii{$key} if substr( $key, 0, 1 ) eq '_';
		}

		push @items, \%ii;

	}

	$sth->finish();

	return scalar @items ? \@items : undef;

}

1;
