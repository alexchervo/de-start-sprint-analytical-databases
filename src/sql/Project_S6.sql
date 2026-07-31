DROP TABLE VT260714C69C17__STAGING.group_log;

CREATE TABLE VT260714C69C17__STAGING.group_log (
    id IDENTITY(1,1) PRIMARY KEY,
    group_id int,
    user_id int,
    user_id_from int,
    event varchar(6),
    datetime timestamp(0)
)
ORDER BY group_id, user_id
PARTITION BY datetime::date
GROUP BY calendar_hierarchy_day(datetime::date, 3, 2);

CREATE TABLE VT260714C69C17__DWH.l_user_group_activity
(
hk_l_user_group_activity bigint PRIMARY KEY,
hk_user_id bigint NOT NULL CONSTRAINT fk_l_user_group_activity_h_users REFERENCES VT260714C69C17__DWH.h_users (hk_user_id),
hk_group_id bigint NOT NULL CONSTRAINT fk_l_user_group_activity_h_groups REFERENCES VT260714C69C17__DWH.h_groups (hk_group_id),
load_dt datetime,
load_src varchar(20)
)
ORDER BY load_dt
SEGMENTED BY hk_l_user_group_activity ALL nodes
PARTITION BY load_dt::date
GROUP BY calendar_hierarchy_day(load_dt::date, 3, 2);

INSERT INTO VT260714C69C17__DWH.l_user_group_activity(
	hk_l_user_group_activity, 
	hk_user_id,
	hk_group_id,
	load_dt,
	load_src)
SELECT DISTINCT 
	hash(hu.hk_user_id, hg.hk_group_id),
	hu.hk_user_id,
	hg.hk_group_id,
	now() AS load_dt,
	's3' AS load_src
FROM VT260714C69C17__STAGING.group_log g
LEFT JOIN VT260714C69C17__DWH.h_users hu ON g.user_id = hu.user_id
LEFT JOIN VT260714C69C17__DWH.h_groups hg ON g.group_id = hg.group_id
WHERE hash(hu.hk_user_id, hg.hk_group_id) 
NOT IN 
	(SELECT hk_l_user_group_activity 
		FROM VT260714C69C17__DWH.l_user_group_activity luga);

DROP TABLE VT260714C69C17__DWH.s_auth_history;

CREATE TABLE VT260714C69C17__DWH.s_auth_history(
	hk_l_user_group_activity bigint NOT NULL CONSTRAINT fk_s_auth_history_l_user_group_activity REFERENCES VT260714C69C17__DWH.l_user_group_activity (hk_l_user_group_activity),
	user_id_from integer,
	event varchar(6),
	event_dt datetime,
	load_dt datetime,
	load_src varchar(20)
)
ORDER BY load_dt
SEGMENTED BY hk_l_user_group_activity ALL nodes
PARTITION BY load_dt::date
GROUP BY calendar_hierarchy_day(load_dt::date, 3, 2);

INSERT INTO VT260714C69C17__DWH.s_auth_history(
	hk_l_user_group_activity, 
	user_id_from,
	event,
	event_dt,
	load_dt,
	load_src)
SELECT DISTINCT 
	luga.hk_l_user_group_activity,
	gl.user_id_from,
	gl.event,
	gl.datetime,
	now() AS load_dt,
	's3' AS load_src
from VT260714C69C17__STAGING.group_log gl
LEFT join VT260714C69C17__DWH.h_groups hg ON gl.group_id = hg.group_id
left join VT260714C69C17__DWH.h_users hu ON gl.user_id = hu.user_id
left join VT260714C69C17__DWH.l_user_group_activity luga 
ON hg.hk_group_id = luga.hk_group_id 
AND hu.hk_user_id = luga.hk_user_id;

WITH user_group_messages AS (
SELECT
	lgd.hk_group_id,
	COUNT(DISTINCT sdi.message_from) AS cnt_users_in_group_with_messages
FROM VT260714C69C17__DWH.l_groups_dialogs lgd 
LEFT JOIN VT260714C69C17__DWH.s_dialog_info sdi 
ON lgd.hk_message_id = sdi.hk_message_id
GROUP BY lgd.hk_group_id
)
SELECT 
	hk_group_id,
    cnt_users_in_group_with_messages
FROM user_group_messages
ORDER BY cnt_users_in_group_with_messages
LIMIT 10;

SELECT
	hg.hk_group_id,
	count(*) AS cnt_added_users
FROM VT260714C69C17__DWH.h_groups hg 
LEFT JOIN VT260714C69C17__DWH.l_user_group_activity luga 
ON hg.hk_group_id = luga.hk_group_id
LEFT JOIN VT260714C69C17__DWH.s_auth_history sah 
ON luga.hk_l_user_group_activity = sah.hk_l_user_group_activity
WHERE sah.event = 'add'
GROUP BY hg.hk_group_id, hg.registration_dt
ORDER BY hg.registration_dt ASC
LIMIT 10;

with user_group_log as (
	SELECT
		hg.hk_group_id,
		count(*) AS cnt_added_users
	FROM VT260714C69C17__DWH.h_groups hg 
	LEFT JOIN VT260714C69C17__DWH.l_user_group_activity luga 
	ON hg.hk_group_id = luga.hk_group_id
	LEFT JOIN VT260714C69C17__DWH.s_auth_history sah 
	ON luga.hk_l_user_group_activity = sah.hk_l_user_group_activity
	WHERE sah.event = 'add'
	GROUP BY hg.hk_group_id, hg.registration_dt
	ORDER BY hg.registration_dt ASC
)
select 
	hk_group_id,
	cnt_added_users
from user_group_log
order by cnt_added_users
limit 10;

WITH 
user_group_log as (
	SELECT
		hg.hk_group_id,
		count(*) AS cnt_added_users
	FROM VT260714C69C17__DWH.h_groups hg 
	LEFT JOIN VT260714C69C17__DWH.l_user_group_activity luga 
	ON hg.hk_group_id = luga.hk_group_id
	LEFT JOIN VT260714C69C17__DWH.s_auth_history sah 
	ON luga.hk_l_user_group_activity = sah.hk_l_user_group_activity
	WHERE sah.event = 'add'
	GROUP BY hg.hk_group_id, hg.registration_dt
	ORDER BY hg.registration_dt ASC
	LIMIT 10
),
user_group_messages as (
	SELECT
		lgd.hk_group_id,
		COUNT(DISTINCT sdi.message_from) AS cnt_users_in_group_with_messages
	FROM VT260714C69C17__DWH.l_groups_dialogs lgd 
	LEFT JOIN VT260714C69C17__DWH.s_dialog_info sdi 
	ON lgd.hk_message_id = sdi.hk_message_id
	GROUP BY lgd.hk_group_id
	)
SELECT 
	ugl.hk_group_id,
	ugl.cnt_added_users,
	ugm.cnt_users_in_group_with_messages, 
	ugm.cnt_users_in_group_with_messages / ugl.cnt_added_users AS conversion
FROM user_group_log ugl
LEFT JOIN user_group_messages ugm 
ON ugl.hk_group_id = ugm.hk_group_id
ORDER BY ugm.cnt_users_in_group_with_messages / ugl.cnt_added_users DESC;