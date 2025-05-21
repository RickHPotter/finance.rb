# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users
  patch "/locale", to: "users#update_locale", as: :update_locale

  # devise_for :users, controllers: {
  #   confirmations: "users/confirmations"
  # }

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :pages, only: :index do
    collection do
      get :donation
      get :notification
    end
  end

  resources :user_cards, except: :show
  resources :user_bank_accounts, except: :show
  resources :categories, except: :show
  resources :entities, except: :show

  resources :cash_transactions, except: :show do
    collection do
      get :month_year
      get :inspect
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

  root "pages#index"
end
