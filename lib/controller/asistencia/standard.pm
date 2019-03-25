package controller::asistencia::standard;

use strict;
use Sort::Key qw/keysort rnkeysort/;

sub _aggregate_client_day_attendance {

	my ( $x, $attendance ) = @_;

	return undef unless $attendance && scalar @{$attendance};

	my %clients;

	foreach my $aa ( @{$attendance} ) {

		if ( !$clients{ $aa->{client_id} } ) {
			$clients{ $aa->{client_id} } = {
				client_id           => $aa->{client_id},
				is_client           => $aa->{is_client},
				display_client_name => $aa->{display_client_name},
				times               => [],
			};
		}

		foreach my $time ( @{ $aa->{times} } ) {
			push @{ $clients{ $aa->{client_id} }->{times} },
			  {
				date                   => $aa->{date},
				admin_id               => $time->{admin_id},
				time                   => $time->{time},
				id                     => $time->{id},
				cancelled              => $time->{cancelled},
				cancelled_admin_id     => $time->{cancelled_admin_id},
				cancelled_notes        => $time->{cancelled_notes},
				display_admin_name     => $time->{display_admin_name},
				display_cancelled_name => $time->{display_cancelled_name},
				epoch                  => global::date_time->get_epoch( $aa->{date} . ' ' . $time->{time} ),
			  };
		}

		my @sorted = rnkeysort { $_->{epoch} } @{ $clients{ $aa->{client_id} }->{times} };
		$clients{ $aa->{client_id} }->{times} = \@sorted;

	}

	my @sorted = keysort { $_->{display_client_name} } values %clients;
	return \@sorted;

}

1;
