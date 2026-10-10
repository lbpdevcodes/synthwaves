require "rails_helper"

RSpec.describe "Track uploads", type: :request do
  let(:user) { create(:user) }
  let(:album) { create(:album, title: "Landing Album", user: user) }

  before { login_user(user) }

  def audio_blob(filename)
    ActiveStorage::Blob.create_and_upload!(
      io: Rails.root.join("spec/fixtures/files/test.mp3").open,
      filename: filename,
      content_type: "audio/mpeg"
    )
  end

  describe "GET /track_uploads/new" do
    it "opens a multi-file upload into the album in the modal" do
      get new_track_upload_path(album_id: album.id), headers: {"Turbo-Frame" => "modal"}

      form = Nokogiri::HTML(response.body).at_css("turbo-frame#modal dialog form[action='#{track_uploads_path}']")
      expect(form["data-controller"]).to include("bulk-upload")
      expect(form.at_css("input[type='hidden'][name='album_id']")["value"]).to eq(album.id.to_s)
      expect(form.at_css("input[type='file'][multiple][accept*='audio']")).to be_present
    end

    it "asks for an album title, suggesting the artist's albums, when opened from an artist" do
      get new_track_upload_path(artist_id: album.artist.id)

      doc = Nokogiri::HTML(response.body)
      input = doc.at_css("input[name='album_title']")
      expect(doc.css("datalist##{input["list"]} option").map { |o| o["value"] }).to eq(["Landing Album"])
    end

    it "returns not found for another user's album" do
      get new_track_upload_path(album_id: create(:album).id)
      expect(response).to have_http_status(:not_found)
    end

    it "is offered from the album menu and the artist page, opening in the modal" do
      get album_path(album)
      expect(Nokogiri::HTML(response.body).at_css("a[href='#{new_track_upload_path(album_id: album.id)}']")["data-turbo-frame"]).to eq("modal")

      get artist_path(album.artist)
      expect(Nokogiri::HTML(response.body).at_css("a[href='#{new_track_upload_path(artist_id: album.artist.id)}']")["data-turbo-frame"]).to eq("modal")
    end
  end

  describe "POST /track_uploads" do
    it "files each uploaded file as a track in the album, titled by its file name" do
      blobs = [audio_blob("01 Opening.mp3"), audio_blob("02 Closing.mp3")]

      post track_uploads_path, params: {album_id: album.id, signed_blob_ids: blobs.map(&:signed_id)}, headers: {"Turbo-Frame" => "modal"}

      tracks = album.tracks.order(:title)
      expect(tracks.map(&:title)).to eq(["01 Opening", "02 Closing"])
      expect(tracks.map(&:artist).uniq).to eq([album.artist])
      expect(tracks.map { |t| t.audio_file.blob }).to match_array(blobs)
      expect(tracks.map(&:file_format).uniq).to eq(["mp3"])
      expect(Nokogiri::HTML(response.body).at_css("turbo-stream[action='visit']")["location"]).to eq(album_path(album))
      expect(flash[:notice]).to eq("2 tracks added to Landing Album.")
    end

    it "reads each track's tags in the background" do
      blob = audio_blob("song.mp3")

      post track_uploads_path, params: {album_id: album.id, signed_blob_ids: [blob.signed_id]}

      expect(MetadataExtractionJob).to have_been_enqueued.with(album.tracks.sole.id)
    end

    it "leaves tag reading to the converter for formats it converts" do
      blob = audio_blob("song.wav")

      expect {
        post track_uploads_path, params: {album_id: album.id, signed_blob_ids: [blob.signed_id]}
      }.not_to have_enqueued_job(MetadataExtractionJob)
    end

    it "creates the album under the artist when uploading from the artist page" do
      artist = album.artist
      post track_uploads_path, params: {artist_id: artist.id, album_title: "Fresh Session", signed_blob_ids: [audio_blob("take.mp3").signed_id]}

      new_album = artist.albums.find_by!(title: "Fresh Session")
      expect(new_album.tracks.map(&:title)).to eq(["take"])
      expect(response).to redirect_to(album_path(new_album))
    end

    it "asks for files when none were uploaded" do
      post track_uploads_path, params: {album_id: album.id}, headers: {"Turbo-Frame" => "modal"}

      expect(response).to have_http_status(:unprocessable_content)
      expect(Nokogiri::HTML(response.body).at_css("turbo-frame#modal dialog").text).to include("Choose at least one audio file")
    end

    it "asks for an album title when uploading from the artist page without one" do
      post track_uploads_path, params: {artist_id: album.artist.id, signed_blob_ids: [audio_blob("take.mp3").signed_id]}

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Album title can&#39;t be blank")
    end

    it "returns not found for another user's album" do
      post track_uploads_path, params: {album_id: create(:album).id, signed_blob_ids: [audio_blob("x.mp3").signed_id]}
      expect(response).to have_http_status(:not_found)
    end
  end
end
