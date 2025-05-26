defmodule RephiWeb.Auth.Pipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :erp_commerce,
    error_handler: RephiWeb.Auth.ErrorHandler,
    module: RephiWeb.Auth.Guardian

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug Guardian.Plug.LoadResource, allow_blank: true
end
