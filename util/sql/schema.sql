-- Convention for database items with version control:
--
--   CREATE TABLE items ( -- dbentry_type=x
--     id        SERIAL PRIMARY KEY,
--     locked    boolean NOT NULL DEFAULT FALSE,
--     hidden    boolean NOT NULL DEFAULT FALSE,
--     -- item-specific columns here
--   );
--   CREATE TABLE items_hist ( -- History of the 'items' table
--     chid integer NOT NULL,  -- references changes.id
--     -- item-specific columns here
--   );
--
-- The '-- dbentry_type=x' comment is required, and is used by
-- util/sqleditfunc.pl to generate the correct editing functions.  The history
-- of the 'locked' and 'hidden' flags is recorded in the changes table.  It's
-- possible for 'items' to have more item-specific columns than 'items_hist'.
-- Some columns are caches or otherwise autogenerated, and do not need to be
-- versioned.
--
-- item-related tables work roughly the same:
--
--   CREATE TABLE items_field (
--     id integer,  -- references items.id
--     -- field-specific columns here
--   );
--   CREATE TABLE items_field_hist ( -- History of the 'items_field' table
--     chid integer, -- references changes.id
--     -- field-specific columns here
--   );
--
-- The changes and *_hist tables contain all the data. In a sense, the other
-- tables related to the item are just a cache/view into the latest versions.
-- All modifications to the item tables has to go through the edit_* functions
-- in func.sql, these are also responsible for keeping things synchronized.
--
-- Note: Every CREATE TABLE clause and each column should be on a separate
-- line. This file is parsed by util/sqleditfunc.pl, and it doesn't implement a
-- full SQL query parser.


-- affiliate_links
CREATE TABLE affiliate_links (
  id SERIAL PRIMARY KEY,
  rid integer NOT NULL,
  hidden boolean NOT NULL DEFAULT false,
  priority smallint NOT NULL DEFAULT 0,
  affiliate smallint NOT NULL DEFAULT 0,
  url varchar NOT NULL,
  version varchar NOT NULL DEFAULT '',
  lastfetch timestamptz,
  price varchar NOT NULL DEFAULT '',
  data varchar NOT NULL DEFAULT ''
);

-- anime
CREATE TABLE anime (
  id integer NOT NULL PRIMARY KEY,
  year smallint,
  ann_id integer,
  nfo_id varchar(200),
  type anime_type,
  title_romaji varchar(250),
  title_kanji varchar(250),
  lastfetch timestamptz
);

-- changes
CREATE TABLE changes (
  id         SERIAL PRIMARY KEY,
  type       dbentry_type NOT NULL,
  itemid     integer NOT NULL,
  rev        integer NOT NULL DEFAULT 1,
  added      timestamptz NOT NULL DEFAULT NOW(),
  requester  integer NOT NULL DEFAULT 0,
  ip         inet NOT NULL DEFAULT '0.0.0.0',
  comments   text NOT NULL DEFAULT '',
  ihid       boolean NOT NULL DEFAULT FALSE,
  ilock      boolean NOT NULL DEFAULT FALSE
);

-- chars
CREATE TABLE chars ( -- dbentry_type=c
  id         SERIAL PRIMARY KEY,
  locked     boolean NOT NULL DEFAULT FALSE,
  hidden     boolean NOT NULL DEFAULT FALSE,
  name       varchar(250) NOT NULL DEFAULT '',
  original   varchar(250) NOT NULL DEFAULT '',
  alias      varchar(500) NOT NULL DEFAULT '',
  image      integer  NOT NULL DEFAULT 0,
  "desc"     text     NOT NULL DEFAULT '',
  gender     gender NOT NULL DEFAULT 'unknown',
  s_bust     smallint NOT NULL DEFAULT 0,
  s_waist    smallint NOT NULL DEFAULT 0,
  s_hip      smallint NOT NULL DEFAULT 0,
  b_month    smallint NOT NULL DEFAULT 0,
  b_day      smallint NOT NULL DEFAULT 0,
  height     smallint NOT NULL DEFAULT 0,
  weight     smallint NOT NULL DEFAULT 0,
  bloodt     blood_type NOT NULL DEFAULT 'unknown',
  main       integer, -- chars.id
  main_spoil smallint NOT NULL DEFAULT 0
);

