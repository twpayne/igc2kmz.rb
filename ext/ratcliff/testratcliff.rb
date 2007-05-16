require "ratcliff"
require "test/unit"

class TC_Ratcliff < Test::Unit::TestCase

  def test_one_char_equal
    assert_equal(1.0, "a".ratcliff("a"))
  end

  def test_one_char_not_equal
    assert_equal(0.0, "a".ratcliff("b"))
  end

  def test_equal
    assert_equal(1.0, "abc".ratcliff("abc"))
  end

  def test_not_equal
    assert_equal(0.0, "abc".ratcliff("def"))
  end

  def test_transpose
    assert_equal(0.5, "ab".ratcliff("ba"))
  end

end
