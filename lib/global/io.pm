package global::io;

use strict;
use CGI;
use File::MimeInfo::Magic;
use Number::Bytes::Human 'format_bytes';
use File::Slurp;
use Image::Size;
use Data::Structure::Util 'unbless';
use IO::Scalar;
use Amazon::S3;
use GD::Image;
use Image::Scale;
use LWP::UserAgent;
use Mozilla::CA;

sub s3_save {

	my ( $x, %pp ) = @_;

	my $cgi = CGI->new();

	my ( $file_name, $ext ) = $pp{file} =~ /^(.*)\.(\S+)$/;
	my $file_name_full = $file_name . '.' . $ext;
	my $id = $pp{file_id} ? $pp{file_id} : global::standard->uuid();

	my $data = read_file( $pp{file}, { binmode => 'raw' } );

	my $scalar_handle = IO::Scalar->new( \$data );
	my $mime          = mimetype($scalar_handle);
	my $size          = ( stat( $pp{file} ) )[7];

	my %valid_image_mimes = (
		'image/jpeg' => 1,
		'image/png'  => 1,
	);

	# validate file to be an image before we do any upload mumbo jumbo
	if ( $pp{verify_image} ) {

		return {
			status  => 0,
			message => 'El archivo especificado no es una imagen v&aacute;lida. Verifica el archivo y vuelve a intentar.',
		} unless $valid_image_mimes{$mime};

	}

	# validate mime type
	if ( $pp{verify_mime} ) {

		my $required_mime_found = 0;

		foreach my $required_mime ( @{ $pp{verify_mime} } ) {
			if ( $required_mime eq $mime ) {
				$required_mime_found = 1;
				last;
			}
		}

		return {
			status  => 0,
			message => 'El archivo especificado no es del tipo valido : ' . join( ', ', @{ $pp{verify_mime} } ) . '.',
		} unless $required_mime_found;

	}

	my $thumbnail_data;
	my $image_size;

	my $content_disposition = qq{attachment;filename="$file_name_full"};

	my @uploads;

	push @uploads,
	  {
		id                  => $id,
		ext                 => $ext,
		mime                => $mime,
		size                => $size,
		name                => $file_name_full,
		content_disposition => $content_disposition,
		data                => $data,
	  };

	if ( $valid_image_mimes{$mime} ) {

		$content_disposition = qq{filename="$file_name_full"};
		$image_size = $x->get_image_size( file_content => $data );

		if ( $pp{max_height} ) {
			return {
				code    => 0,
				message => "La altura m&aacute;xima permitida para esta imagen es de <b>$pp{max_height}</b> pixeles.",
			} if $image_size->{height} > $pp{max_height};

		}

		# create thumbnail
		$thumbnail_data = $x->resize_image(
			data   => $data,
			height => 150,
			mime   => $mime
		) if $pp{create_thumbnail};

		push @uploads,
		  {
			data   => $thumbnail_data,
			prefix => 'THUMBNAILS',
			mime   => 'image/png',
		  } if $thumbnail_data;

		# resize the image if thats what the user asked us to do - if we resize we get a png response - update the mimetype accordingly
		if ( $pp{resize_image} ) {

			foreach my $size ( @{ $pp{resize_image} } ) {

				my $resized_data = $x->resize_image(
					data   => $data,
					height => $size,
					mime   => $mime
				);

				next unless $resized_data;

				push @uploads,
				  {
					data   => $resized_data,
					prefix => $size . 'PX',
					mime   => 'image/png',
				  };

			}

		}

	}

	$uploads[0]->{image_size}          = $image_size;
	$uploads[0]->{content_disposition} = $content_disposition;

	return { status => 0, message => 'UNDEFINED-ERROR' } unless scalar @uploads;

	if ( !$ENV{READ_ONLY_STORAGE} ) {

		# upload to s3 bucket
		my $s3 = Amazon::S3->new(
			{
				aws_access_key_id     => '',
				aws_secret_access_key => '',
				retry                 => 1
			}
		);

		my $bucket = $s3->bucket('adminfit');

		my @keys;

		foreach my $up (@uploads) {

			my $s3_key = $ENV{DB_NAME} . '/';
			$s3_key .= $pp{dir} . '/'      if $pp{dir};
			$s3_key .= $up->{prefix} . '/' if $up->{prefix};
			$s3_key .= $id;

			$bucket->add_key(
				$s3_key,
				$up->{data},
				{
					content_type        => $up->{mime},
					content_disposition => $content_disposition,
				}
			);

		}

	}

	delete $uploads[0]->{data};
	$uploads[0]->{status} = 1;

	return $uploads[0];

}

