package controller::tips;

use strict;
use base 'controller::tips::standard';

sub new {

	my ( $n, $d ) = @_;

	my $x = {
		v => view::render->new( $d->{r} ),
		m => model::init->new( $d->{dbh} ),
	};

	bless $x;
	return $x;

}

sub esconder_do {

	my ( $x, $d ) = @_;

	$x->accept_notification(
		tip_id  => $d->{p}->{id},
		user_id => $d->{s}->{user_id}
	);

	$d->{p} = undef;
	$d->save_state();

	return $x->{v}->http_redirect_to_referer();

}

sub get {

	my ( $x, %pp ) = @_;

	if ( $pp{user_id} && !$pp{always_show} ) {

		my $tip_seen = $x->{m}->count(
			where => { tip_id => $pp{tip}, user_id => $pp{user_id} },
			table => '_g_seen_tips'
		);

		return undef if $tip_seen;

	}

	my $hide_tip_uri = global::ttf->uri( c => 'tips', m => 'esconder-do', id => $pp{tip} );

	my $hide_tip_div = qq {
		<br>
		<br>
		<div class="text-right align-right">
			<a href="$hide_tip_uri" class="btn btn-primary btn-sm">
				<i class="fe fe-x mr-2"></i>
				No volver a mostrar este mensaje
			</a>
		</div>};

	$hide_tip_div = undef if $pp{no_dismiss_button};

	my $method = lc '_' . $pp{tip};
	$method =~ s/-/_/g;

	my $tip = __PACKAGE__->$method(%pp);
	$tip =~ s/\s+/ /g;
	$tip .= $hide_tip_div unless $pp{no_dismiss_button};

	return $tip;

}

1;
