require "net/http"
require "openssl"
require "json"
require "digest"

# Uploads one local video file to a synthwaves.fm server. Runs outside the
# Rails app (bin/import_video), so it loads nothing but the standard library.
module VideoImport
  class Error < StandardError; end
end

require_relative "video_import/connection"
require_relative "video_import/source_file"
require_relative "video_import/api"
require_relative "video_import/progress"
require_relative "video_import/storage_upload"
require_relative "video_import/importer"
