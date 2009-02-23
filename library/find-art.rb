
require 'rubygems'
require 'amazon'
require 'amazon/aws/search'
require 'sqlite3'

require 'pp'

DEV_TOKEN = '0Q5B7WX2NCVGPSFH4Z82'

def album_cover_fetch(artist, album)
  @request = Amazon::AWS::Search::Request.new(DEV_TOKEN)
#  begin
  search = Amazon::AWS::ItemSearch.new( 'Music', { 'Artist' => artist, 'Album' => album })
  @response = @request.search(search, Amazon::AWS::ResponseGroup.new('Large'))

  products = @response.instance_variable_get('@item_search_response').to_h

#  p products.keys

#  url = products['items'].to_h['item'].product[0].first.to_h['large_image'].instance_variable_get('@url').first.instance_variable_get('@__val__')

  url = ""
  products['items'].to_h['item'].product.each do |item|
      item.each do |it|
      url = it.to_h['large_image'].instance_variable_get('@url').first.instance_variable_get('@__val__')
      end
  end
  url
#  url
  # p products['items'].to_h['total_results'].instance_variable_get('@__val__')
  # p products['items'].to_h['total_pages'].instance_variable_get('@__val__')

  # rescue
  #   # there was no exact match for artist
  #   products = []
  # end
  
  # if products.empty?
  #   return nil
  # end
  
  # products.each do |p|
  #   if !album.nil? && !album.blank? && matches?(album, p.product_name)
  #     return p.image_url_medium
  #   end
  # end
  
  # product = product_matches.sort { |a,b| 
  #   a.sales_rank <=> b.sales_rank
  # }.first unless product_matches.empty?
  
  # product.image_url_medium unless product.nil?
end

$db = SQLite3::Database.new('library.sqlite')

$get_artist_stmt = 
  ('SELECT name FROM artists WHERE id = ' +
   '(SELECT artist_id FROM album_artist_relations ' +
   ' WHERE album_id = :id)')

$get_album_stmt =
  ('SELECT name FROM albums WHERE id = :id')

# albumlist = $db.execute('SELECT albums.id AS id FROM albums ' +
#                         'EXCEPT SELECT album_art.album_id ' +
#                         'AAS id FROM album_art')

# album_id = albumlist.first
# artist_name = $db.get_first_value($get_artist_stmt, {:id => album_id})
# album_name = $db.get_first_value($get_album_stmt, {:id => album_id})

# p [artist_name, album_name]
# p album_cover_fetch(artist_name, album_name)

# end

$db.execute('SELECT albums.id AS id FROM albums ' +
            'EXCEPT SELECT album_art.album_id ' +
            'AS id FROM album_art') do |album_name_row|
  album_id = *album_name_row

  artist_name = $db.get_first_value($get_artist_stmt, {:id => album_id})
  album_name = $db.get_first_value($get_album_stmt, {:id => album_id})

  next if artist_name == 'Unknown Artist'
  next if album_name  == 'Unknown Album'

  p [artist_name, album_name]
  p album_cover_fetch(artist_name, album_name)
end
