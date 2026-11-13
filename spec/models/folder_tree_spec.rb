require "rails_helper"

RSpec.describe FolderTree do
  let(:user) { create(:user) }
  let!(:tv) { create(:folder, user: user, name: "TV") }
  let!(:the_wire) { create(:folder, user: user, parent: tv, name: "The Wire") }
  let!(:south_park) { create(:folder, user: user, parent: tv, name: "South Park") }
  let!(:season_one) { create(:folder, user: user, parent: south_park, name: "Season 1") }
  let!(:movies) { create(:folder, user: user, name: "Movies") }
  let(:tree) { FolderTree.new(user.folders.to_a) }

  it "lists folders parents first, siblings by name" do
    expect(tree.to_a).to eq([movies, tv, south_park, season_one, the_wire])
  end

  it "leaves out a folder not saved yet" do
    user.folders.new(name: "Unsaved")

    expect(tree.to_a).to eq([movies, tv, south_park, season_one, the_wire])
  end

  it "labels a folder with its path" do
    expect(tree.label(season_one)).to eq("TV › South Park › Season 1")
  end

  it "offers every folder but the folder itself and those inside it as a parent" do
    expect(tree.possible_parents_for(south_park)).to eq([movies, tv, the_wire])
  end

  it "offers every folder as the parent of a new one" do
    expect(tree.possible_parents_for(Folder.new)).to eq(tree.to_a)
  end
end
