require "coord"
require "lib"

class Task

  class Point < Coord

    attr_reader :name

    def initialize(lat, lon, alt, name)
      super(lat, lon, alt)
      @name = name
    end

    def intersect?(fix0, fix1)
      false
    end

  end

  class Circle < Point

    DEFAULT_RADIUS = nil 

    def initialize(lat, lon, alt, name, radius)
      super(lat, lon, alt, name)
      @radius = radius
    end

    def radius
      @radius || self.class.const_get("DEFAULT_RADIUS")
    end

    def intersect?(fix0, fix1)
      radius < distance_to(fix0) and distance_to(fix1) <= radius ? fix1 : nil
    end

  end

  class Turnpoint < Circle

    DEFAULT_RADIUS = 400

  end

  class StartCircle

    def initialize(lat, lon, alt, name, radius, start_time)
      super(lat, lon, alt, name, radius)
      @start_time = start_time
    end

  end

  class TakeOff < StartCircle

    DEFAULT_RADIUS = 1000

    def intersect?(fix0, fix1)
      distance_to(fix0) <= radius and @start_time <= fix0.time ? fix0 : false
    end

  end

  class StartOfSpeedSection < StartCircle

    def intersect?(fix0, fix1)
      fix0.timestamp < @start_time and super and fix0
    end

  end

  class EndOfSpeedSection < Circle
  end

  class Goal < Circle

    DEFAULT_RADIUS = 400

  end

  class GoalLine < Point

    attr_reader :length
    attr_reader :bearing

    def initialize(lat, lon, alt, length, bearing)
      super(lat, lon, alt)
      @length = length
      @bearing = bearing
    end

    def intersect(fix0, fix1)
      false # FIXME
    end

  end

  attr_reader :name
  attr_reader :number
  attr_reader :objects

  def initialize(name, number, objects)
    @name = name
    @number = number
    @objects = objects
  end

end
