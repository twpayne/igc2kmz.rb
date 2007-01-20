require "photo"
require "kmz"

class Photo

  def to_kmz(hints, options = {})
    point = KML::Point.new(:coordinates => hints.igc.fix_at(@time + hints.photo_tz_offset - hints.tz_offset), :altitudeMode => hints.altitude_mode)
    name = File.basename(@uri.path)
    src = @uri.scheme ? @uri : "images/photos/#{name}"
    description = KML::Description.new(KML::CData.new("<img alt=\"#{name.to_xml}\" src=\"#{src.to_xml}\" width=\"#{@jpeg.width}\" height=\"#{@jpeg.height}\" />"))
    placemark = KML::Placemark.new(point, KML::Name.new(name.to_kml), description, KML::Snippet.new, options)
    files = {}
    files["images/#{name}"] = File.open(@uri.to_s) unless @uri.scheme
    KMZ.new(placemark, :files => files)
  end

end
