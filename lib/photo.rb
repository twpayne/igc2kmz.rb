require "rubygems"
require "exifr"
require "open-uri"

class Photo

  attr_reader :time

  def initialize(uri)
    @uri = uri.is_a?(URI) ? uri : URI.parse(uri)
    if @uri.is_a?(URI::Generic)
      File.open(@uri.to_s) do |io|
        @jpeg = EXIFR::JPEG.new(io)
      end
    else
      @uri.open do |io|
        case io.content_type.downcase
        when "image/jpeg", nil then @jpeg = EXIFR::JPEG.new(io)
        else raise "unsupported content type #{io.content_type}"
        end
      end
    end
    raise "no EXIF information" unless @jpeg.exif
    raise "no DateTimeOriginal tag" unless @jpeg.exif.date_time_original
    @time = Time.utc(*@jpeg.exif.date_time_original.to_a[0, 6].reverse)
  end

end
