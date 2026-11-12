module VideoImport
  # Uploads a file larger than storage takes in one PUT, in parts: the server
  # starts the upload and signs each part's PUT, storage takes the parts, and
  # the server joins them into the blob it hands back.
  class MultipartUpload
    ATTEMPTS = 3

    def initialize(api:, out:, wait: method(:sleep))
      @api = api
      @out = out
      @wait = wait
    end

    def store(source)
      multipart = @api.start_multipart_upload(source)
      join(multipart, source)
      joined = true
      multipart.signed_id
    ensure # Ctrl-C included: parts left in storage are billed, and nothing lists them.
      throw_away(multipart) if multipart && !joined
    end

    private

    # Best effort: a failure here must not hide why the upload stopped.
    def throw_away(multipart)
      @api.abort_multipart_upload(multipart)
    rescue Error => e
      @out.puts("The parts sent so far stay in storage: #{e.message}")
    end

    def join(multipart, source)
      meter = Meter.uploading(source, @out)
      etags = FilePart.split(source, multipart.part_size).map { |part| send_part(multipart, part, meter) }
      @api.complete_multipart_upload(multipart, etags)
    end

    # A dropped part costs that part, not the file: it goes again, on a URL
    # signed afresh, since the last one may have expired.
    def send_part(multipart, part, meter, attempt: 1)
      target = @api.presign_part(multipart, part)
      etag = StorageUpload.new(url: target.url, headers: target.headers, meter: meter.from(part.offset)).put(part)
      {part_number: part.number, etag: etag}
    rescue Error => e
      raise Error, "#{part.filename} did not go up after #{ATTEMPTS} tries: #{e.message}" if attempt == ATTEMPTS

      @wait.call(attempt)
      send_part(multipart, part, meter, attempt: attempt + 1)
    end
  end
end
