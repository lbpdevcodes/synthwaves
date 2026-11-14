module VideoImport
  # Uploads every finished video under a folder, one at a time, each under
  # the title its file name gives (VideoTitle, corrected by TitleFixes), and
  # skips the titles the folder's UploadLog says are up already.
  class FolderImport
    Item = Data.define(:path, :title) do
      def file = File.basename(path)
    end

    def initialize(folder:, out:, importer:, subtitle_upload:, embedded: EmbeddedSubtitles.new)
      @folder = folder
      @out = out
      @importer = importer
      @subtitle_upload = subtitle_upload
      @embedded = embedded
    end

    # True when every ready video went up with all its subtitles.
    def call(dry_run: false)
      report = FolderReport.new(@out)
      items.each { |item| dry_run ? plan(item) : import(item, report) }
      return true if dry_run

      report.print
      report.success?
    end

    private

    def items
      fixes = TitleFixes.in(@folder)
      videos = FolderScan.videos(@folder) { |dir, reason| @out.puts("Skipping the folder #{dir}: it can't be read (#{reason})") }
      videos.map { |path| Item.new(path, fixes.apply(VideoTitle.from(path))) }
    end

    def log = @log ||= UploadLog.in(@folder)

    # A sample is named first: it shares the release's title, so the log
    # would otherwise call it uploaded already.
    def skip_reason(item) = SampleClip.reason(item.path) || uploaded_already(item) || UnfinishedDownload.reason(item.path)

    def uploaded_already(item)
      video_id = log.filed(item.title)
      "uploaded already as video #{video_id}" if video_id
    end

    def skipping(item, reason) = %(Skipping "#{item.title}" (#{item.file}): #{reason})

    def plan(item)
      reason = skip_reason(item)
      @out.puts(reason ? skipping(item, reason) : %(Would upload "#{item.title}" (#{item.file}) with #{subtitles_described(item)}))
    rescue Error => e
      @out.puts(skipping(item, e.message))
    end

    def subtitles_described(item)
      beside = SubtitleFiles.beside(item.path).size
      return counted(beside, "subtitle file") unless beside.zero?

      inside = @embedded.names(item.path).size
      inside.zero? ? "no subtitles" : "#{counted(inside, "subtitle track")} from inside the file"
    end

    def counted(count, noun) = "#{count} #{noun}#{"s" unless count == 1}"

    def import(item, report)
      reason = skip_reason(item)
      return skip(item, reason, report) if reason

      @out.puts("", %(=== "#{item.title}" (#{item.file})))
      Dir.mktmpdir("import_videos") { |dir| upload(item, subtitles_for(item, dir), report) }
    rescue Error => e
      fail_with(item, e.message, report)
    end

    def skip(item, reason, report)
      @out.puts(skipping(item, reason))
      report.skipped(item.title, reason)
    end

    def fail_with(item, reason, report)
      @out.puts("Failed: #{reason}")
      report.failed(item.title, reason)
    end

    # The files beside the video, or else the text tracks inside it.
    def subtitles_for(item, dir)
      beside = SubtitleFiles.beside(item.path)
      beside.empty? ? @embedded.extract(item.path, dir) : beside
    end

    # The log records a filed video before its subtitles go, so a refused
    # subtitle can never lead to the video being uploaded twice.
    def upload(item, subtitles, report)
      filed = @importer.call(item.path, title: item.title)
      log.record(item.title, filed["id"])
      @out.puts(%(Filed "#{filed["title"]}" as video #{filed["id"]} (#{filed["status"]}).))
      @subtitle_upload.call(filed["id"], subtitles).each { |problem| report.check(item.title, filed["id"], problem) }
      report.uploaded(item.title, filed["id"])
    end
  end
end
