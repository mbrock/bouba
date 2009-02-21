
CREATE TABLE artists
  (id   INTEGER PRIMARY KEY,
   name TEXT UNIQUE);

CREATE TABLE albums
  (id   INTEGER PRIMARY KEY,
   name TEXT UNIQUE);

CREATE TABLE tracks
  (id        INTEGER PRIMARY KEY,
   name      TEXT,
   album_id  INTEGER,
   artist_id INTEGER,
   track     INTEGER,
   filename  TEXT);

CREATE TABLE album_artist_relations
  (album_id  INTEGER PRIMARY KEY,
   artist_id INTEGER KEY);
