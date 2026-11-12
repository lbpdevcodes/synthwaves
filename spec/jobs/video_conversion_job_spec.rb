require "rails_helper"

RSpec.describe VideoConversionJob, type: :job do
  let(:user) { create(:user) }

  describe "#perform" do
    it "sets status to failed on error" do
      video = create(:video, user: user, status: "processing", file_format: "mkv")
      video.file.attach(io: StringIO.new("fake video"), filename: "test.mkv", content_type: "video/x-matroska")

      allow(VideoMetadataExtractor).to receive(:call).and_raise(StandardError, "ffprobe failed")

      described_class.new.perform(video.id)

      video.reload
      expect(video.status).to eq("failed")
      expect(video.error_message).to eq("ffprobe failed")
    end

    it "does nothing when no file is attached" do
      video = create(:video, user: user, status: "processing")

      expect { described_class.new.perform(video.id) }.not_to raise_error
      expect(video.reload.status).to eq("processing")
    end
  end

  describe "#conversion_strategy" do
    let(:job) { described_class.new }

    it "returns :none for h264+aac in mp4 container" do
      metadata = {video_codec: "h264", audio_codec: "aac", audio_channels: 2, container: "mov,mp4,m4a,3gp,3g2,mj2"}
      expect(job.send(:conversion_strategy, metadata)).to eq(:none)
    end

    it "returns :remux for h264+aac in mkv container" do
      metadata = {video_codec: "h264", audio_codec: "aac", audio_channels: 2, container: "matroska,webm"}
      expect(job.send(:conversion_strategy, metadata)).to eq(:remux)
    end

    it "returns :transcode_audio for h264 with non-aac audio" do
      metadata = {video_codec: "h264", audio_codec: "opus", container: "matroska,webm"}
      expect(job.send(:conversion_strategy, metadata)).to eq(:transcode_audio)
    end

    it "returns :transcode_audio for h264+ac3 in mp4 container" do
      metadata = {video_codec: "h264", audio_codec: "ac3", container: "mov,mp4,m4a,3gp,3g2,mj2"}
      expect(job.send(:conversion_strategy, metadata)).to eq(:transcode_audio)
    end

    it "returns :full for non-h264 video" do
      metadata = {video_codec: "vp9", audio_codec: "aac", container: "matroska,webm"}
      expect(job.send(:conversion_strategy, metadata)).to eq(:full)
    end

    it "returns :full when video_codec is nil" do
      metadata = {video_codec: nil}
      expect(job.send(:conversion_strategy, metadata)).to eq(:full)
    end

    it "returns :transcode_audio for h264+aac+mp4 with 6-channel surround audio" do
      metadata = {video_codec: "h264", audio_codec: "aac", audio_channels: 6, container: "mov,mp4,m4a,3gp,3g2,mj2"}
      expect(job.send(:conversion_strategy, metadata)).to eq(:transcode_audio)
    end

    it "returns :transcode_audio for h264+aac+mkv with 6-channel surround audio" do
      metadata = {video_codec: "h264", audio_codec: "aac", audio_channels: 6, container: "matroska,webm"}
      expect(job.send(:conversion_strategy, metadata)).to eq(:transcode_audio)
    end

    it "returns :none for h264+aac+mp4 with stereo audio" do
      metadata = {video_codec: "h264", audio_codec: "aac", audio_channels: 2, container: "mov,mp4,m4a,3gp,3g2,mj2"}
      expect(job.send(:conversion_strategy, metadata)).to eq(:none)
    end
  end

  describe "#needs_audio_normalization?" do
    let(:job) { described_class.new }

    it "returns false for nil audio_channels (no audio stream)" do
      metadata = {audio_channels: nil}
      expect(job.send(:needs_audio_normalization?, metadata)).to be false
    end

    it "returns false for mono audio" do
      metadata = {audio_channels: 1}
      expect(job.send(:needs_audio_normalization?, metadata)).to be false
    end

    it "returns false for stereo audio" do
      metadata = {audio_channels: 2}
      expect(job.send(:needs_audio_normalization?, metadata)).to be false
    end

    it "returns true for 6-channel surround audio" do
      metadata = {audio_channels: 6}
      expect(job.send(:needs_audio_normalization?, metadata)).to be true
    end

    it "returns true for 8-channel audio" do
      metadata = {audio_channels: 8}
      expect(job.send(:needs_audio_normalization?, metadata)).to be true
    end
  end

  describe "conversion paths" do
    let(:job) { described_class.new }

    it "calls remux_to_mp4 for remux strategy" do
      video = create(:video, user: user, status: "processing", file_format: "mkv")
      video.file.attach(io: StringIO.new("fake video"), filename: "test.mkv", content_type: "video/x-matroska")

      metadata = {video_codec: "h264", audio_codec: "aac", audio_channels: 2, container: "matroska,webm", duration: 10.0, width: 1920, height: 1080, bitrate: 5000}
      allow(VideoMetadataExtractor).to receive(:call).and_return(metadata)
      allow(job).to receive(:remux_to_mp4)
      allow(job).to receive(:generate_thumbnail)

      job.perform(video.id)

      expect(job).to have_received(:remux_to_mp4)
    end

    it "calls transcode_audio_to_mp4 for transcode_audio strategy" do
      video = create(:video, user: user, status: "processing", file_format: "mkv")
      video.file.attach(io: StringIO.new("fake video"), filename: "test.mkv", content_type: "video/x-matroska")

      metadata = {video_codec: "h264", audio_codec: "ac3", container: "matroska,webm", duration: 10.0, width: 1920, height: 1080, bitrate: 5000}
      allow(VideoMetadataExtractor).to receive(:call).and_return(metadata)
      allow(job).to receive(:transcode_audio_to_mp4)
      allow(job).to receive(:generate_thumbnail)

      job.perform(video.id)

      expect(job).to have_received(:transcode_audio_to_mp4)
    end

    it "calls transcode_audio_to_mp4 for surround h264+aac+mp4" do
      video = create(:video, user: user, status: "processing", file_format: "mp4")
      video.file.attach(io: StringIO.new("fake video"), filename: "test.mp4", content_type: "video/mp4")

      metadata = {video_codec: "h264", audio_codec: "aac", audio_channels: 6, container: "mov,mp4,m4a,3gp,3g2,mj2", duration: 10.0, width: 1920, height: 1080, bitrate: 5000}
      allow(VideoMetadataExtractor).to receive(:call).and_return(metadata)
      allow(job).to receive(:transcode_audio_to_mp4)
      allow(job).to receive(:generate_thumbnail)

      job.perform(video.id)

      expect(job).to have_received(:transcode_audio_to_mp4)
    end

    it "persists audio_channels to the video record" do
      video = create(:video, user: user, status: "processing", file_format: "mp4", audio_channels: nil)
      video.file.attach(io: StringIO.new("fake video"), filename: "test.mp4", content_type: "video/mp4")

      metadata = {video_codec: "h264", audio_codec: "aac", audio_channels: 2, container: "mov,mp4,m4a,3gp,3g2,mj2", duration: 10.0, width: 1920, height: 1080, bitrate: 5000}
      allow(VideoMetadataExtractor).to receive(:call).and_return(metadata)
      allow(job).to receive(:generate_thumbnail)

      job.perform(video.id)

      expect(video.reload.audio_channels).to eq(2)
    end

    it "calls convert_to_mp4 for full strategy" do
      video = create(:video, user: user, status: "processing", file_format: "mkv")
      video.file.attach(io: StringIO.new("fake video"), filename: "test.mkv", content_type: "video/x-matroska")

      metadata = {video_codec: "vp9", audio_codec: "opus", container: "matroska,webm", duration: 10.0, width: 1920, height: 1080, bitrate: 5000}
      allow(VideoMetadataExtractor).to receive(:call).and_return(metadata)
      allow(job).to receive(:convert_to_mp4)
      allow(job).to receive(:generate_thumbnail)

      job.perform(video.id)

      expect(job).to have_received(:convert_to_mp4)
    end
  end

  describe "thumbnail" do
    let(:job) { described_class.new }

    it "seeks to 10% of the video before it starts decoding" do
      video = create(:video, user: user, status: "processing")
      video.file.attach(io: StringIO.new("fake video"), filename: "test.mp4", content_type: "video/mp4")
      metadata = {video_codec: "h264", audio_codec: "aac", audio_channels: 2, container: "mov,mp4,m4a,3gp,3g2,mj2", duration: 5700.0}
      allow(VideoMetadataExtractor).to receive(:call).and_return(metadata)
      commands = []
      allow(job).to receive(:system) { |*args| commands << args }

      job.perform(video.id)

      thumbnail = commands.find { |args| args.include?("-vframes") }
      expect(thumbnail.index("-ss")).to be < thumbnail.index("-i")
      expect(thumbnail[thumbnail.index("-ss") + 1]).to eq("570.0")
    end

    it "takes the same frame as decoding up to that point does" do
      skip "needs ffmpeg and ffprobe on PATH" unless VideoClips.tools?

      Dir.mktmpdir do |dir|
        clip = VideoClips.h264_one_keyframe(dir)
        video = create(:video, user: user, status: "processing")
        video.file.attach(io: File.open(clip), filename: "long.mp4", content_type: "video/mp4")
        seek = (VideoMetadataExtractor.call(clip)[:duration] * 0.1).round(2).to_s
        decoded_up_to = File.join(dir, "reference.jpg")
        system("ffmpeg", "-v", "error", "-y", "-i", clip, "-ss", seek, "-vframes", "1", "-vf", "scale=640:-1", decoded_up_to, exception: true)

        described_class.perform_now(video.id)

        expect(Digest::MD5.hexdigest(video.reload.thumbnail.download)).to eq(Digest::MD5.file(decoded_up_to).hexdigest)
      end
    end
  end
end
