-- FR-04: shipment. Removes packed stock from the SHIPPING staging location
-- entirely (it has left the warehouse), closing the order state machine.

set define off

create or replace package pkg_shipment as

  function ship_order (
    p_order_id        in outbound_order.order_id%type,
    p_carrier          in shipment.carrier%type default null,
    p_tracking_number  in shipment.tracking_number%type default null
  ) return shipment.shipment_id%type;

end pkg_shipment;
/

create or replace package body pkg_shipment as

  function ship_order (
    p_order_id        in outbound_order.order_id%type,
    p_carrier          in shipment.carrier%type default null,
    p_tracking_number  in shipment.tracking_number%type default null
  ) return shipment.shipment_id%type is
    l_warehouse_id    outbound_order.warehouse_id%type;
    l_shipping_loc_id location.location_id%type;
    l_shipment_id     shipment.shipment_id%type;
  begin
    select warehouse_id into l_warehouse_id
      from outbound_order
     where order_id = p_order_id
       and status = 'PACKED';

    l_shipping_loc_id := pkg_inventory.get_location_by_type(l_warehouse_id, 'SHIPPING');

    for r in (
      select spl.item_id, spl.lot_id, sum(spl.qty) as qty
        from ship_package_line spl
        join ship_package sp on sp.package_id = spl.package_id
       where sp.order_id = p_order_id
       group by spl.item_id, spl.lot_id
    ) loop
      pkg_inventory.post_transaction(
        p_item_id => r.item_id, p_location_id => l_shipping_loc_id, p_lot_id => r.lot_id,
        p_txn_type => 'SHIP', p_qty => -r.qty,
        p_source_doc_type => 'OUTBOUND_ORDER', p_source_doc_id => p_order_id
      );
    end loop;

    insert into shipment (
      order_id, carrier, tracking_number, ship_date, status, ship_from_warehouse_id
    ) values (
      p_order_id, p_carrier, p_tracking_number, trunc(sysdate), 'SHIPPED', l_warehouse_id
    )
    returning shipment_id into l_shipment_id;

    update ship_package
       set status = 'SHIPPED'
     where order_id = p_order_id;

    update outbound_order_line
       set qty_shipped = qty_picked,
           updated_by = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
           updated_on = sysdate
     where order_id = p_order_id;

    update outbound_order
       set status = 'SHIPPED',
           updated_by = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
           updated_on = sysdate
     where order_id = p_order_id;

    return l_shipment_id;
  exception
    when no_data_found then
      raise_application_error(-20080, 'Outbound order not found or not in PACKED status: order_id=' || p_order_id);
  end ship_order;

end pkg_shipment;
/
