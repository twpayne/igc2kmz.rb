require "rubygems"
require "fileutils"
require "geoid"
require "hpricot"
require "html"
require "open-uri"
require "optparse"
require "RMagick"
require "tempfile"
require "uri"

module Streetmap 

  TILE_SCALE = [nil, nil, nil, 1_000, 1_000, 10_000]
  TILE_SIZE = [nil, nil, nil, 200, 200, 250]

  class Map

    attr_reader :image
    attr_reader :grid0
    attr_reader :grid1

    def initialize(bounds, zoom = 3, tilesdir = "tmp/cache/streetmap/tiles")
      raise ArgumentError unless 3..5 == zoom
      grid0, grid1 = bounds
      grid0 = Geoid::NationalGrid.gr_to_grid(grid0) if grid0.is_a?(String)
      grid1 = Geoid::NationalGrid.gr_to_grid(grid1) if grid1.is_a?(String)
      grid0.east, grid1.east = grid1.east, grid0.east if grid1.east < grid0.east
      grid0.north, grid1.north = grid1.north, grid0.north if grid1.north < grid0.north
      @tile_scale = Streetmap::TILE_SCALE[zoom]
      @tile_size = Streetmap::TILE_SIZE[zoom]
      i0 = (grid0.east / @tile_scale).to_i
      j0 = (grid0.north / @tile_scale).to_i
      i1 = ((grid1.east + @tile_scale - 1) / @tile_scale).to_i
      j1 = ((grid1.north + @tile_scale - 1) / @tile_scale).to_i
      @grid0 = Grid.new(i0 * @tile_scale, j0 * @tile_scale, 0.0)
      @grid1 = Grid.new(i1 * @tile_scale, j1 * @tile_scale, 0.0)
      @image = Magick::Image.new((i1 - i0) * @tile_size, (j1 - j0) * @tile_size)
      (i0...i1).each do |i|
        (j0...j1).each do |j|
          grid = Grid.new(i * @tile_scale, j * @tile_scale, 0.0)
          Streetmap.download_tile(grid, {:zoom => zoom}, tilesdir)
          tile_filename = Streetmap.grid_to_tile_filename(grid, zoom)
          tile = Magick::ImageList.new(File.join(tilesdir, tile_filename))
          pixels = tile.get_pixels(0, 0, @tile_size, @tile_size)
          @image.store_pixels((i - i0) * @tile_size, (j1 - j - 1) * @tile_size, @tile_size, @tile_size, pixels)
        end
      end
    end

    def include?(grid)
      (grid0.east..grid1.east).include?(grid.east) and (grid0.north..grid1.north).include?(grid.north)
    end


  end

  class << self

    def grid_to_tile_filename(grid, zoom = 3) 
      gr = Geoid::NationalGrid.grid_to_gr(grid, 2)
      case zoom
      when 3, 4
        x = (grid.east.to_i % 100_000) / 1_000
        y = (grid.north.to_i % 100_000) / 1_000
        [gr, ["S", "N"][(y % 10) / 5], ["W", "E"][(x % 10) / 5], 2 * (x % 5), 2 * (y % 5), ".gif"].join
      when 5
        [gr, ".gif"].join
      else
        raise
      end
    end 

    def grid_to_uri(grid, args = {}) 
      uri_args = {}
      uri_args[:scheme] = "http"
      uri_args[:host] = "www.streetmap.co.uk"
      uri_args[:path] = "/streetmap.dll"
      query = []
      query.push([:X, grid.east.to_i])
      query.push([:Y, grid.north.to_i])
      query.push([:zoom, args[:zoom].to_i]) if args[:zoom]
      [:title, :back, :url].each do |arg|
        query.push([arg, args[arg].url_encode]) if args[arg]
      end
      uri_args[:query] = "grid2map?" + query.collect { |pair| pair.join("=") }.join("&")
      URI::HTTP.build(uri_args)
    end

    def download_tile(grid, args = {}, tilesdir = "", fetch_all = true)
      tile_filename = grid_to_tile_filename(grid, args[:zoom] || 3)
      FileUtils.mkdir_p(tilesdir)
      return if FileTest.exist?(File.join(tilesdir, tile_filename))
      page_uri = grid_to_uri(grid, args)
      Hpricot(open(page_uri)).search("//img[@src]") do |img|
        src_uri = img["src"]
        next unless /\A\/image\.dll/.match(src_uri)
        src_uri = page_uri + URI.parse(src_uri)
        next unless src_uri.query
        query = src_uri.query.html_entity_decode.split("&").collect do |pair|
          pair.split("=", 2)
        end.collect do |key, value|
          [key.url_decode.intern, value && value.url_decode]
        end
        next unless query.assoc(:ShowImage)
        next if !fetch_all and query.assoc(:image)[1] != tile_filename
        query.delete_if do |key, value|
          [:arrow, :logo, :x, :y].include?(key)
        end
        src_uri.query = query.collect do |pair|
          pair[0].to_s.url_encode + (pair[1] ? "=" + pair[1].url_encode : "")
        end.join("&")
        image_filename = File.join(tilesdir, query.assoc(:image)[1])
        Tempfile.open("streetmap") do |io|
          io.write(src_uri.open.read)
          io.close
          FileUtils.mv(io.path, image_filename)
        end
      end
    end

    def main(argv)
      zoom = 3
      bounds = %w(SO0000 SO5050)
      output = nil
      OptionParser.new do |op|
        op.on("--help", "help") do |arg|
          puts(op)
          exit(0)
        end
        op.on("--bounds=BOUNDS", Array, "bounds") do |arg|
          bounds = arg
        end
        op.on("--output=FILENAME", String, "output filename") do |arg|
          output = arg
        end
        op.on("--zoom=ZOOM", Integer, "zoom") do |arg|
          zoom = arg
        end
        op.parse!(argv)
      end
      output = [bounds[0], bounds[1], zoom].join("-") + ".png" unless output
      Streetmap::Map.new(bounds, zoom).image.write(output)
      exit(0)
    end

  end
      
end 

Streetmap.main(ARGV) if $0 == __FILE__