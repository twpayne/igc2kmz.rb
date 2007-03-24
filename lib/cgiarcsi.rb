require "fileutils"
require "lib"
require "mmap"
require "net/http"
require "singleton"
require "tempfile"
require "zip/zip"

module CGIARCSI

  module SRTM90mDEM

    MIRRORS = {
      :it => "http://srtm.jrc.it/SRTM_Data_ArcAscii/",
      :uk => "http://armadillo.geog.kcl.ac.uk/portal/srtm3/srtm_data_arcascii/",
      :us => "http://srtm.csi.cgiar.org/SRT-ZIP/srtm_v3/SRTM_Data_ArcAscii/",
    }
    MIRROR = MIRRORS[:us]

    CACHE_DIRECTORY = File.join("tmp", "cache", "srtm")
    ZIP_CACHE_DIRECTORY = File.join(CACHE_DIRECTORY, "zip")
    TILE_CACHE_DIRECTORY = File.join(CACHE_DIRECTORY, "tile")

    @@tiles = {}

    class NoTile

      include Singleton

      def [](i, j)
        0
      end

    end

    class Tile

      def initialize(mmap)
        @mmap = mmap
        @mmap.madvise(Mmap::MADV_RANDOM)
      end

      def [](i, j)
        @mmap[2 * (6000 * j + i), 2].unpack("s")[0]
      end

      class << self

        def new(x, y)
          return NoTile.instance unless (1..72).include?(x) and (1..24).include?(y)
          FileUtils.mkpath([TILE_CACHE_DIRECTORY, ZIP_CACHE_DIRECTORY])
          tile = File.join(TILE_CACHE_DIRECTORY, "srtm_%02d_%02d.tile" % [x, y])
          return super(Mmap.new(tile)) if FileTest.exist?(tile) and !FileTest.zero?(tile)
          return NoTile.instance if FileTest.exist?("#{tile}.404")
          zip = "srtm_%02d_%02d.zip" % [x, y]
          zip_cache_filename = File.join(ZIP_CACHE_DIRECTORY, zip)
          unless FileTest.exist?(zip_cache_filename) and !FileTest.zero?(zip_cache_filename)
            uri = URI.parse("#{MIRROR}#{zip}")
            Tempfile.open(zip) do |tempfile|
              Net::HTTP.start(uri.host, uri.port) do |http|
                http.request_get(uri.request_uri) do |request|
                  case request
                  when Net::HTTPOK
                    request.read_body do |segment|
                      tempfile.write(segment)
                    end
                  when Net::HTTPNotFound
                    FileUtils.touch("#{tile}.404")
                    return NoTile.instance
                  else
                    raise request
                  end
                end
              end
              FileUtils.mv(tempfile.path, zip_cache_filename)
            end
          end
          Zip::ZipInputStream.open(zip_cache_filename) do |zis|
            asc = "Z_%d_%d.ASC" % [x, y]
            while entry = zis.get_next_entry
              next unless entry.name == asc
              File.open(tile, "w+") do |io|
                CGIARCSI.parse_ASC(entry.get_input_stream, io)
              end
            end
          end
          return super(Mmap.new(tile))
        end
      end

    end

    class << self

      def [](lat, lon)
        x, i = (lon + 185 + 0.5 / 1200).divmod(5)
        y, j = (65 - lat + 0.5 / 1200).divmod(5)
        tile = @@tiles[72 * (y - 1) + (x - 1)] ||= Tile.new(x, y)
        tile[(1200 * i).to_i, (1200 * j).to_i]
      end

    end

  end

end

require "ccgiarcsi"
