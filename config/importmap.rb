# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "hotkeys-js" # @3.13.5
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin "stimulus-use", to: "https://ga.jspm.io/npm:stimulus-use@0.52.1/dist/index.js"
pin "stimulus-rails-nested-form" # @4.1.0
pin "stimulus-textarea-autogrow" # @4.1.0
pin "stimulus-rails-autosave" # @5.1.0
pin "stimulus-notification" # @2.2.0
pin "flowbite", to: "https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.3.0/flowbite.turbo.min.js"
pin "flowbite-datepicker"

pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/models", under: "models"
