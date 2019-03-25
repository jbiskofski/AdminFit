package model::init;

use strict;
use base 'model::base';

require Tie::Hash;

sub new {

	my ( $n, $dbh ) = @_;

	my $x = {};
	tie( %{$x}, 'MODELINSTANCES' );
	$x->{dbh} = $dbh;
	bless $x;
	return $x;

}

package MODELINSTANCES;

sub TIEHASH {

	my $x = shift;

	my %hash;

	bless( \%hash, $x );
	return \%hash;

}

sub FETCH {

	my ( $x, $key ) = @_;
	my $model = 'model::' . $key;
	return $x->{$key} if $x->{$key};
	my $instance = $model->new( $x->{dbh} );
	$x->{$key} = $instance;
	return $instance;

}

sub STORE {

	my ( $x, $key, $value ) = @_;
	$x->{$key} = $value;

}

sub FIRSTKEY {
	return undef;
}

1;
