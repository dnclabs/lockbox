class AuthenticationController < ApplicationController
  skip_before_filter :require_user

  def show
    if Partner.authenticate(params[:id])
      head 200 and return
    else
      head 401 and return
    end
  end

end
