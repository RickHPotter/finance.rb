# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

  devise_for :users
  patch "/locale", to: "users#update_locale", as: :update_locale

  resource :profile, only: %i[edit update]
  resource :preference, only: %i[update]
  resources :friendships, param: :public_id, only: %i[index create update destroy]

  # devise_for :users, controllers: {
  #   confirmations: "users/confirmations"
  # }

  get "serviceworker" => "rails/pwa#serviceworker", as: :pwa_serviceworker, constraints: { format: "js" }
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest, constraints: { format: "json" }

  resource :static, only: [], controller: "static" do
    get :donation
    get :notification
  end

  resources :pages, only: [], controller: "static" do
    collection do
      get :donation
      get :notification
    end
  end

  resources :user_cards do
    member do
      get :reference_date
    end

    resources :references, only: %i[index edit update], controller: "references" do
      collection do
        get :merge
        post :perform_merge
      end
    end
  end

  resources :user_bank_accounts
  resources :categories do
    member do
      post :merge_preview, to: "category_merge_previews#create"
      post :merge,         to: "category_merges#create"
    end
  end
  resources :entities do
    member do
      post :merge_preview, to: "entity_merge_previews#create"
      post :merge,         to: "entity_merges#create"
    end
  end
  resources :contexts, only: %i[index show new create destroy] do
    collection do
      get :dismiss
    end

    member do
      patch :archive
      patch :unarchive
      patch :switch
    end
  end

  resources :balances, only: :index do
    collection do
      get :current_balance_json
      get :cash_balance_json
      get :monthly_analysis, action: :monthly_analysis_json, constraints: ->(request) { request.format.json? }, as: :monthly_analysis_json
      get :monthly_analysis
    end
  end

  resources :card_transactions do
    member do
      get :duplicate
    end

    collection do
      get :month_year
      get :search
      post :pay_in_advance
      post :add_to_subscription
    end
  end

  resources :cash_transactions do
    member do
      get :duplicate
      patch :report_payment_failure
      patch :fix_exchange_projection
    end

    collection do
      get :month_year
      post :add_to_subscription
    end
  end

  resources :cash_installments, only: [] do
    member do
      patch :pay
    end

    collection do
      post :pay_multiple
      post :partial_pay_multiple
      post :transfer_multiple
    end
  end

  resources :budgets do
    member do
      get :duplicate
    end

    collection do
      get :month_year
      patch :bulk_update
      delete :bulk_destroy
    end
  end

  resources :investments, except: :show do
    member do
      get :duplicate
    end

    collection do
      get :month_year
    end
  end

  resources :subscriptions, except: :show
  post "allocation_mutations/preview", to: "allocation_mutation_previews#create", as: :preview_allocation_mutations
  post "allocation_mutations/apply", to: "allocation_mutations#create", as: :apply_allocation_mutations
  resources :audit_operations, only: %i[index show]
  resources :audit_versions, only: :index
  get "audit_records/:item_type/:item_id", to: "audit_versions#index", defaults: { record_filter: true }, as: :record_audit_versions
  get "healthcheck", to: "health_check/dashboard#show", as: :healthcheck
  post "healthcheck/runs", to: "health_check/runs#create", as: :healthcheck_runs
  get "healthcheck/checks/:check_key", to: "health_check/checks#show", as: :healthcheck_check
  post "healthcheck/checks/:check_key/run", to: "health_check/check_runs#create", as: :healthcheck_check_run
  post "healthcheck/checks/:check_key/repairs/:repair_key/preview",
       to: "health_check/repair_previews#create",
       as: :healthcheck_repair_preview
  patch "healthcheck/checks/:check_key/repairs/:repair_key",
        to: "health_check/repairs#update",
        as: :healthcheck_repair
  match "healthcheck/maintenance/naming-convention/preview",
        to: "health_check/naming_conventions#preview",
        via: %i[get post],
        as: :preview_healthcheck_naming_convention
  patch "healthcheck/maintenance/naming-convention",
        to: "health_check/naming_conventions#update",
        as: :healthcheck_naming_convention
  resource :settings, only: :show

  resources :conversations, param: :public_id, only: %i[index show create] do
    member do
      patch :archive
      patch :unarchive
      patch :mute
      patch :unmute
    end

    resources :messages, only: :create do
      member do
        patch :apply
        patch :revert
      end
    end
  end

  resources :push_subscriptions, only: :create

  namespace :admin do
    get :data_backup, to: "backups#data_backup"

    resources :audit_operations, only: [] do
      resource :rollback_preview, only: %i[show create], controller: "audit_rollback_previews"
    end
  end

  namespace :lalas do
    root "cash_transactions#index"

    resources :card_transactions, only: %i[index] do
      collection do
        get :month_year
        get :search
      end
    end

    resources :cash_transactions, only: %i[index] do
      collection do
        get :month_year
        get :search
      end
    end
  end

  scope "/internal/:entity_slug", as: :internal, module: :lalas do
    root "cash_transactions#index"

    resources :card_transactions, only: %i[index] do
      collection do
        get :month_year
        get :search
      end
    end

    resources :cash_transactions, only: %i[index] do
      collection do
        get :month_year
        get :search
      end
    end
  end

  scope "/:user_slug/external/:entity_slug", as: :external, module: :lalas do
    root "cash_transactions#index"

    resources :card_transactions, only: %i[index] do
      collection do
        get :month_year
        get :search
      end
    end

    resources :cash_transactions, only: %i[index] do
      collection do
        get :month_year
        get :search
      end
    end
  end
end
