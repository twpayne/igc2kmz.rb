require "html"
require "kmz"
require "optima"
require "units"

class Optimum

  def to_kmz(hints, folder_options = {})
    name = (@multiplier.zero? ? "%s (%s)" : "%s (%s, %.1f points)") % [@flight_type, hints.units[:distance][distance], score]
    rows = []
    total = distance
    rows << ["League", Optima::LEAGUES[hints.optima.league]]
    rows << ["Type", @flight_type]
    if @circuit
      if @fixes.length == 4
        rows << ["#{@names[1]} - #{@names[2]}", hints.units[:distance][@fixes[1].distance_to(@fixes[2])]]
        rows << ["#{@names[2]} - #{@names[1]}", hints.units[:distance][@fixes[2].distance_to(@fixes[1])]]
      else
        (1...(@fixes.length - 2)).each do |index|
          leg = @fixes[index].distance_to(@fixes[index + 1])
          rows << ["#{@names[index]} - #{@names[index + 1]}", "%s (%.1f%%)" % [hints.units[:distance][leg], 100.0 * leg / total]]
        end
        leg = @fixes[-2].distance_to(@fixes[1])
        rows << ["#{@names[-2]} - #{@names[1]}", "%s (%.1f%%)" % [hints.units[:distance][leg], 100.0 * leg / total]]
      end
    else
      (0...(@fixes.length - 1)).each do |index|
        rows << ["#{@names[index]} - #{@names[index + 1]}", hints.units[:distance][@fixes[index].distance_to(@fixes[index + 1])]]
      end
    end
    unless @multiplier.zero?
      rows << ["Total", hints.units[:distance][total]]
      rows << ["Multiplier", "\xc3\x97 %.1f" % @multiplier]
      rows << ["Score", "<b>%.1f points</b>" % score]
    end
    if @circuit
      rows << ["#{@names[0]} - #{@names[-1]}", hints.units[:distance][@fixes[0].distance_to(@fixes[-1])]]
    end
    description = KML::Description.new(KML::CData.new(rows.to_html_table))
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
      name = hints.units[:distance][coord0.distance_to(coord1)]
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

  def to_kmz(hints, options = {})
    kmz = KMZ.new(KML::Folder.radio(KML::Name.new("Cross country"), options))
    kmz.merge(hints.stock.invisible_none_folder)
    best_optimum = @optima.sort_by(&:score)[-1]
    @optima.each do |optimum|
      kmz.merge(optimum.to_kmz(hints, :visibility => optimum == best_optimum ? nil : 0))
    end
    kmz
  end

end
