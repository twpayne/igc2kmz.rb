require "coord"

module Math

  class << self

    def deg_to_rad(x)
      x * PI / 180.0
    end

    def rad_to_deg(x)
      x * 180.0 / PI
    end

  end

end

class Cartesian

  attr_accessor :x
  attr_accessor :y
  attr_accessor :z

  def initialize(x, y, z)
    @x = x
    @y = y
    @z = z
  end

  def ==(other)
    @x == other.x and @y == other.y and @z == other.z
  end

end

class Grid

  attr_accessor :east
  attr_accessor :north
  attr_accessor :height

  def initialize(east, north, height)
    @east = east
    @north = north
    @height = height
  end

  def ==(other)
    @east == other.east and @north == other.north and @height == other.height
  end

end

module Geoid

  class Ellipsoid

    attr_reader :a
    attr_reader :b
    attr_reader :e2

    def initialize(a, b)
      @a = a
      @b = b
      @e2 = (a * a - b * b) / (a * a)
      freeze
    end

    def coord_to_cartesian(coord)
      nu = @a / Math.sqrt(1.0 - @e2 * Math.sin(coord.lat) * Math.sin(coord.lat))
      x = (nu + coord.alt) * Math.cos(coord.lat) * Math.cos(coord.lon)
      y = (nu + coord.alt) * Math.cos(coord.lat) * Math.sin(coord.lon)
      z = ((1.0 - @e2) * nu + coord.alt) * Math.sin(coord.lat)
      Cartesian.new(x, y, z)
    end

    def cartesian_to_coord(cartesian, precision = 0.000000001)
      lon = Math.atan2(cartesian.y, cartesian.x)
      p = Math.sqrt(cartesian.x * cartesian.x + cartesian.y * cartesian.y)
      lat = Math.atan2(cartesian.z, p * (1.0 - @e2))
      nu = @a / Math.sqrt(1.0 - @e2 * Math.sin(lat) * Math.sin(lat))
      while true
        lat = Math.atan2(cartesian.z + @e2 * nu * Math.sin(lat), p)
        new_nu = @a / Math.sqrt(1.0 - @e2 * Math.sin(lat) * Math.sin(lat))
        break if (new_nu - nu).abs < precision
        nu = new_nu
      end
      alt = p / Math.cos(lat) - nu
      Coord.new(lat, lon, alt)
    end

    Airy1830          = new(6_377_563.396, 6_356_256.910)
    Airy1830Modified  = new(6_377_340.189, 6_356_034.447)
    International1924 = new(6_378_388.000, 6_356_911.946)
    WGS84             = new(6_378_137.000, 6_356_752.3141)

  end

  class HelmertTransform

    attr_reader :t
    attr_reader :s
    attr_reader :r

    def initialize(t = [0.0, 0.0, 0.0], s = 0.0, r = [0.0, 0.0, 0.0])
      @t = t
      @s = s
      @r = r
      freeze
    end

    def cartesian_to_cartesian(cartesian)
      x = @t[0] + (1.0 + @s) * cartesian.x - @r[2] * cartesian.y + @r[1] * cartesian.z
      y = @t[1] + @r[2] * cartesian.x + (1.0 + @s) * cartesian.y - @r[0] * cartesian.z
      z = @t[2] - @r[1] * cartesian.x + @r[0] * cartesian.y + (1.0 + @s) * cartesian.z
      Cartesian.new(x, y, z)
    end

    def inverse
      t = [-@t[0], -@t[1], -@t[2]]
      s = -@s
      r = [-@r[0], -@r[1], -@r[2]]
      HelmertTransform.new(t, s, r)
    end

    class << self

      def ITRSETRS89(t_survey)
        delta_t = t_survey - 1989.0
        t = [0.041, 0.041, -0.049]
        s = 0.0
        r = [0.00020 * delta_t / 3600.0, 0.00050 * delta_t / 3600.0, -0.00065 * delta_t / 3600.0]
        new(t, s, r)
      end

    end

    WGS84_to_NationalGrid = new([-446.448, 125.157, -542.060], 20.4894 / 1000000.0, [Math.deg_to_rad(-0.1502 / 3600.0), Math.deg_to_rad(-0.2470 / 3600.0), Math.deg_to_rad(-0.8421 / 3600.0)])
    NationalGrid_to_WGS84 = WGS84_to_NationalGrid.inverse
    ITRS94_to_ETRS89 = ITRSETRS89(1994)
    ITRS96_to_ETRS89 = ITRSETRS89(1996)
    ITRS97_to_ETRS89 = ITRSETRS89(1997)

  end

  class TransverseMercatorProjection

    attr_reader :ell

    def initialize(f0, lat0, lon0, east0, north0, ell, &block)
      @f0 = f0
      @lat0 = lat0
      @lon0 = lon0
      @east0 = east0
      @north0 = north0
      @ell = ell
      (class << self; self; end).class_eval(&block) if block
      freeze
    end

    def coord_to_grid(coord)
      sin_lat = Math.sin(coord.lat)
      sin_lat2 = sin_lat * sin_lat
      cos_lat = Math.cos(coord.lat)
      cos_lat2 = cos_lat * cos_lat
      cos_lat4 = cos_lat2 * cos_lat2
      tan_lat = Math.tan(coord.lat)
      tan_lat2 = tan_lat * tan_lat
      tan_lat4 = tan_lat2 * tan_lat2
      delta_lat = coord.lat - @lat0
      sigma_lat = coord.lat + @lat0
      delta_lon = coord.lon - @lon0
      delta_lon2 = delta_lon * delta_lon
      delta_lon4 = delta_lon2 * delta_lon2
      n = (@ell.a - @ell.b) / (@ell.a + @ell.b)
      n2 = n * n
      nu = @ell.a * @f0 / Math.sqrt(1.0 - @ell.e2 * sin_lat2)
      rho = @ell.a * @f0 * (1.0 - @ell.e2) * (1.0 - @ell.e2 * sin_lat2) ** -1.5
      eta2 = nu / rho - 1.0
      m = @ell.b * @f0 * ((1.0 + n + 5.0 * n2 / 4.0 + 5.0 * n * n2 / 4.0) * delta_lat - (3.0 * n + 3.0 * n2 + 21.0 * n * n2 / 8.0) * Math.sin(delta_lat) * Math.cos(sigma_lat) + (15.0 * n2 / 8.0 + 15.0 * n * n2 / 8.0) * Math.sin(2.0 * delta_lat) * Math.cos(2.0 * sigma_lat) - (35.0 * n / 24.0) * n2 * Math.sin(3.0 * delta_lat) * Math.cos(3.0 * sigma_lat))
      i = m + @north0
      ii = nu * sin_lat * cos_lat / 2.0
      iii = nu * sin_lat * cos_lat * cos_lat2 * (5.0 - tan_lat2 + 9.0 * eta2) /  24.0
      iiia = nu * sin_lat * cos_lat * cos_lat4 * (61.0 - 58.0 * tan_lat2 + tan_lat4) / 720.0
      iv = nu * cos_lat
      v = nu * cos_lat * cos_lat2 * (nu / rho - tan_lat2) / 6.0
      vi = nu * cos_lat * cos_lat4 * (5.0 - 18.0 * tan_lat2 + tan_lat4 + 14.0 * eta2 - 58.0 * tan_lat2 * eta2) / 120.0
      north = i + ii * delta_lon2 + iii * delta_lon4 + iiia * delta_lon2 * delta_lon4
      east = @east0 + iv * delta_lon + v * delta_lon * delta_lon2 + vi * delta_lon * delta_lon4
      Grid.new(east, north, coord.alt)
    end

    def grid_to_coord(grid)
      delta_east = grid.east - @east0
      delta_east2 = delta_east * delta_east
      delta_east4 = delta_east2 * delta_east2
      lat_ = (grid.north - @north0) / (@ell.a * @f0) + @lat0
      n = (@ell.a - @ell.b) / (@ell.a + @ell.b)
      n2 = n * n
      while true
        delta_lat_ = lat_ - @lat0
        sigma_lat_ = lat_ + @lat0
        m = @ell.b * @f0 * ((1.0 + n + 5.0 * n2 / 4.0 + 5.0 * n * n2 / 4.0) * delta_lat_ - (3.0 * n + 3.0 * n2 + 21.0 * n * n2 / 8.0) * Math.sin(delta_lat_) * Math.cos(sigma_lat_) + (15.0 * n2 / 8.0 + 15.0 * n * n2 / 8.0) * Math.sin(2.0 * delta_lat_) * Math.cos(2.0 * sigma_lat_) - (35.0 * n / 24.0) * n2 * Math.sin(3.0 * delta_lat_) * Math.cos(3.0 * sigma_lat_))
        break if grid.north - @north0 - m < 0.0001
        lat_ = (grid.north - @north0 - m) / (@ell.a * @f0) + lat_
      end
      sec_lat_ = 1.0 / Math.cos(lat_)
      sin_lat_ = Math.sin(lat_)
      sin_lat_2 = sin_lat_ * sin_lat_
      tan_lat_ = Math.tan(lat_)
      tan_lat_2 = tan_lat_ * tan_lat_
      tan_lat_4 = tan_lat_2 * tan_lat_2
      nu = @ell.a * @f0 / Math.sqrt(1.0 - @ell.e2 * sin_lat_2)
      nu2 = nu * nu
      nu4 = nu2 * nu2
      rho = @ell.a * @f0 * (1.0 - @ell.e2) * (1.0 - @ell.e2 * sin_lat_2) ** -1.5
      eta2 = nu / rho - 1.0
      vii = tan_lat_ / (2.0 * rho * nu)
      viii = tan_lat_ * (5.0 + 3.0 * tan_lat_2 + eta2 - 9.0 * tan_lat_2 * eta2) / (24.0 * rho * nu * nu2)
      ix = tan_lat_ * (61.0 + 90.0 * tan_lat_2 + 45.0 * tan_lat_4) / (720.0 * rho * nu * nu4)
      x = sec_lat_ / nu
      xi = sec_lat_ * (nu / rho + 2.0 * tan_lat_2) / (6.0 * nu * nu2)
      xii = sec_lat_ * (5.0 + 28.0 * tan_lat_2 + 24.0 * tan_lat_4) / (120.0 * nu * nu4)
      xiia = sec_lat_ * (61.0 + 662.0 * tan_lat_2 + 1320.0 * tan_lat_4 + 720.0 * tan_lat_2 * tan_lat_4) / (5040.0 * nu * nu2 * nu4)
      lat = lat_ - vii * delta_east2 + viii * delta_east4 - ix * delta_east2 * delta_east4
      lon = @lon0 + x * delta_east - xi * delta_east * delta_east2 + xii * delta_east * delta_east4 - xiia * delta_east * delta_east2 * delta_east4
      Coord.new(lat, lon, grid.height)
    end

  end

  NationalGrid = TransverseMercatorProjection.new(0.9996012717, Math.deg_to_rad(49.0), Math.deg_to_rad(-2.0), 400_000.0, -100_000.0, Ellipsoid::Airy1830) do

    def gr_to_grid(gr)
      md = /\A([A-HJ-Z])([A-HJ-Z])((?:\d\d)+)\z/.match(gr.gsub(/\s+/, "").upcase)
      raise ArgumentError if md.nil?
      half_figures = md[3].size / 2
      granularity = 10 ** (5 - half_figures)
      square1 = md[1][0] - ?A
      square1 -= 1 if square1 > ?H - ?A
      square2 = md[2][0] - ?A
      square2 -= 1 if square2 > ?H - ?A
      east = 100_000.0 * (5 * (square1 % 5) + (square2 % 5) - 10) + granularity * md[3][0, half_figures].to_i
      north = 100_000.0 * (19 - 5 * (square1 / 5) - (square2 / 5)) + granularity * md[3][half_figures, half_figures].to_i
      Grid.new(east, north, 0.0)
    end

    def grid_to_gr(grid, figures = 6)
      raise ArgumentError unless (0..700_000) === grid.east
      raise ArgumentError unless (0..1_300_000) === grid.north
      raise ArgumentError unless figures % 2 == 0
      east, x = grid.east.divmod(100_000)
      north, y = grid.north.divmod(100_000)
      letter1 = ?A + 17 + ((east / 5) % 5) - 5 * ((north / 5) % 5)
      letter1 += 1 if letter1 > ?H
      letter2 = ?A + 20 + (east % 5) - 5 * (north % 5)
      letter2 += 1 if letter2 > ?H
      half_figures = figures / 2
      granularity = 10 ** (5 - half_figures)
      format = "%c%c%0#{half_figures}d%0#{half_figures}d"
      sprintf(format, letter1, letter2, x / granularity, y / granularity)
    end

    def grid_to_wgs84_coord(grid)
      coord = grid_to_coord(grid)
      cartesian = @ell.coord_to_cartesian(coord)
      wgs84_cartesian = HelmertTransform::NationalGrid_to_WGS84.cartesian_to_cartesian(cartesian)
      Ellipsoid::WGS84.cartesian_to_coord(wgs84_cartesian)
    end

    def gr_to_wgs84_coord(gr)
      grid = gr_to_grid(gr)
      wgs84_coord = grid_to_wgs84_coord(grid)
    end

    def wgs84_coord_to_grid(wgs84_coord)
      wgs84_cartesian = Ellipsoid::WGS84.coord_to_cartesian(wgs84_coord)
      cartesian = HelmertTransform::WGS84_to_NationalGrid.cartesian_to_cartesian(wgs84_cartesian)
      coord = @ell.cartesian_to_coord(cartesian)
      coord_to_grid(coord)
    end

  end

  IrishNationalGrid = TransverseMercatorProjection.new(1.000035, Math.deg_to_rad(53.0 + 30.0 / 60.0), Math.deg_to_rad(-8.0), 200_000.0, 250_000.0, Ellipsoid::Airy1830Modified)
  UTMZone29 = TransverseMercatorProjection.new(0.9996, Math.deg_to_rad(0.0), Math.deg_to_rad(-9.0), 500_000.0, 0.0, Ellipsoid::International1924)
  UTMZone30 = TransverseMercatorProjection.new(0.9996, Math.deg_to_rad(0.0), Math.deg_to_rad(-3.0), 500_000.0, 0.0, Ellipsoid::International1924)
  UTMZone31 = TransverseMercatorProjection.new(0.9996, Math.deg_to_rad(0.0), Math.deg_to_rad(3.0), 500_000.0, 0.0, Ellipsoid::International1924)

end
