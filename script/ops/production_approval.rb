require "time"
require "cgi"
require_relative "release_evidence"

module Ops
  class ProductionApproval
    Superseded = Class.new(ReleaseSupport::Error)

    def initialize(repository:, api: ReleaseSupport, sleeper: ->(seconds) { sleep seconds }, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      raise ReleaseSupport::Error, "Unbekanntes Release-Repository" unless ReleaseManifest::IMAGES.key?(repository)
      @repository, @api, @sleeper = repository, api, sleeper
      @clock = clock
    end

    def self.selection(repository:, event_name:, ref:, event:)
      unless ref == "refs/heads/main" && event.dig("repository", "full_name") == repository
        raise ReleaseSupport::Error, "Produktionsfreigabe benötigt das eigene Main-Repository"
      end
      case event_name
      when "workflow_run"
        { staging_run_id: ReleaseSupport.run_id(event.fetch("workflow_run").fetch("id")), mode: "promote" }
      when "workflow_dispatch"
        inputs = event.fetch("inputs")
        mode = inputs.fetch("mode")
        raise ReleaseSupport::Error, "Unbekannter Produktionsmodus" unless %w[promote rollback].include?(mode)
        { staging_run_id: ReleaseSupport.run_id(inputs.fetch("staging_run_id")), mode: }
      else
        raise ReleaseSupport::Error, "Unbekannter Produktionsauslöser"
      end
    end

    def self.validate_binding!(manifest:, commit:, digest:, fingerprint:)
      actual = Digest::SHA256.hexdigest(JSON.generate(ImageFingerprint.canonical(manifest)))
      unless manifest.fetch("commit") == commit && manifest.fetch("digest") == digest && actual == fingerprint
        raise ReleaseSupport::Error, "Freigabenachweis wurde seit der manuellen Prüfung verändert"
      end
      true
    end

    def validate_environment!
      environment = @api.github_json("repos/#{@repository}/environments/production")
      rules = environment.fetch("protection_rules").select { |rule| rule["type"] == "required_reviewers" }
      reviewers = rules.one? && rules.first.fetch("reviewers").map { |item| item["type"] == "User" ? item.dig("reviewer", "id") : nil }
      unless environment["can_admins_bypass"] == false && rules.one? && rules.first["prevent_self_review"] == false &&
          reviewers.all? { |id| id.is_a?(Integer) } && reviewers.sort == [ 3525, 266476119 ]
        raise ReleaseSupport::Error, "Production benötigt die verbindliche Freigabe durch marcbey oder kasch0"
      end
      true
    end

    def latest_staging_run
      runs = paginated_runs("deploy-staging", "branch=main&status=success").select do |run|
        ReleaseManifest.trusted_run?(run, @repository) && run["event"] == "workflow_run" && run["path"] == ".github/workflows/deploy-staging.yml"
      end
      runs.max_by { |run| [ Time.iso8601(run.fetch("updated_at")), run.fetch("id") ] } || raise(ReleaseSupport::Error, "Kein erfolgreicher Staging-Lauf")
    rescue ArgumentError
      raise ReleaseSupport::Error, "Staging-Lauf ohne gültige Abschlusszeit"
    end

    def validate_current!(manifest:, remote:, project:, mode:)
      raise ReleaseSupport::Error, "Unbekannter Produktionsmodus" unless %w[promote rollback].include?(mode)
      return true if mode == "rollback"
      unless latest_staging_run.fetch("id") == manifest.fetch("staging_run_id")
        raise Superseded, "Die Produktionsfreigabe wurde durch einen neueren Staging-Lauf überholt"
      end
      running = remote.running(project:, destination: "staging")
      unless ReleaseManifest.image_identity(running) == manifest.slice("image", "commit", "digest")
        raise Superseded, "Das freigegebene Image läuft nicht mehr unverändert auf Staging"
      end
      true
    end

    # The caller owns DeployLock from the first status read until every cancel is terminal.
    # If human approval races the cancel, mutation cannot enter that same host lock.
    def supersede_waiting!(current_run_id:)
      waiting = paginated_runs("deploy-production", "event=workflow_run&status=waiting").select { |run| automatic_waiter?(run) }
      waiting.select! { |run| pending_production?(run.fetch("id")) }
      if waiting.any? { |run| run.fetch("id") > current_run_id }
        raise Superseded, "Eine neuere Produktionsfreigabe wartet bereits"
      end
      waiting.each do |candidate|
        id = candidate.fetch("id")
        next if id == current_run_id || !automatic_waiter?(@api.run(@repository, id)) || !pending_production?(id)
        next unless automatic_waiter?(@api.run(@repository, id))
        @api.capture("gh", "api", "--method", "POST", "repos/#{@repository}/actions/runs/#{id}/cancel")
        deadline = @clock.call + 60
        until @api.run(@repository, id)["status"] == "completed"
          raise ReleaseSupport::Error, "Abbruch der alten Freigabe nicht bestätigt; Serversperre bleibt zur Prüfung bestehen" if @clock.call >= deadline
          @sleeper.call(1)
        end
      end
    end

    def summary(manifest:, production:, mode:)
      base, target = production.fetch("commit"), manifest.fetch("commit")
      unless [ base, target ].all? { |sha| ReleaseManifest.sha?(sha) }
        raise ReleaseSupport::Error, "Versionsvergleich benötigt geprüfte Commit-IDs"
      end
      url = "https://github.com/#{@repository}"
      host = @repository == "marcbey/stuttgart-live.de" ? "staging.stuttgart-live.de" : "staging.russ-live.de"
      stage_label = mode == "rollback" ? "Aktuelles Staging (kann eine andere Version zeigen)" : "Staging prüfen"
      lines = [ "## Produktionsfreigabe: #{mode}", "", "- Aktuell auf Produktion: `#{base}`", "- Freizugebende Version: `#{target}`",
        "- Image-Digest: `#{manifest.fetch('digest')}`", "- [Alle Änderungen seit Produktion](#{url}/compare/#{base}..#{target})",
        "- [#{stage_label}](https://#{host}/)", "- [Erfolgreicher Staging-Lauf](#{url}/actions/runs/#{manifest.fetch('staging_run_id')})", "", "### Hinzukommende Pull Requests", "" ]
      append_pulls(lines, pulls_between(base, target), url)
      if mode == "rollback"
        lines << "" << "### Entfallende Pull Requests" << ""
        append_pulls(lines, pulls_between(target, base), url)
      end
      lines << "" << "Freigabe durch marcbey oder kasch0: Review deployments → Approve and deploy. Datenbank und Inhalte werden nicht zurückgesetzt."
      lines.join("\n") + "\n"
    end

    private

    def append_pulls(lines, pulls, url)
      pulls.each do |pull|
        title = CGI.escapeHTML(pull.fetch("title")).gsub(/[\r\n]+/, " ").gsub(/[\\`*_{}\[\]()#+.!|~]/) { |character| "\\#{character}" }
        number = Integer(pull.fetch("number"))
        lines << "- [##{number}: #{title}](#{url}/pull/#{number})"
      end
    end

    def paginated_runs(workflow, query)
      runs = []
      1.upto(100) do |page|
        batch = @api.github_json("repos/#{@repository}/actions/workflows/#{workflow}.yml/runs?#{query}&per_page=100&page=#{page}").fetch("workflow_runs")
        runs.concat(batch)
        return runs if batch.size < 100
      end
      raise ReleaseSupport::Error, "Workflow-Liste konnte nicht vollständig geprüft werden"
    end

    def automatic_waiter?(run)
      run["event"] == "workflow_run" && run["status"] == "waiting" && run["head_branch"] == "main" &&
        run["path"] == ".github/workflows/deploy-production.yml" && run.dig("repository", "full_name") == @repository &&
        run.dig("head_repository", "full_name") == @repository
    end

    def pending_production?(id)
      @api.github_json("repos/#{@repository}/actions/runs/#{ReleaseSupport.run_id(id)}/pending_deployments").any? { |entry| entry.dig("environment", "name") == "production" }
    end

    def pulls_between(base, target)
      commits = []
      1.upto(100) do |page|
        batch = @api.github_json("repos/#{@repository}/compare/#{base}...#{target}?per_page=100&page=#{page}").fetch("commits")
        commits.concat(batch)
        break if batch.size < 100
      end
      commits.flat_map do |commit|
        sha = commit.fetch("sha")
        raise ReleaseSupport::Error, "Ungültiger Commit im Versionsvergleich" unless ReleaseManifest.sha?(sha)
        @api.github_json("repos/#{@repository}/commits/#{sha}/pulls?per_page=100")
      end.uniq { |pull| pull.fetch("number") }.sort_by { |pull| pull.fetch("number") }
    end
  end
end
