var is transaction_id
delete from _f_debts where charge_id in ( select id from _f_charges where transaction_id = 'b2678d23-e113-11e8-8901-0cc47a058364' );
delete from _f_payments where charge_id in ( select id from _f_charges where transaction_id = 'b2678d23-e113-11e8-8901-0cc47a058364' );
delete from _f_payments where transaction_id = 'b2678d23-e113-11e8-8901-0cc47a058364';
delete from _f_charges where transaction_id = 'b2678d23-e113-11e8-8901-0cc47a058364';
delete from _f_transactions where id = 'b2678d23-e113-11e8-8901-0cc47a058364';

var is client_id
-- force balance recalculation
UPDATE _f_payments SET id = _f_payments.id where client_id = '9312ca48-cafd-11e8-8901-0cc47a058364';
