CREATE OR REPLACE FUNCTION update_visit_days()
RETURNS TRIGGER AS
$BODY$
declare
        _CHARGE_ID UUID;
    	_CLIENT_ID UUID;
        _CHARGE_IS_CANCELLED BOOL;
        _VISIT_NUMBER INTEGER;
        _VISIT_EXPIRATION_DATE DATE;
        _VISITS_USED INTEGER;
        _VISITS_REMAINING INTEGER;
BEGIN

	CASE
		WHEN TG_TABLE_NAME = '_f_charges'
                        THEN    _CHARGE_ID := NEW.id;
                                _CLIENT_ID := NEW.client_id;
		WHEN TG_TABLE_NAME = '_f_charges_cancelled' THEN
                        SELECT  _f_charges.client_id,NEW.charge_id
                        INTO    _CLIENT_ID,_CHARGE_ID
                        FROM    _f_charges
                        WHERE   _f_charges.id = NEW.charge_id;
		WHEN TG_TABLE_NAME = '_a_attendance' THEN
                        IF TG_OP IN ('DELETE','TRUNCATE') THEN
                                _CHARGE_ID := OLD.visits_charge_id;
                                _CLIENT_ID := OLD.client_id;
                        ELSE
                                _CHARGE_ID := NEW.visits_charge_id;
                                _CLIENT_ID := NEW.client_id;
                        END IF;
	END CASE;

        -- RAISE EXCEPTION 'charge_id : %, client_id : %', _CHARGE_ID, _CLIENT_ID;

	SELECT _f_charges.visit_number,_f_charges.visits_expiration_date
	INTO _VISIT_NUMBER,_VISIT_EXPIRATION_DATE
	FROM _f_charges
        JOIN _i_inventory_sales ON (_i_inventory_sales.id = _f_charges.item_sale_id)
        JOIN _i_items ON (_i_items.id = _i_inventory_sales.item_id)
        JOIN _f_client_memberships ON ( _f_client_memberships.client_id = _f_charges.client_id )
        JOIN _f_memberships ON ( _f_memberships.id = _f_client_memberships.membership_id )
	WHERE _f_charges.id = _CHARGE_ID
        AND _f_memberships.is_visits_membership = TRUE
        AND _i_items.type_code = 'VISITS';

        IF _VISIT_NUMBER IS NULL OR _VISIT_EXPIRATION_DATE IS NULL
        THEN RETURN NULL;
        END IF;

        SELECT COUNT(*)
        INTO _VISITS_USED
        FROM (
                SELECT DISTINCT date
                FROM  _a_attendance
                WHERE client_id = _CLIENT_ID
                AND   visits_charge_id = _CHARGE_ID
                AND   cancelled = FALSE
        ) AS SS;

   	_VISITS_USED = COALESCE(_VISITS_USED,0);

        SELECT CASE WHEN COUNT(*) > 0 THEN TRUE ELSE FALSE END
        INTO _CHARGE_IS_CANCELLED
        FROM _f_charges_cancelled
        WHERE charge_id = _CHARGE_ID;

        IF _CHARGE_IS_CANCELLED
        THEN _VISITS_USED = 0; _VISIT_EXPIRATION_DATE = NOW() - INTERVAL '1 DAY';
        END IF;

        -- RAISE EXCEPTION 'charge_id : %, client_id : %, vis-num : %, vis-expdate : %, vis-used %, cancelled %',
        --      _CHARGE_ID, _CLIENT_ID, _VISIT_NUMBER, _VISIT_EXPIRATION_DATE, _VISITS_USED, _CHARGE_IS_CANCELLED;

	INSERT INTO _g_client_visits
    	VALUES (_CLIENT_ID,_CHARGE_ID,_VISIT_NUMBER,_VISIT_EXPIRATION_DATE,_VISITS_USED,( _VISIT_NUMBER - _VISITS_USED ))
        ON CONFLICT ( client_id, charge_id )
        DO UPDATE SET
		visit_number = _VISIT_NUMBER,
        	visits_expiration_date = _VISIT_EXPIRATION_DATE,
        	visits_used = _VISITS_USED,
            	visits_remaining = ( _VISIT_NUMBER - _VISITS_USED );

        RETURN NEW;

END;
$BODY$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_visit_days_on_charge ON _f_charges CASCADE;
DROP TRIGGER IF EXISTS trigger_update_visit_days_on_charge_cancel ON _f_charges_cancelled CASCADE;
DROP TRIGGER IF EXISTS trigger_update_visit_days_on_attendance ON _a_attendance CASCADE;

CREATE TRIGGER trigger_update_visit_days_on_charge
	AFTER INSERT OR UPDATE
    	ON _f_charges
    	FOR EACH ROW
	EXECUTE PROCEDURE update_visit_days();

CREATE TRIGGER trigger_update_visit_days_on_charge_cancel
	AFTER INSERT OR UPDATE
    	ON _f_charges_cancelled
    	FOR EACH ROW
	EXECUTE PROCEDURE update_visit_days();

CREATE TRIGGER trigger_update_visit_days_on_attendance
	AFTER INSERT OR UPDATE OR DELETE
    	ON _a_attendance
    	FOR EACH ROW
	EXECUTE PROCEDURE update_visit_days();
