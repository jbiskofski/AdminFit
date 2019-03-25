package controller::visitas;

use strict;

sub new {

	my ( $n, $d ) = @_;

	my $x = {
		v => view::render->new( $d->{r} ),
		m => model::init->new( $d->{dbh} ),
	};

	bless $x;
	return $x;

}

sub uso_de_cliente {

	my ( $x, $d ) = @_;

	$d->{data}->{visit_package} = $x->{m}->{memberships}->get_visit_memberships(
		charge_id => $d->{p}->{id},
		limit     => 1
	);

	$d->{data}->{user} = $x->{m}->{users}->get_users(
		where => { '_g_users.id' => $d->{data}->{visit_package}->{client_id} },
		limit => 1,
	);

	$d->{data}->{attendance} = $x->{m}->{attendance}->get_attendance( where => { '_a_attendance.visits_charge_id' => $d->{p}->{id} } );

	if ( $d->{data}->{attendance} ) {

		my @values;
		my @labels;

		my $first_date = $d->{data}->{attendance}->[-1]->{date};
		my $last_date  = $d->{data}->{attendance}->[0]->{date};

		my $dates = global::date_time->get_dates_between( $first_date, $last_date );
		my %usage = map { $_->{date} => scalar @{ $_->{times} } } @{ $d->{data}->{attendance} };

		foreach my $date ( @{$dates} ) {
			my ( $day, $month ) = split( /\D+/, $date );
			push @labels, $day . '/' . $month;
			push @values, $usage{$date} || 0;
		}

		$d->{data}->{charts}->{daily_attendance} = global::charts->lines(
			color  => 'red',
			values => \@values,
			labels => \@labels,
			div_id => 'DIV-DAILY-ATTENDANCE-CHART',
			title  => 'Visitas',
		);

	}

	$x->{v}->render($d);

}

1;
