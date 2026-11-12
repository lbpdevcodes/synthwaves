require "rails_helper"

RSpec.describe "Subsonic Folders API", type: :request do
  let(:user) { create(:user, subsonic_password: "testpass") }
  let(:auth_params) { {u: user.email_address, p: "testpass", v: "1.16.1", c: "test", f: "json"} }

  describe "getFolders" do
    it "returns all folders with video counts" do
      folder1 = create(:folder, user: user, name: "Series A")
      folder2 = create(:folder, user: user, name: "Series B")
      create(:video, user: user, folder: folder1)
      create(:video, user: user, folder: folder1)
      create(:video, user: user, folder: folder2)
      create(:video, :processing, user: user, folder: folder2)

      get "/api/rest/getFolders", params: auth_params

      json = JSON.parse(response.body)
      folders = json["subsonic-response"]["folders"]["folder"]
      expect(folders.length).to eq(2)

      a = folders.find { |f| f["name"] == "Series A" }
      b = folders.find { |f| f["name"] == "Series B" }
      expect(a["videoCount"]).to eq(2)
      expect(b["videoCount"]).to eq(1)
    end

    it "does not return other users' folders" do
      other_user = create(:user)
      create(:folder, user: other_user, name: "Other folder")
      create(:folder, user: user, name: "My folder")

      get "/api/rest/getFolders", params: auth_params

      json = JSON.parse(response.body)
      folders = json["subsonic-response"]["folders"]["folder"]
      expect(folders.length).to eq(1)
      expect(folders.first["name"]).to eq("My folder")
    end
  end

  describe "getFolder" do
    it "returns folder with its videos" do
      folder = create(:folder, user: user, name: "My Series")
      create(:video, user: user, folder: folder, title: "Ep 1", season_number: 1, episode_number: 1)
      create(:video, user: user, folder: folder, title: "Ep 2", season_number: 1, episode_number: 2)
      create(:video, :processing, user: user, folder: folder, title: "Ep 3")

      get "/api/rest/getFolder", params: auth_params.merge(id: folder.id)

      json = JSON.parse(response.body)
      f = json["subsonic-response"]["folder"]
      expect(f["id"]).to eq(folder.id.to_s)
      expect(f["name"]).to eq("My Series")
      expect(f["video"].length).to eq(2)
      expect(f["video"].map { |v| v["title"] }).to eq(["Ep 1", "Ep 2"])
    end

    it "returns error for nonexistent folder" do
      get "/api/rest/getFolder", params: auth_params.merge(id: 999999)

      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["error"]["code"]).to eq(70)
    end
  end
end
