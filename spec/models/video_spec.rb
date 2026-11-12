require "rails_helper"

RSpec.describe Video, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:folder).optional }
    it { should have_one_attached(:file) }
    it { should have_one_attached(:thumbnail) }
    it { should have_many(:favorites).dependent(:destroy) }
    it { should have_many(:subtitles).class_name("VideoSubtitle").dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:title) }

    it "refuses a folder from another user's library" do
      video = build(:video, user: create(:user), folder: create(:folder))

      expect(video).not_to be_valid
      expect(video.errors[:folder]).to include("must be one of your folders")
    end

    it "still saves other changes to a video already filed in a foreign folder" do
      video = create(:video)
      video.update_column(:folder_id, create(:folder).id)

      expect(video.reload.update(status: "ready", title: "Converted")).to be true
    end

    it "accepts a folder from the video's own library" do
      user = create(:user)
      video = build(:video, user: user, folder: create(:folder, user: user))

      expect(video).to be_valid
    end
  end

  describe "#subtitles" do
    it "lists a video's subtitles by label" do
      video = create(:video)
      create(:video_subtitle, video: video, label: "Spanish")
      create(:video_subtitle, video: video, label: "English")

      expect(video.subtitles.map(&:label)).to eq(%w[English Spanish])
    end
  end

  describe ".ready" do
    it "returns only videos with ready status" do
      ready_video = create(:video, status: "ready")
      processing_video = create(:video, :processing)
      failed_video = create(:video, :failed)

      expect(Video.ready).to include(ready_video)
      expect(Video.ready).not_to include(processing_video, failed_video)
    end
  end

  describe ".search" do
    it "returns videos matching by title" do
      matching = create(:video, title: "Concert Footage")
      non_matching = create(:video, title: "Tutorial")

      results = Video.search("Concert")

      expect(results).to include(matching)
      expect(results).not_to include(non_matching)
    end

    it "returns all videos when query is blank" do
      videos = create_list(:video, 3)
      expect(Video.search("")).to match_array(videos)
    end

    it "returns all videos when query is nil" do
      videos = create_list(:video, 3)
      expect(Video.search(nil)).to match_array(videos)
    end
  end

  describe ".standalone" do
    it "returns videos without a folder" do
      standalone = create(:video)
      in_folder = create(:video, :in_folder)

      expect(Video.standalone).to include(standalone)
      expect(Video.standalone).not_to include(in_folder)
    end
  end

  describe ".in_folder" do
    it "returns videos with a folder" do
      standalone = create(:video)
      in_folder = create(:video, :in_folder)

      expect(Video.in_folder).to include(in_folder)
      expect(Video.in_folder).not_to include(standalone)
    end
  end

  describe ".ordered" do
    it "orders by season_number then episode_number" do
      v3 = create(:video, season_number: 2, episode_number: 1)
      v1 = create(:video, season_number: 1, episode_number: 1)
      v2 = create(:video, season_number: 1, episode_number: 3)

      expect(Video.ordered).to eq([v1, v2, v3])
    end
  end

  describe "callbacks" do
    it "enqueues VideoConversionJob after create" do
      video = build(:video, status: "processing")
      video.file.attach(
        io: StringIO.new("fake video"),
        filename: "test.mp4",
        content_type: "video/mp4"
      )

      expect { video.save! }.to have_enqueued_job(VideoConversionJob).with(video.id)
    end

    it "enqueues no conversion for a video filed ready" do
      video = build(:video, status: "ready")
      video.file.attach(io: StringIO.new("fake video"), filename: "test.mp4", content_type: "video/mp4")

      expect { video.save! }.not_to have_enqueued_job(VideoConversionJob)
    end

    # ActiveStorage's video analyzer downloads the whole file to read it,
    # and nothing reads what it finds: VideoConversionJob, or the details
    # bin/import_video sends, fill the video's own columns.
    it "never analyzes its file, which would download it" do
      analyze = ActiveStorage.analyze
      ActiveStorage.analyze = :later # production's default; the test environment analyzes lazily
      uploaded = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("fake video"), filename: "test.mp4", content_type: "video/mp4")
      video = build(:video, status: "ready")
      video.file.attach(uploaded) # a direct upload, as the import endpoint attaches it

      expect { video.save! }.not_to have_enqueued_job(ActiveStorage::AnalyzeJob)
    ensure
      ActiveStorage.analyze = analyze
    end
  end
end
