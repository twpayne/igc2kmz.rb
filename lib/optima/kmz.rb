require "kmz"
require "optima"

class Optimum

  def to_kmz(hints, folder_options = {})
    name = (@multiplier.zero? ? "%s (%.1fkm)" : "%s (%.1fkm, %.1f points)") % [@flight_type, distance / 1000.0, score]
    folder = KML::Folder.hide_children(KML::Name.new(name), folder_options)
    if @circuit
      coords = @fixes[1...-1]
      coords << @fixes[1] if @fixes.length > 4
    else
      coords = @fixes
    end
    coords.each_cons(2) do |coord0, coord1|
      line_string = KML::LineString.new(:coordinates => [coord0, coord1], :tessellate => 1)
      point = KML::Point.new(:coordinates => coord0.halfway_to(coord1))
      multi_geometry = KML::MultiGeometry.new(line_string, point)
      name = "%.1fkm" % (coord0.distance_to(coord1) / 1000)
      placemark = KML::Placemark.new(multi_geometry, :name => name, :styleUrl => hints.stock.optima_style.url)
      folder.add(placemark)
    end
    @fixes.each_with_index do |fix, index|
      folder.add(fix.to_kml(hints, @names[index], {:altitudeMode => :absolute, :extrude => 1}, :styleUrl => hints.stock.optima_style.url))
    end
    KMZ.new(folder)
  end

end

class Optima

  def to_kmz(hints)
    kmz = KMZ.new(KML::Folder.radio(KML::Name.new("Cross country"), :open => 0))
    kmz.merge(hints.stock.invisible_none_folder)
    best_optimum = @optima.sort_by(&:score)[-1]
    @optima.each do |optimum|
      kmz.merge(optimum.to_kmz(hints, :open => 0, :visibility => optimum == best_optimum ? 1 : 0))
    end
    kmz
  end

end
