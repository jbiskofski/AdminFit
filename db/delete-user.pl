#!/usr/local/bin/perl

use strict;
use DBI;

my $database = shift @ARGV;
my $user_id  = shift @ARGV;

die "usage : $0 <DATABASE> <USER-ID>\n" unless $user_id;

my $dbh = DBI->connect( "dbi:Pg:dbname=$database", 'pgsql' );
$dbh->begin_work() || die $DBI::errstr;
my $sql = qq {
	delete from _a_attendance where client_id = '$user_id';
	delete from _f_payments where client_id = '$user_id';
	delete from _f_debts where charge_id in (
		select id from _f_charges where client_id = '$user_id'
	);
	delete from _f_charges where client_id = '$user_id';
	delete from _i_inventory_sales where transaction_id in (
		select id from _f_transactions where client_id = '$user_id'
	);
	delete from _f_client_memberships where client_id = '$user_id';
	delete from _f_balances where client_id = '$user_id';
	delete from _f_transactions where client_id = '$user_id';
	delete from _f_charges where client_id = '$user_id';
	delete from _g_users where id = '$user_id';
};

$dbh->do($sql) || die $DBI::errstr;
$dbh->commit() || die $DBI::errstr;
$dbh->disconnect();
