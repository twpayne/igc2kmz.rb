require "kmz"
require "task"

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

    def description
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

    def description
      radius == DEFAULT_RADIUS ? "Turnpoint" : "Turnpoint (%dm radius)" % radius
    end

    def label
      "TP"
    end

    def kml_geometry
      KML::MultiGeometry.new(super, KML::Point.new(:coordinates => self))
    end

  end

  class StartOfSpeedSection < StartCircle

    def description
      "Start of speed section (%.1fkm radius)" % (radius / 1000.0)
    end

    def label
      "SS"
    end

  end

  class EndOfSpeedSection < Circle

    def description
      "End of speed section (%.1fkm radius)" % (radius / 1000.0)
    end

    def label
      "ES"
    end

  end

  class GoalCircle < Circle

    def description
      radius == DEFAULT_RADIUS ? "Goal" : "Goal (%dm radius)" % radius
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

    def description
      "Goal line (%dm wide)" % @length
    end

    def label
      "GOAL"
    end

  end

  def to_kmz(hints, options = {})
    folder = KML::Folder.hide_children(KML::Name.new("%s task %d (%.1fkm)" % [@competition_name, @number, @distance / 1000.0]), options)
    object0 = nil
    turnpoint_number = 0
    rows = []
    distance = 0
    @course.each do |object|
      if object.is_a?(Turnpoint) or object.is_a?(GoalCircle) or object.is_a?(GoalLine)
        if object0
          coords = [object0.boundary(object), object.boundary(object0)]
          line_string = KML::LineString.new(:coordinates => coords)
          point = KML::Point.new(:coordinates => coords[0].halfway_to(coords[1]))
          multi_geometry = KML::MultiGeometry.new(point, line_string)
          name = "%.1fkm" % (object0.distance_to(object) / 1000.0)
          description = "%s to %s (%.1fkm)" % [object0.name, object.name, object0.distance_to(object) / 1000.0]
          placemark = KML::Placemark.new(multi_geometry, KML::Snippet.new, :name => name, :description => description, :styleUrl => hints.stock.task_style.url)
          folder.add(placemark)
          distance += object0.distance_to(object)
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
      placemark = KML::Placemark.new(object.kml_geometry, KML::Snippet.new, :name => label, :description => object.description, :styleUrl => hints.stock.task_style.url)
      folder.add(placemark)
      rows << [label, "%.1fkm" % (distance / 1000.0), object.name, object.description]
    end
    folder.add(KML::Description.new(KML::CData.new(rows.to_html_table)))
    folder.add(KML::Snippet.new)
    KMZ.new(folder)
  end

end
