#!/usr/local/bin/perl

use strict;

use Getopt::Std;
use FindBin;
use File::Slurp;
use JSON::XS;

my %args;
getopts( 'd:', \%args );

my $specific_day;
my $specific_month;
my $specific_year;

if ( $args{d} ) {
	if ( $args{d} =~ /^\d{2}\/\d{2}\/\d{4}$/ ) {
		( $specific_day, $specific_month, $specific_year ) = split( /\D+/, $args{d} );
	}
	else {
		die "==> invalid date $args{d}\n";
	}
}

use lib "$FindBin::Bin/../../lib";
require "$FindBin::Bin/../startup.pl";

use global::data;
use model::init;

my $json    = read_file "$FindBin::Bin/../../tenants.json";
my $tenants = JSON::XS->new()->latin1()->decode($json);

foreach my $tt ( @{$tenants} ) {
	print "==> processing : $tt->{db}\n";
	my $result = _process_tenant( $tt->{db} );
	print "==> $tt->{db} processed successfully. charged : $result->{charged}, skipped : $result->{skipped}\n";
}

print "==> ce finite!\n";

sub _process_tenant {

	my $db = shift;

	my %dispatch_values = (
		accessing => 'cron/process-charges',
		db        => $db,
	);

	my $d = global::data->new( undef, \%dispatch_values );

	$d->{dbh}->begin_work() || die($DBI::errstr);

	my $m   = model::init->new( $d->{dbh} );
	my $cff = controller::finanzas->new($d);

	my %membership_options = (
		where => {
			'_g_users.active'    => 1,
			'_g_users.is_client' => 1,
		},
	);

	if ($specific_day) {
		$membership_options{specific_day_renewals} = $specific_day;
	}
	else {
		$membership_options{get_todays_renewals} = 1;
	}

	my $memberships = $m->{memberships}->get_client_memberships(%membership_options);

	if ( !$memberships ) {
		$d->{dbh}->commit();
		$d->{dbh}->disconnect();
		return {
			charged => 0,
			skipped => 0,
		};
	}

	my %client_ids = map { $_->{client_id} => 1 } @{$memberships};

	my %charge_options = (
		only_membership_charges => 1,
		not_cancelled           => 1,
		client_ids              => [ keys %client_ids ],
	);

	if ( $specific_month && $specific_year ) {
		$charge_options{month} = $specific_month;
		$charge_options{year}  = $specific_year;
	}
	else {
		$charge_options{get_current_month} = 1;
	}

	my $existing_charges_tmp = $m->{charges}->get_charges(%charge_options);

	my %existing_charges = map { $_->{client_id} => $_ } @{$existing_charges_tmp} if $existing_charges_tmp;
	my $total_charged    = 0;
	my $total_skipped    = 0;

	foreach my $mm ( @{$memberships} ) {

		next unless $mm->{user_active};

		if ( $existing_charges{ $mm->{client_id} } ) {
			print "==> skipping client_id : $mm->{client_id} because charge already exists.\n";
			$total_skipped++;
			next;
		}

		print "==> creating client charge : $mm->{client_id}\n";

		my %charge_membership_options = ( client_id => $mm->{client_id} );

		if ( $specific_month && $specific_year ) {
			$charge_membership_options{month}         = $specific_month;
			$charge_membership_options{year}          = $specific_year;
			$charge_membership_options{creation_date} = $args{d};
		}

		my $new_charge = $cff->charge_client_membership(%charge_membership_options);
		print "==> client charge created. charge_id $new_charge->{id}\n";
		$total_charged++;

	}

	$m->delete( where => { tip_id => 'RENOVACIONES-DEL-DIA' }, table => '_g_seen_tips' );

	$d->{dbh}->commit();
	$d->{dbh}->disconnect();

	return {
		charged => $total_charged,
		skipped => $total_skipped
	};

}
