package model::transactions;

use strict;
use base 'model::base';

use Sort::Key 'rnkeysort';

sub new {

	my ( $n, $dbh ) = @_;

	my $x = {
		dbh => $dbh,
		m   => model::init->new($dbh)
	};

	bless $x;
	return $x;

}

sub get_transactions {

	my ( $x, %pp ) = @_;

	return undef unless scalar keys %pp;

	my @items;
	my %charge_ids;

	my $q = $x->get_quote();

	my $sql_where = $x->generate_sql_where(%pp) if scalar keys %pp;
	my $sql_limit = " LIMIT $pp{limit} "        if $pp{limit};

	my $sql_date_where = " AND _f_transactions.date_time::DATE = $q->{$pp{date}} "
	  if $pp{date};

	my $sql_between_dates;
	if ( $pp{start_date} && $pp{end_date} ) {
		$sql_between_dates = qq {
	  		  AND (
	  			  _f_transactions.date_time >= $q->{ $pp{start_date} }
	  			  AND _f_transactions.date_time < $q->{ $pp{end_date} }::DATE + INTERVAL '1 DAY'
	  		  )
	  	  };
		$sql_date_where = undef;
	}

	my $sql_client_id_where = " AND _f_transactions.client_id = $q->{$pp{client_id}} " if $pp{client_id};

	my $sql_month_where = " AND EXTRACT(MONTH FROM _f_transactions.date_time) = $pp{month} " if $pp{month};
	my $sql_year_where  = " AND EXTRACT(YEAR FROM _f_transactions.date_time) = $pp{year} "   if $pp{year};

	my $sql = qq {
	SELECT 	_f_transactions.id,_f_transactions.admin_id,
		_f_transactions.client_id,_f_transactions.date_time,
		_f_transactions.method_type_code,_f_transactions.notes,
		CLIENTS.name,CLIENTS.lastname1,CLIENTS.lastname2,
		ADMINS.name,ADMINS.lastname1,ADMINS.lastname2,
		ARRAY_AGG(_f_charges.id),
		SUM(_f_charges.amount),
		ARRAY_AGG(_f_payments.payment_amount),
		SUM(_f_payments.payment_amount),
		ARRAY_AGG(_f_payments.debit_amount),
		SUM(_f_payments.debit_amount),
		COUNT(_f_payments.*)
	FROM 	_f_transactions
	JOIN 	_f_payments ON ( _f_payments.transaction_id = _f_transactions.id )
	JOIN 	_f_charges ON ( _f_charges.id = _f_payments.charge_id )
	JOIN 	_g_users CLIENTS ON ( CLIENTS.id = _f_transactions.client_id )
	JOIN 	_g_users ADMINS ON ( ADMINS.id = _f_transactions.admin_id )
	WHERE 	TRUE
	$sql_where
	$sql_date_where
	$sql_between_dates
	$sql_client_id_where
	$sql_month_where
	$sql_year_where
	GROUP BY _f_transactions.id,_f_transactions.admin_id,
		 _f_transactions.client_id,_f_transactions.date_time,
		 _f_transactions.method_type_code,_f_transactions.notes,
		 CLIENTS.name,CLIENTS.lastname1,CLIENTS.lastname2,
		 ADMINS.name,ADMINS.lastname1,ADMINS.lastname2
	ORDER BY _f_transactions.date_time DESC
	$sql_limit
	};

	my @keys = qw/transaction_id admin_id client_id date_time
	  method_type_code notes _client_name _client_lastname1
	  _client_lastname2 _admin_name _admin_lastname1
	  _admin_lastname2 _ARRAY_charge_ids charge_amount
	  _ARRAY_payment_amounts
	  payment_amount
	  _ARRAY_debit_amounts
	  debit_amount
	  payment_count/;

	my $sth = $x->{dbh}->prepare($sql) || die( $DBI::errstr . $sql );
	$sth->execute() || die( $DBI::errstr . $sql );

	while ( my @item = $sth->fetchrow() ) {

		my %ii;

		for ( my $c = 0 ; $c < scalar(@item) ; $c++ ) {
			$ii{ $keys[$c] } = $item[$c];
		}

		$ii{admin_display_name}  = global::standard->get_person_display_name( $ii{_admin_name},  $ii{_admin_lastname1},  $ii{_admin_lastname2} );
		$ii{client_display_name} = global::standard->get_person_display_name( $ii{_client_name}, $ii{_client_lastname1}, $ii{_client_lastname2} );
		$ii{payment_date_time}   = global::date_time->format_date_time( $ii{payment_date_time} );
		$ii{date_time}           = global::date_time->format_date_time( $ii{date_time} );

		$ii{display_method} = $x->{m}->{payments}->_get_display_method(
			method_type_code => $ii{method_type_code},
			payment_amount   => $ii{payment_amount},
			debit_amount     => $ii{debit_amount},
		);

		foreach my $charge_id ( @{ $ii{_ARRAY_charge_ids} } ) {
			$charge_ids{$charge_id} = 1;
		}

		$ii{charges} = global::standard->hashify_arrays(
			keys   => [ 'id',                   'paid_amount',               'debit_amount' ],
			unique => 'id',
			items  => [ $ii{_ARRAY_charge_ids}, $ii{_ARRAY_payment_amounts}, $ii{_ARRAY_debit_amounts} ]
		);

		foreach my $key ( keys %ii ) {
			delete $ii{$key} if substr( $key, 0, 1 ) eq '_';
		}

		push @items, \%ii;

	}

	$sth->finish();

	return undef unless scalar @items;

	my $charges_tmp = $x->{m}->{charges}->get_charges(
		charge_ids    => [ keys %charge_ids ],
		not_cancelled => $pp{not_cancelled},
	);

	my %charges = map { $_->{id} => $_ } @{$charges_tmp};

	my @transactions_with_charges;

	foreach my $tt (@items) {
		my @charges;
		foreach my $ch ( @{ $tt->{charges} } ) {
			next unless $charges{ $ch->{id} };
			my $transaction_paid_amount = $ch->{paid_amount};
			my $charge                  = $charges{ $ch->{id} };
			$charge->{transaction_paid_amount} = $transaction_paid_amount;
			push @charges, $charge;
		}
		next unless scalar @charges;
		my @sorted = rnkeysort { $_->{transaction_paid_amount} } @charges;
		$tt->{charges} = \@sorted;
		push @transactions_with_charges, $tt;
	}

	return $transactions_with_charges[0] if $pp{limit} == 1;
	return \@transactions_with_charges;

}

1;
