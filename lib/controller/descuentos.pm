package controller::descuentos;

use strict;
use base 'controller::descuentos::management';

sub new {

	my ( $n, $d ) = @_;

	my $x = {
		v => view::render->new( $d->{r} ),
		m => model::init->new( $d->{dbh} ),
	};

	bless $x;
	return $x;

}

sub default {

	my ( $x, $d ) = @_;

	$d->{data}->{discounts} = $x->{m}->{discounts}->get_discounts();

	$d->{data}->{memberships} = $x->{m}->{memberships}->get_memberships(
		where => {
			'_f_memberships.active' => 1
		}
	);

	my $month_discounts = $x->{m}->{discounts}->get_timeframe_discounts( get_current_month => 1 );

	if ( $month_discounts && scalar @{ $month_discounts->{dates} } ) {

		my @daily_labels;
		my @daily_discounts;

		foreach my $dd ( @{ $month_discounts->{dates} } ) {
			my ( $day, $month, $year ) = split( /\D+/, $dd->{date} );
			push @daily_labels, $day;
			push @daily_discounts, $dd->{total} || 0;
		}

		$d->{data}->{charts}->{daily_discounts} = global::charts->lines(
			monify => 1,
			color  => 'blue',
			values => \@daily_discounts,
			labels => \@daily_labels,
			div_id => 'DIV-DAILY-DISCOUNT-CHART',
			title  => 'Descuentos',
		);

	}

	$d->get_form_validations();
	$x->{v}->render($d);

}

sub x_check_name_availability {

	my ( $x, $d ) = @_;

	my $count = $x->{m}->count(
		where => {
			name => $d->{p}->{name}
		},
		ignore_case => 1,
		table       => '_f_discounts'
	);

	$x->{v}->render_json( { available => $count ? 0 : 1 } );

}

sub upsert_do {

	my ( $x, $d ) = @_;

	my $is_update = 1 if $d->{p}->{id};

	if ($is_update) {

		my $discount = $x->{m}->{discounts}->get_discounts(
			where => { '_f_discounts.id' => $d->{p}->{id} },
			limit => 1,
		);

		if ( $discount->{is_permanent} ) {
			$d->warning('No es posible modificar o deshabilitar el descuento general.');
			return $x->{v}->status($d);
		}

	}

	$d->{p}->{id} = global::standard->uuid() unless $is_update;

	$d->{p}->{amount} = $d->{p}->{amount} && $d->{p}->{amount} > 0 ? $d->{p}->{amount} : 0;
	$d->{p}->{amount} =~ s/,//;

	if ( $d->{p}->{type_code} eq 'G' ) {
		$d->{p}->{requirement_type_code}   = 'A';
		$d->{p}->{discount_month_duration} = 1;
	}

	my %insert = (
		id                      => $d->{p}->{id},
		name                    => $d->{p}->{name},
		amount                  => $d->{p}->{amount},
		type_code               => $d->{p}->{type_code},
		requirement_type_code   => $d->{p}->{requirement_type_code},
		discount_month_duration => $d->{p}->{discount_month_duration},
		notes                   => $d->{p}->{notes},
	);

	$x->{m}->upsert(
		insert          => \%insert,
		conflict_fields => ['id'],
		table           => '_f_discounts',
	);

	if ( $d->{p}->{requirement_type_code} eq 'S' ) {

		my %membership_ids;
		my @insert_membership_ids;

		foreach my $key ( keys %{ $d->{p} } ) {
			next unless $key =~ /^MM-(\S+)$/;
			$membership_ids{$1} = 1;
		}

		foreach my $membership_id ( keys %membership_ids ) {
			push @insert_membership_ids,
			  {
				discount_id   => $d->{p}->{id},
				membership_id => $membership_id,
			  };
		}

		$x->{m}->delete(
			where => { discount_id => $d->{p}->{id} },
			table => '_f_discount_participating_memberships'
		);

		$x->{m}->bulk_insert(
			items => \@insert_membership_ids,
			table => '_f_discount_participating_memberships'
		) if scalar @insert_membership_ids;

	}

	my $message =
	  $d->{p}->{id}
	  ? 'Descuento actualizado.'
	  : 'Descuento agregado.';

	$d->success($message);
	$d->save_state();

	my $method = $is_update ? 'ver' : 'default';

	return $x->{v}->http_redirect(
		c  => 'descuentos',
		m  => $method,
		id => $d->{p}->{id},
	);

}

