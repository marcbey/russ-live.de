module StuttgartLiveUrls
  def self.base_url(environment: Rails.configuration.x.deployment_environment)
    case environment
    when "staging" then "https://staging.stuttgart-live.de"
    when "production", "development", "test", "build" then "https://www.stuttgart-live.de"
    else raise DeploymentEnvironment::ConfigurationError, "Umgebungsprofil für Stuttgart-Verweise fehlt"
    end
  end
end
