module VideoImport
  # PUTs a file to a presigned storage URL, streaming it from disk.
  class StorageUpload
    # Storage answers only once the whole body is in, and may take a while
    # to confirm a large one.
    READ_TIMEOUT = 600

    def initialize(url:, headers:, out:)
      @uri = URI(url)
      @headers = headers
      @out = out
    end

    def put(source)
      response = source.open { |file| Connection.deliver(uri, request_for(source, file), read_timeout: READ_TIMEOUT) }
      return if response.is_a?(Net::HTTPSuccess)

      raise Error, "storage rejected the upload (#{response.code}): #{reason(response.body.to_s)}"
    end

    private

    attr_reader :uri, :headers, :out

    # The presigned URL signs Content-Length, so the body goes out as one
    # sized stream, never chunked.
    def request_for(source, file)
      Net::HTTP::Put.new(uri, headers).tap do |request|
        request.content_length = source.byte_size
        request.body_stream = Progress.new(file, Meter.new(label: "Uploading #{source.filename}", total: source.byte_size, out: out))
      end
    end

    # S3-style storage explains a refusal in XML: <Code> and <Message>.
    def reason(body)
      details = [body[%r{<Code>(.*?)</Code>}, 1], body[%r{<Message>(.*?)</Message>}, 1]].compact
      details.empty? ? "no details" : details.join(": ")
    end
  end
end