-- chars_hist
CREATE TABLE chars_hist (
  chid       integer  NOT NULL PRIMARY KEY,
  name       varchar(250) NOT NULL DEFAULT '',
  original   varchar(250) NOT NULL DEFAULT '',
  alias      varchar(500) NOT NULL DEFAULT '',
  image      integer  NOT NULL DEFAULT 0,
  "desc"     text     NOT NULL DEFAULT '',
  gender     gender NOT NULL DEFAULT 'unknown',
  s_bust     smallint NOT NULL DEFAULT 0,
  s_waist    smallint NOT NULL DEFAULT 0,
  s_hip      smallint NOT NULL DEFAULT 0,
  b_month    smallint NOT NULL DEFAULT 0,
  b_day      smallint NOT NULL DEFAULT 0,
  height     smallint NOT NULL DEFAULT 0,
  weight     smallint NOT NULL DEFAULT 0,
  bloodt     blood_type NOT NULL DEFAULT 'unknown',
  main       integer, -- chars.id
  main_spoil smallint NOT NULL DEFAULT 0
);

-- chars_traits
CREATE TABLE chars_traits (
  id         integer NOT NULL,
  tid        integer NOT NULL, -- traits.id
  spoil      smallint NOT NULL DEFAULT 0,
  PRIMARY KEY(id, tid)
);

-- chars_traits_hist
CREATE TABLE chars_traits_hist (
  chid       integer NOT NULL,
  tid        integer NOT NULL, -- traits.id
  spoil      smallint NOT NULL DEFAULT 0,
  PRIMARY KEY(chid, tid)
);

-- chars_vns
CREATE TABLE chars_vns (
  id         integer NOT NULL,
  vid        integer NOT NULL, -- vn.id
  rid        integer NULL, -- releases.id
  spoil      smallint NOT NULL DEFAULT 0,
  role       char_role NOT NULL DEFAULT 'main'
);

-- chars_vns_hist
CREATE TABLE chars_vns_hist (
  chid       integer NOT NULL,
  vid        integer NOT NULL, -- vn.id
  rid        integer NULL, -- releases.id
  spoil      smallint NOT NULL DEFAULT 0,
  role       char_role NOT NULL DEFAULT 'main'
);

-- login_throttle
CREATE TABLE login_throttle (
  ip inet NOT NULL PRIMARY KEY,
  timeout timestamptz NOT NULL
);

-- notifications
CREATE TABLE notifications (
  id serial PRIMARY KEY,
  uid integer NOT NULL,
  date timestamptz NOT NULL DEFAULT NOW(),
  read timestamptz,
  ntype notification_ntype NOT NULL,
  ltype notification_ltype NOT NULL,
  iid integer NOT NULL,
  subid integer,
  c_title text NOT NULL,
  c_byuser integer NOT NULL DEFAULT 0
);

-- producers
CREATE TABLE producers ( -- dbentry_type=p
  id         SERIAL PRIMARY KEY,
  locked     boolean NOT NULL DEFAULT FALSE,
  hidden     boolean NOT NULL DEFAULT FALSE,
  type       producer_type NOT NULL DEFAULT 'co',
  name       varchar(200) NOT NULL DEFAULT '',
  original   varchar(200) NOT NULL DEFAULT '',
  website    varchar(250) NOT NULL DEFAULT '',
  lang       language NOT NULL DEFAULT 'ja',
  "desc"     text NOT NULL DEFAULT '',
  alias      varchar(500) NOT NULL DEFAULT '',
  l_wp       varchar(150),
  rgraph     integer -- relgraphs.id
);

-- producers_hist
CREATE TABLE producers_hist (
  chid       integer NOT NULL PRIMARY KEY,
  type       producer_type NOT NULL DEFAULT 'co',
  name       varchar(200) NOT NULL DEFAULT '',
  original   varchar(200) NOT NULL DEFAULT '',
  website    varchar(250) NOT NULL DEFAULT '',
  lang       language NOT NULL DEFAULT 'ja',
  "desc"     text NOT NULL DEFAULT '',
  alias      varchar(500) NOT NULL DEFAULT '',
  l_wp       varchar(150)
);

