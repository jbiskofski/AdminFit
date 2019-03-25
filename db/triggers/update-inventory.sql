CREATE OR REPLACE FUNCTION update_available_inventory()
RETURNS TRIGGER AS
$BODY$
declare
	_ITEM_ID UUID;
	_ADD INTEGER;
	_SELL INTEGER;
	_OUT INTEGER;
	_AVAILABLE INTEGER;
BEGIN

        IF TG_OP = 'INSERT' THEN
                _ITEM_ID := NEW.item_id;
        ELSE
                _ITEM_ID := OLD.item_id;
        END IF;

	SELECT	SUM(_i_inventory_add.count)
	INTO 	_ADD
	FROM	_i_inventory_add
	JOIN 	_i_items ON (_i_items.id = _i_inventory_add.item_id)
	WHERE 	_i_items.use_inventory = TRUE
	AND 	_i_inventory_add.item_id = _ITEM_ID
	GROUP BY _i_inventory_add.item_id;

	SELECT	SUM(_i_inventory_out.count)
	INTO 	_OUT
	FROM	_i_inventory_out
	JOIN 	_i_items ON (_i_items.id = _i_inventory_out.item_id)
	AND 	_i_inventory_out.item_id = _ITEM_ID
	GROUP BY _i_inventory_out.item_id;

	SELECT	COUNT(*)
	INTO 	_SELL
	FROM	_i_inventory_sales
	JOIN 	_i_items ON (_i_items.id = _i_inventory_sales.item_id)
	AND 	_i_inventory_sales.item_id = _ITEM_ID
	GROUP BY _i_inventory_sales.item_id;

   	_ADD = COALESCE(_ADD,0);
   	_OUT = COALESCE(_OUT,0);
   	_SELL = COALESCE(_SELL,0);
	_AVAILABLE = (_ADD - _OUT - _SELL);

	IF _AVAILABLE < 0 THEN _AVAILABLE = 0; END IF;

	INSERT INTO _i_inventory_totals
    	VALUES (_ITEM_ID,_ADD,_OUT,_SELL,_AVAILABLE)
        ON CONFLICT ( item_id )
        DO UPDATE SET add = _ADD, out = _OUT, sell = _SELL, available = _AVAILABLE;

    RETURN NEW;

END;
$BODY$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_inventory_on_add   ON _i_inventory_add CASCADE;
DROP TRIGGER IF EXISTS trigger_update_inventory_on_out   ON _i_inventory_out CASCADE;
DROP TRIGGER IF EXISTS trigger_update_inventory_on_sales ON _i_inventory_sales CASCADE;

CREATE TRIGGER trigger_update_inventory_on_add
	AFTER INSERT OR UPDATE
    	ON _i_inventory_add
    	FOR EACH ROW
	EXECUTE PROCEDURE update_available_inventory();

CREATE TRIGGER trigger_update_inventory_on_out
	AFTER INSERT OR UPDATE
    	ON _i_inventory_out
    	FOR EACH ROW
	EXECUTE PROCEDURE update_available_inventory();

CREATE TRIGGER trigger_update_inventory_on_sales
	AFTER INSERT OR UPDATE
    	ON _i_inventory_sales
    	FOR EACH ROW
	EXECUTE PROCEDURE update_available_inventory();
