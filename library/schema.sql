
CREATE TABLE artists
  (id   INTEGER PRIMARY KEY,
   name TEXT UNIQUE);

CREATE TABLE albums
  (id      INTEGER PRIMARY KEY,
   name    TEXT UNIQUE,
   artwork BLOB);

CREATE TABLE tracks
  (id        INTEGER PRIMARY KEY,
   name      TEXT,
   album_id  INTEGER,
   artist_id INTEGER,
   track     INTEGER,
   filename  TEXT    UNIQUE);

CREATE TABLE albums_artists
  (album_id  INTEGER,
   artist_id INTEGER);


