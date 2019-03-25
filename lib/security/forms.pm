package security::forms;

use strict;
use base 'model::base';

sub transform_pre {

	my ( $n, $validations, $pp ) = @_;

	my $hide_loading = $pp->{hide_loading} ? 'true' : 'false';

	my $form_name = $pp->{form_name} ? $pp->{form_name} : 'default';

	my $js = qq/
	<script>
		require(['security'], function(sx) {
			var sx = new security("__FORM-NAME__", $hide_loading);
	/;

	my %_field_names;
	%_field_names = map { $_ => 1 } @{ $pp->{field_names} } if ( defined( $pp->{field_names} ) && scalar( @{ $pp->{field_names} } ) );

	my %_exclude_field_names;
	%_exclude_field_names = map { $_ => 1 } @{ $pp->{exclude_field_names} }
	  if ( defined( $pp->{exclude_field_names} ) && scalar( @{ $pp->{exclude_field_names} } ) );

	foreach my $type ( keys %{$validations} ) {

		next if ( $type eq 'unique'
			|| $type eq 'uniquecombo'
			|| $type eq 'uniqueupdate'
			|| $type eq 'requireone'
			|| $type eq 'uniquecomboupdate' );

		foreach my $vv ( @{ $validations->{$type} } ) {

			next unless ( !%_field_names         || defined( $_field_names{ $vv->{input} } ) );
			next unless ( !%_exclude_field_names || !defined( $_exclude_field_names{ $vv->{input} } ) );

			$vv->{message} =~ s/\s+/ /g;
			$vv->{message} =~ s/^\s+//;
			$vv->{message} =~ s/\"/\\\"/g;

			my $sx_type = $type;
			$sx_type =~ s/_/=/;
			$sx_type = '(IFDEF)' . $type if $vv->{ifdef};
			$js .= qq{\nsx.addvalidation("$vv->{input}","$sx_type","$vv->{message}");};

		}

	}

	$js .= "\n});\n</script>";

	my $default_form_name = $pp->{method} || 'default';

	return sub {
		my $form_name = shift;
		$form_name = $default_form_name unless $form_name;
		my $this_form_validation = $js;
		$this_form_validation =~ s/__FORM-NAME__/$form_name/;
		return $this_form_validation;
	};

}

sub validate_post {

	my ( $n, $d, $options ) = @_;

	my ( $controller, $method ) = split( /\//, $ENV{ACCESSING} );
	my $class = 'security::' . $controller . '::post';

	my $validations = $class->$method( $d->{dbh}, $d->{p}, $options );
	return 'POST-VALIDATIONS-OK' if $validations eq 'NO-VALIDATIONS-REQUIRED';

	die "$class provides no post validations" unless $validations;

	if ( defined( $validations->{status} ) && $validations->{status} == 0 ) {
		my $vvr = view::render->new( $d->{r} );
		$d->warning( $validations->{message} );
		return $vvr->status($d);
	}

	my $model = model::configuration->new( $d->{dbh} );

	my @warnings;

	my %_field_names;
	%_field_names = map { $_ => 1 } @{ $options->{field_names} }
	  if ( $options->{field_names} && scalar( @{ $options->{field_names} } ) );

	my %_excluded_field_names;
	%_excluded_field_names = map { $_ => 1 } @{ $options->{exclude_field_names} }
	  if ( $options->{exclude_field_names} && scalar( @{ $options->{exclude_field_names} } ) );

	foreach my $validation ( keys %{$validations} ) {

		next if $validation eq 'listhasoptions';
		next if $validation eq 'javascript';

		my @vv = @{ $validations->{$validation} };

		my @clean_vv;

		# clean vv before validation
		foreach my $psv (@vv) {
			next unless $psv->{input} =~ /\S+/;
			next unless ( !%_field_names || defined( $_field_names{ $psv->{input} } ) );
			next if ( defined( $_excluded_field_names{ $psv->{input} } ) );
			push @clean_vv, $psv;
		}

		@vv = @clean_vv;

		if ( $validation eq 'passwordmatches' ) {
			foreach my $psv (@vv) {
				next unless $psv->{input} =~ /\S+/;
				next if $psv->{ifdef} && !$d->{p}->{ $psv->{input} };
				my $confirmation_input = '_' . $psv->{input};
				push @warnings, $psv->{message} unless $d->{p}->{ $psv->{input} } eq $d->{p}->{$confirmation_input};
			}
		}

		if ( $validation eq 'uniqueupdate' ) {

			my $ww = {};
			my $message;
			my ( $table, $fields );

			foreach my $psv (@vv) {

				next unless $psv =~ /\S+/;
				( $table, $fields ) = split( /\./, $psv->{input} );
				$message = $psv->{message};

				foreach my $field ( split( /\|/, $fields ) ) {
					$ww->{$field} = $d->{p}->{$field};
				}

			}

			push @warnings,
			  $message if $model->exists_not_me(
				where => $ww,
				table => $table,
				id    => $d->{p}->{id}
			  );

		}

		if ( $validation eq 'req' || $validation eq 'required' || $validation eq 'selectoption' || $validation eq 'ischecked' || $validation eq 'bool' ) {

			foreach my $psv (@vv) {
				next unless $psv->{input} =~ /\S+/;
				next if $psv->{ifdef} && !$d->{p}->{ $psv->{input} };
				my $trim_value = $d->{p}->{ $psv->{input} };
				$trim_value =~ s/^\s+|\s+$//g;
				push @warnings, $psv->{message} if !length($trim_value) || !$d->{p}->{ $psv->{input} };
			}

		}

		if ( $validation eq 'date' ) {

			foreach my $psv (@vv) {
				next unless $psv->{input} =~ /\S+/;
				next if $psv->{ifdef} && !$d->{p}->{ $psv->{input} };
				my $trim_value = $d->{p}->{ $psv->{input} };
				$trim_value =~ s/^\s+|\s+$//g;
				push @warnings, $psv->{message}
				  unless $trim_value =~ /^\d{2}\/\d{2}\/\d{4}$/
				  && global::date_time->check_valid_date($trim_value);
			}

		}

		if ( $validation eq 'num' || $validation eq 'numeric' ) {

			foreach my $psv (@vv) {
				next unless $psv->{input} =~ /\S+/;
				next if $psv->{ifdef} && !$d->{p}->{ $psv->{input} };
				my $trim_value = $d->{p}->{ $psv->{input} };
				$trim_value =~ s/^\s+|\s+$//g;
				push @warnings, $psv->{message} unless $trim_value =~ /^\d+/;
			}

		}

		if ( $validation eq 'money' ) {

			foreach my $psv (@vv) {
				next unless $psv->{input} =~ /\S+/;
				next if $psv->{ifdef} && !$d->{p}->{ $psv->{input} };
				my $trim_value = $d->{p}->{ $psv->{input} };
				$trim_value =~ s/^\s+|\s+$//g;
				push @warnings, $psv->{message}
				  unless $trim_value =~ /^\d+$/ || $trim_value =~ /^\d+\.\d+$/;
			}

		}

		## NEED TO IMPLEMENT ##
		if ( $validation eq 'uniquecombo' ) {

			global::standard->inspect( 'need-to-implement', __FILE__, __LINE__ );

			my $ww = {};
			my $message;
			my ( $table, $fields );

			foreach my $psv (@vv) {
				next unless $psv =~ /\S+/;
				my @psvalues = split( /:/, $psv );
				( $table, $fields ) = split( /\./, $psvalues[0], 2 );
				$message = $psvalues[1];

				foreach my $field ( split( /\|/, $fields ) ) {
					$ww->{$field} = $d->{p}->{$field};
				}

			}

			push @warnings, $message if $model->exists( $ww, $table );

		}

		if ( $validation eq 'uniquecomboupdate' ) {

			global::standard->inspect( 'need-to-implement', __FILE__, __LINE__ );

			my $ww = {};
			my $message;
			my ( $table, $fields );

			foreach my $psv (@vv) {
				next unless $psv =~ /\S+/;
				my @psvalues = split( /:/, $psv );
				( $table, $fields ) = split( /\./, $psvalues[0], 2 );
				$message = $psvalues[1];

				foreach my $field ( split( /\|/, $fields ) ) {
					$ww->{$field} = $d->{p}->{$field};
				}

			}

			push @warnings, $message if $model->exists_not_me( $ww, $table, $d->{p}->{id} );

		}

		if ( $validation eq 'requireone' ) {

			global::standard->inspect( 'need-to-implement', __FILE__, __LINE__ );

			my ( $ok, $message );

			foreach my $psv (@vv) {

				next unless $psv =~ /\S+/;
				my @psvalues = split( /:/, $psv );
				my @fields   = split( /,/, $psvalues[0] );
				$message = $psvalues[1];

				foreach my $field (@fields) {
					next unless $d->{p}->{$field} =~ /\S+/;
					$ok = 1;
				}
			}

			push @warnings, $message unless $ok;

		}

		if ( $validation eq 'email' ) {

			global::standard->inspect( 'need-to-implement', __FILE__, __LINE__ );

			foreach my $psv (@vv) {
				next unless $psv =~ /\S+/;
				my @psvalues = split( /:/, $psv );
				my $field    = $psvalues[0];
				my $message  = $psvalues[1];
				push @warnings, $message if $d->{p}->{$field} !~ /\S+\@\S+\.\S+/;
			}

		}

		if ( $validation eq 'rfc' ) {

			global::standard->inspect( 'need-to-implement', __FILE__, __LINE__ );

			foreach my $psv (@vv) {
				next unless $psv =~ /\S+/;
				my @psvalues = split( /:/, $psv );
				my $field    = $psvalues[0];
				my $message  = $psvalues[1];

				if ( $d->{p}->{$field} !~ /^[A-ZÑ&]{3,4}[0-9]{2}[0-1][0-9][0-3][0-9][A-Z0-9]{2}[A0-9]$/ ) {
					push @warnings, $message;
				}
			}

		}

		if ( $validation eq 'curp' ) {

			global::standard->inspect( 'need-to-implement', __FILE__, __LINE__ );

			foreach my $psv (@vv) {
				next unless $psv =~ /\S+/;
				my @psvalues = split( /:/, $psv );
				my $field    = $psvalues[0];
				my $message  = $psvalues[1];

				if ( $d->{p}->{$field} !~ /^$|^[A-Z][AEIOUX][A-Z]{2}[0-9]{2}[0-1][0-9][0-3][0-9][MH][A-Z]{2}[BCDFGHJKLMNÑPQRSTVWXYZ]{3}[0-9A-Z][0-9]$/ ) {
					push @warnings, $message;
				}
			}

		}

		if ( $validation =~ /^length_(\d+)$/ || $validation =~ /^len_(\d+)$/ ) {

			global::standard->inspect( 'need-to-implement', __FILE__, __LINE__ );

			my $detail = $1;
			foreach my $psv (@vv) {
				next unless $psv =~ /\S+/;
				my @psvalues = split( /:/, $psv );
				my $field    = $psvalues[0];
				my $message  = $psvalues[1];

				if ( length( $d->{p}->{$field} ) != $detail ) {
					push @warnings, $message;
				}
			}

		}

		if ( $validation =~ /^maxlength_(\d+)$/ || $validation =~ /^maxlen_(\d+)$/ ) {

			global::standard->inspect( 'need-to-implement', __FILE__, __LINE__ );

			my $detail = $1;
			foreach my $psv (@vv) {
				next unless $psv =~ /\S+/;
				my @psvalues = split( /:/, $psv );
				my $field    = $psvalues[0];
				my $message  = $psvalues[1];

				if ( length( $d->{p}->{$field} ) > $detail ) {
					push @warnings, $message;
				}
			}

		}

		if ( $validation =~ /^minlength_(\d+)$/ || $validation =~ /^minlen_(\d+)$/ ) {

			global::standard->inspect( 'need-to-implement', __FILE__, __LINE__ );

			my $detail = $1;
			foreach my $psv (@vv) {
				next unless $psv =~ /\S+/;
				my @psvalues = split( /:/, $psv );
				my $field    = $psvalues[0];
				my $message  = $psvalues[1];

				if ( length( $d->{p}->{$field} ) < $detail ) {
					push @warnings, $message;
				}
			}

		}

		if ( $validation =~ /^lessthan_(\d+)$/ || $validation =~ /^lt_(\d+)$/ ) {

			global::standard->inspect( 'need-to-implement', __FILE__, __LINE__ );

			my $detail = $1;
			foreach my $psv (@vv) {
				next unless $psv =~ /\S+/;
				my @psvalues = split( /:/, $psv );
				my $field    = $psvalues[0];
				my $message  = $psvalues[1];

				if ( $d->{p}->{$field} >= $detail ) {
					push @warnings, $message;
				}
			}

		}

		if ( $validation =~ /^greaterthan_(\d+)$/ || $validation =~ /^gt_(\d+)$/ ) {

			global::standard->inspect( 'need-to-implement', __FILE__, __LINE__ );

			my $detail = $1;
			foreach my $psv (@vv) {
				next unless $psv =~ /\S+/;
				my @psvalues = split( /:/, $psv );
				my $field    = $psvalues[0];
				my $message  = $psvalues[1];

				if ( $d->{p}->{$field} <= $detail ) {
					push @warnings, $message;
				}
			}

		}

		if ( $validation eq 'alnum' || $validation eq 'alphanumeric' ) {

			global::standard->inspect( 'need-to-implement', __FILE__, __LINE__ );

			foreach my $psv (@vv) {
				next unless $psv =~ /\S+/;
				my @psvalues = split( /:/, $psv );
				my $field    = $psvalues[0];
				my $message  = $psvalues[1];

				if ( $d->{p}->{$field} !~ /^\w*$/ ) {
					push @warnings, $message;
				}
			}

		}

		if ( $validation eq 'numfloat' ) {

			global::standard->inspect( 'need-to-implement', __FILE__, __LINE__ );

			foreach my $psv (@vv) {
				next unless $psv =~ /\S+/;
				my @psvalues = split( /:/, $psv );
				my $field    = $psvalues[0];
				my $message  = $psvalues[1];

				if ( $d->{p}->{$field} !~ /^\d+\.*\d*$/ ) {
					push @warnings, $message;
				}
			}

		}

		if ( $validation eq 'phone' ) {

			global::standard->inspect( 'need-to-implement', __FILE__, __LINE__ );

			foreach my $psv (@vv) {
				next unless $psv =~ /\S+/;
				my @psvalues = split( /:/, $psv );
				my $field    = $psvalues[0];
				my $message  = $psvalues[1];

				if ( $d->{p}->{$field} !~ /^\d{10}$/ ) {
					push @warnings, $message;
				}
			}

		}

		if ( $validation eq 'alpha' || $validation eq 'alphabetic' ) {

			global::standard->inspect( 'need-to-implement', __FILE__, __LINE__ );

			foreach my $psv (@vv) {
				next unless $psv =~ /\S+/;
				my @psvalues = split( /:/, $psv );
				my $field    = $psvalues[0];
				my $message  = $psvalues[1];

				if ( $d->{p}->{$field} !~ /^[A-Za-z]+$/ ) {
					push @warnings, $message;
				}
			}

		}

		if ( $validation eq 'alnumhyphen' ) {

			global::standard->inspect( 'need-to-implement', __FILE__, __LINE__ );

			foreach my $psv (@vv) {
				next unless $psv =~ /\S+/;
				my @psvalues = split( /:/, $psv );
				my $field    = $psvalues[0];
				my $message  = $psvalues[1];

				if ( $d->{p}->{$field} !~ /^[A-Za-z0-9\-_]+$/ ) {
					push @warnings, $message;
				}
			}

		}

	}

	if ( scalar @warnings ) {
		my $vvr = view::render->new( $d->{r} );
		foreach my $msg (@warnings) {
			$d->warning($msg);
		}
		return $vvr->status($d);
	}

	return 'POST-VALIDATIONS-OK' if !scalar @warnings;

}

1;
