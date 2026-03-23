# frozen_string_literal: true

class ContextsController < ApplicationController
  include TabsConcern

  before_action :set_context_tabs

  def index
    contexts = current_user.contexts.includes(:source_context).order(:created_at)
    render Views::Contexts::Index.new(contexts:, current_context:)
  end

  def show
    context = current_user.contexts.find(params[:id])
    render Views::Contexts::Show.new(context:, current_context:)
  end

  def new
    context = current_user.contexts.new(source_context: source_context)
    render Views::Contexts::New.new(context:, source_context:)
  end

  def create
    context = Logic::ContextCloneService.new(
      source_context:,
      name: context_params[:name],
      description: context_params[:description]
    ).call

    redirect_to context_path(context)
  end

  def switch
    context = current_user.contexts.find(params[:id])
    session[:current_context_id] = context.id

    redirect_back fallback_location: root_path
  end

  private

  def context_params
    params.require(:context).permit(:name, :description, :source_context_id)
  end

  def source_context
    source_context_id = params.dig(:context, :source_context_id) || params[:source_context_id]
    @source_context ||= current_user.contexts.find(source_context_id)
  end

  def set_context_tabs
    set_tabs(active_menu: :hub, active_sub_menu: :context)
  end
end
