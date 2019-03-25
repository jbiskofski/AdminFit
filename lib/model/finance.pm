package model::finance;

use strict;
use base 'model::base';

use Sort::Key qw/keysort rnkeysort/;
use Sort::Key::Multi qw/rsrnrnskeysort rnrnskeysort rnrnkeysort rsrnkeysort/;

sub new {

	my ( $n, $dbh ) = @_;

	my $x = {
		dbh => $dbh,
		m   => model::init->new($dbh)
	};

	bless $x;
	return $x;

}

sub get_statement {

	my ( $x, %pp ) = @_;

	return undef unless $pp{client_id} || $pp{charge_id};

	my %statement;

	my $charges = $x->{m}->{charges}->get_charges(
		only_membership_charges => $pp{only_membership_charges},
		client_id               => $pp{client_id},
		charge_id               => $pp{charge_id},
		year                    => $pp{year},
		month                   => $pp{month},
	);

	return undef unless $charges;

	my %charge_ids = map { $_->{id} => 1 } @{$charges};

	my $payments_tmp = $x->{m}->{payments}->get_payments(
		in => {
			table => '_f_payments',
			field => 'charge_id',
			items => [ keys %charge_ids ]
		}
	);

	my $discounts_tmp = $x->{m}->{discounts}->get_charge_discounts(
		in => {
			table => '_f_charge_discounts',
			field => 'charge_id',
			items => [ keys %charge_ids ]
		}
	);

	my %payments;

	if ($payments_tmp) {
		foreach my $pay ( @{$payments_tmp} ) {
			push @{ $payments{ $pay->{charge_id} } }, $pay;
		}
	}

	my %discounts;

	if ($discounts_tmp) {
		foreach my $disc ( @{$discounts_tmp} ) {
			push @{ $discounts{ $disc->{charge_id} } }, $disc;
		}
	}

	my $prepayments_found = 0;

	foreach my $ch ( @{$charges} ) {

		$prepayments_found = 1 if $ch->{type_code} eq 'P';

		my $display_month = global::date_time->get_display_month( $ch->{month} );

		if ( !$statement{months}->{ $ch->{year} . ':' . $ch->{month} } ) {
			$statement{months}->{ $ch->{year} . ':' . $ch->{month} } = {
				year          => $ch->{year},
				month         => $ch->{month},
				display_month => $display_month,
			};
		}

		$ch->{discount_amount} = 0;
		$ch->{original_amount} = $ch->{amount};

		if ( $discounts{ $ch->{id} } ) {
			$ch->{discounts} = $discounts{ $ch->{id} };
			foreach my $disc ( @{ $discounts{ $ch->{id} } } ) {
				$ch->{discount_amount} += $disc->{discount_amount};
				$ch->{amount} -= $disc->{discount_amount};
			}
			$ch->{display_discounts} = $x->_get_display_discounts( $discounts{ $ch->{id} } );
		}

		$ch->{cancelled_paid}   = 0;
		$ch->{paid}             = 0;
		$ch->{debit_paid}       = 0;
		$ch->{remaining_amount} = $ch->{amount};

		if ( $payments{ $ch->{id} } ) {
			$ch->{payments} = $payments{ $ch->{id} };
			foreach my $pay ( @{ $payments{ $ch->{id} } } ) {
				$ch->{cancelled_paid} += $pay->{cancelled_payment_amount};
				$ch->{paid}           += $pay->{payment_amount};
				$ch->{debit_paid}     += $pay->{debit_amount};
				$ch->{remaining_amount} -= $pay->{payment_amount};
				$ch->{remaining_amount} -= $pay->{debit_amount};
			}
			$ch->{remaining_amount} = 0 if $ch->{is_prepayment};
			$ch->{display_payments} = $x->_get_display_payments( $payments{ $ch->{id} } );
		}

		my $ym = $statement{months}->{ $ch->{year} . ':' . $ch->{month} };

		$ch->{display_month}          = $display_month;
		$ch->{epoch}                  = global::date_time->get_epoch( $ch->{creation_date_time} );
		$ym->{charges}->{ $ch->{id} } = $ch;

		return $ym->{charges}->{ $ch->{id} } if $pp{charge_id};

	}

	my $total_remaining = 0;
	my $total_paid      = 0;

	foreach my $ym ( values %{ $statement{months} } ) {

		$pp{aggregate} = 0 if $pp{month} || $pp{year};

		if ( $pp{aggregate} ) {
			$ym->{charges} = $x->_aggregate_same_item_charges( [ values %{ $ym->{charges} } ] );
		}
		else {
			my @sorted = rsrnkeysort { $_->{type_code}, $_->{epoch} } values %{ $ym->{charges} };
			$ym->{charges} = \@sorted;
		}

		foreach my $ch ( @{ $ym->{charges} } ) {
			$ym->{remaining_amount} += $ch->{remaining_amount};
			$total_remaining        += $ch->{remaining_amount};
			$total_paid             += $ch->{paid};
		}

	}

	my @sorted = rnrnkeysort { $_->{year}, $_->{month} } values %{ $statement{months} };
	$statement{months} = \@sorted;

	if ($prepayments_found) {
		my $client_id = $charges->[0]->{client_id};
		$statement{balance} = $x->get_balance( client_id => $client_id );
	}

	$statement{total} = {
		remaining_amount => $total_remaining,
		paid             => $total_paid,
	};

	return \%statement;

}