-- producers_relations
CREATE TABLE producers_relations (
  id         integer NOT NULL,
  pid        integer NOT NULL, -- producers.id
  relation   producer_relation NOT NULL,
  PRIMARY KEY(id, pid)
);

-- producers_relations_hist
CREATE TABLE producers_relations_hist (
  chid       integer NOT NULL,
  pid        integer NOT NULL, -- producers.id
  relation   producer_relation NOT NULL,
  PRIMARY KEY(chid, pid)
);

-- quotes
CREATE TABLE quotes (
  vid integer NOT NULL,
  quote varchar(250) NOT NULL,
  PRIMARY KEY(vid, quote)
);

-- releases
CREATE TABLE releases ( -- dbentry_type=r
  id         SERIAL PRIMARY KEY,
  locked     boolean NOT NULL DEFAULT FALSE,
  hidden     boolean NOT NULL DEFAULT FALSE,
  title      varchar(250) NOT NULL DEFAULT '',
  original   varchar(250) NOT NULL DEFAULT '',
  type       release_type NOT NULL DEFAULT 'complete',
  website    varchar(250) NOT NULL DEFAULT '',
  catalog    varchar(50) NOT NULL DEFAULT '',
  gtin       bigint NOT NULL DEFAULT 0,
  released   integer NOT NULL DEFAULT 0,
  notes      text NOT NULL DEFAULT '',
  minage     smallint,
  patch      boolean NOT NULL DEFAULT FALSE,
  freeware   boolean NOT NULL DEFAULT FALSE,
  doujin     boolean NOT NULL DEFAULT FALSE,
  resolution smallint NOT NULL DEFAULT 0,
  voiced     smallint NOT NULL DEFAULT 0,
  ani_story  smallint NOT NULL DEFAULT 0,
  ani_ero    smallint NOT NULL DEFAULT 0
);

-- releases_hist
CREATE TABLE releases_hist (
  chid       integer NOT NULL PRIMARY KEY,
  title      varchar(250) NOT NULL DEFAULT '',
  original   varchar(250) NOT NULL DEFAULT '',
  type       release_type NOT NULL DEFAULT 'complete',
  website    varchar(250) NOT NULL DEFAULT '',
  catalog    varchar(50) NOT NULL DEFAULT '',
  gtin       bigint NOT NULL DEFAULT 0,
  released   integer NOT NULL DEFAULT 0,
  notes      text NOT NULL DEFAULT '',
  minage     smallint,
  patch      boolean NOT NULL DEFAULT FALSE,
  freeware   boolean NOT NULL DEFAULT FALSE,
  doujin     boolean NOT NULL DEFAULT FALSE,
  resolution smallint NOT NULL DEFAULT 0,
  voiced     smallint NOT NULL DEFAULT 0,
  ani_story  smallint NOT NULL DEFAULT 0,
  ani_ero    smallint NOT NULL DEFAULT 0
);

-- releases_lang
CREATE TABLE releases_lang (
  id         integer NOT NULL,
  lang       language NOT NULL,
  PRIMARY KEY(id, lang)
);

-- releases_lang_hist
CREATE TABLE releases_lang_hist (
  chid       integer NOT NULL,
  lang       language NOT NULL,
  PRIMARY KEY(chid, lang)
);

-- releases_media
CREATE TABLE releases_media (
  id         integer NOT NULL,
  medium     medium NOT NULL,
  qty        smallint NOT NULL DEFAULT 1,
  PRIMARY KEY(id, medium, qty)
);

-- releases_media_hist
CREATE TABLE releases_media_hist (
  chid       integer NOT NULL,
  medium     medium NOT NULL,
  qty        smallint NOT NULL DEFAULT 1,
  PRIMARY KEY(chid, medium, qty)
);

-- releases_platforms
CREATE TABLE releases_platforms (
  id         integer NOT NULL,
  platform   platform NOT NULL,
  PRIMARY KEY(id, platform)
);

