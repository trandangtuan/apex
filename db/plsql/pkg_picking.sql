-- FR-03/FR-05: wave release and scan-confirmed picking.
-- confirm_pick is the scan entry point: it checks the scanned barcode/QR
-- against the task's item before moving any stock, so a wrong-item scan is
-- rejected instead of silently picking the wrong SKU. Picked stock moves to
-- the warehouse's SHIPPING staging location (not fully removed from the
-- system yet) so it stays visible in INVENTORY_BALANCE until PKG_SHIPMENT
-- actually ships it.

set define off

create or replace package pkg_picking as

  function release_wave (
    p_wave_date in pick_wave.wave_date%type default sysdate
  ) return pick_wave.wave_id%type;

  procedure assign_wave (
    p_wave_id  in pick_wave.wave_id%type,
    p_order_id in outbound_order.order_id%type
  );

  procedure confirm_pick (
    p_task_id      in pick_task.task_id%type,
    p_scanned_code in pick_task.scanned_code%type,
    p_qty_picked   in pick_task.qty_picked%type
  );

end pkg_picking;
/

create or replace package body pkg_picking as

  function release_wave (
    p_wave_date in pick_wave.wave_date%type default sysdate
  ) return pick_wave.wave_id%type is
    l_wave_id pick_wave.wave_id%type;
  begin
    insert into pick_wave (wave_date, status)
    values (p_wave_date, 'RELEASED')
    returning wave_id into l_wave_id;

    return l_wave_id;
  end release_wave;

  procedure assign_wave (
    p_wave_id  in pick_wave.wave_id%type,
    p_order_id in outbound_order.order_id%type
  ) is
  begin
    update pick_task t
       set wave_id = p_wave_id,
           status = case when t.status = 'PENDING' then 'ASSIGNED' else t.status end,
           updated_on = sysdate
     where t.order_line_id in (select line_id from outbound_order_line where order_id = p_order_id)
       and t.status in ('PENDING', 'ASSIGNED');
  end assign_wave;

  procedure confirm_pick (
    p_task_id      in pick_task.task_id%type,
    p_scanned_code in pick_task.scanned_code%type,
    p_qty_picked   in pick_task.qty_picked%type
  ) is
    l_item_id         pick_task.item_id%type;
    l_lot_id          pick_task.lot_id%type;
    l_from_location   pick_task.from_location_id%type;
    l_qty_requested   pick_task.qty_requested%type;
    l_qty_already     pick_task.qty_picked%type;
    l_order_line_id   pick_task.order_line_id%type;
    l_order_id        outbound_order_line.order_id%type;
    l_warehouse_id    outbound_order.warehouse_id%type;
    l_barcode         item.barcode_value%type;
    l_qr               item.qr_value%type;
    l_shipping_loc_id  location.location_id%type;
    l_open_lines       number;
  begin
    select t.item_id, t.lot_id, t.from_location_id, t.qty_requested, t.qty_picked, t.order_line_id,
           ol.order_id, o.warehouse_id, i.barcode_value, i.qr_value
      into l_item_id, l_lot_id, l_from_location, l_qty_requested, l_qty_already, l_order_line_id,
           l_order_id, l_warehouse_id, l_barcode, l_qr
      from pick_task t
      join outbound_order_line ol on ol.line_id = t.order_line_id
      join outbound_order o on o.order_id = ol.order_id
      join item i on i.item_id = t.item_id
     where t.task_id = p_task_id;

    -- NOT IN (l_barcode, l_qr) would silently pass on any mismatch once either
    -- is null (x NOT IN (a, NULL) is NULL, not TRUE, in PL/SQL) -- most items
    -- only have a barcode, so this must be spelled out instead of NOT IN.
    if p_scanned_code is null
       or (
            (l_barcode is null or p_scanned_code <> l_barcode)
            and (l_qr is null or p_scanned_code <> l_qr)
          )
    then
      raise_application_error(-20060,
        'Scan mismatch on task_id=' || p_task_id || ': scanned "' || p_scanned_code ||
        '" does not match expected item barcode/QR');
    end if;

    if l_qty_already + p_qty_picked > l_qty_requested then
      raise_application_error(-20061,
        'Pick quantity exceeds task request for task_id=' || p_task_id ||
        ' (requested ' || l_qty_requested || ', already picked ' || l_qty_already ||
        ', trying to add ' || p_qty_picked || ')');
    end if;

    l_shipping_loc_id := pkg_inventory.get_location_by_type(l_warehouse_id, 'SHIPPING');

    pkg_inventory.post_transaction(
      p_item_id => l_item_id, p_location_id => l_from_location, p_lot_id => l_lot_id,
      p_txn_type => 'PICK', p_qty => -p_qty_picked,
      p_source_doc_type => 'PICK_TASK', p_source_doc_id => p_task_id
    );

    pkg_inventory.post_transaction(
      p_item_id => l_item_id, p_location_id => l_shipping_loc_id, p_lot_id => l_lot_id,
      p_txn_type => 'MOVE', p_qty => p_qty_picked,
      p_source_doc_type => 'PICK_TASK', p_source_doc_id => p_task_id
    );

    pkg_inventory.release_allocation(
      p_item_id => l_item_id, p_location_id => l_from_location, p_lot_id => l_lot_id, p_qty => p_qty_picked
    );

    update pick_task
       set qty_picked   = qty_picked + p_qty_picked,
           scanned_code = p_scanned_code,
           scan_ts      = systimestamp,
           status       = case when qty_picked + p_qty_picked >= qty_requested then 'PICKED' else 'IN_PROGRESS' end,
           updated_by   = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
           updated_on   = sysdate
     where task_id = p_task_id;

    update outbound_order_line
       set qty_picked = qty_picked + p_qty_picked,
           status = case when qty_picked + p_qty_picked >= qty_ordered then 'PICKED' else status end,
           updated_by = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
           updated_on = sysdate
     where line_id = l_order_line_id;

    update outbound_order
       set status = 'PICKING',
           updated_by = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
           updated_on = sysdate
     where order_id = l_order_id
       and status = 'ALLOCATED';

    select count(*) into l_open_lines
      from outbound_order_line
     where order_id = l_order_id
       and status not in ('PICKED', 'CANCELLED');

    if l_open_lines = 0 then
      update outbound_order
         set status = 'PICKED',
             updated_by = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
             updated_on = sysdate
       where order_id = l_order_id;
    end if;
  end confirm_pick;

end pkg_picking;
/
