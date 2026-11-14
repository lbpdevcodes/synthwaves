module VideoImport
  # Why a video is a release's sample clip rather than the release: its file
  # name ends with the word "sample" (Heat.1995.1080p-GRP-Sample.mkv).
  # A sample takes the release's title, so uploading it would also make the
  # upload log skip the real file.
  module SampleClip
    def self.reason(path)
      "a sample clip" if File.basename(path, ".*").split(/[ ._-]+/).last&.casecmp?("sample")
    end
  end
end