sub resize_image {

	my ( $x, %pp ) = @_;

	my $original_size = $x->get_image_size( file_content => $pp{data} );
	my $new_width = int( ( $pp{height} * $original_size->{width} ) / $original_size->{height} );
	my $img = Image::Scale->new( \$pp{data} );
	$img->resize_gd( { height => $pp{height}, width => $new_width, keep_scale => 1 } );
	return $img->as_png();

}

sub get_human_size {

	my ( $n, $bytes ) = @_;

	my $human_size = format_bytes($bytes);

	# add the 'B' for bytes if the human_size doesnt include a quantitative descriptor
	$human_size .= 'B' if $human_size =~ /^\d+$/;

	return $human_size;

}

sub get_image_size {

	my ( $x, %pp ) = @_;

	my $width;
	my $height;

	if ( $pp{file_content} ) {
		( $width, $height ) = imgsize( \$pp{file_content} );
	}
	elsif ( $pp{file_path} ) {
		( $width, $height ) = imgsize( $pp{file_path} );
	}

	return ( { width => $width, height => $height } );

}

sub s3_delete {

	my ( $x, $file_id ) = @_;

	# upload to s3 bucket
	my $s3 = Amazon::S3->new(
		{
			aws_access_key_id     => '',
			aws_secret_access_key => '',
			retry                 => 1
		}
	);

	my $bucket = $s3->bucket('adminfit');
	my $s3_key = "$ENV{DB_NAME}/$file_id";
	$bucket->delete_key($s3_key);

	return 1;

}

sub save_user_image {

	my ( $x, %pp ) = @_;

	$pp{data} =~ /;base64,(.*)$/;
	my $base64data    = $1;
	my $data          = MIME::Base64::decode_base64($base64data);
	my $scalar_handle = IO::Scalar->new( \$data );

	my $s3 = Amazon::S3->new(
		{
			aws_access_key_id     => '',
			aws_secret_access_key => '',
			retry                 => 1
		}
	);

	my $bucket = $s3->bucket('adminfit');

	my $s3_key           = $ENV{DB_NAME} . '/users/' . $pp{user_id} . '/MAIN';
	my $s3_thumbnail_key = $ENV{DB_NAME} . '/users/' . $pp{user_id} . '/THUMBNAIL';
	my $s3_tiny_key      = $ENV{DB_NAME} . '/users/' . $pp{user_id} . '/TINY';

	# create thumbnail
	my $thumbnail_data = $x->resize_image(
		data   => $data,
		height => 150,
		mime   => 'image/png',
	);

	# create tiny
	my $tiny_data = $x->resize_image(
		data   => $data,
		height => 50,
		mime   => 'image/png',
	);

	my $main_upload_status      = $bucket->add_key( $s3_key,           $data,           { content_type => 'image/png' } );
	my $thumbnail_upload_status = $bucket->add_key( $s3_thumbnail_key, $thumbnail_data, { content_type => 'image/png' } );
	my $tiny_upload_status      = $bucket->add_key( $s3_tiny_key,      $tiny_data,      { content_type => 'image/png' } );

	return { code => 1, message => 'OK' } if $main_upload_status && $thumbnail_upload_status && $tiny_upload_status;
	return { code => 0, message => 'Se ha producido un error al procesar la fotograf&iacute;a. Consulte al administrador.' };

}

1;
