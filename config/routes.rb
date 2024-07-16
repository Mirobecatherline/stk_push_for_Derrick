Rails.application.routes.draw do
  resources :mpesas
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  post 'stkpush', to: 'mpesas#stkpush'
  post 'stkquery', to: 'mpesas#stkquery'
  post 'callback_url', to: 'mpesas#callback_url'
  # Defines the root path route ("/")
  # root "posts#index"
end
# [
#     "success",
#     {
#         "MerchantRequestID": "53e3-4aa8-9fe0-8fb5e4092cdd3587974",
#         "CheckoutRequestID": "ws_CO_09072024132642043721969149",
#         "ResponseCode": "0",
#         "ResponseDescription": "Success. Request accepted for processing",
#         "CustomerMessage": "Success. Request accepted for processing"
#     }
# ]