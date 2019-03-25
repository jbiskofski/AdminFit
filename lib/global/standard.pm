package global::standard;

use strict;
use Data::Dumper::HTML 'dumper_html';
use Data::Dumper 'Dumper';
use Crypt::ScryptKDF 'scrypt_b64';
use UUID;
use Text::Unaccent::PurePerl 'unac_string';

sub uuid {
	return lc UUID::uuid();
}

sub short_unique_id {

	my $rv;

	for ( my $i = 0 ; $i < 8 ; ) {
		my $j = chr( int( rand(127) ) );
		if ( $j =~ /[a-zA-Z0-9]/ ) { $rv .= $j; $i++; }
	}

	return uc($rv);

}

sub random_number {

	my ( $n, $length ) = @_;

	my $random_number;

	for ( my $i = 0 ; $i < $length ; $i++ ) {
		my $number = int( rand(9) );
		$random_number .= $number + 1;
	}

	return $random_number;

}

sub unaccent {

	my ( $n, $string ) = @_;

	$string = lc($string);
	$string = unac_string($string);
	$string = lc($string);

	return $string;

}

sub inspect {

	my $null = shift;
	my $cgi  = CGI->new();

	$Data::Dumper::Sortkeys = 1;

	print $cgi->header();
	print qq{<div style="font-family: monospace">\n};
	print '<br><b>caller : ' . ( caller(1) )[3] . '</b><hr>';
	print dumper_html(@_);
	print qq{</div><br><br>\n\n};
	die 'INTERNAL-DEBUG-DIE';

}

sub shout {

	my ( $x, @messages ) = @_;
	my $cgi = CGI->new();

	print $cgi->header();
	print qq{<div style="font-family: monospace">\n};
	print '<br><b>caller : ' . ( caller(1) )[3] . '</b><hr>';

	foreach my $mm (@messages) {

		my $all_lines = $mm;
		$all_lines =~ s/\s+/ /g;
		$mm = global::standard->cutcut( $mm, 1 ) if $all_lines =~ /CUTCUT/;

		$mm =~ s/\n/<br>\n/go;
		$mm =~ s/\$X\$/'/go;
		$mm =~ s/\$\S{4}\$/'/go;
		$mm =~ s/\t/\&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;/g;
		$mm =~ s/\s/\&nbsp;/g;
		print qq{<div style="font-family: monospace">$mm</div><br><br>\n};
	}

	die 'INTERNAL-DEBUG-DIE';

}

sub cutcut {

	my ( $n, $string, $do_return ) = @_;

	my @lines = split /\n/, $string;
	my $return_string;
	my $cutcut_seen = 0;
	my $cutcut_done = 0;

	foreach my $l (@lines) {
		chomp $l;
		my $cutcut_match = $l =~ /CUTCUT/ ? 1 : 0;
		if ( $cutcut_seen && $cutcut_match ) {
			$cutcut_done = 1;
			last;
		}
		elsif ($cutcut_seen) {
			$return_string .= $l . "\n";
		}
		elsif ( !$cutcut_seen && $cutcut_match ) {
			$cutcut_seen = 1;
		}
	}

	$return_string = "-- NOCUTCUTFOUND --\n\n" . $string unless $cutcut_done;
	return $return_string if $do_return;
	global::standard->shout($return_string);

}

sub scrypt {

	my ( $n, %pp ) = @_;
	my $scrypted = scrypt_b64( $pp{string}, $pp{salt} );
	return $scrypted;

}

sub remove_file_params {

	my ( $n, $params ) = @_;

	my %new_params;
	foreach my $key ( keys %{$params} ) {
		next if ref( $params->{$key} ) eq 'Fh';
		next if ref( $params->{$key} ) eq 'CGI::File::Temp';

		if ( ref( $params->{$key} ) eq 'ARRAY' ) {
			foreach my $ii ( @{ $params->{$key} } ) {
				$ii = undef if ref($ii) eq 'Fh';
				$ii = undef if ref($ii) eq 'CGI::File::Temp';
			}
		}

		$new_params{$key} = $params->{$key};
	}

	return ( \%new_params );

}

sub hashify_arrays {

	my ( $n, %pp ) = @_;

	return undef
	  unless $pp{items}
	  && ref( $pp{items}->[0] ) eq 'ARRAY'
	  && scalar @{ $pp{items}->[0] };

	my @result;

	for ( my $c = 0 ; $c < scalar( @{ $pp{items} } ) ; $c++ ) {
		foreach ( my $d = 0 ; $d < scalar( @{ $pp{items}->[$c] } ) ; $d++ ) {
			next unless defined $pp{items}->[$c]->[$d];
			$result[$d]->{ $pp{keys}->[$c] } = $pp{items}->[$c]->[$d];
		}
	}

	return undef unless scalar @result;

	if ( $pp{not_null_key} ) {
		@result = grep { defined( $_->{ $pp{not_null_key} } ) } @result;
	}

	if ( $pp{sort_by} ) {
		@result = keysort { $_->{ $pp{sort_by} } } @result;
	}

	return \@result unless $pp{unique};

	my %seen;
	my @unique_items;

	foreach my $rr (@result) {
		next if $seen{ $rr->{ $pp{unique} } };
		$seen{ $rr->{ $pp{unique} } } = 1;
		push( @unique_items, $rr );
	}

	return \@unique_items;

}

sub get_person_display_name {

	my ( $n, $name, $lastname1, $lastname2 ) = @_;

	my $display_name = $lastname1;
	$display_name .= ' ' . $lastname2 if $lastname2;
	$display_name .= ', ' . $name;

	return $display_name;

}

sub log_inspect {

	my ( $x, @messages ) = @_;

	$Data::Dumper::Sortkeys = 1;

	my $date_time = global::date_time->get_date_time();

	open( LOG, ">>/var/tmp/algebraix.log" );

	print LOG $ENV{DB_NAME} . ' ' . $date_time . "\n";

	foreach my $mm (@messages) {
		print LOG ( caller(1) )[3] . "\n" . Dumper($mm) . "\n\n";
	}

	print LOG "\n";
	close(LOG);

}

sub log {

	my ( $x, @messages ) = @_;

	$Data::Dumper::Sortkeys = 1;

	my $date_time = global::date_time->get_date_time();

	open( LOG, ">>/var/tmp/algebraix.log" );

	print LOG $ENV{DB_NAME} . ' ' . $date_time . "\n";

	foreach my $mm (@messages) {
		print LOG $mm . "\n";
	}

	print LOG "\n";
	close LOG;

}

1;
