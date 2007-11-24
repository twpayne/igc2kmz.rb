require "singleton"

module Math

  def Math.deg_to_rad(x)
    x * Math::PI / 180.0
  end

  def Math.rad_to_deg(x)
    x * 180.0 / Math::PI
  end

  def Math.rad_to_dms(x)
    deg = rad_to_deg(x)
    [deg.to_i, (60.0 * deg).to_i % 60, 3600.0 * deg - 60 * (deg * 60).to_i]
  end

end

module Geoid

  class Ellipsoid

    attr_accessor(:a, :b, :e2, :f)

    def initialize(a, b)
      @a = a
      @b = b
      @e2 = (a * a - b * b) / (a * a)
      @f = 1.0 - b / a
    end

    def llh_to_xyz(llh)
      return nil if llh.nil?
      latitude, longitude, height = llh
      nu = @a / Math.sqrt(1.0 - @e2 * Math.sin(latitude) * Math.sin(latitude))
      x = (nu + height) * Math.cos(latitude) * Math.cos(longitude)
      y = (nu + height) * Math.cos(latitude) * Math.sin(longitude)
      z = ((1.0 - @e2) * nu + height) * Math.sin(latitude)
      [x, y, z]
    end

    def xyz_to_llh(xyz, precision = 0.000000001)
      return nil if xyz.nil?
      x, y, z = xyz
      longitude = Math.atan2(y, x)
      p = Math.sqrt(x * x + y * y)
      latitude = Math.atan2(z, p * (1.0 - @e2))
      nu = @a / Math.sqrt(1.0 - @e2 * Math.sin(latitude) * Math.sin(latitude))
      while true
        latitude = Math.atan2(z + @e2 * nu * Math.sin(latitude), p)
        new_nu = @a / Math.sqrt(1.0 - @e2 * Math.sin(latitude) * Math.sin(latitude))
        break if (new_nu - nu).abs < precision
        nu = new_nu
      end
      height = p / Math.cos(latitude) - nu
      [latitude, longitude, height]
    end

    Airy1830          = Ellipsoid.new(6_377_563.396, 6_356_256.910)
    Airy1830Modified  = Ellipsoid.new(6_377_340.189, 6_356_034.447)
    International1924 = Ellipsoid.new(6_378_388.000, 6_356_911.946)
    WGS84             = Ellipsoid.new(6_378_137.000, 6_356_752.3141)

  end

  class HelmertTransform

    attr_accessor(:t, :s, :r)

    def initialize(t = [0.0, 0.0, 0.0], s = 0.0, r = [0.0, 0.0, 0.0])
      @t = t
      @s = s
      @r = r
    end

    def xyz_to_xyz(xyz)
      return nil if xyz.nil?
      x, y, z = xyz
      x_ = @t[0] + (1.0 + @s) * x - @r[2] * y + @r[1] * z
      y_ = @t[1] + @r[2] * x + (1.0 + @s) * y - @r[0] * z
      z_ = @t[2] - @r[1] * x + @r[0] * y + (1.0 + @s) * z
      [x_, y_, z_]
    end

    def inverse
      t = [-@t[0], -@t[1], -@t[2]]
      s = -@s
      r = [-@r[0], -@r[1], -@r[2]]
      HelmertTransform.new(t, s, r)
    end

    def HelmertTransform.ITRSETRS89(t_survey)
      delta_t = t_survey - 1989.0
      t = [0.041, 0.041, -0.049]
      s = 0.0
      r = [0.00020 * delta_t / 3600.0, 0.00050 * delta_t / 3600.0, -0.00065 * delta_t / 3600.0]
      HelmertTransform.new(t, s, r)
    end
    
    WGS84_to_NationalGrid = HelmertTransform.new([-446.448, 125.157, -542.060], 20.4894 / 1000000.0, [Math.deg_to_rad(-0.1502 / 3600.0), Math.deg_to_rad(-0.2470 / 3600.0), Math.deg_to_rad(-0.8421 / 3600.0)])
    NationalGrid_to_WGS84 = WGS84_to_NationalGrid.inverse
    ITRS94_to_ETRS89 = HelmertTransform.ITRSETRS89(1994)
    ITRS96_to_ETRS89 = HelmertTransform.ITRSETRS89(1996)
    ITRS97_to_ETRS89 = HelmertTransform.ITRSETRS89(1997)

  end

  class Projection

  end

  class TransverseMercatorProjection < Projection
 
    attr_accessor(:f0, :latitude0, :longitude0, :easting0, :northing0, :ellipsoid)

    def initialize(f0, latitude0, longitude0, easting0, northing0, ellipsoid)
      @f0 = f0
      @latitude0 = latitude0
      @longitude0 = longitude0
      @easting0 = easting0
      @northing0 = northing0
      @ellipsoid = ellipsoid
    end

    def llh_to_enh(llh)
      return nil if llh.nil?
      latitude, longitude, height = llh
      sin_latitude = Math.sin(latitude)
      sin_latitude2 = sin_latitude * sin_latitude
      cos_latitude = Math.cos(latitude)
      cos_latitude2 = cos_latitude * cos_latitude
      cos_latitude4 = cos_latitude2 * cos_latitude2
      tan_latitude = Math.tan(latitude)
      tan_latitude2 = tan_latitude * tan_latitude
      tan_latitude4 = tan_latitude2 * tan_latitude2
      delta_latitude = latitude - @latitude0
      sigma_latitude = latitude + @latitude0
      delta_longitude = longitude - @longitude0
      delta_longitude2 = delta_longitude * delta_longitude
      delta_longitude4 = delta_longitude2 * delta_longitude2
      n = (@ellipsoid.a - @ellipsoid.b) / (@ellipsoid.a + @ellipsoid.b)
      n2 = n * n
      nu = @ellipsoid.a * @f0 / Math.sqrt(1.0 - @ellipsoid.e2 * sin_latitude2)
      rho = @ellipsoid.a * @f0 * (1.0 - @ellipsoid.e2) * (1.0 - @ellipsoid.e2 * sin_latitude2) ** -1.5
      eta2 = nu / rho - 1.0
      m = @ellipsoid.b * @f0 * ((1.0 + n + 5.0 * n2 / 4.0 + 5.0 * n * n2 / 4.0) * delta_latitude - (3.0 * n + 3.0 * n2 + 21.0 * n * n2 / 8.0) * Math.sin(delta_latitude) * Math.cos(sigma_latitude) + (15.0 * n2 / 8.0 + 15.0 * n * n2 / 8.0) * Math.sin(2.0 * delta_latitude) * Math.cos(2.0 * sigma_latitude) - (35.0 * n / 24.0) * n2 * Math.sin(3.0 * delta_latitude) * Math.cos(3.0 * sigma_latitude))
      i = m + @northing0
      ii = nu * sin_latitude * cos_latitude / 2.0
      iii = nu * sin_latitude * cos_latitude * cos_latitude2 * (5.0 - tan_latitude2 + 9.0 * eta2) /  24.0
      iiia = nu * sin_latitude * cos_latitude * cos_latitude4 * (61.0 - 58.0 * tan_latitude2 + tan_latitude4) / 720.0
      iv = nu * cos_latitude
      v = nu * cos_latitude * cos_latitude2 * (nu / rho - tan_latitude2) / 6.0
      vi = nu * cos_latitude * cos_latitude4 * (5.0 - 18.0 * tan_latitude2 + tan_latitude4 + 14.0 * eta2 - 58.0 * tan_latitude2 * eta2) / 120.0
      northing = i + ii * delta_longitude2 + iii * delta_longitude4 + iiia * delta_longitude2 * delta_longitude4
      easting = @easting0 + iv * delta_longitude + v * delta_longitude * delta_longitude2 + vi * delta_longitude * delta_longitude4
      [easting, northing, height]
    end

    def enh_to_llh(enh)
      return nil if enh.nil?
      easting, northing, height = enh
      delta_easting = easting - @easting0
      delta_easting2 = delta_easting * delta_easting
      delta_easting4 = delta_easting2 * delta_easting2
      latitude_ = (northing - @northing0) / (@ellipsoid.a * @f0) + @latitude0
      n = (@ellipsoid.a - @ellipsoid.b) / (@ellipsoid.a + @ellipsoid.b)
      n2 = n * n
      while true
        delta_latitude_ = latitude_ - @latitude0
        sigma_latitude_ = latitude_ + @latitude0
        m = @ellipsoid.b * @f0 * ((1.0 + n + 5.0 * n2 / 4.0 + 5.0 * n * n2 / 4.0) * delta_latitude_ - (3.0 * n + 3.0 * n2 + 21.0 * n * n2 / 8.0) * Math.sin(delta_latitude_) * Math.cos(sigma_latitude_) + (15.0 * n2 / 8.0 + 15.0 * n * n2 / 8.0) * Math.sin(2.0 * delta_latitude_) * Math.cos(2.0 * sigma_latitude_) - (35.0 * n / 24.0) * n2 * Math.sin(3.0 * delta_latitude_) * Math.cos(3.0 * sigma_latitude_))
        break if northing - @northing0 - m < 0.0001
        latitude_ = (northing - @northing0 - m) / (@ellipsoid.a * @f0) + latitude_
      end
      sec_latitude_ = 1.0 / Math.cos(latitude_)
      sin_latitude_ = Math.sin(latitude_)
      sin_latitude_2 = sin_latitude_ * sin_latitude_
      tan_latitude_ = Math.tan(latitude_)
      tan_latitude_2 = tan_latitude_ * tan_latitude_
      tan_latitude_4 = tan_latitude_2 * tan_latitude_2
      nu = @ellipsoid.a * @f0 / Math.sqrt(1.0 - @ellipsoid.e2 * sin_latitude_2)
      nu2 = nu * nu
      nu4 = nu2 * nu2
      rho = @ellipsoid.a * @f0 * (1.0 - @ellipsoid.e2) * (1.0 - @ellipsoid.e2 * sin_latitude_2) ** -1.5
      eta2 = nu / rho - 1.0
      vii = tan_latitude_ / (2.0 * rho * nu)
      viii = tan_latitude_ * (5.0 + 3.0 * tan_latitude_2 + eta2 - 9.0 * tan_latitude_2 * eta2) / (24.0 * rho * nu * nu2)
      ix = tan_latitude_ * (61.0 + 90.0 * tan_latitude_2 + 45.0 * tan_latitude_4) / (720.0 * rho * nu * nu4)
      x = sec_latitude_ / nu
      xi = sec_latitude_ * (nu / rho + 2.0 * tan_latitude_2) / (6.0 * nu * nu2)
      xii = sec_latitude_ * (5.0 + 28.0 * tan_latitude_2 + 24.0 * tan_latitude_4) / (120.0 * nu * nu4)
      xiia = sec_latitude_ * (61.0 + 662.0 * tan_latitude_2 + 1320.0 * tan_latitude_4 + 720.0 * tan_latitude_2 * tan_latitude_4) / (5040.0 * nu * nu2 * nu4)
      latitude = latitude_ - vii * delta_easting2 + viii * delta_easting4 - ix * delta_easting2 * delta_easting4
      longitude = @longitude0 + x * delta_easting - xi * delta_easting * delta_easting2 + xii * delta_easting * delta_easting4 - xiia * delta_easting * delta_easting2 * delta_easting4
      [latitude, longitude, height]
    end

  end

  class NationalGridSingleton < TransverseMercatorProjection
    
    include Singleton

    LETTER_EASTING = {"A" => 0, "B" => 1, "C" => 2, "D" => 3, "E" => 4, "F" => 0, "G" => 1, "H" => 2, "J" => 3, "K" => 4, "L" => 0, "M" => 1, "N" => 2, "O" => 3, "P" => 4, "Q" => 0, "R" => 1, "S" => 2, "T" => 3, "U" => 4, "V" => 0, "W" => 1, "X" => 2, "Y" => 3, "Z" => 4}
    LETTER_NORTHING = {"A" => 4, "B" => 4, "C" => 4, "D" => 4, "E" => 4, "F" => 3, "G" => 3, "H" => 3, "J" => 3, "K" => 3, "L" => 2, "M" => 2, "N" => 2, "O" => 2, "P" => 2, "Q" => 1, "R" => 1, "S" => 1, "T" => 1, "U" => 1, "V" => 0, "W" => 0, "X" => 0, "Y" => 0, "Z" => 0}
    LETTERS = [%w"V Q L F A", %w"W R M G B", %w"X S N H C", %w"Y T O J D", %w"Z U P K E"]

    def initialize
      super(0.9996012717, Math.deg_to_rad(49.0), Math.deg_to_rad(-2.0), 400_000.0, -100_000.0, Ellipsoid::Airy1830)
    end

    def gr_to_enh(gr)
      match = /\A([A-HJ-Z])([A-HJ-Z])((?:\d\d)+)\z/.match(gr.gsub(/\s+/, "").upcase)
      raise "Invalid grid reference #{gr.inspect}" if match.nil?
      figures = match[3].size
      square_size = 10 ** (5 - figures / 2)
      easting = (LETTER_EASTING[match[1]] - LETTER_EASTING["S"]) * 500_000.0 + (LETTER_EASTING[match[2]] - LETTER_EASTING["V"]) * 100_000.0 + square_size * match[3][0, figures / 2].to_i
      northing = (LETTER_NORTHING[match[1]] - LETTER_NORTHING["S"]) * 500_000.0 + (LETTER_NORTHING[match[2]] - LETTER_NORTHING["V"]) * 100_000.0 + square_size * match[3][figures / 2, figures / 2].to_i
      [easting, northing, 0.0]
    end

    def enh_to_gr(enh, figures = 6)
      return nil if enh.nil?
      return nil if enh[0] < 0 or   700_000 < enh[0]
      return nil if enh[1] < 0 or 1_300_000 < enh[1]
      code = LETTERS[(enh[0].to_i / 500_000 + LETTER_EASTING["S"]) % 5][(enh[1].to_i / 500_000 + LETTER_NORTHING["S"]) % 5] +
             LETTERS[((enh[0].to_i % 500_000) / 100_000 + LETTER_EASTING["V"]) % 5][((enh[1].to_i % 500_000) / 100_000 + LETTER_NORTHING["V"]) % 5]
      x_figures = ((enh[0] % 100_000) * 10 ** (figures / 2 - 5)).to_i
      y_figures = ((enh[1] % 100_000) * 10 ** (figures / 2 - 5)).to_i
      format = "%s%0#{figures / 2}d%0#{figures / 2}d"
      sprintf(format, code, x_figures, y_figures)
    end

    def enh_to_wgs84_llh(enh)
      llh = enh_to_llh(enh)
      xyz = @ellipsoid.llh_to_xyz(llh)
      wgs84_xyz = HelmertTransform::NationalGrid_to_WGS84.xyz_to_xyz(xyz)
      Ellipsoid::WGS84.xyz_to_llh(wgs84_xyz)
    end

    def gr_to_wgs84_llh(gr)
      enh = gr_to_enh(gr)
      wgs84_llh = enh_to_wgs84_llh(enh)
    end

    def wgs84_llh_to_enh(wgs84_llh)
      wgs84_xyz = Ellipsoid::WGS84.llh_to_xyz(wgs84_llh)
      xyz = HelmertTransform::WGS84_to_NationalGrid.xyz_to_xyz(wgs84_xyz)
      llh = @ellipsoid.xyz_to_llh(xyz)
      llh_to_enh(llh)
    end

  end

  class Projection

    NationalGrid = NationalGridSingleton.instance
    IrishNationalGrid = TransverseMercatorProjection.new(1.000035, Math.deg_to_rad(53.0 + 30.0 / 60.0), Math.deg_to_rad(-8.0), 200_000.0, 250_000.0, Ellipsoid::Airy1830Modified)
    UTMZone29 = TransverseMercatorProjection.new(0.9996, Math.deg_to_rad(0.0), Math.deg_to_rad(-9.0), 500_000.0, 0.0, Ellipsoid::International1924)
    UTMZone30 = TransverseMercatorProjection.new(0.9996, Math.deg_to_rad(0.0), Math.deg_to_rad(-3.0), 500_000.0, 0.0, Ellipsoid::International1924)
    UTMZone31 = TransverseMercatorProjection.new(0.9996, Math.deg_to_rad(0.0), Math.deg_to_rad(3.0), 500_000.0, 0.0, Ellipsoid::International1924)

  end

end
