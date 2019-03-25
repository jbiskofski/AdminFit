package controller::descuentos::management;

use strict;

sub discount_charge {

	my ( $x, %pp ) = @_;

	my $charge_discount_id = global::standard->uuid();

	$x->{m}->insert(
		insert => {
			id                   => $charge_discount_id,
			charge_id            => $pp{charge_id},
			discount_id          => $pp{discount_id},
			discount_name        => $pp{discount_name},
			discount_amount      => $pp{discount_amount},
			original_amount      => $pp{original_amount},
			post_discount_amount => $pp{post_discount_amount},
			admin_id             => $pp{admin_id},
			notes                => $pp{notes},
		},
		table => '_f_charge_discounts',
	);

	return $charge_discount_id;

}

sub cancel_discount {

	my ( $x, %pp ) = @_;

	my $discount = $x->{m}->{discounts}->get_charge_discounts( where => { '_f_charge_discounts.id' => $pp{discount_id} }, limit => 1 );

	$x->{m}->upsert(
		insert => {
			charge_discount_id => $pp{discount_id},
			discount_amount    => $discount->{discount_amount},
			admin_id           => $pp{admin_id},
			notes              => $pp{notes},
		},
		conflict_fields => ['charge_discount_id'],
		table           => '_f_charge_discounts_cancelled',
	);

	$x->{m}->update(
		update => {
			discount_amount => 0,
		},
		where => {
			id => $pp{discount_id},
		},
		table => '_f_charge_discounts',
	);

	return 1;

}

1;
