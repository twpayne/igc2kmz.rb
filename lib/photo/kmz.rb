require "photo"
require "kmz"

class Photo

  def to_kmz(hints, options = {})
    point = KML::Point.new(:coordinates => hints.igc.fix_at(@time + hints.photo_tz_offset - hints.tz_offset), :altitudeMode => :absolute)
    name = File.basename(@uri.path)
    src = @uri.scheme ? @uri : "images/photos/#{name}"
    description = KML::Description.new(KML::CData.new("<img alt=\"#{name}\" src=\"#{src}\" width=\"#{@jpeg.width}\" height=\"#{@jpeg.height}\" />"))
    placemark = KML::Placemark.new(point, KML::Name.new(name), description, KML::Snippet.new, options)
    files = {}
    files["images/#{name}"] = File.open(@uri.to_s) unless @uri.scheme
    KMZ.new(placemark, :files => files)
  end

end
