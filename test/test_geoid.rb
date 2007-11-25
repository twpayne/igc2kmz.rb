$:.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require "test/unit"
require "geoid"

module Test

  module Unit

    module Assertions

      def assert_to_dp(expected_float, actual_float, dp, message = nil)
        _wrap_assertion do
          {expected_float => "first", actual_float => "second"}.each do |float, nth|
            assert_respond_to(float, :to_f, "The #{nth} argument must respond to to_f; it did not")
          end
          assert_respond_to(dp, :to_i, "The number of decimal places must respond to to_i; it did not")
          full_message = build_message(message, expected_float.to_s, actual_float.to_s, dp) do |arg1, arg2, arg3|
            "<#{arg1}> and\n" +
            "<#{arg2}> expected to be equal to\n" +
            "<#{arg3}> decimal places"
          end
          assert_block(full_message) do
            multiplier = 10 ** dp.to_i
            (expected_float.to_f * multiplier + 0.5).to_i == (actual_float.to_f * multiplier + 0.5).to_i
          end
        end
      end

      def assert_to_sf(expected_float, actual_float, sf, message = nil)
        _wrap_assertion do
          {expected_float => "first", actual_float => "second"}.each do |float, nth|
            assert_respond_to(float, :to_f, "The #{nth} argument must respond to to_f; it did not")
          end
          assert_respond_to(sf, :to_i, "The number of significant digits must respond to to_i; it did not")
          assert_operator(sf.to_i, :>, 0, "The number of significant digits must be greater than zero")
          full_message = build_message(message, expected_float, actual_float, sf) do |arg1, arg2, arg3|
            "<#{arg1}> and\n" +
            "<#{arg2}> expected to be equal to\n" +
            "<#{arg3}> significant figures"
          end
          assert_block(full_message) do
            multiplier = 10 ** (sf.to_i - Math.log10(expected_float.to_f).floor - 1)
            (expected_float.to_f * multiplier + 0.5).to_i == (actual_float.to_f * multiplier + 0.5).to_i
          end
        end
      end

    end

  end

end

class TC_Geoid < Test::Unit::TestCase

  def setup
    @projection = Geoid::NationalGrid
    @coord = Coord.new(Math.deg_to_rad(52.0 + 39.0 / 60.0 + 27.2531 / 3600.0), Math.deg_to_rad(1.0 + 43.0 / 60.0 + 4.5177 / 3600.0), 24.7)
    @delta = Math.deg_to_rad(0.00005 / 3600.0)
    @cartesian = Cartesian.new(3_874_938.849, 116_218.624, 5_047_168.208)
    @grid = Grid.new(651_409.903, 313_177.270, 0.0)
    @gr = "TG51401317"
  end

  def test_coord_to_cartesian
    cartesian = @projection.ell.coord_to_cartesian(@coord)
    assert_to_dp(@cartesian.x, cartesian.x, 3)
    assert_to_dp(@cartesian.y, cartesian.y, 3)
    assert_to_dp(@cartesian.z, cartesian.z, 3)
  end

  def test_cartesian_to_coord
    coord = @projection.ell.cartesian_to_coord(@cartesian)
    assert_in_delta(@coord.lat, coord.lat, @delta)
    assert_in_delta(@coord.lon, coord.lon, @delta)
    assert_to_dp(@coord.alt, coord.alt, 3)
  end

  def test_coord_to_grid
    grid = @projection.coord_to_grid(@coord)
    assert_to_dp(@grid.east, grid.east, 3)
    assert_to_dp(@grid.north, grid.north, 3)
  end

  def test_grid_to_coord
    coord = @projection.grid_to_coord(@grid)
    assert_in_delta(@coord.lat, coord.lat, @delta)
    assert_in_delta(@coord.lon, coord.lon, @delta)
  end

  def test_gr_to_grid
    grid = @projection.gr_to_grid(@gr)
    assert_in_delta(@grid.east, grid.east, 10.0)
    assert_in_delta(@grid.north, grid.north, 10.0)
  end

  def test_gr_to_grid_2
    assert_equal(Grid.new(651400.0, 313170.0, 0.0), @projection.gr_to_grid("TG51401317"))
  end

  def test_gr_to_grid_3
    assert_equal(Grid.new(300000.0, 200000.0, 0.0), @projection.gr_to_grid("SO000000"))
  end

  def test_gr_to_grid_4
    assert_equal(Grid.new(500000.0, 900000.0, 0.0), @projection.gr_to_grid("OA000000"))
  end

  def test_gr_to_grid_5
    assert_equal(Grid.new(100000.0, 1000000.0, 0.0), @projection.gr_to_grid("HW000000"))
  end

  def test_grid_to_gr
    gr = @projection.grid_to_gr(@grid, @gr.size - 2)
    assert_equal(@gr, gr)
  end

end
