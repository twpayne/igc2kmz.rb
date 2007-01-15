require "fileutils"
require "lib"
require "mmap"
require "net/http"
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

    class Tile

      def initialize(mmap)
        @mmap = mmap
        @mmap.madvise(Mmap::MADV_RANDOM)
      end

      def [](i, j)
        @mmap[2 * (6000 * j + i), 2].unpack("n")[0]
      end

      class << self

        def new(x, y)
          FileUtils.mkpath([TILE_CACHE_DIRECTORY, ZIP_CACHE_DIRECTORY])
          tile = File.join(TILE_CACHE_DIRECTORY, "srtm_%02d_%02d.tile" % [x, y])
          return super(Mmap.new(tile)) if FileTest.exist?(tile) and !FileTest.zero?(tile)
          zip = "srtm_%02d_%02d.zip" % [x, y]
          zip_cache_filename = File.join(ZIP_CACHE_DIRECTORY, zip)
          unless FileTest.exist?(zip_cache_filename) and !FileTest.zero?(zip_cache_filename)
            uri = URI.parse("#{MIRROR}#{zip}")
            Tempfile.open(zip) do |tempfile|
              Net::HTTP.start(uri.host, uri.port) do |http|
                http.request_get(uri.request_uri) do |request|
                  raise unless request.is_a?(Net::HTTPOK)
                  request.read_body do |segment|
                    tempfile.write(segment)
                  end
                end
              end
              FileUtils.mv(tempfile.path, zip_cache_filename)
            end
          end
          Zip::ZipInputStream.open(zip_cache_filename) do |zis|
            asc = "Z_%d_%d.ASC" % [x, y]
            while entry = zis.get_next_entry
              if entry.name == asc
                ncols = nrows = nil
                io = entry.get_input_stream
                line = nil
                io.each do |line|
                  case line
                  when /\Ancols\s+(\d+)\s*\z/             then raise unless $1.to_i == 6000
                  when /\Anrows\s+(\d+)\s*\z/             then raise unless $1.to_i == 6000
                  when /\Axllcorner\s+(-?\d+)\s*\z/       then raise unless $1.to_i == 5 * (x - 37)
                  when /\Ayllcorner\s+(-?\d+)\s*\z/       then raise unless $1.to_i == 5 * (12 - y)
                  when /\Acellsize\s+(\d+(?:\.\d+))\s*\z/ then raise unless (6000 * $1.to_f - 5).abs < 1e-12
                  when /\ANODATA_value\s+(-?\d+)\s*\z/    then raise unless $1.to_i == -9999
                  else break
                  end
                end
                mmap = nil
                File.open(tile, "w") do |tileio|
                  mmap = Mmap.new(tileio.path, "w")
                  mmap.madvise(Mmap::MADV_SEQUENTIAL)
                  mmap.extend(2 * 6000 * 6000)
                end
                mmap[0, 2 * 6000] = line.split(/\s+/).collect!(&:to_i).pack("n*")
                1.upto(6000 - 1) do |i|
                  mmap[2 * 6000 * i, 2 * 6000] = io.readline.split(/\s+/).collect!(&:to_i).pack("n*")
                end
                raise unless io.eof?
                mmap.mprotect("r")
                return super(mmap)
              end
            end
          end
          raise
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
