$:.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "google/chart"
require "test/unit"

class TC_Google_Chart_Encoding_Simple < Test::Unit::TestCase

  def setup
    @encoding = Google::Chart::Encoding::Simple.new
  end

  def test_encode
    assert_equal("s:ATb19,Mn5tz", @encoding.encode([[0, 19, 27, 53, 61], [12, 39, 57, 45, 51]]))
  end

end

class TC_Google_Chart_Encoding_Text < Test::Unit::TestCase

  def setup
    @encoding = Google::Chart::Encoding::Text.new
  end

  def test_encode
    assert_equal("t:10.0,58.0,95.0|30.0,8.0,63.0", @encoding.encode([[10.0, 58.0, 95.0], [30.0, 8.0, 63.0]]))
  end

end

class TC_Google_Chart_Encoding_Extended < Test::Unit::TestCase

  def setup
    @encoding = Google::Chart::Encoding::Extended.new
  end

  def test_encode
    assert_equal("e:AAAZAaAzA0A9A-A.", @encoding.encode([[0, 25, 26, 51, 52, 61, 62, 63]]))
    assert_equal("e:BABZBaBzB0B9B-B.", @encoding.encode([[64, 89, 90, 115, 116, 125, 126, 127]]))
    assert_equal("e:.A.Z.a.z.0.9.-..", @encoding.encode([[4032, 4057, 4058, 4083, 4084, 4093, 4094, 4095]]))
  end

end

