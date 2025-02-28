# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users, controllers: {
    confirmations: "users/confirmations"
  }

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :pages, only: :index do
    collection { get :notification }
  end

  resources :user_cards, except: :show
  resources :user_bank_accounts, except: :show
  resources :entities, except: :show
  resources :categories, except: :show
  resources :budgets, except: %i[index show]

  resources :cash_transactions, except: :show do
    member do
      post :pay_cash_installment
    end

    collection do
      get :month_year
    end
  end

  resources :card_transactions, except: :show do
    collection do
      get :month_year
      get :search
    end
  end

  root "pages#index"
end
