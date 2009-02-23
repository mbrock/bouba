
require 'rubygems'
require 'amazon'
require 'amazon/aws/search'
require 'sqlite3'
require 'open-uri'

require 'pp'

DEV_TOKEN = '0Q5B7WX2NCVGPSFH4Z82'

class NilClass
  def method_missing (*whatever)
    nil
  end
end

def album_cover_fetch(artist, album)
  @request = Amazon::AWS::Search::Request.new(DEV_TOKEN)

  search = Amazon::AWS::ItemSearch.new( 'Music', { 'Keywords' => artist + ' ' + album })
  begin
    @response = @request.search(search, Amazon::AWS::ResponseGroup.new('Large'))
  rescue Amazon::AWS::Error::NoExactMatches
    return nil
  end

  products = @response.instance_variable_get('@item_search_response').to_h

  item = products['items'].item
  if item.respond_to? :image_sets
    url = item.image_sets.image_set.large_image.url.to_s
  else
    url = item.product.first.first.large_image.url.to_s
  end
  
  if url == ""
    return nil
  else
    return url
  end
end

$db = SQLite3::Database.new('library.sqlite')

$get_artist_stmt = 
  ('SELECT name FROM artists WHERE id = ' +
   '(SELECT artist_id FROM album_artist_relations ' +
   ' WHERE album_id = :id)')

$get_album_stmt =
  ('SELECT name FROM albums WHERE id = :id')

$insert_album_art =
  ('INSERT OR REPLACE INTO album_art (album_id, image) ' +
   'VALUES (:album_id, :image)')


$db.execute('SELECT albums.id AS id FROM albums') do |album_name_row|
#            'EXCEPT SELECT album_art.album_id ' +
#            'AS id FROM album_art') 
  album_id = *album_name_row

  artist_name = $db.get_first_value($get_artist_stmt, {:id => album_id})
  album_name = $db.get_first_value($get_album_stmt, {:id => album_id})

  next if artist_name == 'Unknown Artist'
  next if album_name  == 'Unknown Album'

  p [artist_name, album_name]
  url = album_cover_fetch(artist_name, album_name)

  if url != nil
    coverart = open(url).read
    $db.execute($insert_album_art, { :album_id => album_id,
                                     :image    => SQLite3::Blob.new(coverart) })
  end
end
