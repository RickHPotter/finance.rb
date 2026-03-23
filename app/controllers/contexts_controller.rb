# frozen_string_literal: true

class ContextsController < ApplicationController
  def switch
    context = current_user.contexts.find(params[:id])
    session[:current_context_id] = context.id

    redirect_back fallback_location: root_path
  end
end
