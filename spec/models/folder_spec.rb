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
    it { should validate_uniqueness_of(:name).scoped_to(:user_id, :parent_id) }
  end

  describe "nesting" do
    it "holds subfolders" do
      tv = create(:folder, name: "TV")
      south_park = create(:folder, user: tv.user, parent: tv, name: "South Park")

      expect(tv.children).to eq([south_park])
    end

    it "lets two folders share a name under different parents" do
      user = create(:user)
      south_park = create(:folder, user: user, name: "South Park")
      the_wire = create(:folder, user: user, name: "The Wire")
      create(:folder, user: user, parent: south_park, name: "Season 1")

      expect(build(:folder, user: user, parent: the_wire, name: "Season 1")).to be_valid
    end

    it "refuses a second top-level folder with the same name" do
      tv = create(:folder, name: "TV")

      expect(build(:folder, user: tv.user, name: "TV")).not_to be_valid
    end

    it "refuses a parent from another user's library" do
      folder = build(:folder, parent: create(:folder))

      expect(folder).not_to be_valid
      expect(folder.errors[:parent]).to eq(["must be one of your folders"])
    end

    it "refuses to put a folder inside itself" do
      tv = create(:folder, name: "TV")

      expect(tv.update(parent: tv)).to be(false)
      expect(tv.errors[:base]).to eq(["TV can't go inside itself or anything inside it"])
    end

    it "refuses to put a folder inside one of its own subfolders" do
      tv = create(:folder, name: "TV")
      south_park = create(:folder, user: tv.user, parent: tv, name: "South Park")
      season_one = create(:folder, user: tv.user, parent: south_park, name: "Season 1")

      expect(tv.update(parent: season_one)).to be(false)
      expect(tv.reload.parent).to be_nil
    end
  end

  describe "#destroy" do
    let(:user) { create(:user) }
    let(:tv) { create(:folder, user: user, name: "TV") }
    let(:south_park) { create(:folder, user: user, parent: tv, name: "South Park") }

    it "moves the folder's videos up into its parent" do
      episode = create(:video, user: user, folder: south_park)

      south_park.destroy

      expect(episode.reload.folder).to eq(tv)
    end

    it "moves the folder's subfolders up into its parent" do
      season_one = create(:folder, user: user, parent: south_park, name: "Season 1")

      south_park.destroy

      expect(season_one.reload.parent).to eq(tv)
    end

    context "when a subfolder's name is already taken in the parent" do
      let!(:taken) { create(:folder, user: user, parent: tv, name: "Season 1") }
      let!(:season_one) { create(:folder, user: user, parent: south_park, name: "Season 1") }

      it "refuses, naming the clash" do
        expect(south_park.destroy).to be(false)
        expect(south_park.errors[:base]).to eq(["Can't delete South Park: TV already has one named Season 1."])
      end

      it "changes nothing" do
        episode = create(:video, user: user, folder: south_park)

        south_park.destroy

        expect(Folder.exists?(south_park.id)).to be(true)
        expect(season_one.reload.parent).to eq(south_park)
        expect(episode.reload.folder).to eq(south_park)
      end
    end

    it "names Videos when the clash is at the top level" do
      create(:folder, user: user, name: "Season 1")
      create(:folder, user: user, parent: tv, name: "Season 1")

      tv.destroy

      expect(tv.errors[:base]).to eq(["Can't delete TV: Videos already has one named Season 1."])
    end
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

    it "falls back to the first subfolder cover by name when it has no thumbnail of its own" do
      tv = create(:folder, name: "TV")
      the_wire = create(:folder, user: tv.user, parent: tv, name: "The Wire")
      south_park = create(:folder, user: tv.user, parent: tv, name: "South Park")
      attach_image(the_wire.cover_image, "wire.jpg")
      attach_image(south_park.cover_image, "south_park.jpg")

      expect(tv.cover.filename.to_s).to eq("south_park.jpg")
    end
  end

  describe "#add_videos" do
    it "files each video in the folder, moving it out of any other" do
      folder = create(:folder)
      loose = create(:video, user: folder.user)
      elsewhere = create(:video, user: folder.user, folder: create(:folder, user: folder.user))

      folder.add_videos([loose, elsewhere])

      expect(folder.videos.reload).to contain_exactly(loose, elsewhere)
    end

    it "files none of them when one belongs to another user" do
      folder = create(:folder)
      mine = create(:video, user: folder.user)

      expect { folder.add_videos([mine, create(:video)]) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(mine.reload.folder).to be_nil
    end
  end

  describe "#videos_to_add" do
    it "lists the owner's videos outside this folder, loose ones first, then by folder and title" do
      folder = create(:folder, user: folder_owner = create(:user))
      create(:video, user: folder_owner, folder: folder, title: "Already in")
      create(:video, title: "Someone else's")
      in_zulu = create(:video, user: folder_owner, folder: create(:folder, user: folder_owner, name: "Zulu"), title: "A")
      in_alpha = create(:video, user: folder_owner, folder: create(:folder, user: folder_owner, name: "Alpha"), title: "B")
      loose_b = create(:video, user: folder_owner, title: "Loose B")
      loose_a = create(:video, :processing, user: folder_owner, title: "Loose A")

      expect(folder.videos_to_add).to eq([loose_a, loose_b, in_alpha, in_zulu])
    end
  end

  describe "#remove_videos" do
    it "takes the folder's own videos out and leaves other folders' videos alone" do
      folder = create(:folder)
      inside = create(:video, user: folder.user, folder: folder)
      other_folder = create(:folder, user: folder.user)
      elsewhere = create(:video, user: folder.user, folder: other_folder)

      folder.remove_videos([inside, elsewhere])

      expect(inside.reload.folder).to be_nil
      expect(elsewhere.reload.folder).to eq(other_folder)
    end
  end

  describe ".find_or_create_named!" do
    let(:user) { create(:user) }
    let(:tv) { create(:folder, user: user, name: "TV") }

    it "reuses the one folder with that name, wherever it sits" do
      the_wire = create(:folder, user: user, parent: tv, name: "The Wire")

      expect(Folder.find_or_create_named!(user, "The Wire")).to eq(the_wire)
    end

    it "creates a top-level folder when none has that name" do
      folder = Folder.find_or_create_named!(user, "The Wire")

      expect(folder).to have_attributes(user: user, name: "The Wire", parent: nil, persisted?: true)
    end

    it "refuses a name several folders share, naming each by its path" do
      %w[South\ Park The\ Wire].each do |show|
        create(:folder, user: user, parent: create(:folder, user: user, parent: tv, name: show), name: "Season 1")
      end

      expect { Folder.find_or_create_named!(user, "Season 1") }.to raise_error(
        Folder::AmbiguousName, "Several folders are named Season 1: TV › South Park › Season 1 and TV › The Wire › Season 1"
      )
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
