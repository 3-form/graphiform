Rails.application.configure do
  config.cache_classes = true
  config.eager_load = false

  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    'Cache-Control' => "public, max-age=#{1.hour.to_i}"
  }

  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Rails 7.1+ renamed this to action_dispatch.show_exceptions = :rescuable.
  # The boolean form is still accepted in 7.1/7.2 but deprecated in 8.x.
  config.action_dispatch.show_exceptions = :rescuable

  config.action_controller.allow_forgery_protection = false

  config.active_storage.service = :test if config.respond_to?(:active_storage)

  config.action_mailer.perform_caching = false
  config.action_mailer.delivery_method = :test

  config.active_support.deprecation = :stderr

  # config.action_view.raise_on_missing_translations = true
end