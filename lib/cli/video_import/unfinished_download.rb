module VideoImport
  # Why a video is not ready to upload yet: a download client still has a
  # .part file for it, or a program still has the file open to write.
  module UnfinishedDownload
    def self.reason(path)
      return "still downloading" if File.exist?("#{path}.part")

      "still being written" if being_written?(path)
    end

    # lsof -Fa prints each open descriptor's access mode as "ar", "aw" or "au".
    def self.being_written?(path)
      output, _status = Open3.capture2("lsof", "-Fa", "--", path, err: File::NULL)
      output.lines.any? { |line| line.chomp.match?(/\Aa[wu]\z/) }
    rescue Errno::ENOENT
      false
    end
  end
end
