class ApplicationJob < ActiveJob::Base
  sidekiq_options retry: 3, dead: true

  before_enqueue do |job|
    Rails.logger.info "Enqueueing job #{job.class.name} args=#{job.arguments.inspect}"
  end

  before_perform do |job|
    Rails.logger.info "Starting job #{job.class.name} START"
  end

  after_perform do |job|
    Rails.logger.info "Job #{job.class.name} END"
  end
end