-- releases_platforms_hist
CREATE TABLE releases_platforms_hist (
  chid       integer NOT NULL,
  platform   platform NOT NULL,
  PRIMARY KEY(chid, platform)
);

-- releases_producers
CREATE TABLE releases_producers (
  id         integer NOT NULL,
  pid        integer NOT NULL, -- producers.id
  developer  boolean NOT NULL DEFAULT FALSE,
  publisher  boolean NOT NULL DEFAULT TRUE,
  CHECK(developer OR publisher),
  PRIMARY KEY(id, pid)
);

-- releases_producers_hist
CREATE TABLE releases_producers_hist (
  chid       integer NOT NULL,
  pid        integer NOT NULL, -- producers.id
  developer  boolean NOT NULL DEFAULT FALSE,
  publisher  boolean NOT NULL DEFAULT TRUE,
  CHECK(developer OR publisher),
  PRIMARY KEY(chid, pid)
);

-- releases_vn
CREATE TABLE releases_vn (
  id         integer NOT NULL,
  vid        integer NOT NULL, -- vn.id
  PRIMARY KEY(id, vid)
);

-- releases_vn_hist
CREATE TABLE releases_vn_hist (
  chid       integer NOT NULL,
  vid        integer NOT NULL, -- vn.id
  PRIMARY KEY(chid, vid)
);

-- relgraphs
CREATE TABLE relgraphs (
  id SERIAL PRIMARY KEY,
  svg xml NOT NULL
);

-- rlists
CREATE TABLE rlists (
  uid integer NOT NULL DEFAULT 0,
  rid integer NOT NULL DEFAULT 0,
  status smallint NOT NULL DEFAULT 0,
  added timestamptz NOT NULL DEFAULT NOW(),
  PRIMARY KEY(uid, rid)
);

-- screenshots
CREATE TABLE screenshots (
  id SERIAL NOT NULL PRIMARY KEY,
  width smallint NOT NULL DEFAULT 0,
  height smallint NOT NULL DEFAULT 0
);

-- sessions
CREATE TABLE sessions (
  uid integer NOT NULL,
  token bytea NOT NULL,
  added timestamptz NOT NULL DEFAULT NOW(),
  lastused timestamptz NOT NULL DEFAULT NOW(),
  PRIMARY KEY (uid, token)
);

-- staff
CREATE TABLE staff ( -- dbentry_type=s
  id         SERIAL PRIMARY KEY,
  locked     boolean NOT NULL DEFAULT FALSE,
  hidden     boolean NOT NULL DEFAULT FALSE,
  aid        integer NOT NULL DEFAULT 0, -- staff_alias.aid
  gender     gender NOT NULL DEFAULT 'unknown',
  lang       language NOT NULL DEFAULT 'ja',
  "desc"     text NOT NULL DEFAULT '',
  l_wp       varchar(150) NOT NULL DEFAULT '',
  l_site     varchar(250) NOT NULL DEFAULT '',
  l_twitter  varchar(16) NOT NULL DEFAULT '',
  l_anidb    integer
);

-- staff_hist
CREATE TABLE staff_hist (
  chid       integer NOT NULL PRIMARY KEY,
  aid        integer NOT NULL DEFAULT 0, -- Can't refer to staff_alias.id, because the alias might have been deleted
  gender     gender NOT NULL DEFAULT 'unknown',
  lang       language NOT NULL DEFAULT 'ja',
  "desc"     text NOT NULL DEFAULT '',
  l_wp       varchar(150) NOT NULL DEFAULT '',
  l_site     varchar(250) NOT NULL DEFAULT '',
  l_twitter  varchar(16) NOT NULL DEFAULT '',
  l_anidb    integer
);

-- staff_alias
CREATE TABLE staff_alias (
  id         integer NOT NULL,
  aid        SERIAL PRIMARY KEY, -- Globally unique ID of this alias
  name       varchar(200) NOT NULL DEFAULT '',
  original   varchar(200) NOT NULL DEFAULT ''
);

-- staff_alias_hist
CREATE TABLE staff_alias_hist (
  chid       integer NOT NULL,
  aid        integer NOT NULL, -- staff_alias.aid, but can't reference it because the alias may have been deleted
  name       varchar(200) NOT NULL DEFAULT '',
  original   varchar(200) NOT NULL DEFAULT '',
  PRIMARY KEY(chid, aid)
);

