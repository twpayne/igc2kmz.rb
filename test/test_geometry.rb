$:.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "geometry"
require "test/unit"

class TC_Point < Test::Unit::TestCase

  def test_cross
    assert_equal(Point.new(1, 2, 3).cross(Point.new(4, 5, 6)), Point.new(-3, 6, -3))
  end

  def test_divide
    assert_equal(Point.new(2, 4, 6) / 2, Point.new(1, 2, 3))
  end

  def test_dot
    assert_equal(Point.new(1, 2, 3).dot(Point.new(4, 5, 6)), 1 * 4 + 2 * 5 + 3 * 6)
  end

  def test_equal
    assert_equal(Point.new(0, 0, 0) == Point.new(0, 0, 0), true)
  end

  def test_minus
    assert_equal(Point.new(1, 2, 3) - Point.new(4, 5, 6), Point.new(-3, -3, -3))
  end

  def test_plus
    assert_equal(Point.new(1, 2, 3) + Point.new(4, 5, 6), Point.new(5, 7, 9))
  end

  def test_times
    assert_equal(Point.new(1, 2, 3) * 2, Point.new(2, 4, 6))
  end

  def test_uminus
    assert_equal(-Point.new(1, 2, 3), Point.new(-1, -2, -3))
  end

end
