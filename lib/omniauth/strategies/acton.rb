require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class Acton < OmniAuth::Strategies::OAuth2

      args [:client_id, :client_secret]

      option :name, "acton"
      option :provider_ignores_state, false

      option :client_options, {
        site: 'https://restapi.actonsoftware.com',
        authorize_url: '/authorize?scope=PRODUCTION',
        token_url: '/token'
      }

      option :authorize_options, [:scope, :response_type]

      def request_phase
        redirect client.auth_code.authorize_url(
          {
            scope: options[:scope]
          }
        )
      end

      def callback_phase
        error = request.params["error_reason"] || request.params["error"]
        if error
          fail!(error, CallbackError.new(request.params["error"],
            request.params["error_description"] ||
            request.params["error_reason"], request.params["error_uri"]))
        else
          conn = Faraday.new(:url => 'https://restapi.actonsoftware.com/token/') do |faraday|
            faraday.response :logger
            faraday.adapter  Faraday.default_adapter
          end

          result = conn.post do |req|
            req.headers['Content-Type'] = "application/x-www-form-urlencoded"
            req.headers['Cache-Control'] = "no-cache"
            req.body = "grant_type=authorization_code&code=#{request.params["code"]}&client_id=#{options[:client_id]}&client_secret=#{options[:client_secret]}&redirect_uri=#{options[:redirect_uri]}"
          end

          result = JSON.parse(result.body)

          env['omniauth.auth'] = {
            credentials: {
              token: result["access_token"],
              refresh_token: result["refresh_token"],
              expires_in: result["expires_in"]
            }
          }
          call_app!
        end
      rescue ::OAuth2::Error, CallbackError => e
        fail!(:invalid_credentials, e)
      rescue ::Timeout::Error, ::Errno::ETIMEDOUT => e
        fail!(:timeout, e)
      rescue ::SocketError => e
        fail!(:failed_to_connect, e)
      end

      def auth_hash
        hash = AuthHash.new(:provider => name, :uid => uid)
        hash.info = info unless skip_info?
        hash.credentials = credentials if credentials
        hash
      end
    end
  end
end

OmniAuth.config.add_camelization 'acton', 'Acton'
