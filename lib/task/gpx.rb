require "gpx"
require "task"

class GPX

  element :Axis
  element :Length
  element :Radius
  element :StartTime

end

class Task

  class Point < Coord

    def to_gpx
      rtept = GPX::Element.new("rtept", "lat" => Radians.to_deg(@lat), "lon" => Radians.to_deg(@lon))
      rtept.add(GPX::Type.new(self.class.to_s.sub(/\A.*::/, "").downcase))
      rtept.add(GPX::Name.new(@name)) if @name
      rtept.add(GPX::Ele.new(@alt)) unless @alt.zero?
      rtept
    end

  end

  class Circle < Point

    def to_gpx
      rtept = super
      rtept.add(GPX::Radius.new(@radius)) if @radius
      rtept
    end

  end

  class StartCircle < Circle

    def to_gpx
      rtept = super
      rtept.add(GPX::StartTime.new(@start_time.to_gpx)) if @start_time
      rtept
    end

  end

  class TakeOff < StartCircle

    class << self

      def new_from_gpx(rtept)
        lat = Radians.new_from_deg(rtept.attributes["lat"].to_f)
        lon = Radians.new_from_deg(rtept.attributes["lon"].to_f)
        alt = rtept.elements["ele"].default(0) { text.to_f }
        name = rtept.elements["name"].default { text }
        radius = rtept.elements["radius"].default { text.to_f }
        start_time = rtept.elements["starttime"].default { Time.new_from_gpx(self.text) }
        new(lat, lon, alt, name, radius, start_time)
      end

    end

  end

  class StartOfSpeedSection < StartCircle

    class << self

      def new_from_gpx(rtept)
        lat = Radians.new_from_deg(rtept.attributes["lat"].to_f)
        lon = Radians.new_from_deg(rtept.attributes["lon"].to_f)
        alt = rtept.elements["ele"].default(0) { text.to_f }
        name = rtept.elements["name"].default { text }
        radius = rtept.elements["radius"].default { text.to_f }
        start_time = rtept.elements["starttime"].default { Time.new_from_gpx(self.text) }
        new(lat, lon, alt, name, radius, start_time)
      end

    end

  end

  class Turnpoint < Circle

    class << self

      def new_from_gpx(rtept)
        lat = Radians.new_from_deg(rtept.attributes["lat"].to_f)
        lon = Radians.new_from_deg(rtept.attributes["lon"].to_f)
        alt = rtept.elements["ele"].default(0) { text.to_f }
        name = rtept.elements["name"].default { text }
        radius = rtept.elements["radius"].default { text.to_f }
        new(lat, lon, alt, name, radius)
      end

    end

  end

  class EndOfSpeedSection < Circle

    class << self

      def new_from_gpx(rtept)
        lat = Radians.new_from_deg(rtept.attributes["lat"].to_f)
        lon = Radians.new_from_deg(rtept.attributes["lon"].to_f)
        alt = rtept.elements["ele"].default(0) { text.to_f }
        name = rtept.elements["name"].default { text }
        radius = rtept.elements["radius"].default { text.to_f }
        new(lat, lon, alt, name, radius)
      end

    end

  end

  class GoalCircle < Circle

    class << self

      def new_from_gpx(rtept)
        lat = Radians.new_from_deg(rtept.attributes["lat"].to_f)
        lon = Radians.new_from_deg(rtept.attributes["lon"].to_f)
        alt = rtept.elements["ele"].default(0) { text.to_f }
        name = rtept.elements["name"].default { text }
        radius = rtept.elements["radius"].default { text.to_f }
        new(lat, lon, alt, name, radius)
      end

    end

  end

  class GoalLine < Point

    def to_gpx
      rtept = super
      rtept.add(GPX::Length.new(@length))
      rtept.add(GPX::Axis.new(Radians.to_deg(@axis % (2 * Math::PI))))
      rtept
    end

    class << self

      def new_from_gpx(rtept)
        lat = Radians.new_from_deg(rtept.attributes["lat"].to_f)
        lon = Radians.new_from_deg(rtept.attributes["lon"].to_f)
        alt = rtept.elements["ele"].default(0) { text.to_f }
        name = rtept.elements["name"].default { text }
        length = rtept.elements["length"].default { text.to_f }
        axis = rtept.elements["axis"].default { Radians.new_from_deg(text.to_f) }
        new(lat, lon, alt, name, length, axis)
      end

    end

  end

  def to_gpx
    rte = GPX::Rte.new
    rte.add(GPX::Name.new(@competition)) if @competition
    rte.add(GPX::Number.new(@number)) if @number
    rte.add(GPX::Type.new(@type)) if @type
    @course.collect(&:to_gpx).each(&rte.method(:add))
    rte
  end

  class << self

    def new_from_gpx(rte)
      competition = rte.elements["name"].default { text }
      number = rte.elements["number"].default { text.to_i }
      type = rte.elements["type"].default { text.intern }
      course = []
      rte.elements.each("rtept") do |rtept|
        case rtept.elements["type"].default { text }
        when "takeoff"             then course << TakeOff.new_from_gpx(rtept)
        when "startofspeedsection" then course << StartOfSpeedSection.new_from_gpx(rtept)
        when "turnpoint"           then course << Turnpoint.new_from_gpx(rtept)
        when "endofspeedsection"   then course << EndOfSpeedSection.new_from_gpx(rtept)
        when "goalcircle"          then course << GoalCircle.new_from_gpx(rtept)
        when "goalline"            then course << GoalLine.new_from_gpx(rtept)
        end
      end
      new(competition, number, type, course)
    end

  end

end
