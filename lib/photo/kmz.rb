require "photo"
require "kmz"

class Photo

  def to_kmz(hints, options = {})
    if @jpeg.exif.date_time_original
      time = Time.utc(*@jpeg.exif.date_time_original.to_a[0, 6].reverse) + hints.photo_tz_offset - hints.tz_offset
      coordinate = hints.igc.fix_at(time)
    else
      coordinate = hints.igc.fixes[0]
    end
    point = KML::Point.new(:coordinates => [coordinate], :altitudeMode => :absolute)
    name = File.basename(@uri.path)
    src = @uri.scheme ? @uri : "images/#{name}"
    description = KML::Description.new(KML::CData.new("<img alt=\"#{name}\" src=\"#{src}\" />"))
    placemark = KML::Placemark.new(point, KML::Name.new(name), description, KML::Snippet.new, KML::StyleUrl.new(hints.stock.photo_style.url), options)
    files = {}
    files["images/#{name}"] = File.open(@uri.to_s) unless @uri.scheme
    KMZ.new(placemark, :files => files)
  end

end
