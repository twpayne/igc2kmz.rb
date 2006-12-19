require "kmz"
require "optima"

class Optimum

  def to_kmz(hints, folder_options = {})
    name = (@multiplier.zero? ? "%s (%.1fkm)" : "%s (%.1fkm, %.1f points)") % [@flight_type, distance / 1000.0, score]
    rows = []
    total = distance
    if @circuit
      if @fixes.length == 4
        rows << ["#{@names[1]} - #{@names[2]}", "%.1fkm" % (@fixes[1].distance_to(@fixes[2]) / 1000.0)]
        rows << ["#{@names[2]} - #{@names[1]}", "%.1fkm" % (@fixes[2].distance_to(@fixes[1]) / 1000.0)]
      else
        (1...(@fixes.length - 2)).each do |index|
          leg = @fixes[index].distance_to(@fixes[index + 1])
          rows << ["#{@names[index]} - #{@names[index + 1]}", "%.1fkm (%.1f%%)" % [leg / 1000.0, 100.0 * leg / total]]
        end
        leg = @fixes[-2].distance_to(@fixes[1])
        rows << ["#{@names[-2]} - #{@names[1]}", "%.1fkm (%.1f%%)" % [leg / 1000.0, 100.0 * leg / total]]
      end
    else
      (0...(@fixes.length - 1)).each do |index|
        rows << ["#{@names[index]} - #{@names[index + 1]}", "%.1fkm" % (@fixes[index].distance_to(@fixes[index + 1]) / 1000.0)]
      end
    end
    unless @multiplier.zero?
      rows << ["Total", "%.1fkm" % (total / 1000.0)]
      rows << ["Multiplier", "\xc3\x97 %.1f" % @multiplier]
      rows << ["Score", "<b>%.1f points</b>" % score]
    end
    if @circuit
      rows << ["#{@names[0]} - #{@names[-1]}", "%.1fkm" % (@fixes[0].distance_to(@fixes[-1]) / 1000.0)]
    end
    description = KML::Description.new(KML::CData.new("<table>", rows.collect do |th, td|
      "<tr><th>#{th}</th><td>#{td}</td></tr>"
    end.join, "</table>"))
    folder = KML::Folder.hide_children(KML::Name.new(name), description, KML::Snippet.new, folder_options)
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
    kmz = KMZ.new(KML::Folder.radio(KML::Name.new("Cross country")))
    kmz.merge(hints.stock.invisible_none_folder)
    best_optimum = @optima.sort_by(&:score)[-1]
    @optima.each do |optimum|
      kmz.merge(optimum.to_kmz(hints, :visibility => optimum == best_optimum ? nil : 0))
    end
    kmz
  end

end
