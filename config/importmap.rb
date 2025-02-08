# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "hotkeys-js" # @3.13.9
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin "stimulus-use" # @0.52.3
pin "stimulus-rails-nested-form" # @4.1.0
pin "stimulus-textarea-autogrow" # @4.1.0
pin "stimulus-rails-autosave" # @5.1.0
pin "stimulus-notification" # @2.2.0
pin "flowbite", to: "https://cdn.jsdelivr.net/npm/flowbite@3.1.2/dist/flowbite.turbo.min.js"
pin "flowbite-datepicker"

pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/models", under: "models"
