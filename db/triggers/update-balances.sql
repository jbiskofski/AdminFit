CREATE OR REPLACE FUNCTION update_balances()
RETURNS TRIGGER AS
$BODY$
declare
    	_CLIENT_ID UUID;
	_CREDIT_AMOUNT NUMERIC(9,2);
	_CANCELLED_DEBIT_AMOUNT NUMERIC(9,2);
	_DEBIT_AMOUNT NUMERIC(9,2);
    	_PAYMENT_ID UUID;
BEGIN

	CASE
		WHEN TG_TABLE_NAME = '_f_payments' THEN _PAYMENT_ID := NEW.id;
		WHEN TG_TABLE_NAME = '_f_payments_cancelled' THEN _PAYMENT_ID := NEW.payment_id;
	ELSE _PAYMENT_ID := NEW.id;
	END CASE;

	SELECT _f_payments.client_id
	INTO _CLIENT_ID
	FROM _f_payments
	WHERE _f_payments.id = _PAYMENT_ID;

   	SELECT SUM(_f_payments.payment_amount)
   	INTO _CREDIT_AMOUNT
   	FROM _f_payments
   	JOIN _f_charges ON ( _f_charges.id = _f_payments.charge_id)
   	WHERE _f_payments.client_id = _CLIENT_ID
        AND   _f_charges.type_code = 'P';

   	SELECT SUM(_f_payments.debit_amount)
	INTO _DEBIT_AMOUNT
        FROM _f_payments
        JOIN _f_charges ON ( _f_charges.id = _f_payments.charge_id)
        WHERE _f_payments.client_id = _CLIENT_ID
        AND   _f_charges.type_code <> 'P';

	SELECT SUM(_f_payments_cancelled.debit_amount)
   	INTO _CANCELLED_DEBIT_AMOUNT
   	FROM _f_payments_cancelled
	JOIN _f_payments ON ( _f_payments.id = _f_payments_cancelled.payment_id )
   	JOIN _f_charges ON ( _f_charges.id = _f_payments.charge_id)
   	WHERE _f_payments.client_id = _CLIENT_ID;

   	_CREDIT_AMOUNT = COALESCE(_CREDIT_AMOUNT,0);
   	_DEBIT_AMOUNT = COALESCE(_DEBIT_AMOUNT,0);
   	_CANCELLED_DEBIT_AMOUNT = COALESCE(_CANCELLED_DEBIT_AMOUNT,0);

	INSERT INTO _f_balances
    	VALUES (_CLIENT_ID,_CREDIT_AMOUNT,_DEBIT_AMOUNT,_CANCELLED_DEBIT_AMOUNT,( _CREDIT_AMOUNT - _DEBIT_AMOUNT ))
        ON CONFLICT ( client_id )
        DO UPDATE SET
		credit_amount = _CREDIT_AMOUNT,
        	debit_amount = _DEBIT_AMOUNT,
        	cancelled_debit_amount = _CANCELLED_DEBIT_AMOUNT,
            	balance_amount = ( _CREDIT_AMOUNT - _DEBIT_AMOUNT );

    RETURN NEW;

END;
$BODY$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_balances_on_payment ON _f_payments CASCADE;
DROP TRIGGER IF EXISTS trigger_update_balances_on_payment_cancel ON _f_payments_cancelled CASCADE;

CREATE TRIGGER trigger_update_balances_on_payment
	AFTER INSERT OR UPDATE
    	ON _f_payments
    	FOR EACH ROW
	EXECUTE PROCEDURE update_balances();

CREATE TRIGGER trigger_update_balances_on_payment_cancel
	AFTER INSERT OR UPDATE
    	ON _f_payments_cancelled
    	FOR EACH ROW
	EXECUTE PROCEDURE update_balances();
