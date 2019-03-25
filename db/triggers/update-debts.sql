CREATE OR REPLACE FUNCTION update_debts()
RETURNS TRIGGER AS
$BODY$
declare
	_CHARGE_AMOUNT NUMERIC(9,2);
	_CHARGE_TYPE_CODE CHAR(1);
   	_DISCOUNT_AMOUNT NUMERIC(9,2);
   	_PAID_AMOUNT NUMERIC(9,2);
   	_DEBIT_AMOUNT NUMERIC(9,2);
   	_REMAINING_AMOUNT NUMERIC(9,2);
    	_CHARGE_ID UUID;
BEGIN

	CASE
		WHEN TG_TABLE_NAME = '_f_payments' THEN _CHARGE_ID := NEW.charge_id;
		WHEN TG_TABLE_NAME = '_f_charge_discounts' THEN _CHARGE_ID := NEW.charge_id;
        ELSE _CHARGE_ID := NEW.id;
	END CASE;

	SELECT _f_charges.amount,_f_charges.type_code
   		INTO _CHARGE_AMOUNT,_CHARGE_TYPE_CODE
        FROM _f_charges
        WHERE _f_charges.id = _CHARGE_ID;

   	SELECT SUM(_f_charge_discounts.discount_amount)
   		INTO _DISCOUNT_AMOUNT
        FROM _f_charge_discounts
        WHERE _f_charge_discounts.charge_id = _CHARGE_ID
        GROUP BY _f_charge_discounts.charge_id;

   	SELECT SUM(_f_payments.payment_amount),SUM(_f_payments.debit_amount)
   		INTO _PAID_AMOUNT,_DEBIT_AMOUNT
        FROM _f_payments
        WHERE _f_payments.charge_id = _CHARGE_ID
        GROUP BY _f_payments.charge_id;

   	_CHARGE_AMOUNT = COALESCE(_CHARGE_AMOUNT,0);
   	_DISCOUNT_AMOUNT = COALESCE(_DISCOUNT_AMOUNT,0);
   	_PAID_AMOUNT = COALESCE(_PAID_AMOUNT,0);
   	_DEBIT_AMOUNT = COALESCE(_DEBIT_AMOUNT,0);

	IF _CHARGE_TYPE_CODE = 'P' THEN
		_CHARGE_AMOUNT = _PAID_AMOUNT;
	END IF;

   	_REMAINING_AMOUNT = _CHARGE_AMOUNT - _DISCOUNT_AMOUNT - _PAID_AMOUNT - _DEBIT_AMOUNT;

	INSERT INTO _f_debts
    	VALUES (_CHARGE_ID,_CHARGE_AMOUNT,_DISCOUNT_AMOUNT,_PAID_AMOUNT,_DEBIT_AMOUNT,_REMAINING_AMOUNT)
        ON CONFLICT ( charge_id )
        DO UPDATE SET charge_amount = _CHARGE_AMOUNT,
        	discount_amount = _DISCOUNT_AMOUNT,
            	paid_amount = _PAID_AMOUNT,
            	debit_amount = _DEBIT_AMOUNT,
            	remaining_amount = _REMAINING_AMOUNT;

    RETURN NEW;

END;
$BODY$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_debts_on_charge ON _f_charges CASCADE;
DROP TRIGGER IF EXISTS trigger_update_debts_on_payment ON _f_payments CASCADE;
DROP TRIGGER IF EXISTS trigger_update_debts_on_discount ON _f_charge_discounts CASCADE;

CREATE TRIGGER trigger_update_debts_on_charge
	AFTER INSERT OR UPDATE
    	ON _f_charges
    	FOR EACH ROW
	EXECUTE PROCEDURE update_debts();

CREATE TRIGGER trigger_update_debts_on_payment
	AFTER INSERT OR UPDATE
    	ON _f_payments
    	FOR EACH ROW
	EXECUTE PROCEDURE update_debts();

CREATE TRIGGER trigger_update_debts_on_discount
	AFTER INSERT OR UPDATE
    	ON _f_charge_discounts
    	FOR EACH ROW
	EXECUTE PROCEDURE update_debts();
