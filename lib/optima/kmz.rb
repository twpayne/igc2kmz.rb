require "kmz"
require "optima"

class Optimum

  def to_kmz(hints, folder_options = {})
    name = (@multiplier.zero? ? '%s (%.1fkm)' : '%s (%.1fkm, %.2f points)') % [@flight_type, distance / 1000.0, score]
    folder = KML::Folder.hide_children(KML::Name.new(name), folder_options)
    if @circuit
      coordinates = @fixes[1...-1]
      coordinates << @fixes[1] if @fixes.length > 4
    else
      coordinates = @fixes
    end
    line_string = KML::LineString.new(:coordinates => coordinates, :tessellate => 1)
    placemark = KML::Placemark.new(line_string, :styleUrl => hints.stock.distance_style.url)
    folder.add(placemark)
    @fixes.each_with_index do |fix, index|
      folder.add(fix.to_kml(hints, @names[index], nil, :styleUrl => hints.stock.distance_style.url))
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