class TC_Google_Chart < Test::Unit::TestCase

  def setup
    @chart = Google::Chart.new("lc", 256, 64)
  end

  def test_cht
    assert_equal(["cht", "lc"], Google::Chart.new("lc", 0, 0).pairs.assoc("cht"))
    assert_equal(["cht", "lxy"], Google::Chart.new("lxy", 0, 0).pairs.assoc("cht"))
    assert_equal(["cht", "bhs"], Google::Chart.new("bhs", 0, 0).pairs.assoc("cht"))
    assert_equal(["cht", "bvs"], Google::Chart.new("bvs", 0, 0).pairs.assoc("cht"))
    assert_equal(["cht", "bhg"], Google::Chart.new("bhg", 0, 0).pairs.assoc("cht"))
    assert_equal(["cht", "bvg"], Google::Chart.new("bvg", 0, 0).pairs.assoc("cht"))
    assert_equal(["cht", "p"], Google::Chart.new("p", 0, 0).pairs.assoc("cht"))
    assert_equal(["cht", "p3"], Google::Chart.new("p3", 0, 0).pairs.assoc("cht"))
    assert_equal(["cht", "v"], Google::Chart.new("v", 0, 0).pairs.assoc("cht"))
    assert_equal(["cht", "s"], Google::Chart.new("s", 0, 0).pairs.assoc("cht"))
  end

  def test_chco
    @chart.colors = %w(ff0000 00ff00 0000ff)
    assert_equal(["chco", "ff0000,00ff00,0000ff"], @chart.pairs.assoc("chco"))
  end

  def test_chf_solid
    @chart << Google::Chart::Fill::Solid.new("bg", "efefef")
    assert_equal(["chf", "bg,s,efefef"], @chart.pairs.assoc("chf"))
  end

  def test_chf_solid2
    @chart << Google::Chart::Fill::Solid.new("bg", "efefef")
    @chart << Google::Chart::Fill::Solid.new("c", "000000")
    assert_equal(["chf", "bg,s,efefef|c,s,000000"], @chart.pairs.assoc("chf"))
  end

  def test_chf_linear_gradient
    @chart << Google::Chart::Fill::LinearGradient.new("c", 0, "ffffff".."76A4FB")
    @chart << Google::Chart::Fill::Solid.new("bg", "EFEFEF")
    assert_equal(["chf", "c,lg,0,ffffff,0,76A4FB,1|bg,s,EFEFEF"], @chart.pairs.assoc("chf"))
  end

  def test_chf_linear_gradient2
    @chart << Google::Chart::Fill::LinearGradient.new("c", 0, 0 => "ffffff", 1 => "76A4FB")
    @chart << Google::Chart::Fill::Solid.new("bg", "EFEFEF")
    assert_equal(["chf", "c,lg,0,ffffff,0,76A4FB,1|bg,s,EFEFEF"], @chart.pairs.assoc("chf"))
  end

  def test_chf_linear_stripes
    @chart << Google::Chart::Fill::LinearStripes.new("c", 0, [["CCCCCC", 0.2], ["FFFFFF", 0.2]])
    assert_equal(["chf", "c,ls,0,CCCCCC,0.2,FFFFFF,0.2"], @chart.pairs.assoc("chf"))
  end

  def test_chf_linear_stripes2
    @chart << Google::Chart::Fill::LinearStripes.new("c", 90, [["999999", 0.25], ["CCCCCC", 0.25], ["FFFFFF", 0.25]])
    assert_equal(["chf", "c,ls,90,999999,0.25,CCCCCC,0.25,FFFFFF,0.25"], @chart.pairs.assoc("chf"))
  end

  def test_chtt
    @chart.title = "Line 1\nLine 2"
    assert_equal(["chtt", "Line+1|Line+2"], @chart.pairs.assoc("chtt"))
  end

  def test_chts
    @chart.title_color = "FF0000"
    @chart.title_fontsize = 20
    assert_equal(["chts", "FF0000,20"], @chart.pairs.assoc("chts"))
  end

  def test_chdl
    @chart.legend = %w(First Second Third)
    assert_equal(["chdl", "First|Second|Third"], @chart.pairs.assoc("chdl"))
  end

  def test_chl
    @chart.labels = %w(May Jun Jul Aug Sep Oct)
    assert_equal(["chl", "May|Jun|Jul|Aug|Sep|Oct"], @chart.pairs.assoc("chl"))
  end

  def test_chxt
    @chart << Google::Chart::Axis.new("x")
    @chart << Google::Chart::Axis.new("y")
    @chart << Google::Chart::Axis.new("r")
    @chart << Google::Chart::Axis.new("x")
    @chart << Google::Chart::Axis.new("t")
    assert_equal(["chxt", "x,y,r,x,t"], @chart.pairs.assoc("chxt"))
  end

  def test_chxl
    @chart << Google::Chart::Axis.new("x", :labels => %w(Jan July Jan July Jan))
    @chart << Google::Chart::Axis.new("y", :labels => %w(0 100))
    @chart << Google::Chart::Axis.new("r", :labels => %w(A B C))
    @chart << Google::Chart::Axis.new("x", :labels => %w(2005 2006 2007))
    assert_equal(["chxt", "x,y,r,x"], @chart.pairs.assoc("chxt"))
    assert_equal(["chxl", "0:|Jan|July|Jan|July|Jan|1:|0|100|2:|A|B|C|3:|2005|2006|2007"], @chart.pairs.assoc("chxl"))
  end

  def test_chxl2
    @chart << Google::Chart::Axis.new("x", :labels => %w(Jan July Jan July Jan))
    @chart << Google::Chart::Axis.new("y")
    @chart << Google::Chart::Axis.new("r", :labels => %w(A B C))
    @chart << Google::Chart::Axis.new("x", :labels => %w(2005 2006 2007))
    assert_equal(["chxt", "x,y,r,x"], @chart.pairs.assoc("chxt"))
    assert_equal(["chxl", "0:|Jan|July|Jan|July|Jan|2:|A|B|C|3:|2005|2006|2007"], @chart.pairs.assoc("chxl"))
  end

  def test_chxp
    @chart << Google::Chart::Axis.new("x")
    @chart << Google::Chart::Axis.new("y", :labels => {10 => "min", 35 => "average", 75 => "max"})
    @chart << Google::Chart::Axis.new("r", :positions => %w(0 1 2 4))
    assert_equal(["chxt", "x,y,r"], @chart.pairs.assoc("chxt"))
    assert_equal(["chxl", "1:|min|average|max"], @chart.pairs.assoc("chxl"))
    assert_equal(["chxp", "1,10,35,75|2,0,1,2,4"], @chart.pairs.assoc("chxp"))
  end

  def test_chxr
    @chart << Google::Chart::Axis.new("x", :range => 100..500)
    @chart << Google::Chart::Axis.new("y", :range => 0..200)
    @chart << Google::Chart::Axis.new("r", :range => 1000..0)
    assert_equal(["chxt", "x,y,r"], @chart.pairs.assoc("chxt"))
    assert_equal(["chxr", "0,100,500|1,0,200|2,1000,0"], @chart.pairs.assoc("chxr"))
  end

  def test_chxs
    @chart << Google::Chart::Axis.new("x")
    @chart << Google::Chart::Axis.new("y", :labels => {10 => "min", 35 => "average", 75 => "max"})
    @chart << Google::Chart::Axis.new("r", :range => 0..4)
    @chart << Google::Chart::Axis.new("x", :labels => %w(Jan Feb Mar), :color => "0000dd", :fontsize => 13)
    assert_equal(["chxt", "x,y,r,x"], @chart.pairs.assoc("chxt"))
    assert_equal(["chxr", "2,0,4"], @chart.pairs.assoc("chxr"))
    assert_equal(["chxl", "1:|min|average|max|3:|Jan|Feb|Mar"], @chart.pairs.assoc("chxl"))
    assert_equal(["chxp", "1,10,35,75"], @chart.pairs.assoc("chxp"))
    assert_equal(["chxs", "3,0000dd,13"], @chart.pairs.assoc("chxs"))
  end

  def test_chxs2
    @chart << Google::Chart::Axis.new("x", :labels => %w(1st 15th 1st 15th 1st), :color => "0000dd", :fontsize => 10)
    @chart << Google::Chart::Axis.new("y")
    @chart << Google::Chart::Axis.new("r", :range => 0..4)
    @chart << Google::Chart::Axis.new("x", :labels => %w(Jan Feb Mar), :color => "0000dd", :fontsize => 12, :alignment => 1)
    assert_equal(["chxt", "x,y,r,x"], @chart.pairs.assoc("chxt"))
    assert_equal(["chxl", "0:|1st|15th|1st|15th|1st|3:|Jan|Feb|Mar"], @chart.pairs.assoc("chxl"))
    assert_equal(["chxs", "0,0000dd,10|3,0000dd,12,1"], @chart.pairs.assoc("chxs"))
  end

  def test_chls
    @chart << Google::Chart::LineStyle.new(3, 6, 3)
    @chart << Google::Chart::LineStyle.new(1, 1, 0)
    assert_equal(["chls", "3,6,3|1,1,0"], @chart.pairs.assoc("chls"))
  end

  def test_chg
    @chart.grid = Google::Chart::Grid.new(20, 50)
    assert_equal(["chg", "20,50"], @chart.pairs.assoc("chg"))
  end

  def test_chg2
    @chart.grid = Google::Chart::Grid.new(20, 50, 1, 5)
    assert_equal(["chg", "20,50,1,5"], @chart.pairs.assoc("chg"))
  end

  def test_chg3
    @chart.grid = Google::Chart::Grid.new(20, 50, 1, 0)
    assert_equal(["chg", "20,50,1,0"], @chart.pairs.assoc("chg"))
  end

  def test_chm
    @chart << Google::Chart::Marker::Shape.new("c", "FF0000", 0, 1.0, 20.0)
    @chart << Google::Chart::Marker::Shape.new("d", "80C65A", 0, 2.0, 20.0)
    @chart << Google::Chart::Marker::Shape.new("a", "990066", 0, 3.0, 9.0)
    @chart << Google::Chart::Marker::Shape.new("o", "FF9900", 0, 4.0, 20.0)
    @chart << Google::Chart::Marker::Shape.new("s", "3399CC", 0, 5.0, 10.0)
    @chart << Google::Chart::Marker::Shape.new("v", "BBCCED", 0, 6.0, 1.0)
    @chart << Google::Chart::Marker::Shape.new("V", "3399CC", 0, 7.0, 1.0)
    @chart << Google::Chart::Marker::Shape.new("x", "FFCC33", 0, 8.0, 20.0)
    @chart << Google::Chart::Marker::Shape.new("h", "3399CC", 0, 7.0, 1.0)
    assert_equal(["chm", "c,FF0000,0,1.0,20.0|d,80C65A,0,2.0,20.0|a,990066,0,3.0,9.0|o,FF9900,0,4.0,20.0|s,3399CC,0,5.0,10.0|v,BBCCED,0,6.0,1.0|V,3399CC,0,7.0,1.0|x,FFCC33,0,8.0,20.0|h,3399CC,0,7.0,1.0"], @chart.pairs.assoc("chm"))
  end

  def test_chm2
    @chart << Google::Chart::Marker::Shape.new("s", "FF0000", 1, 1.0, 10.0)
    assert_equal(["chm", "s,FF0000,1,1.0,10.0"], @chart.pairs.assoc("chm"))
  end

  def test_chm3
    @chart << Google::Chart::Marker::Shape.new("o", "ff9900", 0, 1.0, 10.0)
    @chart << Google::Chart::Marker::Shape.new("o", "ff9900", 0, 2.0, 10.0)
    @chart << Google::Chart::Marker::Shape.new("o", "ff9900", 0, 3.0, 10.0)
    @chart << Google::Chart::Marker::Shape.new("d", "ff9900", 1, 1.0, 10.0)
    @chart << Google::Chart::Marker::Shape.new("d", "ff9900", 1, 2.0, 10.0)
    @chart << Google::Chart::Marker::Shape.new("d", "ff9900", 1, 3.0, 10.0)
    assert_equal(["chm", "o,ff9900,0,1.0,10.0|o,ff9900,0,2.0,10.0|o,ff9900,0,3.0,10.0|d,ff9900,1,1.0,10.0|d,ff9900,1,2.0,10.0|d,ff9900,1,3.0,10.0"], @chart.pairs.assoc("chm"))
  end

  def test_chm4
    @chart << Google::Chart::Marker::Range.new("r", "E5ECF9", 0.75, 0.25)
    @chart << Google::Chart::Marker::Range.new("r", "000000", 0.1,  0.11)
    assert_equal(["chm", "r,E5ECF9,0,0.75,0.25|r,000000,0,0.1,0.11"], @chart.pairs.assoc("chm"))
  end

  def test_chm5
    @chart << Google::Chart::Marker::Range.new("R", "ff0000", 0.1,  0.11)
    @chart << Google::Chart::Marker::Range.new("R", "A0BAE9" ,0.75, 0.25)
    assert_equal(["chm", "R,ff0000,0,0.1,0.11|R,A0BAE9,0,0.75,0.25"], @chart.pairs.assoc("chm"))
  end

  def test_chm6
    @chart << Google::Chart::Marker::Range.new("R", "ff0000", 0.1,  0.11)
    @chart << Google::Chart::Marker::Range.new("R", "A0BAE9" ,0.75, 0.25)
    @chart << Google::Chart::Marker::Range.new("r", "E5ECF9", 0.75, 0.25)
    @chart << Google::Chart::Marker::Range.new("r", "000000", 0.1,  0.11)
    assert_equal(["chm", "R,ff0000,0,0.1,0.11|R,A0BAE9,0,0.75,0.25|r,E5ECF9,0,0.75,0.25|r,000000,0,0.1,0.11"], @chart.pairs.assoc("chm"))
  end

  def test_chm7
    @chart << [61, 61]
    @chart << [28, 30, 31, 33, 35, 36, 42, 48, 43, 37, 32, 24, 28, 31, 32, 28]
    @chart << [16, 18, 18, 21, 23, 23, 29, 36, 31, 25, 20, 12, 17, 19, 20, 16]
    @chart << [7, 9, 9, 12, 14, 14, 20, 27, 21, 15, 10, 3, 7, 10, 11, 7]
    @chart << [0, 0]
    @chart << Google::Chart::Marker::Fill.new("b", "76A4FB", 0, 1)
    @chart << Google::Chart::Marker::Fill.new("b", "224499", 1, 2)
    @chart << Google::Chart::Marker::Fill.new("b", "FF0000", 2, 3)
    @chart << Google::Chart::Marker::Fill.new("b", "80C65A", 3, 4)
    @chart.colors = %w(000000) * 5
    assert_equal(["chd", "s:99,cefhjkqwrlgYcfgc,QSSVXXdkfZUMRTUQ,HJJMOOUbVPKDHKLH,AA"], @chart.pairs.assoc("chd"))
    assert_equal(["chm", "b,76A4FB,0,1,0|b,224499,1,2,0|b,FF0000,2,3,0|b,80C65A,3,4,0"], @chart.pairs.assoc("chm"))
    assert_equal(["chco", "000000,000000,000000,000000,000000"], @chart.pairs.assoc("chco"))
  end

  def test_chm8
    @chart << [28, 30, 31, 33, 35, 36, 42, 48, 43, 37, 32, 24, 28, 31, 32, 28]
    @chart << [16, 18, 18, 21, 23, 23, 29, 36, 31, 25, 20, 12, 17, 19, 20, 16]
    @chart << [7, 9, 9, 12, 14, 14, 20, 27, 21, 15, 10, 3, 7, 10, 11, 7]
    @chart << Google::Chart::Marker::Fill.new("b", "224499", 0, 1)
    @chart << Google::Chart::Marker::Fill.new("b", "FF0000", 1, 2)
    @chart << Google::Chart::Marker::Fill.new("b", "80C65A", 2, 3)
    assert_equal(["chd", "s:cefhjkqwrlgYcfgc,QSSVXXdkfZUMRTUQ,HJJMOOUbVPKDHKLH"], @chart.pairs.assoc("chd"))
    assert_equal(["chm", "b,224499,0,1,0|b,FF0000,1,2,0|b,80C65A,2,3,0"], @chart.pairs.assoc("chm"))
  end

  def test_chm9
    @chart << [0, 19, 18, 19, 26, 21, 29, 54, 53, 61, 60, 53, 46, 40, 28, 0]
    @chart << Google::Chart::Marker::Fill.new("B", "76A4FB", 0, 0)
    assert_equal(["chd", "s:ATSTaVd21981uocA"], @chart.pairs.assoc("chd"))
    assert_equal(["chm", "B,76A4FB,0,0,0"], @chart.pairs.assoc("chm"))
  end

end
