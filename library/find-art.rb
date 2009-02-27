
require 'rubygems'
require 'amazon'
require 'amazon/aws/search'
require 'sqlite3'
require 'levenshtein'
require 'cgi'

require 'open-uri'
require 'pp'

require "../model"

DEV_TOKEN = '0Q5B7WX2NCVGPSFH4Z82'

class NilClass
  def method_missing (*whatever)
    nil
  end
end

def album_cover_fetch(artist, album)
  @request = Amazon::AWS::Search::Request.new(DEV_TOKEN)

  search = Amazon::AWS::ItemSearch.new( 'Music', { 'Artist' => artist })
  begin
    @response = @request.search(search,
                   Amazon::AWS::ResponseGroup.new('Images, ItemAttributes'), 2)
  rescue Amazon::AWS::Error::NoExactMatches
    return nil
  end

  albums = {}
  single_page = @response.instance_variables.length > 0
  responses = (single_page ? [@response] : @response)

  responses.each do |response|
    (single_page ?
     [response.item_search_response] :
      response.item_search_response).each do |key, value|
      key.items.each do |key, value|
        key.item.each do |key, value|
          if key.large_image.url.to_s != ""
            albums[CGI::unescapeHTML(key.item_attributes.title.to_s)] =
              key.large_image.url.to_s
          end
        end
      end
    end
  end

  titles =
   albums.keys.sort_by {|x| Levenshtein.distance(x.downcase, album.downcase)}

  albums[titles.first]
end

Album.find(:all).each do |album|
  next if album.artwork?
  next if album.artists == ['Unknown Artist']
  next if album.name  == 'Unknown Album'
  
  p [album.artists.first.name, album.name]
  url = album_cover_fetch(album.artists.first.name, album.name)

  if url != nil
    puts "Found art: #{url}"
    album.artwork = open(url).read
    album.save!
  end
end
