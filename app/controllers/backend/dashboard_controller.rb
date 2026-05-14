module Backend
  class DashboardController < BaseController
    def show
      @page_meta = {
        title: "Backend | Russ Live",
        body_class: "auth-body"
      }
    end
  end
end
