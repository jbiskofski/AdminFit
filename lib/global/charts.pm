package global::charts;
use strict;

use JavaScript::Minifier;
use Sort::Key 'rnkeysort';

sub lines {

	my ( $n, %pp ) = @_;
	$pp{type} = 'area';
	return __PACKAGE__->lines_bars(%pp);

}

sub bars {

	my ( $n, %pp ) = @_;
	$pp{type} = 'bar';
	return __PACKAGE__->lines_bars(%pp);

}

sub lines_bars {

	my ( $n, %pp ) = @_;

	my @chart_strings;
	my @line_names;
	my @line_colors;

	# you have to add elements to the beginning and end of the labels/values
	# array, because c3 doesnt show those for some reason
	my $chart_labels = "'',";
	foreach my $ll ( @{ $pp{labels} } ) {
		$chart_labels .= "'$ll',";
	}
	$chart_labels .= "''";

	if ( $pp{multi} ) {
		for ( my $c = 0 ; $c < scalar @{ $pp{values} } ; $c++ ) {
			my $values_string = "'',";
			foreach my $vv ( @{ $pp{values}[$c] } ) {
				$values_string .= "'$vv',";
			}
			$values_string .= "''";
			my $data_index = $c + 1;
			push @chart_strings, "['data$data_index'," . $values_string . ']';
			push @line_names,    "'data$data_index':'$pp{multi}->[$c]'";
			push @line_colors,   "'data$data_index': tabler.colors[\"$pp{colors}->[$c]\"]";
			$pp{type} = 'line';
		}
	}
	else {
		my $values_string = "'',";
		foreach my $vv ( @{ $pp{values} } ) {
			$values_string .= "'$vv',";
		}
		$values_string .= "''";
		push @chart_strings, "['data1'," . $values_string . ']';
		my $title = uc( global::standard->unaccent( $pp{title} ) );
		push @line_names, "'data1':'" . $title . "'";
		my $color = $pp{color} || 'blue';
		push @line_colors, "'data1': tabler.colors[\"$color\"]";
	}

	my $line_names_string  = join( ",", @line_names );
	my $line_colors_string = join( ",", @line_colors );
	my $chart_values       = join( ",", @chart_strings );

	my $tooltip_return = $pp{monify} ? qq{ '\$' + __ADMINFIT__.commify(d.toFixed(2)); } : 'd';

	my $x_axis_rotate = 'tick: { rotate: 90, multiline: false }, ' if scalar @{ $pp{labels} } > 10;

	my $js = <<"JS_CHART_DATA";
                require(['c3', 'jquery'], function(c3, \$) {
                        \$(document).ready(function() {
                                var chart = c3.generate({
                                        bindto: '#$pp{div_id}',
                                        data: {
                                                columns: [ $chart_values ],
                                                type: '$pp{type}',
                                                groups: [
                                                        [ 'data1']
                                                ],
                                                colors: { $line_colors_string },
                                                names: { $line_names_string },
                                        },
					axis: {
                                                y: {
                                                        padding: {
                                                                bottom: 0,
                                                        },
                                                        show: false,
                                                        tick: {
                                                                outer: false
                                                        }
                                                },
						x: {
							type: 'category',
							categories: [$chart_labels],
							$x_axis_rotate
							padding: {
						             left: -1,
						             right: -1,
						     	}
						},
                                        },
                                        padding: {
                                                bottom: 0,
                                                left: -1,
                                                right: -1,
                                        },
					legend: {
						show: false,
					},
                                        point: {
                                                show: false
                                        },
					tooltip: {
					        format: {
					            value: function(d) {
							    return $tooltip_return;
						    },
					        }
					},
                                });
                        });
                });
JS_CHART_DATA

	return '<script>' . minify( input => $js ) . '</script>';

}

sub pie {

	my ( $n, %pp ) = @_;

	my @values;
	my $js_labels;
	my $js_colors;

	my @shades = ( 'light', 'dark', 'lighter', 'darker' );
	my $shade_index = 0;

	my @unsorted;
	foreach my $ii ( @{ $pp{values} } ) {
		my @keys   = keys %{$ii};
		my @values = values %{$ii};
		push @unsorted, { label => shift @keys, value => shift @values };
	}

	my @sorted = rnkeysort { $_->{value} } @unsorted;

	if ( $pp{others} && scalar @sorted > $pp{others} ) {

		my @top;
		my $others_count = 0;

		for ( my $c = 0 ; $c < scalar @sorted ; $c++ ) {
			if ( $c < $pp{others} ) {
				push @top, $sorted[$c];
			}
			else {
				$others_count += $sorted[$c]->{value};
			}
		}

		push @top,
		  {
			label => 'Otros',
			value => $others_count
		  } if $others_count;

		@sorted = rnkeysort { $_->{value} } @top;

	}

	for ( my $c = 0 ; $c < scalar @sorted ; $c++ ) {
		my ( $label, $value ) = ( $sorted[$c]->{label}, $sorted[$c]->{value} );
		my $index = $c + 1;
		push @values, [ 'data' . ( $c + 1 ), int($value) ];
		$js_labels .= qq{'data$index':'$label',};
		my $shade = $shades[$shade_index];
		$shade_index++;
		$shade_index = 0 if $shade_index == 4;
		$js_colors .= qq{'data$index': tabler.colors["$pp{color}-$shade"],};
	}

	chop $js_labels;
	chop $js_colors;
	my $js_values = JSON::XS->new()->encode( \@values );

	my $pie_or_donut = $pp{donut} ? 'donut' : 'pie';

	my $tooltip_return = $pp{monify} ? qq{ '\$' + __ADMINFIT__.commify(d.toFixed(2)); } : 'd';

	my $js = <<"JS_CHART_DATA";
		require(['c3', 'jquery'], function(c3, \$) {
			\$(document).ready(function(){
				var chart = c3.generate({
					bindto: '#$pp{div_id}',
					data: {
						columns: $js_values,
						type: '$pie_or_donut',
						colors: { $js_colors },
						names: { $js_labels }
					},
					axis: {},
					legend: {
						show: false,
					},
					padding: {
						bottom: 0,
						top: 0
					},
					tooltip: {
					        format: {
					            value: function(d) {
							    return $tooltip_return;
						    },
					        }
					},
				});
			});
		});
JS_CHART_DATA

	return '<script>' . minify( input => $js ) . '</script>';

}

1;
