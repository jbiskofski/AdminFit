package global::date_time;

use strict;
use Calendar::Gregorian;
use Calendar::Simple;
use Date::Calc qw(Delta_Days Delta_DHMS Mktime Days_in_Month Day_of_Week Add_Delta_Days Day_of_Year leap_year);
use DateTime;
use DateTime::Format::Epoch;
use DateTime::TimeZone;
use Date::Range;
use Date::Simple;
use Sort::Key qw(rnkeysort);
use Time::HiRes;
use Time::Elapsed 'elapsed';
use Time::Local;
use POSIX 'strftime';

sub get_timezone_offset {

	# http://php.net/manual/en/timezones.php - timezone list
	return 0 if $ENV{TIMEZONE} eq 'America/Mexico_City' || !$ENV{TIMEZONE};

	my $tz;

	eval { $tz = DateTime::TimeZone->new( name => $ENV{TIMEZONE} ) };
	my $system_timezone = strftime( "%Z", localtime() );
	$system_timezone = 'America/Mexico_City' if $system_timezone eq 'CDT' || $system_timezone eq 'CST';

	global::standard->inspect("INVALID TIMEZONE DETECTED : $ENV{TIMEZONE}") if !$tz;

	my $base_tz     = DateTime::TimeZone->new( name => $system_timezone );
	my $base_date   = DateTime->now()->set_time_zone($base_tz);
	my $base_offset = $base_date->offset();

	my $tz_date   = $base_date->clone()->set_time_zone($tz);
	my $tz_offset = $tz_date->offset();
	my $offset    = $base_offset - $tz_offset;

	return $offset;

}

sub check_timezone_is_valid {
	return __PACKAGE__->get_timezone_offset() ? 1 : 0;
}

sub get_date {

	my @llt = localtime( time() - __PACKAGE__->get_timezone_offset() );
	return ( sprintf( "%02d", $llt[3] ) . '/' . sprintf( "%02d", ( $llt[4] + 1 ) ) . '/' . ( $llt[5] + 1900 ) );

}

sub get_yesterday {

	my @llt = localtime( time() - __PACKAGE__->get_timezone_offset() - 86400 );
	return ( sprintf( "%02d", $llt[3] ) . '/' . sprintf( "%02d", ( $llt[4] + 1 ) ) . '/' . ( $llt[5] + 1900 ) );

}

sub get_tomorrow {

	my @llt = localtime( time() - __PACKAGE__->get_timezone_offset() + 86400 );
	return ( sprintf( "%02d", $llt[3] ) . '/' . sprintf( "%02d", ( $llt[4] + 1 ) ) . '/' . ( $llt[5] + 1900 ) );

}

sub get_date_time {

	my $foo = __PACKAGE__->get_timezone_offset();
	my @llt = localtime( time() - __PACKAGE__->get_timezone_offset() );

	return (
		    sprintf( "%02d", $llt[3] ) . '/'
		  . sprintf( "%02d", ( $llt[4] + 1 ) ) . '/'
		  . ( $llt[5] + 1900 ) . ' '
		  . sprintf( "%02d", $llt[2] ) . ':'
		  . sprintf( "%02d", $llt[1] ) . ':'
		  . sprintf( "%02d", $llt[0] ) );

}

sub get_date_time_parts {

	my ( $n, $date_time ) = @_;

	$date_time //= __PACKAGE__->get_date_time();

	my ( $day, $month, $year, $hour, $minute, $second ) = split( /\D+/, $date_time );

	my $dow = Day_of_Week( $year, $month, $day );
	$dow = 0 if $dow == 7;

	my $short_year = substr( $year, 2, 4 );

	return {
		dow           => $dow,
		day           => $day,
		month         => $month,
		year          => $year,
		short_year    => $short_year,
		hour          => $hour,
		minute        => $minute,
		second        => $second,
		display_month => __PACKAGE__->get_display_month($month),
		display_dow   => __PACKAGE__->get_display_dow($dow),
	};

}

sub get_time {

	my @llt = localtime( time() - __PACKAGE__->get_timezone_offset() );
	return ( sprintf( "%02d", $llt[2] ) . ':' . sprintf( "%02d", $llt[1] ) . ':' . sprintf( "%02d", $llt[0] ) );

}

sub format_date_time {

	my ( $n, $date_time ) = @_;
	$date_time =~ s/^(\d{4})-(\d{2})-(\d{2})\s+(\d+):(\d+):(\d+).*$/$3\/$2\/$1 $4:$5:$6/;
	return $date_time;

}

sub format_date {

	my ( $n, $date ) = @_;

	my ( $year, $month, $day ) = split( /\D+/, $date );
	return $day . '/' . $month . '/' . $year;

}

sub format_time {

	my ( $n, $time ) = @_;
	$time =~ s/^(\d+):(\d+):(\d+).*$/$1:$2:$3/;
	return $time;

}

