Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "pages#home"

  get "unternehmen", to: "pages#unternehmen"
  get "services", to: "pages#services"
  get "referenzen", to: "pages#referenzen"
  get "jobs", to: "pages#jobs"
  get "jobs/:slug", to: "pages#job", as: :job
  get "presse", to: "pages#presse"
  get "presse/beispiel", to: "pages#press_detail", as: :press_detail
  get "kontakt", to: "pages#kontakt"
  get "impressum", to: "pages#impressum"
  get "datenschutz", to: "pages#datenschutz"
  get "agb", to: "pages#agb"
  get "jugendschutz", to: "pages#jugendschutz"

  get "index.html", to: redirect("/")
  get "unternehmen.html", to: redirect("/unternehmen")
  get "services.html", to: redirect("/services")
  get "referenzen.html", to: redirect("/referenzen")
  get "jobs.html", to: redirect("/jobs")
  get "presse.html", to: redirect("/presse")
  get "presse-detail.html", to: redirect("/presse/beispiel")
  get "kontakt.html", to: redirect("/kontakt")
  get "impressum.html", to: redirect("/impressum")
  get "datenschutz.html", to: redirect("/datenschutz")
  get "agb.html", to: redirect("/agb")
  get "jugendschutz.html", to: redirect("/jugendschutz")
end
