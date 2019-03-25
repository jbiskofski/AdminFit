package view::render;

use strict;
use Apache2::Const -compile => qw(OK REDIRECT);

sub new {

	my ( $n, $r ) = @_;

	my $template_path = __FILE__;
	$template_path =~ s/render\.pm$/templates/;

	my $x = {
		r  => $r,
		tt => Template->new( { INCLUDE_PATH => $template_path } ),
	};

	bless $x;
	return $x;

}

sub render {

	my ( $x, $d ) = @_;

	my $caller = ( caller(1) )[3];
	my @v = split( /::/, $caller );

	my $template_name = $v[1] . '/' . $v[2] . '.tt';

	$x->{r}->err_headers_out->add( 'Set-Cookie' => $d->{cookies}->[0] );
	$x->{r}->err_headers_out->add( 'Set-Cookie' => $d->{cookies}->[1] );

	$x->{r}->content_type('text/html; charset=ISO-8859-15;');
	$x->{tt}->process( $template_name, $d ) || die $x->{tt}->error();
	return Apache2::Const::OK;

}

sub status {

	my ( $x, $d ) = @_;

	my $template_name = 'global/status.tt';
	$x->{r}->content_type('text/html; charset=ISO-8859-15;');
	$x->{tt}->process( $template_name, $d ) || die $x->{tt}->error();
	return Apache2::Const::OK;

}

sub http_redirect {

	my ( $x, %pp ) = @_;

	my $uri = global::ttf->uri( \%pp );
	$x->{r}->headers_out->set( Location => $uri );
	$x->{r}->status(Apache2::Const::REDIRECT);
	return Apache2::Const::REDIRECT;

}

sub http_redirect_to_referer {

	my $x = shift;

	$x->{r}->headers_out->set( Location => $ENV{HTTP_REFERER} );
	$x->{r}->status(Apache2::Const::REDIRECT);
	return Apache2::Const::REDIRECT;

}

sub render_json {

	my ( $x, $data ) = @_;

	$x->{r}->headers_out()->set( 'Cache-Control', 'no-store' );
	$x->{r}->headers_out()->set( 'Expires',       'Thu, 01 Jan 1970 01:00:00 GMT' );
	$x->{r}->content_type('application/json; charset=ISO-8859-15;');
	print JSON::XS->new()->latin1()->encode($data);
	return Apache2::Const::OK;

}

1;
