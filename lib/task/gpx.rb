require "gpx"
require "task"

class GPX

  element :Bearing
  element :Length
  element :Radius

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

  class GoalLine < Point

    def to_gpx
      rtept = super
      rtept.add(GPX::Length.new(@length))
      rtept.add(GPX::Bearing.new(@bearing))
      rtept
    end

  end

  def to_gpx
    rte = GPX::Rte.new
    rte.add(GPX::Name.new(@name)) if @name
    rte.add(GPX::Number.new(@number)) if @number
    @objects.collect(&:to_gpx).each(&rte.method(:add))
    rte
  end

  class << self

    def new_from_gpx(rte)
      name = rte.elements["name"].default { text }
      number = rte.elements["number"].default { text.to_i }
      objects = []
      rte.elements.each("rtept") do |rtept|
        case rtept.elements["type"].default { text }
        when "takeoff"             then objects << TakeOff.new_from_gpx(rtept)
        when "startofspeedsection" then objects << StartOfSpeedSection.new_from_gpx(rtept)
        when "turnpoint"           then objects << Turnpoint.new_from_gpx(rtept)
        when "endofspeedsection"   then objects << EndOfSpeedSection.new_from_gpx(rtept)
        when "goal"                then objects << Goal.new_from_gpx(rtept)
        when "goalline"            then objects << GoalLine.new_from_gpx(rtept)
        end
      end
      new(name, number, objects)
    end

  end

end
