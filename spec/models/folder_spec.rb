require "rails_helper"

RSpec.describe Folder, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should have_many(:videos).dependent(:nullify) }
    it { should have_one_attached(:cover_image) }
    it { should have_many(:favorites).dependent(:destroy) }
  end

  describe "validations" do
    subject { create(:folder) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name).scoped_to(:user_id) }
  end

  describe "#cover" do
    def attach_image(attachment, name)
      attachment.attach(io: StringIO.new("image"), filename: name, content_type: "image/jpeg")
    end

    it "is the cover image when one is attached" do
      folder = create(:folder)
      attach_image(folder.cover_image, "cover.jpg")

      expect(folder.cover.filename.to_s).to eq("cover.jpg")
    end

    it "falls back to the thumbnail of the first ready video in episode order" do
      folder = create(:folder)
      later = create(:video, user: folder.user, folder: folder, season_number: 1, episode_number: 2)
      first = create(:video, user: folder.user, folder: folder, season_number: 1, episode_number: 1)
      processing = create(:video, :processing, user: folder.user, folder: folder, season_number: 0, episode_number: 1)
      attach_image(later.thumbnail, "later.jpg")
      attach_image(first.thumbnail, "first.jpg")
      attach_image(processing.thumbnail, "processing.jpg")

      expect(folder.cover.filename.to_s).to eq("first.jpg")
    end

    it "is nil when there is no cover image and no thumbnail" do
      folder = create(:folder)
      create(:video, user: folder.user, folder: folder)

      expect(folder.cover).to be_nil
    end
  end

  describe ".search" do
    it "returns folders matching by name" do
      matching = create(:folder, name: "Season One")
      non_matching = create(:folder, name: "Movies")

      results = Folder.search("Season")

      expect(results).to include(matching)
      expect(results).not_to include(non_matching)
    end

    it "returns all folders when query is blank" do
      folders = create_list(:folder, 3)
      expect(Folder.search("")).to match_array(folders)
    end

    it "returns all folders when query is nil" do
      folders = create_list(:folder, 3)
      expect(Folder.search(nil)).to match_array(folders)
    end
  end
end
