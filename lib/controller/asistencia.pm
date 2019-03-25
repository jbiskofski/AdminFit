package controller::asistencia;

use strict;
use base 'controller::asistencia::standard';
use Sort::Key qw/keysort nkeysort/;

sub new {

	my ( $n, $d ) = @_;

	my $x = {
		v => view::render->new( $d->{r} ),
		m => model::init->new( $d->{dbh} ),
	};

	bless $x;
	return $x;

}

sub presente_do {

	my ( $x, $d ) = @_;

	my %exists_options = (
		where => {
			'_a_attendance.client_id' => $d->{p}->{id},
		},
		limit => 1,
	);

	my %insert = (
		client_id => $d->{p}->{id},
		admin_id  => $d->{s}->{user_id}
	);

	if ( $d->{p}->{date} ) {
		$exists_options{date} = $d->{p}->{date};
		$exists_options{hour} = $d->{p}->{hour};
		$insert{date}         = $d->{p}->{date};
		$insert{time}         = $d->{p}->{hour} . ':00:00';
	}
	else {
		$exists_options{current_date} = 1;
		$exists_options{current_hour} = 1;
	}

	my $attendance_exists = $x->{m}->{attendance}->get_attendance(%exists_options);

	if ($attendance_exists) {
		$d->warning('No es posible registrar asistencia de un usuario dos veces en la misma hora.');
		$d->{p} = undef;
		$d->save_state();
		return $x->{v}->http_redirect_to_referer();
	}

	my $membership = $x->{m}->{memberships}->get_client_memberships(
		where => {
			'_f_client_memberships.client_id' => $d->{p}->{id},
		},
		limit => 1,
	);

	if ( $membership->{is_visits_membership} ) {

		my $visits_package = $x->{m}->{memberships}->get_visit_memberships(
			client_id => $d->{p}->{id},
			limit     => 1
		);

		unless ( $visits_package->{active} ) {
			$d->warning('El cliente seleccionado no tiene un paquete de visitas activo.');
			$d->{p} = undef;
			$d->save_state();
			return $x->{v}->http_redirect_to_referer();
		}

		$insert{visits_charge_id} = $visits_package->{charge_id} if $visits_package && $visits_package->{charge_id};

	}

	if ( $membership->{has_timeframe_limitations} ) {

		my $parts = global::date_time->get_date_time_parts();

		if (   !$membership->{limit_dows}->{ $parts->{dow} }
			|| !$membership->{limit_hours}->{ $parts->{hour} } )
		{

			my $membership_uri = global::ttf->uri( c => 'membresias', m => 'ver', id => $membership->{membership_id} );
			my $message = qq {
				La membres&iacute;a del cliente : $membership->{name}, no permite entrenar en este horario.
				<br>
				<br>
				<a href="$membership_uri" class="btn btn-danger btn-sm">
					<i class="fe fe-repear mr-2"></i>
					Ver detalles de membres&iacute;a
				</a>
			};

			$d->warning($message);
			$d->{p} = undef;
			$d->save_state();
			return $x->{v}->http_redirect_to_referer();
		}

	}

	$x->{m}->insert(
		insert       => \%insert,
		no_id_column => 1,
		table        => '_a_attendance'
	);

	$d->success('Asistencia registrada.');

	$d->{p} = undef;
	$d->save_state();

	return $x->{v}->http_redirect_to_referer();

}

sub delete_do {

	my ( $x, $d ) = @_;

	$x->{m}->update(
		update => {
			cancelled          => 1,
			cancelled_admin_id => $d->{s}->{user_id},
			cancelled_notes    => $d->{p}->{notes},
		},
		where => { id => $d->{p}->{id} },
		table => '_a_attendance'
	);

	$d->success('Asistencia eliminada.');

	$d->{p} = undef;
	$d->save_state();

	return $x->{v}->http_redirect_to_referer();

}

