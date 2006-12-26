require "kmz"
require "task"
require "units"

class Task

  class Point < Coord

    def boundary(other)
      self
    end

  end

  class Circle < Point

    def boundary(other)
      destination_at(initial_bearing_to(other), radius)
    end

    def kml_geometry
      KML::LineString.new(KML::Coordinates.circle(self, radius), :tessellate => 1)
    end

  end

  class TakeOff < StartCircle

    def description(hints)
      "Take off"
    end

    def label
      "TO"
    end

    def kml_geometry
      KML::Point.new(:coordinates => self)
    end

  end

  class Turnpoint < Circle

    def description(hints)
      radius == DEFAULT_RADIUS ? "Turnpoint" : "Turnpoint (%s radius)" % hints.units[:altitude][radius]
    end

    def label
      "TP"
    end

    def kml_geometry
      KML::MultiGeometry.new(super, KML::Point.new(:coordinates => self))
    end

  end

  class StartOfSpeedSection < StartCircle

    def description(hints)
      "Start of speed section (%s radius)" % hints.units[:distance][radius]
    end

    def label
      "SS"
    end

  end

  class EndOfSpeedSection < Circle

    def description(hints)
      "End of speed section (%s radius)" % hints.units[:distance][radius]
    end

    def label
      "ES"
    end

  end

  class GoalCircle < Circle

    def description(hints)
      radius == DEFAULT_RADIUS ? "Goal" : "Goal (%s radius)" % hints.units[:altitude][radius]
    end

    def label
      "GOAL"
    end

    def kml_geometry
      KML::MultiGeometry.new(super, KML::Point.new(:coordinates => self))
    end

  end

  class GoalLine < Point

    def kml_geometry
      KML::LineString.new(:coordinates => [@left, @right], :tessellate => 1)
    end

    def description(hints)
      "Goal line (%s wide)" % hints.units[:altitude][@length]
    end

    def label
      "GOAL"
    end

  end

  def to_kmz(hints, options = {})
    name = "%s task %d" % [@competition, @number]
    snippet = "%s %s" % [hints.units[:distance][@distance], Task::TYPES[@type]]
    folder = KML::Folder.new(KML::Name.new(name), KML::Snippet.new(snippet), KML::StyleUrl.new(hints.stock.check_hide_children_style.url), options)
    object0 = nil
    turnpoint_number = 0
    labels = @course.collect do |object|
      if object.is_a?(Turnpoint) or object.is_a?(GoalCircle) or object.is_a?(GoalLine)
        if object0
          coords = [object0.boundary(object), object.boundary(object0)]
          line_string = KML::LineString.new(:coordinates => coords)
          point = KML::Point.new(:coordinates => coords[0].halfway_to(coords[1]))
          multi_geometry = KML::MultiGeometry.new(point, line_string)
          name = hints.units[:distance][object0.distance_to(object)]
          description = "%s to %s (%s)" % [object0.name, object.name, hints.units[:distance][object0.distance_to(object)]]
          placemark = KML::Placemark.new(multi_geometry, KML::Snippet.new, :name => name, :description => description, :styleUrl => hints.stock.task_style.url)
          folder.add(placemark)
        end
        object0 = object
      elsif object.is_a?(TakeOff)
        object0 = object
      end
      if object.is_a?(Turnpoint)
        turnpoint_number += 1
        label = "T#{turnpoint_number}"
      else
        label = object.label
      end
      placemark = KML::Placemark.new(object.kml_geometry, KML::Snippet.new, :name => label, :description => object.description(hints), :styleUrl => hints.stock.task_style.url)
      folder.add(placemark)
      label
    end
    rows = []
    cumulative_distance = 0
    object0 = nil
    @course.each_with_index do |object, index|
      cumulative_distance += object0.distance_to(object) if object0
      rows << [labels[index], hints.units[:distance][cumulative_distance], object.name, object.description(hints)]
      object0 = object
    end
    folder.add(KML::Description.new(KML::CData.new("<p>#{snippet}</p>#{rows.to_html_table}")))
    KMZ.new(folder)
  end

end
