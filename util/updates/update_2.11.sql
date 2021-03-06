

CREATE TYPE notification_ntype AS ENUM ('pm', 'dbdel', 'listdel', 'dbedit', 'announce');
CREATE TYPE notification_ltype AS ENUM ('v', 'r', 'p', 't');

CREATE TABLE notifications (
  id serial PRIMARY KEY NOT NULL,
  uid integer NOT NULL REFERENCES users (id),
  date timestamptz NOT NULL DEFAULT NOW(),
  read timestamptz,
  ntype notification_ntype NOT NULL,
  ltype notification_ltype NOT NULL,
  iid integer NOT NULL,
  subid integer,
  c_title text NOT NULL,
  c_byuser integer REFERENCES users (id)
);

-- convert the "unread messages" count into notifications
INSERT INTO notifications (uid, date, ntype, ltype, iid, subid, c_title, c_byuser)
  SELECT tb.iid, tp.date, 'pm', 't', t.id, tp.num, t.title, tp.uid
    FROM threads_boards tb
    JOIN threads t ON t.id = tb.tid
    JOIN threads_posts tp ON tp.tid = t.id AND tp.num = COALESCE(tb.lastread, 1)
    WHERE tb.type = 'u' AND NOT t.hidden AND (tb.lastread IS NULL OR t.count <> tb.lastread);

-- ...and drop the now unused lastread column
ALTER TABLE threads_boards DROP COLUMN lastread;

ALTER TABLE users ADD COLUMN notify_dbedit boolean NOT NULL DEFAULT true;
ALTER TABLE users ADD COLUMN notify_announce boolean NOT NULL DEFAULT false;
UPDATE users SET notify_dbedit = false WHERE id IN(0,1);


-- languages -> ENUM
CREATE TYPE language AS ENUM('cs', 'da', 'de', 'en', 'es', 'fi', 'fr', 'hu', 'it', 'ja', 'ko', 'nl', 'no', 'pl', 'pt-pt', 'pt-br', 'ru', 'sk', 'sv', 'tr', 'vi', 'zh');
ALTER TABLE producers_rev ALTER COLUMN lang DROP DEFAULT;
ALTER TABLE producers_rev ALTER COLUMN lang TYPE language USING CASE lang WHEN 'pt' THEN 'pt-pt' ELSE lang::language END;
ALTER TABLE producers_rev ALTER COLUMN lang SET DEFAULT 'ja';
ALTER TABLE releases_lang ALTER COLUMN lang TYPE language USING CASE lang WHEN 'pt' THEN 'pt-pt' ELSE lang::language END;
-- c_languages is an now array of languages, rather than a serialized string
ALTER TABLE vn ALTER COLUMN c_languages DROP DEFAULT;
ALTER TABLE vn ALTER COLUMN c_languages TYPE language[] USING '{}';
ALTER TABLE vn ALTER COLUMN c_languages SET DEFAULT '{}';



ALTER TABLE changes ADD COLUMN ihid boolean NOT NULL DEFAULT FALSE;
ALTER TABLE changes ADD COLUMN ilock boolean NOT NULL DEFAULT FALSE;

\i util/sql/func.sql

SELECT COUNT(*) FROM (SELECT update_vncache(id) FROM vn) x;

CREATE TRIGGER hidlock_update             BEFORE UPDATE           ON vn            FOR EACH ROW EXECUTE PROCEDURE update_hidlock();
CREATE TRIGGER hidlock_update             BEFORE UPDATE           ON producers     FOR EACH ROW EXECUTE PROCEDURE update_hidlock();
CREATE TRIGGER hidlock_update             BEFORE UPDATE           ON releases      FOR EACH ROW EXECUTE PROCEDURE update_hidlock();