sub ver {

	my ( $x, $d ) = @_;

	$d->{data}->{user} = $x->{m}->{users}->get_users(
		where => { '_g_users.id' => $d->{p}->{id} },
		limit => 1,
	);

	if ( !$d->{data}->{user}->{active} ) {
		my $ctip = controller::tips->new($d);
		$d->notification(
			$ctip->get(
				tip               => 'DISABLED-USER',
				user_id           => $d->{p}->{id},
				is_client         => $d->{data}->{user}->{is_client},
				no_dismiss_button => 1,
			)
		);
	}

	my $parts = global::date_time->get_date_time_parts();
	my $month = $d->{p}->{month} || $parts->{month};
	my $year  = $d->{p}->{year} || $parts->{year};

	$d->{data}->{parts} = global::date_time->get_date_time_parts("1/$month/$year");

	$d->{data}->{prev_next} = global::date_time->get_prev_next(
		month => $d->{p}->{month},
		year  => $d->{p}->{year}
	);

	$d->{data}->{attendance} = $x->{m}->{attendance}->get_attendance(
		where => { '_a_attendance.client_id' => $d->{p}->{id} },
		month => $month,
		year  => $year,
	);

	if ( $d->{data}->{attendance} ) {

		my @values;
		my @labels;

		my $first_date = $d->{data}->{attendance}->[-1]->{date};
		my $last_date  = $d->{data}->{attendance}->[0]->{date};

		my $dates = global::date_time->get_dates_between( $first_date, $last_date );
		my %usage = map { $_->{date} => scalar @{ $_->{times} } } @{ $d->{data}->{attendance} };

		foreach my $date ( @{$dates} ) {
			my ( $day, $month ) = split( /\D+/, $date );
			push @labels, $day;
			push @values, $usage{$date} || 0;
		}

		my %totals;
		foreach my $aa ( @{ $d->{data}->{attendance} } ) {
			my @cancelled = grep { $_->{cancelled} } @{ $aa->{times} };
			my @ok        = grep { !$_->{cancelled} } @{ $aa->{times} };
			$totals{days}++ if scalar @ok;
			$totals{visits}    += scalar @ok;
			$totals{cancelled} += scalar @cancelled;
		}
		$d->{data}->{totals} = \%totals;

		$d->{data}->{charts}->{attendance} = global::charts->lines(
			color  => 'red',
			values => \@values,
			labels => \@labels,
			div_id => 'DIV-ATTENDANCE-CHART',
			title  => 'Asistencia',
		) if $totals{days} > 1;

	}

	$d->get_form_validations();
	$x->{v}->render($d);

}

sub resumen {

	my ( $x, $d ) = @_;

	if ( ( $d->{p}->{start_date} && $d->{p}->{end_date} )
		&& $d->{p}->{start_date} eq $d->{p}->{end_date} )
	{
		$d->{p}->{fecha}      = $d->{p}->{start_date};
		$d->{p}->{start_date} = undef;
		$d->{p}->{end_date}   = undef;
	}

	$d->{p}->{fecha} //= global::date_time->get_date();
	my $date = $d->{p}->{fecha};

	$d->{data}->{multi_day_search} = 0;

	$d->{data}->{attendance} = $x->{m}->{attendance}->get_attendance(
		date                      => $date,
		start_date                => $d->{p}->{start_date},
		end_date                  => $d->{p}->{end_date},
		order_by_client_date_time => 1,
	);

	if ( $d->{data}->{attendance} ) {

		my %totals;
		my @values;
		my @labels;

		my @sorted = nkeysort { $_->{date_epoch} } @{ $d->{data}->{attendance} };

		my $first_date = $sorted[0]->{date};
		my $last_date  = $sorted[-1]->{date};

		if ( $first_date eq $last_date ) {

			my %hours;

			foreach my $aa ( @{ $d->{data}->{attendance} } ) {
				my @cancelled = grep { $_->{cancelled} } @{ $aa->{times} };
				my @ok        = grep { !$_->{cancelled} } @{ $aa->{times} };
				foreach my $time (@ok) {
					my ($hour) = split( /:/, $time->{time} );
					$hours{ int($hour) }++;
				}
				$totals{days}++ if scalar @ok;
				$totals{visits}    += scalar @ok;
				$totals{cancelled} += scalar @cancelled;
			}

			for ( my $c = 0 ; $c <= 23 ; $c++ ) {
				push @labels, $c . ':00';
				push @values, $hours{ int($c) } || 0;
			}

		}
		else {

			$d->{data}->{multi_day_search} = 1;
			my $dates = global::date_time->get_dates_between( $first_date, $last_date );
			my %usage;

			foreach my $aa ( @{ $d->{data}->{attendance} } ) {
				my @cancelled = grep { $_->{cancelled} } @{ $aa->{times} };
				my @ok        = grep { !$_->{cancelled} } @{ $aa->{times} };
				$usage{ $aa->{date} } += scalar @ok;
				$totals{days}++ if scalar @ok;
				$totals{visits}    += scalar @ok;
				$totals{cancelled} += scalar @cancelled;
			}

			foreach my $date ( @{$dates} ) {
				my ($day) = split( /\D+/, $date );
				push @labels, $day;
				push @values, $usage{$date} || 0;
			}

			$d->{data}->{attendance} = $x->_aggregate_client_day_attendance( $d->{data}->{attendance} );

		}

		$d->{data}->{totals} = \%totals;

		$d->{data}->{charts}->{attendance} = global::charts->lines(
			color  => 'red',
			values => \@values,
			labels => \@labels,
			div_id => 'DIV-ATTENDANCE-CHART',
			title  => 'Asistencia',
		) if scalar @values;

	}

	$d->{data}->{date} = $date;

	my $yt = global::date_time->yesterday_tomorrow($date);
	$d->{data}->{yesterday} = $yt->{yesterday};
	$d->{data}->{tomorrow}  = $yt->{tomorrow};

	$x->{v}->render($d);

}

1;
