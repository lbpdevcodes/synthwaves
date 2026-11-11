module VideoImport
  # One HTTP exchange. A network failure becomes an Error naming the host.
  module Connection
    FAILURES = [SystemCallError, IOError, SocketError, Timeout::Error, OpenSSL::SSL::SSLError].freeze

    module_function

    def deliver(uri, request, read_timeout: 60)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: read_timeout) { |http| http.request(request) }
    rescue *FAILURES => e
      raise Error, "connection to #{uri.host} failed: #{e.message}"
    end
  end
end
