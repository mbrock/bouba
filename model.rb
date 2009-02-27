
require 'rubygems'
require 'activerecord'

require 'pathname'
module Bouba
  Base = Pathname.new(File.expand_path(__FILE__)).dirname.to_s
end

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", 
                                        :database => Bouba::Base + "/library/library.sqlite")

class Album < ActiveRecord::Base
  has_many :tracks, :order => 'track ASC'
  has_and_belongs_to_many :artists, :uniq => true
end

class Artist < ActiveRecord::Base
  has_many :albums
  has_and_belongs_to_many :albums, :uniq => true
end

class Track < ActiveRecord::Base
  belongs_to :album
  belongs_to :artist
end
