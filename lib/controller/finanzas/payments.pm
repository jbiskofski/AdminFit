package controller::finanzas::payments;

use strict;
use Sort::Key 'rnkeysort';

sub cancel_payment {

	my ( $x, %pp ) = @_;

	my $payment = $x->{m}->{payments}->get_payments( where => { '_f_payments.id' => $pp{payment_id} }, limit => 1 );

	$x->{m}->upsert(
		insert => {
			payment_id     => $pp{payment_id},
			payment_amount => $payment->{payment_amount},
			debit_amount   => $payment->{debit_amount},
			admin_id       => $pp{admin_id},
			notes          => $pp{notes},
		},
		conflict_fields => ['payment_id'],
		table           => '_f_payments_cancelled',
	);

	$x->{m}->update(
		update => {
			payment_amount => 0,
			debit_amount   => 0,
		},
		where => {
			id => $pp{payment_id},
		},
		table => '_f_payments',
	);

	return 1;

}

1;
