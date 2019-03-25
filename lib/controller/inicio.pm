package controller::inicio;

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

sub default {

	my ( $x, $d ) = @_;

	$d->{data}->{total_clients} = $x->{m}->{clients}->get_total_paying_clients();

	my $debts_and_expirations = $x->{m}->{charges}->get_expiring( days => 5 );

	$d->{data}->{expiring}   = $debts_and_expirations->{expiring};
	$d->{data}->{total_debt} = $debts_and_expirations->{total_debt};

	my $divider = $d->{data}->{total_clients} || 1;
	$d->{data}->{client_debt_pct} = int( ( $debts_and_expirations->{clients_with_debt} * 100 ) / $divider );

	my $daily_payments = $x->{m}->{payments}->get_last_payments( days => 7 );
	my $todays_date = global::date_time->get_date();

	$d->{data}->{income} = 0;

	my @payment_values;
	my @payment_labels;

	foreach my $pay ( @{$daily_payments} ) {
		my ( $date, $value ) = %{$pay};
		my ($day) = split( /\D+/, $date );
		push @payment_values, $value;
		push @payment_labels, $day;
		$d->{data}->{income} = $value if $date eq $todays_date;
	}

	$d->{data}->{charts}->{daily_payments} = global::charts->lines(
		monify => 1,
		values => \@payment_values,
		labels => \@payment_labels,
		div_id => 'DIV-DAILY-PAYMENTS-CHART',
		title  => 'Ingresos',
	);

	if ( $d->{data}->{income} > 0 ) {

		my $payment_concept_dist = $x->{m}->{payments}->get_concept_distribution( date => global::date_time->get_date() );

		$d->{data}->{charts}->{payments} = global::charts->pie(
			monify => 1,
			title  => 'Distribuci&oacute;n',
			color  => 'green',
			values => $payment_concept_dist,
			div_id => 'DIV-PAYMENT-DISTRIBUTION-CHART',
			others => 7,
		) if $payment_concept_dist;

		my $charge_concept_dist = $x->{m}->{charges}->get_concept_distribution( date => global::date_time->get_date() );

		$d->{data}->{charts}->{charges} = global::charts->pie(
			monify => 1,
			title  => 'Distribuci&oacute;n',
			color  => 'red',
			values => $charge_concept_dist,
			div_id => 'DIV-CHARGE-DISTRIBUTION-CHART',
			others => 7,
		) if $charge_concept_dist;

	}

	my $attendees_today = $x->{m}->{attendance}->get_attendees( today => 1 );
	$d->{data}->{attendance_percentage} = int( ( $attendees_today * 100 ) / $divider );

	$d->{data}->{membership_status} = $x->{m}->{memberships}->get_month_status( this_month => 1 );
	$d->{data}->{pending_memberships} = int( $d->{data}->{membership_status}->{PENDING} );

	my $enrollments = $x->{m}->{users}->get_month_enrollments();
	$d->{data}->{total_enrollments} = $enrollments->{total};

	if ( $d->{data}->{membership_status}->{TOTAL} > 0 ) {
		$d->{data}->{paid_membership_pct} =
		  int( ( $d->{data}->{membership_status}->{PAID} * 100 ) / $d->{data}->{membership_status}->{TOTAL} );
	}
	else {
		$d->{data}->{paid_membership_pct} = 0;
	}

	$d->{data}->{sales_total}    = $x->{m}->{charges}->get_day_total();
	$d->{data}->{discount_total} = $x->{m}->{discounts}->get_day_total();

	$d->{data}->{membership_count} = $x->{m}->count(
		where => {
			active => 1,
		},
		table => '_f_memberships'
	);

	$d->{data}->{discount_count} = $x->{m}->count(
		where => {
			active    => 1,
			type_code => 'M',
		},
		table => '_f_discounts'
	);

	$d->{data}->{item_count} = $x->{m}->count(
		where => {
			active => 1,
		},
		table => '_i_items'
	);

	$d->{data}->{staff_count} = $x->{m}->count(
		where => {
			active => 1,
		},
		or => {
			is_admin => 1,
			is_coach => 1,
		},
		table => '_g_users'
	);

	$d->{data}->{inventory_total} = $x->{m}->{inventory}->get_inventory();
	$d->{data}->{dt_parts}        = global::date_time->get_date_time_parts();
	$d->{data}->{one_week_ago}    = global::date_time->get_past_date(7);

	$d->{data}->{birthdays} = $x->{m}->{users}->get_birthdays();

	$x->{v}->render($d);

}

1;