CREATE OR REPLACE FUNCTION tmp_edit_hidlock(t text, iid integer) RETURNS void AS $$
BEGIN
  IF t = 'v' THEN
    PERFORM edit_vn_init(latest) FROM vn WHERE id = iid;
    IF EXISTS(SELECT 1 FROM vn WHERE id = iid AND hidden) THEN
      UPDATE edit_revision SET ihid = true, ip = '0.0.0.0', requester = 1,
        comments = 'This visual novel was deleted before the update to VNDB 2.11, no reason specified.';
    ELSE
      UPDATE edit_revision SET ilock = true, ip = '0.0.0.0', requester = 1,
        comments = 'This visual novel was locked before the update to VNDB 2.11, no reason specified.';
    END IF;
    PERFORM edit_vn_commit();
  ELSIF t = 'r' THEN
    PERFORM edit_release_init(latest) FROM releases WHERE id = iid;
    IF EXISTS(SELECT 1 FROM releases WHERE id = iid AND hidden) THEN
      UPDATE edit_revision SET ihid = true, ip = '0.0.0.0', requester = 1,
        comments = 'This release was deleted before the update to VNDB 2.11, no reason specified.';
    ELSE
      UPDATE edit_revision SET ilock = true, ip = '0.0.0.0', requester = 1,
        comments = 'This release was locked before the update to VNDB 2.11, no reason specified.';
    END IF;
    PERFORM edit_release_commit();
  ELSE
    PERFORM edit_producer_init(latest) FROM producers WHERE id = iid;
    IF EXISTS(SELECT 1 FROM producers WHERE id = iid AND hidden) THEN
      UPDATE edit_revision SET ihid = true, ip = '0.0.0.0', requester = 1,
        comments = 'This producer was deleted before the update to VNDB 2.11, no reason specified.';
    ELSE
      UPDATE edit_revision SET ilock = true, ip = '0.0.0.0', requester = 1,
        comments = 'This producer was locked before the update to VNDB 2.11, no reason specified.';
    END IF;
    PERFORM edit_producer_commit();
  END IF;
END;
$$ LANGUAGE plpgsql;

      SELECT 'v', COUNT(*) FROM (SELECT tmp_edit_hidlock('v', id) FROM vn WHERE (hidden OR locked)) x
UNION SELECT 'r', COUNT(*) FROM (SELECT tmp_edit_hidlock('r', id) FROM releases WHERE hidden OR locked) x
UNION SELECT 'p', COUNT(*) FROM (SELECT tmp_edit_hidlock('p', id) FROM producers WHERE hidden OR locked) x;
DROP FUNCTION tmp_edit_hidlock(text, integer);


-- keep track of when a session is last used
ALTER TABLE sessions ADD COLUMN lastused timestamptz NOT NULL DEFAULT NOW();
ALTER TABLE sessions RENAME COLUMN expiration TO added;
UPDATE sessions SET added = added - '1 year'::interval;
ALTER TABLE sessions ALTER COLUMN added SET DEFAULT NOW();


CREATE TRIGGER notify_pm                  AFTER  INSERT           ON threads_posts FOR EACH ROW EXECUTE PROCEDURE notify_pm();
-- make sure to add these triggers AFTER performing the batch edit above
CREATE TRIGGER notify_dbdel               AFTER  UPDATE           ON vn            FOR EACH ROW EXECUTE PROCEDURE notify_dbdel();
CREATE TRIGGER notify_dbdel               AFTER  UPDATE           ON producers     FOR EACH ROW EXECUTE PROCEDURE notify_dbdel();
CREATE TRIGGER notify_dbdel               AFTER  UPDATE           ON releases      FOR EACH ROW EXECUTE PROCEDURE notify_dbdel();
CREATE TRIGGER notify_listdel             AFTER  UPDATE           ON vn            FOR EACH ROW EXECUTE PROCEDURE notify_listdel();
CREATE TRIGGER notify_listdel             AFTER  UPDATE           ON releases      FOR EACH ROW EXECUTE PROCEDURE notify_listdel();
CREATE TRIGGER notify_dbedit              AFTER  UPDATE           ON vn            FOR EACH ROW EXECUTE PROCEDURE notify_dbedit();
CREATE TRIGGER notify_dbedit              AFTER  UPDATE           ON producers     FOR EACH ROW EXECUTE PROCEDURE notify_dbedit();
CREATE TRIGGER notify_dbedit              AFTER  UPDATE           ON releases      FOR EACH ROW EXECUTE PROCEDURE notify_dbedit();
CREATE TRIGGER notify_announce            AFTER  INSERT           ON threads_posts FOR EACH ROW EXECUTE PROCEDURE notify_announce();