sub compare_date_time {

	my ( $x, $date_time_1, $date_time_2 ) = @_;

	$date_time_1 =~ /^(\d+)\/(\d+)\/(\d+)\s(\d+)\:(\d+)\:(\d+)$/;
	my @ddt1 = ( $3, $2, $1, $4, $5, $6 );

	$date_time_2 =~ /^(\d+)\/(\d+)\/(\d+)\s(\d+)\:(\d+)\:(\d+)$/;
	my @ddt2 = ( $3, $2, $1, $4, $5, $6 );

	my ( $Dd, $Dh, $Dm, $Ds ) = Delta_DHMS( $ddt1[0], $ddt1[1], $ddt1[2], $ddt1[3], $ddt1[4], $ddt1[5], $ddt2[0], $ddt2[1], $ddt2[2], $ddt2[3], $ddt2[4], $ddt2[5] );

	return ( $Dd * 24 * 60 * 60 + $Dh * 60 * 60 + $Dm * 60 + $Ds );

}

sub check_valid_date {

	my ( $n, $date ) = @_;

	return 0 unless $date && $date =~ /^\d{2}\/\d{2}\/\d{4}$/;

	my ( $day, $month, $year ) = split( /\D+/, $date );

	eval { timelocal( 0, 0, 0, $day, $month - 1, $year ); };

	return $@ ? 0 : 1;

}

sub get_display_month {

	my ( $n, $numeric ) = @_;

	my %months = (
		1  => 'Enero',
		2  => 'Febrero',
		3  => 'Marzo',
		4  => 'Abril',
		5  => 'Mayo',
		6  => 'Junio',
		7  => 'Julio',
		8  => 'Agosto',
		9  => 'Septiembre',
		10 => 'Octubre',
		11 => 'Noviembre',
		12 => 'Diciembre',
	);

	return $months{ int($numeric) };

}

sub get_display_dow {

	my ( $n, $numeric ) = @_;

	my %dows = (
		0 => 'Domingo',
		1 => 'Lunes',
		2 => 'Martes',
		3 => 'Mi&eacute;rcoles',
		4 => 'Jueves',
		5 => 'Viernes',
		6 => 'S&aacute;bado',
		7 => 'Domingo',
	);

	return $dows{ int($numeric) };

}

sub get_display_date {

	my ( $n, $date ) = @_;
	my ( $day, $month, $year ) = split( /\D+/, $date );

	return $day . ' de ' . __PACKAGE__->get_display_month($month) . ' - ' . $year;

}

sub get_epoch {

	my ( $x, $date_time ) = @_;

	my ( $day, $month, $year, $hour, $minute, $second ) = split( /\D/, $date_time );

	# dont convert an invalid date to epoch
	$day = 28 if $month == 2 && $day == 29 && !leap_year($year);
	$hour   //= 0;
	$minute //= 0;
	$second //= 0;

	my $epoch = timelocal( $second, $minute, $hour, $day, $month - 1, $year );
	return $epoch - __PACKAGE__->get_timezone_offset();

}

sub get_expiration_date {

	my ( $n, %pp ) = @_;

	my $parts = __PACKAGE__->get_date_time_parts();

	my $dt = DateTime->new(
		day   => $parts->{day},
		month => $parts->{month},
		year  => $parts->{year},
	);

	my @months;

	my %add_options;

	if ( $pp{unit} eq 'D' ) {
		$add_options{days} = $pp{number};
	}
	elsif ( $pp{unit} eq 'W' ) {
		$add_options{weeks} = $pp{number};
	}
	elsif ( $pp{unit} eq 'M' ) {
		$add_options{months} = $pp{number};
	}
	else {
		global::standard->inspect( 'invalid use of global::date_time->get_expiration', \%pp, __FILE__, __LINE__ );
	}

	$dt->add(%add_options);
	my ( $day, $month, $year ) = split( /\D+/, $dt->dmy() );

	return "$day/$month/$year";

}

sub get_prev_next {

	my ( $n, %pp ) = @_;

	if ( !$pp{month} || !$pp{year} ) {
		my $parts = __PACKAGE__->get_date_time_parts();
		$pp{month} = $parts->{month};
		$pp{year}  = $parts->{year};
	}

	my $start_date = 1 . '/' . $pp{month} . '/' . $pp{year};

	my $dt = DateTime->new(
		day   => 1,
		month => $pp{month},
		year  => $pp{year},
	);

	my $prev = $dt->subtract( months => 1 )->dmy();
	my $next = $dt->add( months => 2 )->dmy();

	return {
		prev => __PACKAGE__->get_date_time_parts($prev),
		next => __PACKAGE__->get_date_time_parts($next),
	};

}