sub get_balance {

	my ( $x, %pp ) = @_;

	my $q = $x->get_quote();

	my $sql = qq {
	SELECT 	_f_balances.client_id,_f_balances.credit_amount,
		_f_balances.debit_amount,_f_balances.balance_amount
	FROM 	_f_balances
	WHERE 	_f_balances.client_id = $q->{$pp{client_id}}
	};

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );
	my ( $client_id, $credit, $debit, $balance ) = $sth->fetchrow();
	$sth->finish();

	$credit  //= 0;
	$debit   //= 0;
	$balance //= 0;

	return {
		id      => $client_id,
		credit  => $credit,
		debit   => $debit,
		balance => $balance,
	};

}

sub _get_display_discounts {

	my ( $n, $discounts ) = @_;

	my $display_string;

	foreach my $dd ( @{$discounts} ) {

		if ( $dd->{discount_amount} > 0 ) {

			my $amount = '$' . global::ttf->commify( $dd->{discount_amount} );

			$display_string .= qq {
                        <span class="fe fe-minus-circle"></span>
			$dd->{date_time}
			<br>
			$dd->{discount_name}
			<br>
			$dd->{admin_display_name}
			<br>
			$amount
			<br>
			<br>
			};

		}
		elsif ( $dd->{cancelled_discount_amount} > 0 ) {

			my $amount = '$' . global::ttf->commify( $dd->{cancelled_discount_amount} );

			$display_string .= qq {
                        <span class="fe fe-minus-circle"></span>
			$dd->{date_time}
			<br>
			$dd->{discount_name}
			<br>
			$dd->{cancelled_display_name}
			<br>
			Cancelado : <span class="amount-paid text-inherit">$amount</span>
			<br>
			<br>
			};

		}

	}

	return undef unless $display_string;

	$display_string =~ s/\s+/ /g;
	chomp $display_string;
	$display_string = substr( $display_string, 0, length($display_string) - 11 );
	$display_string = global::ttf->escape($display_string);

	return $display_string;

}

sub _get_display_payments {

	my ( $n, $payments ) = @_;

	my $display_string;

	my $is_first_payment = 1;

	foreach my $pay ( @{$payments} ) {

		my $div_style = 'style="border-top:dashed 1px gray;margin-top:4px;padding-top:1px"' unless $is_first_payment;

		if ( $pay->{payment_amount} > 0 || $pay->{debit_amount} > 0 ) {

			$is_first_payment = 0;
			my $amount = '$' . global::ttf->commify( $pay->{payment_amount} );
			my $debit_amount = '<i class="fe fe-arrow-up-circle text-green"></i> $' . global::ttf->commify( $pay->{debit_amount} ) if $pay->{debit_amount} > 0;

			$display_string .= qq {
			<div class="text-left" $div_style>
	                        <i class="fe fe-plus-circle"></i>
				$pay->{date_time}
				<br>
				$pay->{admin_display_name}
				<br>
				$amount<span style="float:right">$debit_amount</span>
			</div>
			};

		}

		if ( $pay->{cancelled_payment_amount} > 0 || $pay->{cancelled_debit_amount} > 0 ) {

			$is_first_payment = 0;
			my $cancelled_amount = '$' . global::ttf->commify( $pay->{cancelled_payment_amount} );
			my $cancelled_debit_amount = '<i class="fe fe-arrow-up-circle text-green"></i> $' . global::ttf->commify( $pay->{cancelled_debit_amount} ) if $pay->{cancelled_debit_amount} > 0;

			$display_string .= qq {
			<div class="text-left" $div_style>
	                        <i class="fe fe-x text-red"></i>
				$pay->{cancelled_date_time}
				<br>
				$pay->{cancelled_display_name}
				<br>
				<span class="amount-paid text-inherit">$cancelled_amount</span><span style="float:right" class="amount-paid">$cancelled_debit_amount</span>
			</div>
			};

		}

	}

	return undef unless $display_string;

	$display_string =~ s/\s+/ /g;
	chomp $display_string;
	$display_string = global::ttf->escape($display_string);

	return $display_string;

}

