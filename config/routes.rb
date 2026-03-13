# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users
  patch "/locale", to: "users#update_locale", as: :update_locale

  # devise_for :users, controllers: {
  #   confirmations: "users/confirmations"
  # }

  get "serviceworker" => "rails/pwa#serviceworker", as: :pwa_serviceworker, constraints: { format: "js" }
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest, constraints: { format: "json" }

  namespace :v1 do
    resources :pages, only: :index do
      collection do
        get :donation
        get :notification
      end
    end

    resources :user_cards, except: :show do
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

    resources :user_bank_accounts, except: :show
    resources :categories, except: :show
    resources :entities, except: :show

    resources :balances, only: :index do
      collection do
        get :cash_balance_json
        get :transaction_balance_json
      end
    end

    resources :cash_transactions, except: :show do
      collection do
        get :month_year
      end
    end

    resources :card_transactions, except: :show do
      member do
        get :duplicate
      end

      collection do
        get :month_year
        get :search
        post :pay_in_advance
      end
    end

    resources :cash_installments, only: [] do
      member do
        patch :pay
      end

      collection do
        post :pay_multiple
        post :transfer_multiple
      end
    end

    resources :investments, except: :show do
      collection do
        get :month_year
      end
    end

    resources :budgets, except: :show do
      collection do
        get :month_year
      end
    end

    namespace :admin do
      get :data_backup, to: "backups#data_backup"
    end

    resources :conversations, only: %i[index show create] do
      resources :messages, only: :create
    end

    resources :subscriptions, only: :create
    resources :lalas, only: :index

    namespace :lalas do
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

    root "pages#index"
  end

  resources :pages, only: [] do
    collection do
      get :donation
      get :notification
    end
  end

  resources :user_cards, except: :show do
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

  resources :user_bank_accounts, except: :show
  resources :categories, except: :show
  resources :entities, except: :show

  resources :balances, only: :index do
    collection do
      get :cash_balance_json
      get :transaction_balance_json
    end
  end

  resources :cash_transactions, except: :show do
    collection do
      get :month_year
    end
  end

  resources :card_transactions, except: :show do
    member do
      get :duplicate
    end

    collection do
      get :month_year
      get :search
      post :pay_in_advance
    end
  end

  resources :cash_installments, only: [] do
    member do
      patch :pay
    end

    collection do
      post :pay_multiple
      post :transfer_multiple
    end
  end

  resources :investments, except: :show do
    collection do
      get :month_year
    end
  end

  resources :budgets, except: :show do
    collection do
      get :month_year
    end
  end

  resources :conversations, only: %i[index show create] do
    resources :messages, only: :create
  end

  resources :subscriptions, only: :create

  resource :naming_convention, only: [] do
    post :preview
    patch :update
  end

  namespace :admin do
    get :data_backup, to: "backups#data_backup"
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

  root "cash_transactions#index"
end
