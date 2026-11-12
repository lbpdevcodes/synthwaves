require "net/http"
require "openssl"
require "json"
require "digest"
require "open3"
require "tmpdir"

# Uploads one local video file to a synthwaves.fm server. Runs outside the
# Rails app (bin/import_video), so it loads nothing but the standard library.
module VideoImport
  class Error < StandardError; end

  def self.missing_tool(name)
    Error.new("#{name} is not installed: install ffmpeg (brew install ffmpeg), or pass --no-encode to let the server convert the video")
  end
end

require_relative "video_import/connection"
require_relative "video_import/source_file"
require_relative "video_import/api"
require_relative "video_import/meter"
require_relative "video_import/progress"
require_relative "video_import/upload_limit"
require_relative "video_import/storage_upload"
require_relative "video_import/file_part"
require_relative "video_import/multipart_upload"
require_relative "video_import/pass_through"
require_relative "video_import/probe"
require_relative "video_import/conversion"
require_relative "video_import/ready_details"
require_relative "video_import/encoder"
require_relative "video_import/importer"
require_relative "video_import/subtitle_files"
require_relative "video_import/subtitle_upload"
require_relative "video_import/video_title"
require_relative "video_import/title_fixes"
require_relative "video_import/upload_log"
require_relative "video_import/unfinished_download"
require_relative "video_import/embedded_subtitles"
require_relative "video_import/folder_scan"
require_relative "video_import/folder_report"
require_relative "video_import/folder_import"
