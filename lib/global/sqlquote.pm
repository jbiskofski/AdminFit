package global::sqlquote;

use strict;

require Tie::Hash;

sub TIEHASH {

	my $x = shift;

	my %hash;

	bless( \%hash, $x );
	return ( \%hash );

}

sub FETCH {

	my ( $x, $key ) = @_;

	my $uid = __PACKAGE__->mini_unique_id();

	return '$' . $uid . '$' . $key . '$' . $uid . '$';

}

sub mini_unique_id {

	my $rv;

	for ( my $i = 0 ; $i < 4 ; ) {
		my $j = chr( int( rand(127) ) );
		if ( $j =~ /[A-Z]/ ) { $rv .= $j; $i++; }
	}

	return ( uc($rv) );

}

1;
