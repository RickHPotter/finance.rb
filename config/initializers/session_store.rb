Rails.application.config.session_store(:cookie_store, key: "_thirty_fev_session", domain: :all, secure: Rails.env.production?, same_site: :lax)
