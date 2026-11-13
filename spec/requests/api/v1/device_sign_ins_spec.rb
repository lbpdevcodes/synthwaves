require "rails_helper"

RSpec.describe "API::V1::DeviceSignIns", type: :request do
  describe "POST /api/v1/device_sign_ins" do
    it "gives the TV a code to show, the page to enter it on, and a secret to check in with" do
      post "/api/v1/device_sign_ins", params: {device_name: "Apple TV"}, as: :json

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["code"]).to match(/\A[A-Z0-9]{4}-[A-Z0-9]{4}\z/)
      expect(json["url"]).to eq("http://www.example.com/link")
      expect(json["url_with_code"]).to eq("http://www.example.com/link?code=#{json["code"]}")
      expect(json["secret"].length).to be >= 40
      expect(json["expires_in"]).to eq(600)
      expect(json["interval"]).to eq(5)
    end

    it "stops giving one address codes after 10 in 10 minutes" do
      10.times { post "/api/v1/device_sign_ins", params: {device_name: "Apple TV"}, as: :json }

      post "/api/v1/device_sign_ins", params: {device_name: "Apple TV"}, as: :json

      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body).to eq("error" => "Too many attempts. Try again later.")
    end

    it "tells every cache not to keep the secret" do
      post "/api/v1/device_sign_ins", params: {device_name: "Apple TV"}, as: :json

      expect(response.headers["Cache-Control"]).to eq("no-store")
    end
  end

  describe "POST /api/v1/device_sign_in_claim" do
    let!(:sign_in) { DeviceSignIn.start(device_name: "Apple TV") }

    def check_in(secret = sign_in.secret)
      post "/api/v1/device_sign_in_claim", params: {secret:}, as: :json
    end

    it "stops answering one address after 30 check-ins in a minute" do
      30.times { check_in }

      check_in

      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body).to eq("error" => "Too many attempts. Try again later.")
    end

    it "tells the TV to keep waiting until someone enters the code" do
      check_in

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body).to eq("status" => "pending")
    end

    context "once someone has entered the code" do
      let(:user) { create(:user, subsonic_password: "tv-subsonic-pw") }

      before { sign_in.approve(user) }

      it "hands the TV their email and Subsonic password" do
        check_in

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq("email" => user.email_address, "subsonic_password" => "tv-subsonic-pw")
      end

      it "tells every cache not to keep them" do
        check_in

        expect(response.headers["Cache-Control"]).to eq("no-store")
      end

      it "won't hand them over after the code has expired" do
        travel DeviceSignIn::LIFETIME + 1.second

        check_in

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body).to eq("error" => "This code has expired. Get a new one on the TV.")
      end

      it "ignores a secret in the query string, which ends up in logs" do
        post "/api/v1/device_sign_in_claim?secret=#{CGI.escape(sign_in.secret)}"

        expect(response).to have_http_status(:not_found)
      end

      it "hands them over only once" do
        check_in
        check_in

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body).to eq("error" => "This code has expired. Get a new one on the TV.")
      end
    end
  end
end