-- stats_cache
CREATE TABLE stats_cache (
  section varchar(25) NOT NULL PRIMARY KEY,
  count integer NOT NULL DEFAULT 0
);

-- tags
CREATE TABLE tags (
  id SERIAL NOT NULL PRIMARY KEY,
  name varchar(250) NOT NULL UNIQUE,
  description text NOT NULL DEFAULT '',
  meta boolean NOT NULL DEFAULT FALSE,
  added timestamptz NOT NULL DEFAULT NOW(),
  state smallint NOT NULL DEFAULT 0,
  c_items integer NOT NULL DEFAULT 0,
  addedby integer NOT NULL DEFAULT 0,
  cat tag_category NOT NULL DEFAULT 'cont'
);

-- tags_aliases
CREATE TABLE tags_aliases (
  alias varchar(250) NOT NULL PRIMARY KEY,
  tag integer NOT NULL
);

-- tags_parents
CREATE TABLE tags_parents (
  tag integer NOT NULL,
  parent integer NOT NULL,
  PRIMARY KEY(tag, parent)
);

-- tags_vn
CREATE TABLE tags_vn (
  tag integer NOT NULL,
  vid integer NOT NULL,
  uid integer NOT NULL,
  vote smallint NOT NULL DEFAULT 3 CHECK (vote >= -3 AND vote <= 3 AND vote <> 0),
  spoiler smallint CHECK(spoiler >= 0 AND spoiler <= 2),
  date timestamptz NOT NULL DEFAULT NOW(),
  ignore boolean NOT NULL DEFAULT false,
  PRIMARY KEY(tag, vid, uid)
);

-- tags_vn_inherit
CREATE TABLE tags_vn_inherit (
  tag integer NOT NULL,
  vid integer NOT NULL,
  users integer NOT NULL,
  rating real NOT NULL,
  spoiler smallint NOT NULL
);

-- threads
CREATE TABLE threads (
  id SERIAL NOT NULL PRIMARY KEY,
  title varchar(50) NOT NULL DEFAULT '',
  locked boolean NOT NULL DEFAULT FALSE,
  hidden boolean NOT NULL DEFAULT FALSE,
  count smallint NOT NULL DEFAULT 0,
  poll_question varchar(100),
  poll_max_options smallint NOT NULL DEFAULT 1,
  poll_preview boolean NOT NULL DEFAULT FALSE,
  poll_recast boolean NOT NULL DEFAULT FALSE
);

-- threads_poll_options
CREATE TABLE threads_poll_options (
  id     SERIAL PRIMARY KEY,
  tid    integer NOT NULL,
  option varchar(100) NOT NULL
);

-- threads_poll_votes
CREATE TABLE threads_poll_votes (
  tid   integer NOT NULL,
  uid   integer NOT NULL,
  optid integer NOT NULL,
  PRIMARY KEY (tid, uid, optid)
);

-- threads_posts
CREATE TABLE threads_posts (
  tid integer NOT NULL DEFAULT 0,
  num smallint NOT NULL DEFAULT 0,
  uid integer NOT NULL DEFAULT 0,
  date timestamptz NOT NULL DEFAULT NOW(),
  edited timestamptz,
  msg text NOT NULL DEFAULT '',
  hidden boolean NOT NULL DEFAULT FALSE,
  PRIMARY KEY(tid, num)
);

-- threads_boards
CREATE TABLE threads_boards (
  tid integer NOT NULL DEFAULT 0,
  type board_type NOT NULL,
  iid integer NOT NULL DEFAULT 0,
  PRIMARY KEY(tid, type, iid)
);

-- traits
CREATE TABLE traits (
  id SERIAL PRIMARY KEY,
  name varchar(250) NOT NULL,
  alias varchar(500) NOT NULL DEFAULT '',
  description text NOT NULL DEFAULT '',
  meta boolean NOT NULL DEFAULT false,
  added timestamptz NOT NULL DEFAULT NOW(),
  state smallint NOT NULL DEFAULT 0,
  addedby integer NOT NULL DEFAULT 0,
  "group" integer,
  "order" smallint NOT NULL DEFAULT 0,
  sexual boolean NOT NULL DEFAULT false,
  c_items integer NOT NULL DEFAULT 0
);

