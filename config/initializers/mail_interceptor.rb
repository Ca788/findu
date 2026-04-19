# frozen_string_literal: true

if Rails.env.development?
  class DevelopmentMailLogger
    def self.delivering_email(message)
      Rails.logger.info("[MAIL] To: #{message.to.join(', ')} | Subject: #{message.subject}")
      Rails.logger.info("[MAIL] Body:\n#{message.body.to_s}")
    end
  end

  ActionMailer::Base.register_interceptor(DevelopmentMailLogger)
end
