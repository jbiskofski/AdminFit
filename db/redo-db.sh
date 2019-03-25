ssh jbiskofski@core '/usr/local/postgres/bin/pg_dump -U pgsql -f crossfit.db adminfit_HMO'
rsync -avPp jbiskofski@core:~/crossfit.db crossfit.db 
/usr/local/postgres/bin/psql -U pgsql -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;' adminfit_HMO
/usr/local/postgres/bin/psql -U pgsql adminfit_HMO < ./crossfit.db
echo $'delete from _g_configuration where key = \'DEVEL_MODE\'; insert into _g_configuration values (\'DEVEL_MODE\',1);' | /usr/local/postgres/bin/psql -U pgsql adminfit_HMO