sub _aggregate_same_item_charges {

	my ( $n, $charges ) = @_;

	my @single_sale_charges;
	my %item_counts;

	foreach my $ch ( @{$charges} ) {
		next if $ch->{type_code} eq 'M';
		$item_counts{ $ch->{item_id} }++;
	}

	my %products;

	foreach my $ch ( @{$charges} ) {

		if ( $ch->{type_code} eq 'M' || $item_counts{ $ch->{item_id} } <= 1 || $ch->{is_permanent} ) {
			push @single_sale_charges, $ch;
			next;
		}

		my $product_id;

		if ( $ch->{type_code} eq 'P' ) {
			$product_id = 'PREPAYMENT';
		}
		elsif ( $ch->{type_code} eq 'I' ) {
			$product_id = $ch->{item_id};
		}
		else {
			global::standard->inspect("UNKNOWN-CHARGE-TYPE-CODE : $ch->{type_code}");
		}

		if ( !$products{$product_id} ) {
			$products{$product_id} = {
				id                 => $product_id,
				concept            => $ch->{concept},
				creation_date_time => $ch->{creation_date_time},
				amount             => 0,
				paid               => 0,
				type_code          => $ch->{type_code},
				sales              => [],
			};
		}

		$products{$product_id}->{amount}     += $ch->{amount};
		$products{$product_id}->{paid}       += $ch->{paid};
		$products{$product_id}->{debit_paid} += $ch->{debit_paid};
		push @{ $products{$product_id}->{sales} }, $ch;

	}

	my @sorted_single_sale_charges = rsrnkeysort { $_->{type_code}, $_->{epoch} } @single_sale_charges;

	return \@sorted_single_sale_charges unless scalar keys %products;

	foreach my $prod ( values %products ) {

		if ( $prod->{type_code} eq 'P' ) {
			$prod->{remaining_amount} = 0;
		}
		elsif ( $prod->{type_code} eq 'I' ) {
			$prod->{remaining_amount} = $prod->{amount} - $prod->{paid} - $prod->{debit_paid};
		}
		else {
			global::standard->inspect("UNKNOWN-CHARGE-TYPE-CODE : $prod->{type_code}");
		}

		$prod->{id} = $prod->{sales}->[0]->{id};
		my @sorted = rnkeysort { $_->{epoch} } @{ $prod->{sales} };
		$prod->{sales} = \@sorted;

	}

	my @sorted = rnrnskeysort { $_->{remaining_amount}, $_->{amount}, "$_->{concept}->{concept}.$_->{concept}->{details}" } values %products;

	return [ @sorted_single_sale_charges, @sorted ];

}