-- traits_chars
-- This table is a cache for the data in chars_traits and includes child traits
-- into parent traits. In order to improve performance, there are no foreign
-- key constraints on this table.
CREATE TABLE traits_chars (
  cid integer NOT NULL,  -- chars (id)
  tid integer NOT NULL,  -- traits (id)
  spoil smallint NOT NULL DEFAULT 0,
  PRIMARY KEY(cid, tid)
);

-- traits_parents
CREATE TABLE traits_parents (
  trait integer NOT NULL,
  parent integer NOT NULL,
  PRIMARY KEY(trait, parent)
);

-- users
CREATE TABLE users (
  id SERIAL NOT NULL PRIMARY KEY,
  username varchar(20) NOT NULL UNIQUE,
  mail varchar(100) NOT NULL,
  perm smallint NOT NULL DEFAULT 1+4+16,
  -- Interpretation of the passwd column depends on its length:
  -- * 20 bytes: Password reset token (sha1(lower_hex(20 bytes of random data)))
  -- * 46 bytes: scrypt password
  --   4 bytes: N (big endian)
  --   1 byte: r
  --   1 byte: p
  --   8 bytes: salt
  --   32 bytes: scrypt(passwd, global_salt + salt, N, r, p, 32)
  -- * Anything else: Invalid, account disabled.
  passwd bytea NOT NULL DEFAULT '',
  registered timestamptz NOT NULL DEFAULT NOW(),
  c_votes integer NOT NULL DEFAULT 0,
  c_changes integer NOT NULL DEFAULT 0,
  ip inet NOT NULL DEFAULT '0.0.0.0',
  c_tags integer NOT NULL DEFAULT 0,
  ign_votes boolean NOT NULL DEFAULT FALSE,
  email_confirmed boolean NOT NULL DEFAULT FALSE
);

-- users_prefs
CREATE TABLE users_prefs (
  uid integer NOT NULL,
  key prefs_key NOT NULL,
  value varchar NOT NULL,
  PRIMARY KEY(uid, key)
);

-- vn
CREATE TABLE vn ( -- dbentry_type=v
  id         SERIAL PRIMARY KEY,
  locked     boolean NOT NULL DEFAULT FALSE,
  hidden     boolean NOT NULL DEFAULT FALSE,
  title      varchar(250) NOT NULL DEFAULT '',
  original   varchar(250) NOT NULL DEFAULT '',
  alias      varchar(500) NOT NULL DEFAULT '',
  length     smallint NOT NULL DEFAULT 0,
  img_nsfw   boolean NOT NULL DEFAULT FALSE,
  image      integer NOT NULL DEFAULT 0,
  "desc"     text NOT NULL DEFAULT '',
  l_wp       varchar(150) NOT NULL DEFAULT '',
  l_encubed  varchar(100) NOT NULL DEFAULT '',
  l_renai    varchar(100) NOT NULL DEFAULT '',
  rgraph     integer, -- relgraphs.id
  c_released integer NOT NULL DEFAULT 0,
  c_languages language[] NOT NULL DEFAULT '{}',
  c_olang    language[] NOT NULL DEFAULT '{}',
  c_platforms platform[] NOT NULL DEFAULT '{}',
  c_popularity real,
  c_rating   real,
  c_votecount integer NOT NULL DEFAULT 0,
  c_search   text
);

-- vn_hist
CREATE TABLE vn_hist (
  chid       integer NOT NULL PRIMARY KEY,
  title      varchar(250) NOT NULL DEFAULT '',
  original   varchar(250) NOT NULL DEFAULT '',
  alias      varchar(500) NOT NULL DEFAULT '',
  length     smallint NOT NULL DEFAULT 0,
  img_nsfw   boolean NOT NULL DEFAULT FALSE,
  image      integer NOT NULL DEFAULT 0,
  "desc"     text NOT NULL DEFAULT '',
  l_wp       varchar(150) NOT NULL DEFAULT '',
  l_encubed  varchar(100) NOT NULL DEFAULT '',
  l_renai    varchar(100) NOT NULL DEFAULT ''
);

