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
  resources :entities
  resources :categories
  resources :cash_transactions
  resources :card_transactions do
    collection { get :month_year }
  end

  root "pages#index"
end
