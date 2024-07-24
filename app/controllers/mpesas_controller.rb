class MpesasController < ApplicationController
 require 'rest-client'
    def stkpush
        phoneNumber = params[:phoneNumber]
        amount = params[:amount]
      url = "https://api.safaricom.co.ke/mpesa/stkpush/v1/processrequest"
        #  url = "https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest"
        timestamp = "#{Time.now.strftime "%Y%m%d%H%M%S"}"
        business_short_code = ENV["MPESA_SHORTCODE"]
        password = Base64.strict_encode64("#{business_short_code}#{ENV["MPESA_PASSKEY"]}#{timestamp}")
        payload = {
        'BusinessShortCode': business_short_code,
        'Password': password,
        'Timestamp': timestamp,
        'TransactionType': "CustomerPayBillOnline",
        'Amount': amount,
        'PartyA': phoneNumber,
        'PartyB': business_short_code,
        'PhoneNumber': phoneNumber,
        'CallBackURL': "#{ENV["CALLBACK_URL"]}/callback_url",
        'AccountReference': 'Codearn',
        'TransactionDesc': "Payment for Codearn premium"
        }.to_json

        headers = {
        Content_type: 'application/json',
        Authorization: "Bearer #{get_access_token}"
        }

        response = RestClient::Request.new({
        method: :post,
        url: url,
        payload: payload,
        headers: headers
        }).execute do |response, request|
        case response.code
        when 500
        [ :error, JSON.parse(response.to_str) ]
        when 400
        [ :error, JSON.parse(response.to_str) ]
        when 200
            response_data=JSON.parse(response.to_str)
            Mpesa.destroy_all()
            Mpesa.create(
          phoneNumber: phoneNumber,
          amount: amount,
          checkoutRequestID: response_data["CheckoutRequestID"],
          merchantRequestID: response_data["MerchantRequestID"],
        )

        [ :success, JSON.parse(response.to_str) ]
        else
        fail "Invalid response #{response.to_str} received."
        end
        end
        render json: response
    end


    def callback_url
        begin
          body = params[:Body][:stkCallback]
          merchant_request_id = body[:MerchantRequestID]
          result_code = body[:ResultCode]
          result_desc = body[:ResultDesc]
          callback_metadata = body[:CallbackMetadata]
    
          if callback_metadata
            items = callback_metadata[:Item]
            amount = items.find { |item| item[:Name] == "Amount" }[:Value]
            mpesa_receipt_number = items.find { |item| item[:Name] == "MpesaReceiptNumber" }[:Value]
            transaction_date = items.find { |item| item[:Name] == "TransactionDate" }[:Value]
            phone_number = items.find { |item| item[:Name] == "PhoneNumber" }[:Value]
    
            # Create or update the transaction record in the database
            mpesa_transaction = Mpesa.find_or_initialize_by(merchantRequestID: merchant_request_id)
            mpesa_transaction.update(
            #   result_code: result_code,
            #   result_desc: result_desc,
              amount: amount,
              mpesaReceiptNumber: mpesa_receipt_number,
            #   transaction_date: transaction_date,
              phoneNumber: phone_number
            )
    
            render json: { msg: "Received" }, status: :ok
            Rails.logger.info({ msg: "Transaction process was successful", transaction: mpesa_transaction })
          else
            render json: { msg: "Received" }, status: :ok
            Rails.logger.info({ msg: "Transaction process was cancelled", body: body })
          end
        rescue StandardError => e
          render json: { error: e.message }, status: :internal_server_error
        end
      end

# def callback_url
#     result_code = params[:Body][:stkCallback][:ResultCode]
#     result_desc = params[:Body][:stkCallback][:ResultDesc]
#     merchant_request_id = params[:Body][:stkCallback][:MerchantRequestID]
#     checkout_request_id = params[:Body][:stkCallback][:CheckoutRequestID]
#     mpesa_receipt_number = params[:Body][:stkCallback][:CallbackMetadata][:Item].find { |item| item[:Name] == "MpesaReceiptNumber" }[:Value] rescue nil

#     # Find the transaction in the database
#     mpesa_transaction = Mpesa.find_by(merchantRequestID: merchant_request_id, checkoutRequestID: checkout_request_id)

#     if mpesa_transaction
#       # Update the transaction status
#       print(mpesa_receipt_number)
#       status = result_code == 0 ? 'successful' : 'failed'
#       mpesa_transaction.update(
#         # status: status,
#         # result_desc: result_desc,
#         mpesaReceiptNumber: mpesa_receipt_number
#       )
#       render json: { message: "Transaction #{status}", result_desc: result_desc }
#     else
#       render json: { message: "Transaction not found", result_desc: result_desc }, status: :not_found
#     end
#   end
    # stkquery

    def stkquery
        # url = "https://sandbox.safaricom.co.ke/mpesa/stkpushquery/v1/query"
        url = " https://api.safaricom.co.ke/mpesa/transactionstatus/v1/query"
        timestamp = "#{Time.now.strftime "%Y%m%d%H%M%S"}"
        business_short_code = ENV["MPESA_SHORTCODE"]
        password = Base64.strict_encode64("#{business_short_code}#{ENV["MPESA_PASSKEY"]}#{timestamp}")
        payload = {
        'BusinessShortCode': business_short_code,
        'Password': password,
        'Timestamp': timestamp,
        'CheckoutRequestID': params[:checkoutRequestID]
        }.to_json

        headers = {
        Content_type: 'application/json',
        Authorization: "Bearer #{ get_access_token }"
        }

        response = RestClient::Request.new({
        method: :post,
        url: url,
        payload: payload,
        headers: headers
        }).execute do |response, request|
        case response.code
        when 500
        [ :error, JSON.parse(response.to_str) ]
        when 400
        [ :error, JSON.parse(response.to_str) ]
        when 200
        [ :success, JSON.parse(response.to_str) ]
        else
        fail "Invalid response #{response.to_str} received."
        end
        end
        render json: response
    end

    
    private

    def generate_access_token_request
        # @url = "https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials"
        @url = "https://api.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials"
        @consumer_key = ENV['MPESA_CONSUMER_KEY'] 
        @consumer_secret = ENV['MPESA_CONSUMER_SECRET']
        @userpass = Base64::strict_encode64("#{@consumer_key}:#{@consumer_secret}")
        headers = {
            Authorization: "Bearer #{@userpass}"
        }
        res = RestClient::Request.execute( url: @url, method: :get, headers: {
            Authorization: "Basic #{@userpass}"
        })
        res
    end

    def get_access_token
        res = generate_access_token_request()
        if res.code != 200
        r = generate_access_token_request()
        if res.code != 200
        raise MpesaError('Unable to generate access token')
        end
        end
        body = JSON.parse(res, { symbolize_names: true })
        token = body[:access_token]
        AccessToken.destroy_all()
        AccessToken.create!(token: token)
        token
    end

end

[
    "success",
    {
        "ResponseCode": "0",
        "ResponseDescription": "The service request has been accepted successsfully",
        "MerchantRequestID": "8491-75014543-2",
        "CheckoutRequestID": "ws_CO_12122022094855872768372439",
        "ResultCode": "1032",
        "ResultDesc": "Request cancelled by user"
    }
]
