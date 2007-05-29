class Point

  attr_accessor :x
  attr_accessor :y
  attr_accessor :z

  def initialize(x, y, z)
    @x = x
    @y = y
    @z = z
  end

end

class Line

  attr_accessor :a
  attr_accessor :b

  def initialize(a, b)
    @a = a
    @b = b
  end

end

class Plane

  attr_accessor :a
  attr_accessor :b
  attr_accessor :c

  def initialize(a, b, c)
    @a = a
    @b = b
    @c = c
  end

  def normal
    (@b - @a).cross(@c - @a)
  end

end

require "cgeometry"
