require "rails_helper"

RSpec.describe "MCP agent gateway", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:secret_key) { "test_secret_key_123" }
  let(:auth) { basic_headers(api_key.client_id, secret_key) }

  def basic_headers(client_id, secret_key)
    {"Authorization" => "Basic #{Base64.strict_encode64("#{client_id}:#{secret_key}")}"}
  end

  def rpc_post(body, headers: {})
    post "/mcp",
      params: body.is_a?(String) ? body : JSON.generate(body),
      headers: {"CONTENT_TYPE" => "application/json"}.merge(headers)
  end

  def rpc_request(method, params: nil, id: 1)
    request = {"jsonrpc" => "2.0", "id" => id, "method" => method}
    request["params"] = params if params
    request
  end

  describe "authentication" do
    it "rejects a request without credentials with 401 and a JSON-RPC error" do
      rpc_post(rpc_request("ping"))

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to eq('Basic realm="Synthwaves MCP"')
      body = response.parsed_body
      expect(body["id"]).to be_nil
      expect(body.dig("error", "code")).to eq(-32_001)
    end

    it "rejects a wrong secret key" do
      rpc_post(rpc_request("ping"), headers: basic_headers(api_key.client_id, "wrong_secret"))

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects an unknown client_id" do
      rpc_post(rpc_request("ping"), headers: basic_headers("bc_nonexistent", secret_key))

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects an expired key" do
      api_key.update!(expires_at: 1.hour.ago)

      rpc_post(rpc_request("ping"), headers: auth)

      expect(response).to have_http_status(:unauthorized)
    end

    it "touches last_used_at and last_used_ip on a valid request" do
      rpc_post(rpc_request("ping"), headers: auth)

      api_key.reload
      expect(api_key.last_used_at).to be_present
      expect(api_key.last_used_ip).to be_present
    end
  end

  describe "protocol handling" do
    it "answers the initialize handshake with server info and instructions" do
      rpc_post(rpc_request("initialize", params: {
        "protocolVersion" => "2025-06-18",
        "capabilities" => {},
        "clientInfo" => {"name" => "spec", "version" => "1.0"}
      }), headers: auth)

      expect(response).to have_http_status(:ok)
      result = response.parsed_body.fetch("result")
      expect(result.dig("serverInfo", "name")).to eq("synthwaves")
      expect(result.dig("serverInfo", "version")).to eq(AgentGateway::Server::VERSION)
      expect(result["instructions"]).to include("playlist")
    end

    it "returns 202 with an empty body for notifications" do
      rpc_post({"jsonrpc" => "2.0", "method" => "notifications/initialized"}, headers: auth)

      expect(response).to have_http_status(:accepted)
      expect(response.body).to be_empty
    end

    it "answers ping" do
      rpc_post(rpc_request("ping"), headers: auth)

      expect(response.parsed_body.fetch("result")).to eq({})
    end

    it "returns -32700 for a malformed JSON body" do
      rpc_post('{"jsonrpc": "2.0", "id": 1, "met', headers: auth)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("error", "code")).to eq(-32_700)
    end

    it "returns -32602 when calling an unknown tool" do
      rpc_post(rpc_request("tools/call", params: {"name" => "nope", "arguments" => {}}), headers: auth)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("error", "code")).to eq(-32_602)
    end

    it "lists exactly the curated tool set" do
      rpc_post(rpc_request("tools/list"), headers: auth)

      names = response.parsed_body.dig("result", "tools").map { |tool| tool.fetch("name") }
      expect(names).to contain_exactly(
        "search", "match_tracks",
        "list_artists", "get_artist", "list_albums", "get_album", "list_tracks", "get_track",
        "list_playlists", "get_playlist",
        "create_playlist", "update_playlist", "delete_playlist",
        "add_tracks_to_playlist", "remove_playlist_track", "remove_playlist_tracks",
        "reorder_playlist",
        "create_playlist_from_album",
        "upload_track", "import_youtube_playlist",
        "list_favorites", "favorite", "unfavorite"
      )
    end

    it "handles a batch of requests, returning one response per request" do
      rpc_post([rpc_request("ping", id: 1), rpc_request("ping", id: 2)], headers: auth)

      bodies = response.parsed_body
      expect(bodies).to be_an(Array)
      expect(bodies.map { |body| body.fetch("id") }).to contain_exactly(1, 2)
      expect(bodies.map { |body| body.fetch("result") }).to all eq({})
    end
  end

  describe "HTTP semantics" do
    it "rejects GET with 405 and an Allow header" do
      get "/mcp"

      expect(response).to have_http_status(:method_not_allowed)
      expect(response.headers["Allow"]).to eq("POST")
    end

    it "rejects DELETE with 405" do
      delete "/mcp"

      expect(response).to have_http_status(:method_not_allowed)
    end
  end

  describe "rate limiting" do
    it "returns 429 with a JSON-RPC error after 60 requests in a minute" do
      60.times { rpc_post(rpc_request("ping"), headers: auth) }

      rpc_post(rpc_request("ping"), headers: auth)

      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body.dig("error", "code")).to eq(-32_000)
    end
  end
end