sub ver {

	my ( $x, $d ) = @_;

	$d->{data}->{discount} = $x->{m}->{discounts}->get_discounts(
		where => { '_f_discounts.id' => $d->{p}->{id} },
		limit => 1,
	);

	$d->{data}->{memberships} = $x->{m}->{memberships}->get_memberships( where => { '_f_memberships.active' => 1 } );

	$d->{data}->{history} = $x->{m}->{discounts}->get_history(
		discount_id => $d->{p}->{id},
		limit       => 11
	);

	if ( $d->{data}->{history} ) {

		foreach my $hh ( @{ $d->{data}->{history} } ) {
			if ( $hh->{type_code} eq 'CANCELLED' ) {
				$d->{data}->{totals}->{cancelled}++;
			}
			elsif ( $hh->{type_code} eq 'DISCOUNT' ) {
				$d->{data}->{totals}->{discount_amount} += $hh->{discount_amount};
				$d->{data}->{totals}->{discounts}++;
			}
		}

		my %dates;
		foreach my $hh ( @{ $d->{data}->{history} } ) {
			next if $hh->{type_code} eq 'CANCELLED';
			my ($date) = split( /\s+/, $hh->{date_time} );
			$dates{$date} += $hh->{discount_amount};
		}

		my $month_discounts = $x->{m}->{discounts}->get_timeframe_discounts(
			discount_id       => $d->{p}->{id},
			get_current_month => 1
		);

		if ( $month_discounts && scalar @{ $month_discounts->{dates} } ) {

			my @daily_labels;
			my @daily_discounts;

			foreach my $dd ( @{ $month_discounts->{dates} } ) {
				my ( $day, $month, $year ) = split( /\D+/, $dd->{date} );
				push @daily_labels, $day;
				push @daily_discounts, $dd->{total} || 0;
			}

			$d->{data}->{charts}->{daily_discounts} = global::charts->lines(
				monify => 1,
				color  => 'blue',
				values => \@daily_discounts,
				labels => \@daily_labels,
				div_id => 'DIV-DAILY-DISCOUNT-CHART',
				title  => 'Descuentos',
			);

		}

	}

	$d->get_form_validations();

	$x->{v}->render($d);

}

sub switch_active_do {

	my ( $x, $d ) = @_;

	my $discount = $x->{m}->{discounts}->get_discounts(
		where => { '_f_discounts.id' => $d->{p}->{id} },
		limit => 1,
	);

	if ( $discount->{is_permanent} ) {
		$d->warning('No es posible modificar o deshabilitar el descuento general.');
		return $x->{v}->status($d);
	}

	$x->{m}->update(
		update => { active => $d->{p}->{active} },
		where  => {
			id => $d->{p}->{id}
		},
		table => '_f_discounts',
	);

	my $message = $d->{p}->{active} ? 'Descuento reactivado.' : 'Descuento desactivado.';
	$d->success($message);
	$d->save_state();

	return $x->{v}->http_redirect(
		c      => 'descuentos',
		method => 'ver',
		id     => $d->{p}->{id}
	);

}

sub historial {

	my ( $x, $d ) = @_;

	if ( !$d->{p}->{start_date} && !$d->{p}->{end_date} && !$d->{p}->{fecha} ) {
		$d->{p}->{start_date} = global::date_time->get_past_date(21);
		$d->{p}->{end_date}   = global::date_time->get_date();
	}

	if ( ( $d->{p}->{start_date} && $d->{p}->{end_date} )
		&& $d->{p}->{start_date} eq $d->{p}->{end_date} )
	{
		$d->{p}->{fecha}      = $d->{p}->{start_date};
		$d->{p}->{start_date} = undef;
		$d->{p}->{end_date}   = undef;
	}

	$d->{p}->{fecha} //= global::date_time->get_date();

	$d->{data}->{history} = $x->{m}->{discounts}->get_history(
		discount_id => $d->{p}->{id},
		date        => $d->{p}->{fecha},
		start_date  => $d->{p}->{start_date},
		end_date    => $d->{p}->{end_date},
	);

	if ( $d->{data}->{history} ) {

		foreach my $hh ( @{ $d->{data}->{history} } ) {
			if ( $hh->{type_code} eq 'CANCELLED' ) {
				$d->{data}->{totals}->{cancelled}++;
			}
			elsif ( $hh->{type_code} eq 'DISCOUNT' ) {
				$d->{data}->{totals}->{discount_amount} += $hh->{discount_amount};
				$d->{data}->{totals}->{discounts}++;
			}
		}

		my $discounts = $x->{m}->{discounts}->get_timeframe_discounts(
			discount_id => $d->{p}->{id},
			date        => $d->{p}->{fecha},
			start_date  => $d->{p}->{start_date},
			end_date    => $d->{p}->{end_date},
		);

		if ( $discounts && scalar @{ $discounts->{dates} } ) {

			my @daily_labels;
			my @daily_sales;

			foreach my $dd ( @{ $discounts->{dates} } ) {
				push @daily_labels, $dd->{date};
				push @daily_sales, $dd->{total} || 0;
			}

			$d->{data}->{charts}->{daily_discounts} = global::charts->lines(
				monify => 1,
				color  => 'blue',
				values => \@daily_sales,
				labels => \@daily_labels,
				div_id => 'DIV-DAILY-DISCOUNT-CHART',
				title  => 'Descuentos',
			);

		}

	}
	else {
		$d->info('No se han encontrado descuentos utilizando la b&uacute;squeda especificada.');
	}

	$x->{v}->render($d);

}

1;
