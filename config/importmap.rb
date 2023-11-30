# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

pin 'application', preload: true
pin '@hotwired/turbo-rails', to: 'turbo.min.js', preload: true
pin '@hotwired/stimulus', to: 'stimulus.min.js', preload: true
pin '@hotwired/stimulus-loading', to: 'stimulus-loading.js', preload: true
pin 'stimulus-use', to: 'https://ga.jspm.io/npm:stimulus-use@0.52.1/dist/index.js'

pin_all_from 'app/javascript/controllers', under: 'controllers'
