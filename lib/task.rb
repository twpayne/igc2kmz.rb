require "bounds"
require "coord"
require "enumerator"
require "lib"

class Task

  TYPES = {
    :elapsedtime => "elapsed time",
    :racetogoal  => "race to goal",
  }

  class Point < Coord

    attr_reader :name

    def initialize(lat, lon, alt, name)
      super(lat, lon, alt)
      @name = name
    end

    def bounds
      Bounds.new(:lat => @lat..@lat, :lon => @lon..@lon, :alt => @alt..@alt)
    end

    def intersect?(fix0, fix1)
      false
    end

  end

  class Circle < Point

    DEFAULT_RADIUS = nil 

    def bounds
      Bounds.new(:lat => destination_at(Math::PI, radius).lat..destination_at(0.0, radius).lat,
                 :lon => destination_at(1.5 * Math::PI, radius).lon..destination_at(0.5 * Math::PI, radius).lon)
    end

    def initialize(lat, lon, alt, name, radius)
      super(lat, lon, alt, name)
      @radius = radius
    end

    def radius
      @radius || self.class.const_get("DEFAULT_RADIUS")
    end

    def intersect?(fix0, fix1)
      distance0 = distance_to(fix0)
      distance1 = distance_to(fix1)
      return nil unless distance0 > radius and radius >= distance1
      fix0.interpolate(fix1, (distance0 - radius) / (distance0 - distance1))
    end

  end

  class Turnpoint < Circle

    DEFAULT_RADIUS = 400

  end

  class StartCircle < Circle

    def initialize(lat, lon, alt, name, radius, start_time)
      super(lat, lon, alt, name, radius)
      @start_time = start_time
    end

  end

  class TakeOff < StartCircle

    DEFAULT_RADIUS = 1000

    def intersect?(fix0, fix1)
      @start_time <= fix0.time and distance_to(fix0) > radius and radius >= distance_to(fix1)
    end

  end

  class StartOfSpeedSection < StartCircle

    def intersect?(fix0, fix1)
      distance0 = distance_to(fix0)
      distance1 = distance_to(fix1)
      return nil unless distance0 > radius and radius >= distance1
      delta = (distance0 - radius) / (distance0 - distance1)
      fix = fix0.interpolate(fix1, (distance0 - radius) / (distance0 - distance1))
      return nil if fix.time < @start_time
      fix
    end

  end

  class EndOfSpeedSection < Circle
  end

  class GoalCircle < Circle

    DEFAULT_RADIUS = 400

  end

  class GoalLine < Point

    attr_reader :length
    attr_reader :axis

    def initialize(lat, lon, alt, name, length, axis)
      super(lat, lon, alt, name)
      @length = length
      @axis = axis
      @left = destination_at(@axis - Math::PI / 2.0, @length / 2.0)
      @right = destination_at(@axis + Math::PI / 2.0, @length / 2.0)
    end

    def bounds
      Bounds.new(:lat => [@left, @right].collect(&:lat).bounds, :lon => [@left, @right].collect(&:lon).bounds)
    end

    def intersect?(fix0, fix1)
      intersection = Coord.line_segment_intersection(@left, @right, fix0, fix1)
      return nil unless intersection
      fix0.interpolate(fix1, intersection[1])
    end

  end

  attr_reader :competition
  attr_reader :number
  attr_reader :type
  attr_reader :distance
  attr_reader :course

  def initialize(competition, number, type, course)
    @competition = competition
    @number = number
    @type = type
    @course = course
    @distance = 0
    @course.each_cons(2) do |object0, object1|
      @distance += object0.distance_to(object1)
      break if object1.is_a?(GoalCircle) or object1.is_a?(GoalLine)
    end
  end

  def bounds
    result = Bounds.new
    @course.each do |object|
      result.merge(object.bounds)
    end
    result
  end

end
