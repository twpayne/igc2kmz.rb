require "html"
require "kmz"
require "xc"
require "units"

module XC

  class Turnpoint

    def to_kml(hints)
      point = KML::Point.new(:coordinates => self, :altitudeMode => hints.altitude_mode, :extrude => 1)
      statistics = []
      statistics << ["Altitude", hints.units[:altitude][@alt]] if hints.igc.altitude_data?
      statistics << ["Time", @time.to_time(hints)]
      description = KML::Description.new(KML::CData.new(statistics.to_html_table))
      KML::Placemark.new(point, description, :name => @name, :snippet => "", :styleUrl => hints.stock.xc_style.url)
    end

  end

  class Flight

    def make_row(hints, from, to, format)
      from = @turnpoints[from]
      to = @turnpoints[to]
      leg = from.distance_to(to)
      ["#{from.name} \xe2\x86\x92 #{to.name}", format % [hints.units[:distance][leg], 100.0 * leg / @distance]]
    end

    def to_kmz(hints, folder_options = {})
      name = (multiplier.zero? ? "%s (%s)" : "%s (%s, %.1f points)") % [type, hints.units[:distance][distance], score]
      rows = []
      rows << ["League", @league.description] if @league.description
      rows << ["Type", type]
      if circuit?
        if @turnpoints.length == 4
          rows << make_row(hints, 1, 2, "%s")
          rows << make_row(hints, 2, 1, "%s")
        else
          (1...(@turnpoints.length - 2)).each do |index|
            rows << make_row(hints, index, index + 1, "%s (%.1f%%)")
          end
          rows << make_row(hints, -2, 1, "%s (%.1f%%)")
        end
      else
        (0...(@turnpoints.length - 1)).each do |index|
          rows << make_row(hints, index, index + 1, "%s")
        end
      end
      unless multiplier.zero?
        rows << ["Total", hints.units[:distance][@distance]]
        rows << ["Multiplier", "\xc3\x97 %.1f points/km" % multiplier]
        rows << ["Score", "<b>%.1f points</b>" % @score]
      end
      rows << make_row(hints, -1, 0, "%s") if circuit?
      rows << ["Time on task", (turnpoints[-1].time - turnpoints[0].time).to_duration]
      rows << ["Average speed", hints.units[:speed][distance / (turnpoints[-1].time - turnpoints[0].time)]]
      description = KML::Description.new(KML::CData.new(rows.to_html_table))
      folder = KML::Folder.new(KML::Name.new(name), description, KML::Snippet.new, KML::StyleUrl.new(hints.stock.check_hide_children_style.url), folder_options)
      coords = circuit? ? @turnpoints[1...-1].push(@turnpoints[1]) : @turnpoints
      coords.each_cons(2) do |coord0, coord1|
        bearing = coord1.initial_bearing_to(coord0)
        line_string1 = KML::LineString.new(:coordinates => [coord0, coord1], :tessellate => 1)
        line_string2 = KML::LineString.new(:coordinates => [coord1.destination_at(bearing - Math::PI / 12.0, 400.0), coord1, coord1.destination_at(bearing + Math::PI / 12.0, 400.0)])
        point = KML::Point.new(:coordinates => coord0.halfway_to(coord1))
        multi_geometry = KML::MultiGeometry.new(line_string1, line_string2, point)
        name = hints.units[:distance][coord0.distance_to(coord1)]
        placemark = KML::Placemark.new(multi_geometry, :name => name, :styleUrl => hints.stock.xc_style.url)
        folder.add(placemark)
      end
      @turnpoints.each do |turnpoint|
        folder.add(turnpoint.to_kml(hints))
      end
      KMZ.new(folder)
    end

  end

end
