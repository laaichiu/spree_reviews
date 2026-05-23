module ReviewReturnHelpers
  def create_received_return_item(order:, variant:, quantity: nil)
    line_item = order.line_items.find_by!(variant_id: variant.id)
    inventory_unit = order.inventory_units.find_by!(line_item: line_item, variant_id: variant.id)

    FactoryBot.create(
      :return_item,
      inventory_unit: inventory_unit,
      return_authorization: FactoryBot.create(:return_authorization, order: order),
      return_quantity: quantity || inventory_unit.quantity,
      acceptance_status: 'accepted',
      reception_status: 'received'
    )
  end
end

RSpec.configure do |config|
  config.include ReviewReturnHelpers
end
