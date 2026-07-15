class ApplicationController < ActionController::Base
  include Pagy::Method
  include Machina::ControllerHelpers

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  allow_browser versions: :modern

  stale_when_importmap_changes

  before_action :authenticate!

  helper_method :current_user

  def current_user
    @current_user ||= User.find_or_create_from_authorized(Machina::Current.authorized)
  end

  private

  def render_not_found
    head :not_found
  end
end
