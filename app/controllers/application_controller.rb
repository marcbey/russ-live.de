class ApplicationController < ActionController::Base
  include Authentication

  LOCALE_COOKIE_NAME = :russ_live_locale

  around_action :switch_locale
  before_action :redirect_legacy_locale_param

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private
    def switch_locale(&action)
      I18n.with_locale(requested_locale, &action)
    end

    def requested_locale
      cookie_locale || browser_locale || I18n.default_locale
    end

    def cookie_locale
      normalized_locale(cookies[LOCALE_COOKIE_NAME])
    end

    def redirect_legacy_locale_param
      return unless request.get? && params.key?(:locale)

      locale = normalized_locale(params[:locale])
      write_locale_cookie(locale) if locale.present?

      redirect_to clean_current_url_without_locale, allow_other_host: false
    end

    def browser_locale
      request
        .get_header("HTTP_ACCEPT_LANGUAGE")
        .to_s
        .split(",")
        .filter_map { |language| accepted_language_locale(language) }
        .max_by { |(_, quality)| quality }
        &.first
    end

    def accepted_language_locale(language)
      tag, *attributes = language.strip.split(";")
      locale = normalized_locale(tag.to_s.split("-").first)
      return if locale.blank?

      quality = attributes.find { |attribute| attribute.strip.start_with?("q=") }
      [ locale, quality.present? ? quality.split("=").last.to_f : 1.0 ]
    end

    def write_locale_cookie(locale)
      cookies.permanent[LOCALE_COOKIE_NAME] = {
        value: locale.to_s,
        same_site: :lax
      }
    end

    def clean_current_url_without_locale
      query_parameters = request.query_parameters.except("locale")
      query_string = query_parameters.to_query

      query_string.present? ? "#{request.path}?#{query_string}" : request.path
    end

    def normalized_locale(locale)
      locale = locale.to_s.downcase.to_sym
      locale if I18n.available_locales.include?(locale)
    end
end
