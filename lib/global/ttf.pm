package global::ttf;

use strict;
use Data::Dumper::HTML 'dumper_html';
use CGI;
use URI::Escape::JavaScript 'escape';
use MIME::Base64;
use Crypt::OpenSSL::RSA;
use Digest::HMAC_SHA1;
use URI::Escape;
use HTML::Escape 'escape_html';
use JSON::XS;

use model::template_include;

sub new {

	my ( $n, $dbh ) = @_;
	my $x = { dbh => $dbh };
	bless $x;
	return $x;

}

sub json {
	shift;
	my $data = shift;
	return '{}' unless $data;
	return JSON::XS->new()->latin1()->encode($data);
}

sub uri_escape {

	my ( $n, $string ) = @_;
	return URI::Escape::JavaScript::escape($string);

}

sub escape {

	my ( $n, $string ) = @_;
	return escape_html($string);

}

sub commify {

	my ( $x, $number, $not_decimal ) = @_;
	return '' if ( '' eq $number );

	$number = sprintf( "%.2f", $number ) unless $not_decimal;
	1 while $number =~ s/^(-?\d+)(\d\d\d)/$1,$2/;

	$number =~ s/^-0\./0./;

	return $number;

}

sub random {

	my ( $n, $max ) = @_;
	my $random_number;
	my $number = int( rand($max) );
	$random_number .= $number + 1;

	return $random_number;

}

sub uuid {

	my $uid = global::standard->uuid();
	return $uid;

}

sub inspect {

	my ( $x, @data ) = @_;
	$Data::Dumper::Sortkeys = 1;
	my $dump = dumper_html( \@data );
	return $dump;

}

sub uri {

	my $n = shift;

	my %options = ref( $_[0] ) eq 'HASH' ? %{ $_[0] } : (@_);

	my $query_string = '?';

	foreach my $key ( sort keys %options ) {
		next unless length $options{$key};
		next
		  if $key eq 'c'
		  || $key eq 'controller'
		  || $key eq 'm'
		  || $key eq 'method'
		  || $key eq 'jump'
		  || $key eq 'main';
		$query_string .= $key . '=' . $options{$key} . '&';
	}

	chop $query_string;

	$query_string .= '#' . $options{jump} if $options{jump};

	$options{m} = $options{method}     if $options{method};
	$options{c} = $options{controller} if $options{controller};

	my $uri = '/' . $ENV{CUSTOMER} . '/' . $options{c} . '/' . $options{m} . '/';
	$uri .= $options{main} . '/' if $options{main};
	return $uri . $query_string;

}

sub s3 {

	my $n = shift;
	my %pp = ref( $_[0] ) eq 'HASH' ? %{ $_[0] } : (@_);

	my $hmac = Digest::HMAC_SHA1->new('');

	my $expires = time() + 3600;

	if ( $pp{open_access_policy} ) {

		# jan 1st, 2030 - we should be safe with that
		$expires = '1893456000';
	}

	my $url = '/' . $ENV{S3_STORAGE_RESOURCE_BUCKET} . '/adminfit_HMO/' . $pp{id};

	# my $url = '/' . $ENV{S3_STORAGE_RESOURCE_BUCKET} . '/' . $ENV{DB_NAME} . '/' . $pp{id};

	my $sign_data = "GET\n\n\n" . $expires . "\n" . $url;

	my $extra_headers = '';
	$extra_headers = '?response-content-disposition=inline' if ( defined( $pp{mime} ) && 'application/pdf' eq $pp{mime} );
	$sign_data .= $extra_headers;

	$hmac->add($sign_data);

	my $signature = encode_base64( $hmac->digest );
	$signature =~ s/\n//g;

	$signature = URI::Escape::uri_escape($signature);

	#if there are any weird character we need to escape extra_headers
	$url .= $extra_headers;
	my $s3_url = $ENV{S3_STORAGE_RESOURCE_PREFIX} . $url . ( '' eq $extra_headers ? '?' : '&' );

	$s3_url .= qq{AWSAccessKeyId=&Expires=$expires&Signature=$signature};

	return $s3_url;

}

sub unaccent {

	my ( $n, $string ) = @_;
	return global::standard->unaccent($string);

}

sub selected {

	my ( $x, $value ) = @_;
	return $value ? 'selected="selected"' : undef;

}

sub checked {

	my ( $x, $value ) = @_;
	return $value ? 'checked="checked"' : undef;

}

sub disabled {

	my ( $x, $value ) = @_;
	return $value ? 'disabled="disabled"' : undef;

}

sub get_include_data {

	my $x = shift;
	my %pp = ref( $_[0] ) eq 'HASH' ? %{ $_[0] } : (@_);

	( caller() )[1] =~ /include\/(\S+)\.tt$/;
	my $template_include_model_method = $1;
	$template_include_model_method =~ s/\W+/_/g;

	my $mti  = model::template_include->new( $x->{dbh} );
	my $data = $mti->$template_include_model_method(%pp);
	return $data;

}

sub avatar {

	my $n = shift;
	my %pp = ref( $_[0] ) eq 'HASH' ? %{ $_[0] } : (@_);

	if ( $pp{has_profile_picture} ) {
		my $s3_url = global::ttf->s3( id => "users/$pp{id}/PROFILE/TINY" );
		return qq{<span class="$pp{classes} image avatar" style="background-image: url($s3_url)"></span>};
	}
	elsif ( $pp{has_picture} ) {
		my $s3_url = global::ttf->s3( id => "users/$pp{id}/TINY" );
		return qq{<span class="$pp{classes} image avatar" style="background-image: url($s3_url)"></span>};
	}
	else {
		my $display_class = $pp{small} ? 'image avatar' : 'avatar';
		my ( $lastname, $name ) = split( ',', $pp{name} );
		$lastname =~ s/\s+//g;
		$name =~ s/\s+//g;
		my $initials = uc( substr( $name, 0, 1 ) . substr( $lastname, 0, 1 ) );
		return qq{<span class="$pp{classes} $display_class">$initials</span>};
	}

}

sub plural {

	my ( $n, $count, $singular, $plural ) = @_;
	return $plural if !$count || $count <= 0;
	return $count == 1 ? $singular : $plural;

}

sub date {

	my ( $n, $date_time ) = @_;
	my ( $date, $time ) = split( /\s+/, $date_time );
	return $date;

}

sub gr {
	my ( $n, $check ) = @_;
	return '<span class="fe fe-check text-success"></span>' if $check;
	return '<span class="fe fe-x text-danger"></span>';
}

sub tip {

	my ( $n, $tip ) = @_;
	my $n   = shift;
	my $tip = shift;
	return undef unless $tip && length $tip;

	my %pp = ref( $_[0] ) eq 'HASH' ? %{ $_[0] } : (@_);

	$tip = '<p style="text-align:left">' . $tip . '</p>' if $pp{align} eq 'left';
	$tip = __PACKAGE__->escape($tip) unless $pp{dont_escape};

	return qq { data-toggle="tooltip" data-placement="top" title="$tip" } if $pp{no_icon};

	my $icon  = $pp{icon}  ? $pp{icon}  : 'message-square';
	my $color = $pp{color} ? $pp{color} : 'blue';
	return qq{<i class="text-$color fe fe-$icon" data-toggle="tooltip" data-placement="top" title="$tip"></i>};

}

sub abs {

	my ( $n, $number ) = @_;
	return abs $number;

}

sub int {

	my ( $n, $number ) = @_;
	return int $number;

}

sub today {
	return global::date_time->get_date();
}

sub today_parts {
	return global::date_time->get_date_time_parts();
}

1;
