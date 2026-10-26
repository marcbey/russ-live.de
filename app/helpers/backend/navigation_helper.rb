module Backend::NavigationHelper
  def backend_public_page_path
    case controller_path
    when "backend/references"
      referenzen_path
    when "backend/pages"
      if @selected_page
        "#{@selected_page.public_path}?#{ { locale: @selected_page.locale }.to_query }"
      end
    when "backend/jobs"
      if @selected_job&.persisted? && @selected_job.published?
        job_path(@selected_job.slug)
      else
        jobs_path
      end
    when "backend/contacts"
      jobs_path
    when "backend/team_members"
      team_path
    end
  end
end
