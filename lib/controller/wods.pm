package controller::wods;

use strict;
use base 'controller::wods::standard';
use JSON::XS;

sub new {

	my ( $n, $d ) = @_;

	my $x = {
		v => view::render->new( $d->{r} ),
		m => model::init->new( $d->{dbh} ),
	};

	bless $x;
	return $x;

}

sub programacion {

	my ( $x, $d ) = @_;

	$d->{data}->{main_types} = __PACKAGE__->_get_wod_types();
	$d->{data}->{exercises}  = __PACKAGE__->_get_exercises();

	my $parts = global::date_time->get_date_time_parts();
	$d->{data}->{default_wod_name} = $parts->{short_year} . $parts->{month} . $parts->{day};

	$d->get_form_validations();
	$x->{v}->render($d);

}

sub mes {

	my ( $x, $d ) = @_;

	$d->{data}->{prev_next} = global::date_time->get_prev_next(
		month => $d->{p}->{month},
		year  => $d->{p}->{year}
	);

	$d->{data}->{calendar} = $x->{m}->{wods}->get_calendar(
		month => $d->{p}->{month},
		year  => $d->{p}->{year},
	);

	$x->{v}->render($d);

}

sub upsert_do {

	my ( $x, $d ) = @_;

	my $exercises = JSON::XS->new()->latin1()->decode( $d->{p}->{JSON_exercise_items} );

	my $wod_id = $d->{p}->{id} || global::standard->uuid();

	$x->{m}->upsert(
		insert => {
			id           => $wod_id,
			date         => $d->{p}->{date},
			name         => $d->{p}->{name},
			type_code    => $d->{p}->{main_type_code},
			coach_id     => $d->{s}->{user_id},
			instructions => $d->{p}->{instructions},
		},
		conflict_fields => ['id'],
		table           => '_w_wods',
	);

	foreach my $ee ( @{$exercises} ) {
		$ee->{wod_id} = $wod_id;
		$ee->{ask_metric} = $ee->{male_metric} + $ee->{female_metric} > 0 ? 1 : 0;
	}

	$x->{m}->bulk_insert(
		items => $exercises,
		table => '_w_exercises'
	);

	my $message =
	  $d->{p}->{id}
	  ? 'WOD actualizado.'
	  : 'WOD agregado.';

	$d->success($message);
	$d->save_state();

	my $method = $d->{p}->{id} ? 'ver' : 'programacion';

	return $x->{v}->http_redirect(
		c  => 'wods',
		m  => $method,
		id => $d->{p}->{id},
	);

}

1;
