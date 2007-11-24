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
    @projection = Geoid::Projection::NationalGrid
    @llh = [Math.deg_to_rad(52.0 + 39.0 / 60.0 + 27.2531 / 3600.0), Math.deg_to_rad(1.0 + 43.0 / 60.0 + 4.5177 / 3600.0), 24.7]
    @ll_delta = Math.deg_to_rad(0.00005 / 3600.0)
    @xyz = [3_874_938.849, 116_218.624, 5_047_168.208]
    @enh = [651_409.903, 313_177.270, 0.0]
    @gr = "TG51401317"
  end

  def test_llh_to_xyz
    xyz = @projection.ellipsoid.llh_to_xyz(@llh)
    assert_to_dp(@xyz[0], xyz[0], 3)
    assert_to_dp(@xyz[1], xyz[1], 3)
    assert_to_dp(@xyz[2], xyz[2], 3)
  end

  def test_xyz_to_llh
    llh = @projection.ellipsoid.xyz_to_llh(@xyz)
    assert_in_delta(@llh[0], llh[0], @ll_delta)
    assert_in_delta(@llh[1], llh[1], @ll_delta)
    assert_to_dp(@llh[2], llh[2], 3)
  end

  def test_llh_to_enh
    enh = @projection.llh_to_enh(@llh)
    assert_to_dp(@enh[0], enh[0], 3)
    assert_to_dp(@enh[1], enh[1], 3)
  end

  def test_enh_to_llh
    llh = @projection.enh_to_llh(@enh)
    assert_in_delta(@llh[0], llh[0], @ll_delta)
    assert_in_delta(@llh[1], llh[1], @ll_delta)
  end

  def test_gr_to_enh
    enh = @projection.gr_to_enh(@gr)
    assert_in_delta(@enh[0], enh[0], 10.0)
    assert_in_delta(@enh[1], enh[1], 10.0)
  end

  def test_enh_to_gr
    gr = @projection.enh_to_gr(@enh, @gr.size - 2)
    assert_equal(@gr, gr)
  end

  def teardown
    @ellipsoid = nil
  end

end
