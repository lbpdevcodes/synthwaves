require "rails_helper"
require_relative "../../../../lib/cli/video_import"

# bin/import_video encodes locally so the server has nothing expensive left to
# do. This runs the server's real conversion job on what the script uploads,
# so the two cannot drift apart without a failing spec.
RSpec.describe "Videos encoded by bin/import_video, on the server" do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  before { skip "needs ffmpeg and ffprobe on PATH" unless VideoClips.tools? }

  def convert_on_server(path)
    video = create(:video, :processing)
    video.file.attach(io: File.open(path), filename: File.basename(path))
    uploaded = video.file.blob
    VideoConversionJob.perform_now(video.id)
    [video.reload, uploaded]
  end

  it "replaces a raw non-H.264 upload with a converted file" do
    video, uploaded = convert_on_server(VideoClips.mpeg4_surround(@dir))

    expect(video.status).to eq("ready")
    expect(video.file.blob).not_to eq(uploaded)
  end

  it "keeps the file the script encoded as it is" do
    encoder = VideoImport::Encoder.new(out: StringIO.new)

    encoder.prepare(VideoImport::SourceFile.at(VideoClips.mpeg4_surround(@dir))) do |encoded|
      video, uploaded = convert_on_server(encoded.path)

      expect(video.status).to eq("ready")
      expect(video.file.blob).to eq(uploaded)
    end
  end
end
