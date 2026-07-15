# frozen_string_literal: true

class AuthController < ApplicationController
  include Machina::ControllerHelpers

  skip_before_action :authenticate!, only: [ :login, :logout, :machina_callback ]

  def login
    if logged_in?
      redirect_to root_path
    else
      @machina_login_url = Machina.authorize_url(return_to: root_url)
      render :login
    end
  end

  def logout
    logout!
    redirect_to login_path, notice: "Logged out successfully", status: :see_other
  end

  def machina_callback
    cookies[:machina_session] = {
      value: params[:token],
      httponly: true,
      same_site: :lax,
      secure: request.ssl?
    }

    redirect_to params[:return_to].presence || root_path
  end
end
