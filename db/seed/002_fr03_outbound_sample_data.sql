-- Sample/demo data for FR-03/FR-04/FR-05: adds a SHIPPING staging location,
-- two customers, and two outbound orders in different lifecycle states
-- (one fully shipped end-to-end, one only allocated) so the outbound pages
-- have realistic demo data to show every status.

set define off
set serveroutput on

insert into location (warehouse_id, location_code, zone, location_type)
  select warehouse_id, 'SHIP-01', 'SHIPPING', 'SHIPPING' from warehouse where warehouse_code = 'WH-BA';

insert into customer (customer_code, customer_name, address)
values ('CUST-001', 'City Hall Bratislava', 'Primaciálne námestie 1, Bratislava');
insert into customer (customer_code, customer_name, address)
values ('CUST-002', 'Regional Office Kosice', 'Hlavná 1, Kosice');

commit;

declare
  l_wh_id        warehouse.warehouse_id%type;
  l_cust1_id     customer.customer_id%type;
  l_cust2_id     customer.customer_id%type;
  l_item_mon_id  item.item_id%type;
  l_item_bio_id  item.item_id%type;
  l_order1_id    outbound_order.order_id%type;
  l_order2_id    outbound_order.order_id%type;
  l_line1_id     outbound_order_line.line_id%type;
  l_line2_id     outbound_order_line.line_id%type;
  l_task_id      pick_task.task_id%type;
  l_package_id   ship_package.package_id%type;
  l_shipment_id  shipment.shipment_id%type;
begin
  select warehouse_id into l_wh_id from warehouse where warehouse_code = 'WH-BA';
  select customer_id into l_cust1_id from customer where customer_code = 'CUST-001';
  select customer_id into l_cust2_id from customer where customer_code = 'CUST-002';
  select item_id into l_item_mon_id from item where item_code = 'MON-24-001';
  select item_id into l_item_bio_id from item where item_code = 'BIO-RDR-001';

  -- Order 1: full lifecycle demo (received -> allocated -> picking -> picked -> packed -> shipped)
  l_order1_id := pkg_outbound.create_order(
    p_order_number => 'SO-DEMO-0001', p_customer_id => l_cust1_id, p_warehouse_id => l_wh_id,
    p_required_ship_date => trunc(sysdate) + 3
  );
  l_line1_id := pkg_outbound.add_line(p_order_id => l_order1_id, p_item_id => l_item_mon_id, p_qty_ordered => 20);
  pkg_outbound.allocate_order(p_order_id => l_order1_id);

  for r in (select task_id, qty_requested from pick_task where order_line_id = l_line1_id) loop
    pkg_picking.confirm_pick(p_task_id => r.task_id, p_scanned_code => '8901234500024', p_qty_picked => r.qty_requested);
  end loop;

  l_package_id := pkg_packing.pack_order(p_order_id => l_order1_id);
  l_shipment_id := pkg_shipment.ship_order(p_order_id => l_order1_id, p_carrier => 'Slovak Parcel Service', p_tracking_number => 'SPS-TEST-0001');

  dbms_output.put_line('Order 1 (SO-DEMO-0001) shipped: shipment_id=' || l_shipment_id);

  -- Order 2: only allocated so far, demonstrates the mid-flow state in the pages
  l_order2_id := pkg_outbound.create_order(
    p_order_number => 'SO-DEMO-0002', p_customer_id => l_cust2_id, p_warehouse_id => l_wh_id,
    p_required_ship_date => trunc(sysdate) + 5, p_priority => 'HIGH'
  );
  l_line2_id := pkg_outbound.add_line(p_order_id => l_order2_id, p_item_id => l_item_bio_id, p_qty_ordered => 15);
  pkg_outbound.allocate_order(p_order_id => l_order2_id);

  dbms_output.put_line('Order 2 (SO-DEMO-0002) allocated, awaiting pick.');

  commit;
end;
/
