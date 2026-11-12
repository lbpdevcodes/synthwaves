module VideoImport
  # The synthwaves.fm endpoints an import talks to.
  class API
    DirectUpload = Data.define(:signed_id, :url, :headers)

    def initialize(host:, client_id:, secret_key:)
      @host = host
      @client_id = client_id
      @secret_key = secret_key
    end

    def create_direct_upload(source)
      json = post("api/import/direct_uploads", describe(source), failure: "direct upload rejected")
      upload = json.fetch("direct_upload")
      DirectUpload.new(signed_id: json.fetch("signed_id"), url: upload.fetch("url"), headers: upload.fetch("headers"))
    end

    def register_video(signed_blob_id, **video)
      post("api/import/videos", {signed_blob_id: signed_blob_id, **video}, failure: "video import rejected")
    end

    # The bytes go base64-encoded: a subtitle file need not be UTF-8, and
    # JSON must be. Array#pack, because Ruby 4 moved base64 out of the
    # standard library.
    def add_subtitle(video_id, path)
      body = {filename: File.basename(path), content_base64: [File.binread(path)].pack("m0")}
      post("api/import/videos/#{video_id}/subtitles", body, failure: "subtitle rejected")
    end

    private

    attr_reader :host, :client_id, :secret_key

    def describe(source)
      {filename: source.filename, byte_size: source.byte_size, checksum: source.checksum, content_type: source.content_type}
    end

    # Each call authenticates afresh: a JWT lasts an hour, and the upload
    # between creating the blob and filing the video can take longer.
    def post(path, body, failure:) = post_json(path, body, failure: failure, token: fresh_token)

    def fresh_token
      credentials = {client_id: client_id, secret_key: secret_key}
      post_json("api/v1/auth/token", credentials, failure: "authentication failed").fetch("token")
    end

    def post_json(path, body, failure:, token: nil)
      uri = URI.join("#{host}/", path)
      request = Net::HTTP::Post.new(uri, json_headers(token))
      request.body = JSON.generate(body)
      reply(Connection.deliver(uri, request), failure)
    end

    def json_headers(token)
      {"Content-Type" => "application/json", "Authorization" => ("Bearer #{token}" if token)}.compact
    end

    def reply(response, failure)
      json = parse(response.body)
      return json if response.is_a?(Net::HTTPSuccess) && json

      raise Error, "#{failure} (#{response.code}): #{reason(json)}"
    end

    def parse(body)
      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end

    def reason(json)
      return "the server replied with something other than JSON" unless json

      json["error"] || Array(json["errors"]).join(", ")
    end
  end
end
