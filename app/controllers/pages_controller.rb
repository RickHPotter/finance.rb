# frozen_string_literal: true

# Controller for Pages SPA
class PagesController < ApplicationController
  include TabsConcern

  before_action :set_tabs, only: :index

  def index; end
end
