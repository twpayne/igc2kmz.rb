require "photo"
require "kmz"

class Photo

  def to_kmz(hints, options = {})
    point = KML::Point.new(:coordinates => hints.igc.fix_at(@time + hints.photo_tz_offset - hints.tz_offset), :altitudeMode => hints.altitude_mode)
    name = File.basename(@uri.path)
    src = @uri.is_a?(URI::Generic) ? "images/photos/#{name}" : @uri.to_s
    description = KML::Description.new(KML::CData.new("<img alt=\"#{name.to_xml}\" src=\"#{src.to_xml}\" width=\"#{@jpeg.width}\" height=\"#{@jpeg.height}\" />"))
    placemark = KML::Placemark.new(point, KML::Name.new(name.sub(/\.jpe?g/i, "").to_xml), description, KML::Snippet.new, options)
    files = {}
    files[src] = File.open(@uri.to_s) if @uri.is_a?(URI::Generic)
    KMZ.new(placemark, :files => files)
  end

end
