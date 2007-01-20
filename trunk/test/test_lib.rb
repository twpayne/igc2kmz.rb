$:.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "lib"
require "test/unit"

class TC_Array_find_first_ge < Test::Unit::TestCase

  #        0  1  2  3  4  5  6  7  8  9
  ARRAY = [0, 0, 1, 1, 2, 2, 4, 4, 5, 6]

  def test_before
    assert_equal(ARRAY.find_first_ge(-1), 0)
  end

  def test_first
    assert_equal(ARRAY.find_first_ge(0), 0)
  end

  def test_middle
    assert_equal(ARRAY.find_first_ge(1), 2)
  end

  def test_middle2
    assert_equal(ARRAY.find_first_ge(2), 4)
  end

  def test_missing
    assert_equal(ARRAY.find_first_ge(3), 6)
  end

  def test_last
    assert_equal(ARRAY.find_first_ge(6), 9)
  end

  def test_none
    assert_equal(ARRAY.find_first_ge(7), nil)
  end

end

class TC_Range_overlap < Test::Unit::TestCase

  def test_ii_before
    assert(!(2..4).overlap?(0..1))
  end

  def test_ii_equal
    assert((2..4).overlap?(2..4))
  end

  def test_ii_after
    assert(!(2..4).overlap?(5..6))
  end

  def test_ii_just_before
    assert((2..4).overlap?(0..2))
  end

  def test_ii_last_in
    assert((2..4).overlap?(0..3))
  end

  def test_ii_around
    assert((2..4).overlap?(1..5))
  end

  def test_ii_first_in
    assert((2..4).overlap?(3..6))
  end

  def test_ii_just_after
    assert((2..4).overlap?(4..6))
  end

end

class TC_Range_merge < Test::Unit::TestCase

  def test_ii_equal
    assert_equal(2..4, (2..4).merge(2..4))
  end

  def test_ii_before
    assert_equal(0..4, (2..4).merge(0..2))
  end

  def test_ii_last_in
    assert_equal(0..4, (2..4).merge(0..3))
  end

  def test_ii_around
    assert_equal(0..6, (2..4).merge(0..6))
  end

  def test_ii_first_in
    assert_equal(2..6, (2..4).merge(3..6))
  end

end
