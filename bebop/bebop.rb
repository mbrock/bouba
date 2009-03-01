
require 'rubygems'

require 'mongrel'
require 'sqlite3'
require 'haml'
require 'pp'
require 'cgi'
require 'levenshtein'

require '../model'

class Bebop < Mongrel::HttpHandler
  attr_reader :library

  def initialize
    Haml::Helpers.init_haml_helpers
  end

  def haml (name)
    Haml::Engine.new(File.read('haml/' + name + '.haml'))
  end

  def render_haml (name, params = {})
    haml(name).render(self, params)
  end

  def respond_haml (name, params = {}, code = 200, content_type = 'text/html')
    @response.start code do |head, out|
      head["Content-Type"] = content_type
      out.write(render_haml(name, params))
    end
  end

  def search (search_string)
    artists = Artist.find(:all).sort_by do |x|
      Levenshtein.distance(x.name.downcase, search_string.downcase)
    end
    
    albums = Album.find(:all).sort_by do |x|
      Levenshtein.distance(x.name.downcase, search_string.downcase)
    end

    respond_haml('search', 
                 :search_string => CGI::unescape(search_string),
                 :artists => artists.take(10),
                 :albums  => albums.take(10))
  end

  def serve_art (album_id)
    @response.start(200) do |head, out|
      head["Content-Type"] = "image/jpeg"
      out.write(Album.find_by_id(album_id).artwork)
    end
  end

  def serve_mp3 (track_id)
    @response.send_file(Track.find_by_id(track_id).filename)
  end

  def serve_artist (artist_name)
    artist = Artist.find_by_name(CGI::unescape(artist_name))
    if artist.nil?
      respond_haml('artist-not-found', { :artist => CGI::unescape(artist_name) }, 404)
    else
      respond_haml('artist', :artist => artist)
    end
  end

  def serve_album (album_name)
    album = Album.find_by_name(CGI::unescape(album_name))
    if album.nil?
      respond_haml('album-not-found', { :album => CGI::unescape(album_name) }, 404)
    else
      respond_haml('album', :album => album)
    end
  end

  def serve_list
    respond_haml 'all-albums'
  end

  def search_page
    respond_haml 'search-page'
  end

  def art_url_for (album_id)
    if Album.find_by_id(album_id).artwork?
      "/art/#{album_id}"
    else
      '/img/unknown-album.jpg'
    end
  end

  def render_albums (albums)
    albums.map do |album|
      render_haml '_album', :album => album
    end.join("\n")
  end
  
  def process (request, response)
    @response = response
    
    case request.params['REQUEST_METHOD']
    when 'POST'
      if request.body.read =~ /^search=(.+)$/
        search $1
      else
        # no search terms, tell the user that he is a moron...
      end
    else
      case request.params['REQUEST_PATH']
      when /^\/search$/
        search_page
      when /^\/player$/
        respond_haml 'player'
      when /^\/search\/(.+)$/
        search $1
      when /^\/mp3\/(\d+)$/
        serve_mp3 $1.to_i
      when /^\/art\/(\d+)$/
        serve_art $1.to_i
      when /^\/artist\/(.+)$/
        serve_artist $1
      when /^\/album\/(.+)$/
        serve_album $1
      else
        respond_haml 'index'
      end
    end
  end
end

h = Mongrel::HttpServer.new("0.0.0.0", "4000")
h.register("/", Bebop.new)
h.register("/css", Mongrel::DirHandler.new("./css"))
h.register("/img", Mongrel::DirHandler.new("./img"))
h.register("/script", Mongrel::DirHandler.new("./script"))
h.register("/swf", Mongrel::DirHandler.new("./swf"))
h.run.join
