require "rails_helper"
require_relative "../../../../lib/cli/video_import"

# bin/import_video converts locally so the server has nothing expensive left to
# do. This runs the server's real conversion job on what the script uploads,
# so the two cannot drift apart without a failing spec. Each clip takes one of
# the job's conversion paths; the raw clip being replaced shows it does.
RSpec.describe "Videos prepared by bin/import_video, on the server" do
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

  {
    "is not H.264" => :mpeg4_surround,
    "is H.264 with sound that is not AAC" => :h264_ac3,
    "is H.264 with surround sound" => :h264_surround,
    "is H.264 and stereo AAC in Matroska" => :h264_matroska
  }.each do |shape, clip|
    context "with a video that #{shape}" do
      let(:raw) { VideoClips.public_send(clip, @dir) }

      it "replaces the raw file with a converted one" do
        video, uploaded = convert_on_server(raw)

        expect(video.status).to eq("ready")
        expect(video.file.blob).not_to eq(uploaded)
      end

      it "keeps the file the script prepared as it is" do
        encoder = VideoImport::Encoder.new(out: StringIO.new)

        encoder.prepare(VideoImport::SourceFile.at(raw)) do |prepared|
          video, uploaded = convert_on_server(prepared.path)

          expect(video.status).to eq("ready")
          expect(video.file.blob).to eq(uploaded)
        end
      end
    end
  end
end
