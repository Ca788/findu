module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      token = extract_token
      reject_unauthorized_connection unless token.present?

      payload = decode_token(token)
      reject_unauthorized_connection unless payload

      user = User.find_by(id: payload["sub"])
      reject_unauthorized_connection unless user && user.jti == payload["jti"]

      user
    rescue JWT::DecodeError, JWT::ExpiredSignature
      reject_unauthorized_connection
    end

    def extract_token
      request.params[:token].presence ||
        request.params[:access_token].presence ||
        bearer_token_from_header
    end

    def bearer_token_from_header
      header = request.headers["Authorization"].to_s
      header.start_with?("Bearer ") ? header.split(" ", 2).last : nil
    end

    def decode_token(token)
      JWT.decode(token, jwt_secret, true, algorithm: "HS256").first
    end

    def jwt_secret
      ENV.fetch("DEVISE_JWT_SECRET_KEY") { Rails.application.secret_key_base }
    end
  end
end
