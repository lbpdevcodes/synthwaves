module VideoImport
  # One HTTP exchange. A network failure becomes an Error naming the host.
  module Connection
    FAILURES = [SystemCallError, IOError, SocketError, Timeout::Error, OpenSSL::SSL::SSLError].freeze

    module_function

    # max_retries: 0 because Net::HTTP retries a PUT once by default, and a
    # retry would re-send a half-read body stream under the full Content-Length.
    def deliver(uri, request, read_timeout: 60)
      options = {use_ssl: uri.scheme == "https", read_timeout: read_timeout, max_retries: 0}
      Net::HTTP.start(uri.host, uri.port, **options) { |http| http.request(request) }
    rescue *FAILURES => e
      raise Error, "connection to #{uri.host} failed: #{e.message}"
    end
  end
end
