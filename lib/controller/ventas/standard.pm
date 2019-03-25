package controller::ventas::standard;

use strict;
use Sort::Key::Multi 'rnrnkeysort';

sub _get_client_possible_months {

	my ( $x, %pp ) = @_;

	my $previous = global::date_time->get_previous_months( get_previous => 12 );
	my $upcoming = global::date_time->get_next_months( get_next => 12 );
	my $current = global::date_time->get_date_time_parts();

	$current->{current} = 1;

	my @unsorted;
	push @unsorted, @{$previous};
	push @unsorted, $current;
	push @unsorted, @{$upcoming};

	my @sorted = rnrnkeysort { $_->{year}, $_->{month} } @unsorted;

	return {
		months                  => \@sorted,
		has_charged_memberships => 0,
	} unless $pp{mark_membership_months};

	my $charges = $x->{m}->{charges}->get_charges(
		client_id               => $pp{client_id},
		only_membership_charges => 1,
		not_cancelled           => 1,
	);

	my $has_charged_memberships = 0;

	if ($charges) {

		my %charged_yms = map { $_->{year} . '_' . sprintf( "%02d", $_->{month} ) => 1 } @{$charges};

		foreach my $ym (@sorted) {

			if ( $charged_yms{ $ym->{year} . '_' . $ym->{month} } ) {
				$ym->{membership_charged} = 1;
				$has_charged_memberships = 1;
			}

		}

	}

	return {
		months                  => \@sorted,
		has_charged_memberships => $has_charged_memberships,
	};

}

sub _get_pending_charges_from_statement {

	my ( $x, %pp ) = @_;

	return undef unless $pp{statement};
	return undef unless $pp{statement}->{months};

	my @pending;

	foreach my $ym ( @{ $pp{statement}->{months} } ) {

		foreach my $ch ( @{ $ym->{charges} } ) {
			next if $ch->{paid_amount} > 0 && $pp{no_payments};
			next if $ch->{is_cancelled};
			next if $ch->{is_prepayment};
			next unless $ch->{remaining_amount} > 0;
			$ch->{display_month} = $ym->{display_month};
			$ch->{month}         = $ym->{month};
			$ch->{year}          = $ym->{year};
			push @pending, $ch;
		}

	}

	return scalar @pending ? \@pending : undef;

}

1;
