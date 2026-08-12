# frozen_string_literal: true

class AuthController < ApplicationController
  include Machina::ControllerHelpers

  skip_before_action :authenticate!, only: [ :login, :logout ]

  # The Console handshake (redirect, state nonce, callback) is owned by
  # machina-auth: the engine serves GET /machina/callback. The login page's
  # button points at a protected path so the gem's authenticate! mints the
  # state nonce — a pre-built authorize URL would be rejected at the callback.
  def login
    redirect_to root_path if logged_in?
  end

  def logout
    logout!
    redirect_to login_path, notice: "Logged out successfully", status: :see_other
  end
end
