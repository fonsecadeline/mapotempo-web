# Subscribe to grape request and log with Rails.logger
ActiveSupport::Notifications.subscribe('grape.request') do |name, starts, ends, notification_id, payload|
  Rails.logger.info '[API] %s %s (%.3f ms) -> %s %s%s' % [
    payload[:request_method],
    payload[:request_path],
    (ends-starts)*1000,
    (payload[:response_status] || "error"),
    payload[:x_organization] ? "| X-Org: #{payload[:x_organization]}" : "",
    payload[:params] ? "| #{payload[:params].inspect}" : ""
  ]
end

# from grape 1.0.0, hashie is replaced by HashWithIndifferentAccess
Grape.configure do |config|
  config.param_builder = Grape::Extensions::Hashie::Mash::ParamBuilder
end