sub get_calendar {

	my ( $x, %pp ) = @_;

	my $parts = global::date_time->get_date_time_parts();

	my $month = $pp{month} || $parts->{month};
	my $year  = $pp{year}  || $parts->{year};
	my $display_month = global::date_time->get_display_month($month);

	my $calendar = global::date_time->get_calendar(
		month => $month,
		year  => $year,
	);

	my $attendance = $x->{m}->{attendance}->get_month_summary(
		month => $month,
		year  => $year,
	);

	my $day_enrollments = $x->{m}->{users}->get_month_enrollments(
		month => $month,
		year  => $year,
	);

	my $day_dropouts = $x->{m}->{users}->get_dropouts(
		month => $month,
		year  => $year,
	);

	my %enrollment_client_ids;

	if ($day_enrollments) {
		foreach my $day ( keys %{ $day_enrollments->{days} } ) {
			next unless $day_enrollments->{days}->{$day} && ref( $day_enrollments->{days}->{$day} ) eq 'ARRAY';
			foreach my $client_id ( @{ $day_enrollments->{days}->{$day} } ) {
				$enrollment_client_ids{$client_id} = 1;
			}
		}
	}

	my %dropout_client_ids;

	if ($day_dropouts) {
		foreach my $day ( keys %{$day_dropouts} ) {
			next unless $day_dropouts->{$day} && ref( $day_dropouts->{$day} ) eq 'ARRAY';
			foreach my $client_id ( @{ $day_dropouts->{$day} } ) {
				$dropout_client_ids{$client_id} = 1;
			}
		}
	}

	my $payments = $x->{m}->{payments}->get_client_month_payments(
		charge_month              => $month,
		charge_year               => $year,
		new_enrollment_client_ids => [ keys %enrollment_client_ids ],
	);

	my %remembership_client_ids;

	if ($payments) {
		foreach my $day ( keys %{$payments} ) {
			next
			  unless $payments->{$day}
			  && $payments->{$day}->{remembership_client_ids}
			  && ref( $payments->{$day}->{remembership_client_ids} ) eq 'ARRAY';
			foreach my $client_id ( @{ $payments->{$day}->{remembership_client_ids} } ) {
				$remembership_client_ids{$client_id} = 1;
			}
		}
	}

	my %users;

	if ( scalar keys %remembership_client_ids || scalar keys %enrollment_client_ids || scalar keys %dropout_client_ids ) {

		my $users_tmp = $x->{m}->{clients}->get_clients(
			in => {
				table => '_g_users',
				field => 'id',
				items => [ keys %remembership_client_ids, keys %enrollment_client_ids, keys %dropout_client_ids ],
			},
			include_membership => 1,
		);

		my $deleted_users_tmp = $x->{m}->{users}->get_deleted_users(
			in => {
				table => '_g_deleted_users',
				field => 'id',
				items => [ keys %dropout_client_ids ],
			},
		) if scalar keys %dropout_client_ids;

		%users =
		  map {
			$_->{id} => {
				id                  => $_->{id},
				has_profile_picture => $_->{has_profile_picture} || 0,
				has_picture         => $_->{has_picture} || 0,
				name                => $_->{display_name},
				active              => $_->{active} || 0,
				create_date         => $_->{create_date},
				membership_name     => $_->{membership}->{name} || 'DESHABILITADO',
				membership_amount   => $_->{membership}->{amount} || 0,
				is_dependant        => $_->{membership}->{is_dependant} || 0,
				is_deleted_user     => $_->{is_deleted_user} || 0,
				deactivation_date   => global::date_time->format_date( $_->{deactivation_date_time} || $_->{date_time} ),
			  }
		  } @{$users_tmp}, @{$deleted_users_tmp};

	}

	if ( scalar keys %users ) {

		if ($day_enrollments) {
			foreach my $day ( keys %{ $day_enrollments->{days} } ) {
				next unless $day_enrollments->{days}->{$day} && ref( $day_enrollments->{days}->{$day} ) eq 'ARRAY';
				my @unsorted_day_clients;
				foreach my $client_id ( @{ $day_enrollments->{days}->{$day} } ) {
					push @unsorted_day_clients, $users{$client_id};
				}
				$day_enrollments->{days}->{$day} = [ keysort { $_->{name} } @unsorted_day_clients ];
			}
		}

		if ($day_dropouts) {
			foreach my $day ( keys %{$day_dropouts} ) {
				next unless $day_dropouts->{$day} && ref( $day_dropouts->{$day} ) eq 'ARRAY';
				my @unsorted_day_dropouts;
				foreach my $client_id ( @{ $day_dropouts->{$day} } ) {
					push @unsorted_day_dropouts, $users{$client_id};
				}
				$day_dropouts->{$day} = [ keysort { $_->{name} } @unsorted_day_dropouts ];
			}
		}

		if ($payments) {
			foreach my $day ( keys %{$payments} ) {
				next
				  unless $payments->{$day}
				  && $payments->{$day}->{remembership_client_ids}
				  && ref( $payments->{$day}->{remembership_client_ids} ) eq 'ARRAY';
				my @unsorted_day_clients;
				foreach my $client_id ( @{ $payments->{$day}->{remembership_client_ids} } ) {
					push @unsorted_day_clients, $users{$client_id};
				}
				$payments->{$day}->{remembership_clients} = [ keysort { $_->{name} } @unsorted_day_clients ];
			}
		}

	}

	my %totals;

	foreach my $ww ( @{$calendar} ) {

		foreach my $dd ( @{$ww} ) {

			next unless $dd->{day};

			$dd->{data}->{attendance} = $attendance->{ $dd->{day} } || 0;
			$dd->{data}->{payments} = $payments->{ $dd->{day} }->{total};

			my $day_enrollment_total = 0;
			my $day_dropout_total    = 0;
			my $enrollment_display_string;
			my $dropout_display_string;

			if ( ref( $day_enrollments->{days}->{ $dd->{day} } ) eq 'ARRAY' ) {

				my @active_clients = grep { $_->{active} } @{ $day_enrollments->{days}->{ $dd->{day} } };
				$day_enrollment_total = scalar @active_clients || 0;
				foreach my $client ( @{ $day_enrollments->{days}->{ $dd->{day} } } ) {
					if ( $client->{active} ) {
						$enrollment_display_string .= '<i class=\'fe fe-plus text-green\'></i>';
					}
					else {
						$enrollment_display_string .= '<i class=\'fe fe-x text-red\'></i>';
					}
					$enrollment_display_string .= '&nbsp;' . $client->{name} . '<br>';
				}
			}

			if ( ref( $day_dropouts->{ $dd->{day} } ) eq 'ARRAY' ) {
				$day_dropout_total = scalar @{ $day_dropouts->{ $dd->{day} } } || 0;
				foreach my $client ( @{ $day_dropouts->{ $dd->{day} } } ) {
					$dropout_display_string .= '<i class=\'fe fe-x text-black\'></i>';
					$dropout_display_string .= '&nbsp;' . $client->{name} . '<br>';
				}
			}

			my $day_remembership_total = 0;
			my $remembership_display_string;

			if ( ref( $payments->{ $dd->{day} }->{remembership_clients} ) eq 'ARRAY' ) {
				$day_remembership_total = scalar @{ $payments->{ $dd->{day} }->{remembership_clients} };
				foreach my $client ( @{ $payments->{ $dd->{day} }->{remembership_clients} } ) {
					if ( $client->{active} ) {
						$remembership_display_string .= '<i class=\'fe fe-user text-green\'></i>';
					}
					else {
						$remembership_display_string .= '<i class=\'fe fe-x text-red\'></i>';
					}
					$remembership_display_string .= '&nbsp;' . $client->{name} . '<br>' . "\n";
				}
			}

			$dd->{data}->{enrollments}               = $day_enrollment_total;
			$dd->{data}->{enrollment_display_string} = $enrollment_display_string;

			$dd->{data}->{dropouts}               = $day_dropout_total;
			$dd->{data}->{dropout_display_string} = $dropout_display_string;

			$dd->{data}->{rememberships}               = $day_remembership_total;
			$dd->{data}->{remembership_display_string} = $remembership_display_string;

			$totals{attendance} += $dd->{data}->{attendance};
			$totals{payments}   += $dd->{data}->{payments};

		}

	}

	my %enrollments_tmp;
	my %rememberships_tmp;

	my @enrollments;
	if ( scalar keys %enrollment_client_ids ) {
		foreach my $client_id ( keys %enrollment_client_ids ) {
			push @enrollments, $users{$client_id};
		}
		@enrollments = keysort { $_->{name} } @enrollments;
		$totals{enrollments} = scalar @enrollments;
	}

	my @dropouts;
	if ( scalar keys %dropout_client_ids ) {
		foreach my $client_id ( keys %dropout_client_ids ) {
			push @dropouts, $users{$client_id};
		}
		@dropouts = keysort { $_->{name} } @dropouts;
		$totals{dropouts} = scalar @dropouts;
	}

	my @rememberships;
	if ( scalar keys %remembership_client_ids ) {
		foreach my $client_id ( keys %remembership_client_ids ) {
			push @rememberships, $users{$client_id};
		}
		@rememberships = keysort { $_->{name} } @rememberships;
		$totals{rememberships} = scalar @rememberships;
	}

	return {
		weeks                   => $calendar,
		month                   => $month,
		display_month           => $display_month,
		year                    => $year,
		totals                  => \%totals,
		dropout_client_ids      => [ keys %dropout_client_ids ],
		enrollment_client_ids   => [ keys %enrollment_client_ids ],
		remembership_client_ids => [ keys %remembership_client_ids ],
		enrollments             => scalar @enrollments ? \@enrollments : undef,
		dropouts                => scalar @dropouts ? \@dropouts : undef,
		rememberships           => scalar @rememberships ? \@rememberships : undef,
	};

}

1;
