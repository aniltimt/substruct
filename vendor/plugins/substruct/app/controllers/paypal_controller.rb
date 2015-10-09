class PaypalController < ApplicationController
  include ActiveMerchant::Billing::Integrations

  # Handles Instant Payment Notification
  # from PayPal after a purchase.
  def ipn
    notification = Paypal::Notification.new(request.raw_post)
    order = Order.find_by_order_number(
      notification.invoice,
      :include => :shipping_address
    )

    if notification.acknowledge
      begin
        if notification.complete? && order.matches_ipn?(notification, params) 
          order.pass_ipn(params[:txn_id])
        else
          order.fail_ipn()
        end
      rescue => e
        order.update_attribute(:order_status_code_id, 3)
        raise
      ensure
        order.save
      end
    end
    
    render :nothing => true
  end
end
