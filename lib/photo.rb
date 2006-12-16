require "exifr"
require "open-uri"

class Photo

  def initialize(uri)
    @uri = uri.is_a?(URI) ? uri : URI.parse(uri)
    if @uri.scheme
      @uri.open do |io|
        raise unless io.content_type == "image/jpeg"
        @jpeg = EXIFR::JPEG.new(io)
      end
    else
      File.open(@uri.to_s) do |io|
        @jpeg = EXIFR::JPEG.new(io)
      end
    end
  end

end
