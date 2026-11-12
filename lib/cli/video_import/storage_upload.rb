module VideoImport
  # PUTs a file, or one part of it, to a presigned storage URL, streaming it
  # from disk and moving the meter it is given as the bytes go.
  class StorageUpload
    # Storage answers only once the whole body is in, and may take a while
    # to confirm a large one.
    READ_TIMEOUT = 600

    def initialize(url:, headers:, meter:)
      @uri = URI(url)
      @headers = headers
      @meter = meter
    end

    # Returns the ETag storage gave what it took.
    def put(source)
      response = source.open { |file| Connection.deliver(uri, request_for(source, file), read_timeout: READ_TIMEOUT) }
      return response["ETag"] if response.is_a?(Net::HTTPSuccess)

      raise Error, "storage rejected the upload (#{response.code}): #{reason(response.body.to_s)}"
    end

    private

    attr_reader :uri, :headers, :meter

    # The presigned URL signs Content-Length, so the body goes out as one
    # sized stream, never chunked.
    def request_for(source, file)
      Net::HTTP::Put.new(uri, headers).tap do |request|
        request.content_length = source.byte_size
        request.body_stream = Progress.new(file, meter)
      end
    end

    # S3-style storage explains a refusal in XML: <Code> and <Message>.
    def reason(body)
      details = [body[%r{<Code>(.*?)</Code>}, 1], body[%r{<Message>(.*?)</Message>}, 1]].compact
      details.empty? ? "no details" : details.join(": ")
    end
  end
end
