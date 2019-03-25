package controller::wods::standard;

use strict;
use Sort::Key qw/keysort nkeysort/;

sub _get_wod_types {

	shift;
	my (%pp) = @_;

	my @types = (
		{
			id          => 'FT',
			name        => 'FT',
			description => 'For time',
		},
		{
			id          => 'RFT',
			name        => 'RFT',
			description => 'Rounds for time',
		},
		{
			id          => 'AMRAP',
			name        => 'AMRAP',
			description => 'As many rounds as possible',
		},
		{
			id          => 'EMOM',
			name        => 'EMOM',
			description => 'Every minute on the minute',
		},
		{
			id          => 'DEATH-BY',
			name        => 'DEATH-BY',
			description => 'Death by',
		},
		{
			id          => 'TABATA',
			name        => 'TABATA',
			description => '20 segundos de trabajo<br>10 de descanso<br>8 rounds',
		},
		{
			id          => 'COMPLETE',
			name        => 'COMPLETE',
			description => 'Finalizar los ejercicios',
		},
	);

	return \@types;

}

sub _get_exercises {

	shift;
	my (%pp) = @_;

	my @exercises = (

		{
			id   => 'AIR-SQUAT',
			name => 'Air Squats',
		},
		{
			id         => 'FRONT-SQUAT',
			name       => 'Front Squats',
			ask_metric => 1
		},
		{
			id         => 'PRESS',
			name       => 'Press',
			ask_metric => 1
		},
		{
			id         => 'SHOULDER-PRESS',
			name       => 'Shoulder Press',
			ask_metric => 1
		},
		{
			id         => 'PUSH-PRESS',
			name       => 'Push Press',
			ask_metric => 1
		},
		{
			id         => 'PUSH-JERK',
			name       => 'Push Jerk',
			ask_metric => 1
		},
		{
			id         => 'SDHP',
			name       => 'Sumo Deadlift High Pull',
			ask_metric => 1
		},
		{
			id         => 'MED-BALL-CLEAN',
			name       => 'Med Ball Clean',
			ask_metric => 1
		},
		{
			id   => 'RUN',
			name => 'Run',
		},

		# olympic lifting
		{
			id         => 'OHS',
			name       => 'Overhead Squats',
			ask_metric => 1,
		},
		{
			id         => 'CLEAN',
			name       => 'Clean',
			ask_metric => 1
		},
		{
			id         => 'POWER-CLEAN',
			name       => 'Power Clean',
			ask_metric => 1
		},
		{
			id         => 'SNATCH',
			name       => 'Snatch',
			ask_metric => 1
		},
		{
			id         => 'POWER-SNATCH',
			name       => 'Power Snatch',
			ask_metric => 1
		},
		{
			id         => 'HANG-POWER-CLEAN',
			name       => 'Hang Power Clean',
			ask_metric => 1
		},
		{
			id         => 'DUMBBELL-SNATCH',
			name       => 'Dumbbell Snatch',
			ask_metric => 1
		},
		{
			id         => 'CLUSTER',
			name       => 'Cluster',
			ask_metric => 1
		},
		{
			id         => 'TURKISH-GET-UP',
			name       => 'Turkish Get Ups',
			ask_metric => 1
		},
		{
			id         => 'LIFT',
			name       => 'Lift',
			ask_metric => 1
		},
		{
			id         => 'DEADLIFT',
			name       => 'Deadlift',
			ask_metric => 1
		},

		# other
		{
			id   => 'ROW',
			name => 'Row'
		},
		{
			id         => 'THRUSTERS',
			name       => 'Thrusters',
			ask_metric => 1
		},
		{
			id         => 'KB-SWINGS',
			name       => 'Kettlebell Swings',
			ask_metric => 1
		},
		{
			id   => 'DOUBLE-UNDERS',
			name => 'Double Unders'
		},
		{
			id   => 'SINGLE-UNDERS',
			name => 'Single Unders'
		},
		{
			id         => 'WALL-BALL-SHOTS',
			name       => 'Wall Ball Shots',
			ask_metric => 1
		},
		{
			id   => 'WALKING-LUNGES',
			name => 'Walking Lunges'
		},
		{
			id         => 'OVERHEAD-WALKING-LUNGES',
			name       => 'Overhead Walking Lunges',
			ask_metric => 1
		},
		{
			id   => 'WALL-WALKS',
			name => 'Wall Walks'
		},
		{
			id   => 'ASSAULT-BIKE',
			name => 'Assault Bike'
		},

		# gymnastics
		{
			id   => 'PUSH-UPS',
			name => 'Push Up'
		},
		{
			id   => 'SIT-UPS',
			name => 'Sit Up'
		},
		{
			id   => 'PULL-UPS',
			name => 'Pull Ups',
		},
		{
			id   => 'RING-ROWS',
			name => 'Ring Row'
		},
		{
			id   => 'C2B',
			name => 'Chest To Bar'
		},
		{
			id   => 'LSIT',
			name => 'L-Sit'
		},
		{
			id   => 'LSIT-PULL-UP',
			name => 'L-Sit Pull Up'
		},
		{
			id         => 'BOX-JUMP',
			name       => 'Box Jump',
			ask_metric => 1
		},
		{
			id   => 'RING-DIP',
			name => 'Ring Dip'
		},
		{
			id   => 'BURPEE',
			name => 'Burpee'
		},
		{
			id   => 'T2B',
			name => 'Toes To Bar'
		},
		{
			id   => 'HSPU',
			name => 'Handstand Push Ups'
		},
		{
			id   => 'KIPPING-HSPU',
			name => 'Kipping HSPU'
		},
		{
			id   => 'ROPE-CLIMB',
			name => 'Rope Climb'
		},
		{
			id   => 'LEGLESS-ROPE-CLIMB',
			name => 'Legless Rope Climb'
		},

	);

	my @sorted = keysort { $_->{name} } @exercises;
	return \@sorted;

}

1;
