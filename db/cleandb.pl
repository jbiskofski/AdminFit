#!/usr/local/bin/perl

use strict;
use DBI;
use Crypt::ScryptKDF 'scrypt_b64';
use UUID;

my $database = shift @ARGV;
die "usage : $0 <DATABASE>\n" unless $database;

my $user_id                         = lc UUID::uuid();
my $scrypt_password                 = scrypt_b64( '123123', $user_id );
my $publico_general_user_id         = lc UUID::uuid();
my $free_membership_id              = lc UUID::uuid();
my $publico_general_scrypt_password = scrypt_b64( time(), $publico_general_user_id );

system "/usr/local/postgres/bin/pg_dump -U pgsql -s -f crossfit-schema.db $database";

my $dbh = DBI->connect( "dbi:Pg:dbname=$database", 'pgsql' );
$dbh->do("SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '$database' AND pid <> pg_backend_pid()") || die $DBI::errstr;
$dbh->disconnect();

system "/usr/local/postgres/bin/psql -U pgsql -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;' $database < crossfit-schema.db";
system "/usr/local/postgres/bin/psql -U pgsql $database < crossfit-schema.db";
unlink 'crossfit-schema.db';

$dbh = DBI->connect( "dbi:Pg:dbname=$database", 'pgsql' );
my $sql = qq {
INSERT INTO _g_configuration VALUES ('TIMEZONE','America/Phoenix');
INSERT INTO _g_configuration VALUES ('DEVEL_MODE','1');
INSERT INTO _g_users (id,username,scrypt_password,email,name,lastname1,is_admin,is_client,is_coach,is_permanent)
        VALUES ('$user_id','admin','$scrypt_password','admin\@admin.fit','admin','fit',TRUE,FALSE,TRUE,TRUE);
INSERT INTO _g_users (id,username,scrypt_password,email,name,lastname1,is_admin,is_client,is_coach,is_permanent)
        VALUES ('$publico_general_user_id','PUBLICO-GENERAL','$publico_general_scrypt_password','admin\@admin.fit','PUBLICO','GENERAL',FALSE,TRUE,FALSE,TRUE);
INSERT INTO _f_memberships
        VALUES ('$free_membership_id','GRATUITA',0,'I',0,TRUE,NULL,TRUE,TRUE,TRUE,FALSE);
INSERT INTO _f_memberships
        VALUES (uuid_generate_v1(),'VISITAS',0,'I',0,FALSE,NULL,TRUE,TRUE,FALSE,TRUE);
INSERT INTO _f_client_memberships
        VALUES ( '$publico_general_user_id','$free_membership_id',1);
INSERT INTO _f_discounts
	VALUES (uuid_generate_v1(),'DESCUENTO-GENERAL',0,'G','A','Descuento general',TRUE,0,TRUE);
INSERT INTO _i_items
	VALUES (uuid_generate_v1(),'OTHER','ADEUDO-GENERAL',0,FALSE,'{}',TRUE,TRUE);
};
$dbh->do($sql) || die $DBI::errstr;
$dbh->disconnect();
