#!/usr/bin/env ruby
# Copyright (C) 2006, 2007  Daniel Brockman

# Author: Daniel Brockman <daniel@brockman.se>
# URL: http://www.brockman.se/software/bongo/
# Created: April 24, 2006
# Updated: May 15, 2007

# This file is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License, or (at your option) any later version.
#
# This file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with GNU Emacs; if not, write to the Free
# Software Foundation, 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301, USA.
#
# To run this program, you need Ruby-taglib, available at
# <http://www.hakubi.us/ruby-taglib/>, and Mahoro, available at
# <http://mahoro.rubyforge.org/>.

require "fileutils"
require "find"
require "taglib"
require "sqlite3"

if ARGV.empty? or ["-?", "-h", "-help", "--help"].include? ARGV.first
  puts "Usage: #$0 DIRECTORIES..."
  puts "
This program recursively scans DIRECTORIES for media files in formats
that support embedded file tags, such as Ogg and MP3."
  exit
end

COLUMNS = ENV['COLUMNS'] || 80

class NotEnoughData < RuntimeError ; end

class String
  def blank? ; !self[/\S/] end
  def trim ; sub(/^\s+|\s+$/, "") end
end

def singleton (&body)
  object = Object.new
  object.extend(Module.new(&body))
  object.send :initialize
  return object
end

status_line = singleton do
  attr_reader :width
  def initialize
    @width = 0
  end

  def remaining_width
    COLUMNS - @width
  end
  
  def clear
    print "\b" * COLUMNS
    print " " * COLUMNS
    print "\b" * COLUMNS
    @width = 0
  end

  def update
    clear ; yield ; flush
  end

  def flush
    $stdout.flush
  end
  
  def << string
    count = [remaining_width, string.size].min
    print string[0 ... count]
    @width += count
  end
end

n_total_files = 0
print "Counting files..." ; $stdout.flush
Find.find(*ARGV) { |x| n_total_files += 1 if FileTest.file? x }
puts " #{n_total_files}."

def warn_skip (file_name, message)
  puts "Warning: Skipping file `#{file_name}': #{message}"
end

n_completed_files = 0           # This counts all files.
n_processed_files = 0           # This only counts recognized files.

$db = SQLite3::Database.new('library.sqlite')

$create_artist_stmt = 
  $db.prepare('INSERT OR IGNORE INTO artists (name) VALUES (:name)')
$create_album_stmt  = 
  $db.prepare('INSERT OR IGNORE INTO albums  (name) VALUES (:name)')
$create_track_stmt  = 
  $db.prepare('INSERT OR IGNORE INTO tracks '+
              '  (name, artist_id, album_id, track, filename) ' +
              'SELECT :name, artists.id, albums.id, :track, :filename ' +
              'FROM albums, artists ' +
              'WHERE albums.name = :album AND artists.name = :artist')
$create_album_artist_relation_stmt =
  $db.prepare('INSERT OR IGNORE INTO album_artist_relations (album_id, artist_id) ' +
             'SELECT albums.id, artists.id FROM albums, artists ' +
             'WHERE albums.name = :album AND artists.name = :artist')

def create_artist (name)
  $create_artist_stmt.bind_param(:name, name)
  $create_artist_stmt.execute!
end

def create_album (name)
  $create_album_stmt.bind_param(:name, name)
  $create_album_stmt.execute!
end

def create_album_artist_relation (album, artist)
  $create_album_artist_relation_stmt.bind_params({ :album => album,
                                                   :artist  => artist })
  $create_album_artist_relation_stmt.execute!
end

$unknown_artist = 'Unknown Artist'
$unknown_album = 'Unknown Album'
$unknown_title = 'Unknown Title'

create_artist $unknown_artist
create_album $unknown_album

def register_track (data)
  data[:artist_name] = $unknown_artist unless data[:artist_name]
  data[:album_title] = $unknown_album  unless data[:album_title]
  data[:track_title] = $unknown_title  unless data[:track_title]

  artist, album = data[:artist_name], data[:album_title]

  create_artist artist
  create_album album
  create_album_artist_relation album, artist

  $create_track_stmt.bind_params({ :artist => artist,
                                   :album  => album,
                                   :name   => data[:track_title],
                                   :track  => data[:track_index] })
  $create_track_stmt.execute!
end

Find.find *ARGV do |file_name|
  if FileTest.directory? file_name
    status_line.update do
      percent_done = n_completed_files * 100.0 / n_total_files
      status_line << "[%.2f%%] " % percent_done
      count = status_line.remaining_width - "Processing `'...".size
      if file_name.size > count
        file_name_tail = "[...]" + file_name[-count + 5 .. -1]
      else
        file_name_tail = file_name
      end
      status_line << "Processing `#{file_name_tail}'..."
    end
  elsif FileTest.file? file_name
    next if [".jpg", ".png", ".gif"].include? \
      File.extname(file_name).downcase
    begin 
      file = TagLib::File.new(file_name)
      n_processed_files += 1
      data = { :artist_name => file.artist,
               :album_year  => file.year.to_s,
               :album_title => file.album,
               :track_index => "#{0 if file.track < 10}#{file.track}",
               :track_title => file.title }

      for key, value in data do
        if value.blank?
          data.delete key
        else
          data[key] = value.trim
        end
      end

      register_track data

    rescue TagLib::BadFile
      puts ; warn_skip file_name, "Unrecognized file format."
    rescue TagLib::BadTag
      puts ; warn_skip file_name, "Unreadable tag."
    rescue NotEnoughData
      puts ; warn_skip file_name, "Not enough track data " +
        "(need at least the track title)."
    rescue Interrupt
      puts ; puts "Interrupted." ; exit(1)
    rescue Exception
      puts ; raise
    ensure
      file.close unless file == nil
    end

    n_completed_files += 1
  end
end

status_line.update do
  status_line << "[100%] Processing `#{ARGV.last}'..."
end

puts ; puts "Processed #{n_processed_files} media files."

## Local Variables:
## time-stamp-format: "%:b %:d, %:y"
## time-stamp-start: "# Updated: "
## time-stamp-end: "$"
## End:
