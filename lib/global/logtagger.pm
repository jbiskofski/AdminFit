package global::logtagger;

use strict;
require Tie::Hash;

sub TIEHASH {

        my $x = shift;

        my %hash;

        bless( \%hash, $x );
        return ( \%hash );

}

sub FETCH {

        my ( $x, $specific_caller ) = @_;

        my $caller = ( length $specific_caller && $specific_caller ne 'start' ) ? $specific_caller : ( caller(1) )[3];
        return '-- CALLER|' . $caller . '|' . $ENV{TRANSACTION_ID} . ' --';

}

sub FIRSTKEY {

	my ( $x, $specific_caller ) = @_;

	my $caller = ( length $specific_caller && $specific_caller ne 'start' ) ? $specific_caller : ( caller(1) )[3];
	return $caller;

}

sub NEXTKEY {

	return undef;

}

1;
