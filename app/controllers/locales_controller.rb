class LocalesController < ApplicationController
  allow_unauthenticated_access

  def update
    locale = normalized_locale(params[:locale])
    write_locale_cookie(locale) if locale.present?

    redirect_to safe_return_to_path, status: :see_other, allow_other_host: false
  end

  private
    def safe_return_to_path
      uri = URI.parse(params[:return_to].to_s)
      return root_path if uri.host.present? || !uri.path.to_s.start_with?("/")

      query_parameters = Rack::Utils.parse_nested_query(uri.query).except("locale")
      query_string = query_parameters.to_query
      "#{uri.path}#{query_string.present? ? "?#{query_string}" : ""}"
    rescue URI::InvalidURIError
      root_path
    end
end
