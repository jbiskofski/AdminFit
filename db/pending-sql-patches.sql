begin;

CREATE INDEX _g_users_idx2 ON public._g_users
  USING btree ((create_date_time::DATE));

CREATE INDEX _g_users_idx3 ON public._g_users
  USING btree ((deactivation_date_time::DATE));

CREATE INDEX _g_deleted_users_idx1 ON public._g_deleted_users
  USING btree ((date_time::DATE));

commit;
