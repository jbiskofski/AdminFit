/usr/local/postgres/bin/psql -U pgsql -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;' adminfit_HMO
/usr/local/postgres/bin/psql -U pgsql adminfit_HMO < ./crossfit.db
