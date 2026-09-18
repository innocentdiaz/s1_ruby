# frozen_string_literal: true

require_relative "system_one_http"

module S1
  module Providers
    # The System One HTTP contract (SystemOneHTTP) pointed at an address you
    # supply. POST {base_url}{path}, path /v1/systemone unless set. A key is
    # sent as a bearer token when set; a model name is sent when set and left
    # for the server to interpret. support/laya_server.py is one such server.
    #
    #   S1.configure { |c| c.provider = :protocol; c.protocol.base_url = "http://127.0.0.1:8090" }
    class Protocol < Base
      include SystemOneHTTP

      settings :protocol, base_url: -> { ENV.fetch("S1_BASE_URL", nil) },
                          path: -> { ENV.fetch("S1_PATH", PATH) },
                          api_key: -> { ENV.fetch("S1_API_KEY", nil) },
                          model: -> { ENV.fetch("S1_MODEL", nil) },
                          max_retries: 2

      def initialize(base_url: nil, path: nil, api_key: nil, model: nil, max_retries: nil, logger: nil)
        super()
        section = S1.config.protocol
        @base_url = base_url || section.base_url
        @path = path || section.path
        @api_key = api_key || section.api_key
        @model = model || section.model
        @max_retries = max_retries || section.max_retries
        @logger = logger || S1.config.logger
      end

      def call(request)
        raise InvalidRequestError, "no base_url: set S1.config.protocol.base_url or S1_BASE_URL" if @base_url.to_s.empty?

        super
      end
    end
  end
end
