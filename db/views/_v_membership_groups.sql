DROP VIEW _v_membership_groups CASCADE;

CREATE VIEW _v_membership_groups AS (

	WITH GROUP_DETAILS AS (
		SELECT	_f_membership_groups.id,_f_membership_groups.membership_id,
			_f_membership_groups.responsible_client_id,
			_f_membership_group_dependents.dependent_client_id
		FROM 	_f_membership_groups
		JOIN 	_f_membership_group_dependents ON (
			_f_membership_group_dependents.membership_group_id = _f_membership_groups.id
		)
	)
	SELECT 	_f_client_memberships.client_id,_f_client_memberships.membership_id,
		_f_client_memberships.renewal_day,GROUP_DETAILS.id AS GROUP_ID,GROUP_DETAILS.responsible_client_id,
		CASE WHEN _f_client_memberships.client_id = GROUP_DETAILS.responsible_client_id THEN TRUE ELSE FALSE END AS IS_RESPONSIBLE
	FROM 	_f_client_memberships
	JOIN 	_f_memberships ON (_f_memberships.id = _f_client_memberships.membership_id)
	LEFT JOIN group_details ON (
		group_details.membership_id = _f_client_memberships.membership_id
		AND (
	        	group_details.responsible_client_id = _f_client_memberships.client_id
	            	OR
			group_details.dependent_client_id = _f_client_memberships.client_id
		)
	)
	WHERE _f_memberships.type_code = 'G'

);
