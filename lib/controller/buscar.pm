package controller::buscar;

use strict;
use base 'controller::finanzas::charges';

sub new {

	my ( $n, $d ) = @_;

	my $x = {
		v => view::render->new( $d->{r} ),
		m => model::init->new( $d->{dbh} ),
	};

	bless $x;
	return $x;

}

sub x_default {

	my ( $x, $d ) = @_;

	return $x->{v}->render_json( [] ) unless length $d->{p}->{q};
	my $results = $x->{m}->{search}->search( search => $d->{p}->{q} );
	return $x->{v}->render_json( [] ) unless $results;

	my @lis;

	foreach my $rr ( @{$results} ) {

		next unless $rr;

		if ( $rr->{type_code} eq 'CLIENT' ) {
			push @lis, _get_client_li($rr);
		}
		elsif ( $rr->{type_code} eq 'STAFF' ) {
			push @lis, _get_staff_li($rr);
		}
		elsif ( $rr->{type_code} eq 'INVENTORY' ) {
			push @lis, _get_inventory_li($rr);
		}

	}

	$x->{v}->render_json( \@lis );

}

sub _get_client_li {

	my $item     = shift;
	my $inactive = 'text-decoration:line-through;color:#9aa0ac'
	  if !$item->{active};

	my $attendance_uri = global::ttf->uri(
		controller => 'asistencia',
		method     => 'presente-do',
		id         => $item->{id}
	);

	my $sales_uri = global::ttf->uri(
		controller => 'ventas',
		method     => 'punto-de-venta',
		id         => $item->{id}
	);

	my $profile_uri = global::ttf->uri(
		controller => 'clientes',
		method     => 'perfil',
		id         => $item->{id}
	);

	my $statement_uri = global::ttf->uri(
		controller => 'finanzas',
		method     => 'estado-de-cuenta',
		id         => $item->{id}
	);

	my $aria_valuenow = $item->{membership}->{days};
	$aria_valuenow = 0 if $item->{membership}->{expired};
	my $debt_tag;

	if ( $item->{debt_total} > 0 ) {
		my $debt_total = '$' . global::ttf->commify( $item->{debt_total} );
		$debt_tag = qq {
			<small class="text-danger" style="vertical-align:bottom;float:right">
				<span class="fe fe-x text-danger"></span>
				$debt_total
			</small>
		};
	}

	$item->{attendance_today_count} = undef unless $item->{attendance_today_count};

	my $li = qq{
		  <div style="vertical-align:top;margin-left:5px;$inactive;">
		  	$item->{image_tag}
			&nbsp;
		  	$item->{name}
			$debt_tag
		  </div>
		  <div style="padding:5px;text-align:right;">
		  <a href="$sales_uri" class="btn btn-outline-success btn-sm">
		  <i class="fe fe-shopping-cart"></i>
		  </a>&nbsp;
		  <a href="$statement_uri" class="btn btn-outline-secondary btn-sm">
		  <i class="fe fe-dollar-sign"></i>
		  </a>&nbsp;
		  <a href="$attendance_uri" class="btn btn-outline-danger btn-sm">
		  <i class="fe fe-check"></i>
		  $item->{attendance_today_count}
		  </a>&nbsp;
		  <a href="$profile_uri" class="btn btn-outline-primary btn-sm">
		  <i class="fe fe-user"></i>
		  </a>
		  </div>
		  $item->{membership}->{display_days}
		  <div class="progress progress-xs">
			  <div class="progress-bar $item->{membership}->{progress_color_class}"
				  role="progressbar"
				  style="background:red;width:$item->{membership}->{progress_pct}%"
				  aria-valuenow="$aria_valuenow"
				  aria-valuemin="0"
				  aria-valuemax="$item->{membership}->{progress_max_days}">
			  </div>
		  </div>
	  };

	$li =~ s/\s+/ /g;

	return {
		value   => $item->{name},
		label   => $li,
		default => $profile_uri
	};

}

sub _get_staff_li {

	my $item     = shift;
	my $inactive = 'text-decoration:line-through;color:#9aa0ac'
	  if !$item->{active};

	my $attendance_uri = global::ttf->uri(
		controller => 'asistencia',
		method     => 'presente-do',
		id         => $item->{id}
	);

	my $profile_uri = global::ttf->uri(
		controller => 'usuarios',
		method     => 'perfil',
		id         => $item->{id}
	);

	my $sales_uri = global::ttf->uri(
		controller => 'ventas',
		method     => 'punto-de-venta',
		id         => $item->{id}
	);

	my $statement_uri = global::ttf->uri(
		controller => 'finanzas',
		method     => 'estado-de-cuenta',
		id         => $item->{id}
	);

	my $debt_tag;

	if ( $item->{debt_total} > 0 ) {
		my $debt_total = '$' . global::ttf->commify( $item->{debt_total} );
		$debt_tag = qq {
			<small class="text-danger" style="vertical-align:bottom;float:right">
				<span class="fe fe-x text-danger"></span>
				$debt_total
			</small>
		};
	}

	my $li = qq{
  		  <div style="vertical-align:top;margin-left:5px;$inactive;">
  		  	$item->{image_tag}
			&nbsp;
  		  	$item->{name}
  			$debt_tag
  		  </div>
  		  <div style="padding:5px;text-align:right;">
  		  <a href="$sales_uri" class="btn btn-outline-success btn-sm">
  		  <i class="fe fe-shopping-cart"></i>
  		  </a>&nbsp;
  		  <a href="$statement_uri" class="btn btn-outline-secondary btn-sm">
  		  <i class="fe fe-dollar-sign"></i>
  		  </a>&nbsp;
		  <a href="$attendance_uri" class="btn btn-outline-danger btn-sm">
		  <i class="fe fe-check"></i>
		  </a>&nbsp;
  		  <a href="$profile_uri" class="btn btn-outline-primary btn-sm">
  		  <i class="fe fe-user"></i>
  		  </a>
  		  </div>
		  <span class="text-blue">Staff</span>
		  <div class="progress progress-xs">
			  <div class="progress-bar bg-blue"
				  role="progressbar"
				  style="background:red;width:100%"
				  aria-valuenow="100"
				  aria-valuemin="0"
				  aria-valuemax="100">
			  </div>
		  </div>
  	  };

	$li =~ s/\s+/ /g;

	return {
		value   => $item->{name},
		label   => $li,
		default => $profile_uri
	};

}

sub _get_inventory_li {

	my $item     = shift;
	my $inactive = 'text-decoration:line-through;color:#9aa0ac'
	  if !$item->{active};

	my $item_uri = global::ttf->uri(
		controller => 'ventas',
		method     => 'ver',
		id         => $item->{id}
	);

	my $li = qq{
		  <span class="image avatar bg-blue"><i class="fe fe-package text-white"></i></span>
		  <span style="vertical-align:top;margin-left:5px;$inactive">$item->{name}</span>
		  <div style="padding:5px;text-align:right;">
		  <a href="$item_uri" class="btn btn-outline-success btn-sm">
		  <i class="fe fe-zoom-in"></i>
		  </a>
		  </div>
	  };

	$li =~ s/\s+/ /g;

	return {
		value   => $item->{name},
		label   => $li,
		default => $item_uri
	};

}

1;
