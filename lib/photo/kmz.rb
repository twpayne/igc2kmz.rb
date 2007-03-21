require "RMagick"
require "photo"
require "kmz"

class Photo

  def to_kmz(hints, options = {})
    point = KML::Point.new
    point.coordinates = hints.igc.fix_at(@time + hints.photo_tz_offset - hints.tz_offset)
    point.altitude_mode = hints.altitude_mode
    name = File.basename(@uri.is_a?(URI) ? @uri.path : @uri)
    src = @uri.is_a?(URI) ? @uri.to_s : "images/photos/#{name}"
    files = {}
    width, height = @jpeg.width, @jpeg.height
    if width > hints.photo_max_width or height > hints.photo_max_height
      scale = [hints.photo_max_width.to_f / width, hints.photo_max_height.to_f / height].min
      if @uri.is_a?(URI)
        width = (scale * width).round.constrain(1, 4096)
        height = (scale * height).round.constrain(1, 4096)
      else
        image = Magick::Image.read(@uri.to_s).first.scale!(scale)
        width, height = image.columns, image.rows
        files[src] = image.to_blob
      end
    else
      files[src] = File.open(@uri.to_s) unless @uri.is_a?(URI)
    end
    placemark = KML::Placemark.new(point, options)
    placemark.name = name.sub(/\.jpe?g/i, "").to_xml
    placemark.description = KML::CData.new("<img alt=\"#{name.to_xml}\" src=\"#{src.to_xml}\" width=\"#{width}\" height=\"#{height}\" />")
    placemark.snippet = nil
    KMZ.new(placemark, :files => files)
  end

end
