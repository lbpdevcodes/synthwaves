module VideoImport
  # What a folder import did, printed once it has been through every video.
  class FolderReport
    def initialize(out)
      @out = out
      @lists = {"Uploaded" => [], "Skipped" => [], "Failed" => []}
      @checks = []
    end

    def uploaded(title, video_id) = @lists["Uploaded"] << %("#{title}" (video #{video_id}))

    def skipped(title, reason) = @lists["Skipped"] << %("#{title}" (#{reason}))

    def failed(title, reason) = @lists["Failed"] << %("#{title}" (#{reason}))

    # A video that went up, but one of its subtitle files did not.
    def check(title, video_id, problem)
      @checks << %(Check: "#{title}" is up as video #{video_id}, but #{problem}; add it on the video's edit page)
    end

    def print
      @out.puts
      @checks.each { |line| @out.puts(line) }
      @lists.each { |heading, items| @out.puts(["#{heading} #{items.size}", *items.join(", ")].join(": ")) }
    end

    def success? = @lists["Failed"].empty? && @checks.empty?
  end
end