-- vn_anime
CREATE TABLE vn_anime (
  id         integer NOT NULL,
  aid        integer NOT NULL, -- anime.id
  PRIMARY KEY(id, aid)
);

-- vn_anime_hist
CREATE TABLE vn_anime_hist (
  chid       integer NOT NULL,
  aid        integer NOT NULL, -- anime.id
  PRIMARY KEY(chid, aid)
);

-- vn_relations
CREATE TABLE vn_relations (
  id         integer NOT NULL,
  vid        integer NOT NULL, -- vn.id
  relation   vn_relation NOT NULL,
  official   boolean NOT NULL DEFAULT TRUE,
  PRIMARY KEY(id, vid)
);

-- vn_relations_hist
CREATE TABLE vn_relations_hist (
  chid       integer NOT NULL,
  vid        integer NOT NULL, -- vn.id
  relation   vn_relation NOT NULL,
  official   boolean NOT NULL DEFAULT TRUE,
  PRIMARY KEY(chid, vid)
);

-- vn_screenshots
CREATE TABLE vn_screenshots (
  id         integer NOT NULL,
  scr        integer NOT NULL, -- screenshots.id
  rid        integer,          -- releases.id (only NULL for old revisions, nowadays not allowed anymore)
  nsfw       boolean NOT NULL DEFAULT FALSE,
  PRIMARY KEY(id, scr)
);

-- vn_screenshots_hist
CREATE TABLE vn_screenshots_hist (
  chid       integer NOT NULL,
  scr        integer NOT NULL,
  rid        integer,
  nsfw       boolean NOT NULL DEFAULT FALSE,
  PRIMARY KEY(chid, scr)
);

-- vn_seiyuu
CREATE TABLE vn_seiyuu (
  id         integer NOT NULL,
  aid        integer NOT NULL, -- staff_alias.aid
  cid        integer NOT NULL, -- chars.id
  note       varchar(250) NOT NULL DEFAULT '',
  PRIMARY KEY (id, aid, cid)
);

-- vn_seiyuu_hist
CREATE TABLE vn_seiyuu_hist (
  chid       integer NOT NULL,
  aid        integer NOT NULL, -- staff_alias.aid, but can't reference it because the alias may have been deleted
  cid        integer NOT NULL, -- chars.id
  note       varchar(250) NOT NULL DEFAULT '',
  PRIMARY KEY (chid, aid, cid)
);

-- vn_staff
CREATE TABLE vn_staff (
  id         integer NOT NULL,
  aid        integer NOT NULL, -- staff_alias.aid
  role       credit_type NOT NULL DEFAULT 'staff',
  note       varchar(250) NOT NULL DEFAULT '',
  PRIMARY KEY (id, aid, role)
);

-- vn_staff_hist
CREATE TABLE vn_staff_hist (
  chid       integer NOT NULL,
  aid        integer NOT NULL, -- See note at vn_seiyuu_hist.aid
  role       credit_type NOT NULL DEFAULT 'staff',
  note       varchar(250) NOT NULL DEFAULT '',
  PRIMARY KEY (chid, aid, role)
);

-- vnlists
CREATE TABLE vnlists (
  uid integer NOT NULL,
  vid integer NOT NULL,
  status smallint NOT NULL DEFAULT 0,
  added TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  notes varchar NOT NULL DEFAULT '',
  PRIMARY KEY(uid, vid)
);

-- votes
CREATE TABLE votes (
  vid integer NOT NULL DEFAULT 0,
  uid integer NOT NULL DEFAULT 0,
  vote integer NOT NULL DEFAULT 0,
  date timestamptz NOT NULL DEFAULT NOW(),
  PRIMARY KEY(vid, uid)
);

-- wlists
CREATE TABLE wlists (
  uid integer NOT NULL DEFAULT 0,
  vid integer NOT NULL DEFAULT 0,
  wstat smallint NOT NULL DEFAULT 0,
  added timestamptz NOT NULL DEFAULT NOW(),
  PRIMARY KEY(uid, vid)
);
