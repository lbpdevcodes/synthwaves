module VideoImport
  # Uploads a video file to storage, then files it as a Video on the server.
  class Importer
    def initialize(api:, out:)
      @api = api
      @out = out
    end

    def call(path, **video)
      source = SourceFile.at(path)
      upload = @api.create_direct_upload(source)
      StorageUpload.new(url: upload.url, headers: upload.headers, out: @out).put(source)
      @api.register_video(upload.signed_id, **video)
    end
  end
end