sub get_next_months {

	my ( $n, %pp ) = @_;

	if ( !$pp{month} || !$pp{year} ) {
		my $parts = __PACKAGE__->get_date_time_parts();
		$pp{month} = $parts->{month};
		$pp{year}  = $parts->{year};
	}

	my $start_date = 1 . '/' . $pp{month} . '/' . $pp{year};
	my $dt         = DateTime->new(
		day   => 1,
		month => $pp{month},
		year  => $pp{year},
	);

	my @months;

	$dt->subtract( months => $pp{subtract_months} ) if $pp{subtract_months};

	for ( my $c = 0 ; $c < $pp{get_next} ; $c++ ) {

		my $date = $dt->add( months => 1 )->ymd();
		my ( $year, $month ) = split( /\D+/, $date );

		push @months,
		  {
			year          => $year,
			month         => $month,
			display_month => __PACKAGE__->get_display_month($month),
		  };

	}

	return scalar @months ? \@months : undef;

}

sub get_previous_months {

	my ( $n, %pp ) = @_;

	if ( !$pp{month} || !$pp{year} ) {
		my $parts = __PACKAGE__->get_date_time_parts();
		$pp{month} = $parts->{month};
		$pp{year}  = $parts->{year};
	}

	my $start_date = 1 . '/' . $pp{month} . '/' . $pp{year};
	my $dt         = DateTime->new(
		day   => 1,
		month => $pp{month},
		year  => $pp{year},
	);

	my @months;

	for ( my $c = 0 ; $c < $pp{get_previous} ; $c++ ) {

		my $date = $dt->subtract( months => 1 )->ymd();
		my ( $year, $month ) = split( /\D+/, $date );

		push @months,
		  {
			year          => $year,
			month         => $month,
			display_month => __PACKAGE__->get_display_month($month),
		  };

	}

	return scalar @months ? \@months : undef;

}

sub get_past_date {

	my ( $n, $days ) = @_;

	my $dt = DateTime->now();
	my $date = $dt->subtract( days => $days )->ymd();
	return global::date_time->format_date($date);

}

sub get_days_between {

	my ( $x, $in_d1, $in_d2 ) = @_;

	return undef unless ( $in_d1 && $in_d2 );

	$in_d1 =~ /^(\d+)\/(\d+)\/(\d+)$/;
	my ( $d1, $m1, $y1 ) = ( $1, $2, $3 );
	$in_d2 =~ /^(\d+)\/(\d+)\/(\d+)$/;
	my ( $d2, $m2, $y2 ) = ( $1, $2, $3 );

	my $result = Delta_Days( $y1, $m1, $d1, $y2, $m2, $d2 );

	return $result;

}

sub get_dates_between {

	my ( $x, $d1, $d2 ) = @_;

	$d1 =~ s/^(\d+)\/(\d+)\/(\d+)$/$3-$2-$1/;
	my $date1 = Date::Simple->new($d1);

	$d2 =~ s/^(\d+)\/(\d+)\/(\d+)$/$3-$2-$1/;
	my $date2 = Date::Simple->new($d2);

	my $range = Date::Range->new( $date1, $date2 );
	my @dates;

	foreach my $date ( $range->dates() ) {
		push( @dates, $date->format("%d/%m/%Y") );
	}

	return scalar @dates ? \@dates : undef;

}

sub get_calendar {

	my ( $n, %pp ) = @_;

	my $parts = __PACKAGE__->get_date_time_parts();

	my $month = $pp{month} || $parts->{month};
	my $year  = $pp{year}  || $parts->{year};

	my $month_tmp = Calendar::Simple::calendar( $month, $year );

	my @month;

	foreach my $ww ( @{$month_tmp} ) {
		my @week;
		foreach my $dd ( @{$ww} ) {
			push @week, { day => $dd, data => undef };
		}
		push @month, \@week;
	}

	return \@month;

}

sub yesterday_tomorrow {

	my ( $n, $date ) = @_;

	my $time = undef;

	if ($date) {
		my ( $day, $month, $year ) = split( /\//, $date );
		$time = Mktime( $year, $month, $day, 0, 0, 0 );
	}
	else {
		my ( $day, $month, $year ) = split( /\//, __PACKAGE__->get_date() );
		$time = time();
	}

	# yesterdays info
	my @y_llt = localtime( $time - __PACKAGE__->get_timezone_offset() - 86400 );
	my $yesterday = ( sprintf( "%02d", $y_llt[3] ) . '/' . sprintf( "%02d", ( $y_llt[4] + 1 ) ) . '/' . ( $y_llt[5] + 1900 ) );

	# tomorrows llt info
	my @t_llt = localtime( $time - __PACKAGE__->get_timezone_offset() + 86400 );
	my $tomorrow = ( sprintf( "%02d", $t_llt[3] ) . '/' . sprintf( "%02d", ( $t_llt[4] + 1 ) ) . '/' . ( $t_llt[5] + 1900 ) );

	return ( { yesterday => $yesterday, tomorrow => $tomorrow } );

}

1;
