-- FR-04/FR-05: outbound order intake and stock allocation.
-- allocate_line walks candidate INVENTORY_BALANCE rows in pick-path priority
-- (PICK_FACE locations before BULK; FEFO by lot expiry within a location)
-- and creates one PICK_TASK per (location, lot) slice it draws from, so a
-- single order line can be fulfilled from several bins without losing that
-- detail. Actual stock leaves the bin only when PKG_PICKING.confirm_pick
-- scans the task; allocate_line only reserves it via pkg_inventory.allocate.

set define off

create or replace package pkg_outbound as

  function create_order (
    p_order_number       in outbound_order.order_number%type,
    p_customer_id        in outbound_order.customer_id%type,
    p_warehouse_id       in outbound_order.warehouse_id%type,
    p_order_source       in outbound_order.order_source%type default 'MANUAL',
    p_required_ship_date in outbound_order.required_ship_date%type default null,
    p_priority           in outbound_order.priority%type default 'NORMAL'
  ) return outbound_order.order_id%type;

  function add_line (
    p_order_id    in outbound_order_line.order_id%type,
    p_item_id     in outbound_order_line.item_id%type,
    p_qty_ordered in outbound_order_line.qty_ordered%type
  ) return outbound_order_line.line_id%type;

  procedure allocate_line (
    p_line_id in outbound_order_line.line_id%type
  );

  procedure allocate_order (
    p_order_id in outbound_order.order_id%type
  );

  procedure cancel_order (
    p_order_id in outbound_order.order_id%type
  );

end pkg_outbound;
/

create or replace package body pkg_outbound as

  function create_order (
    p_order_number       in outbound_order.order_number%type,
    p_customer_id        in outbound_order.customer_id%type,
    p_warehouse_id       in outbound_order.warehouse_id%type,
    p_order_source       in outbound_order.order_source%type default 'MANUAL',
    p_required_ship_date in outbound_order.required_ship_date%type default null,
    p_priority           in outbound_order.priority%type default 'NORMAL'
  ) return outbound_order.order_id%type is
    l_order_id outbound_order.order_id%type;
  begin
    insert into outbound_order (
      order_number, customer_id, warehouse_id, order_source, required_ship_date, priority
    ) values (
      p_order_number, p_customer_id, p_warehouse_id, p_order_source, p_required_ship_date, p_priority
    )
    returning order_id into l_order_id;

    return l_order_id;
  end create_order;

  function add_line (
    p_order_id    in outbound_order_line.order_id%type,
    p_item_id     in outbound_order_line.item_id%type,
    p_qty_ordered in outbound_order_line.qty_ordered%type
  ) return outbound_order_line.line_id%type is
    l_line_id outbound_order_line.line_id%type;
  begin
    insert into outbound_order_line (
      order_id, item_id, qty_ordered
    ) values (
      p_order_id, p_item_id, p_qty_ordered
    )
    returning line_id into l_line_id;

    return l_line_id;
  end add_line;

  procedure allocate_line (
    p_line_id in outbound_order_line.line_id%type
  ) is
    l_order_id      outbound_order_line.order_id%type;
    l_warehouse_id  outbound_order.warehouse_id%type;
    l_item_id       outbound_order_line.item_id%type;
    l_qty_ordered   outbound_order_line.qty_ordered%type;
    l_qty_allocated outbound_order_line.qty_allocated%type;
    l_remaining     number;
    l_take          number;
    l_next_seq      number;

    -- FR-07: exclude lots not yet passed QC and stock under an active quality hold.
    cursor c_candidates is
      select ib.location_id, ib.lot_id, ib.qty_available
        from inventory_balance ib
        join location l on l.location_id = ib.location_id
       where ib.item_id = l_item_id
         and ib.qty_available > 0
         and l.warehouse_id = l_warehouse_id
         and l.location_type in ('PICK_FACE', 'BULK')
         and (ib.lot_id is null or exists (
               select 1 from lot lt where lt.lot_id = ib.lot_id and lt.qc_status = 'PASSED'
             ))
         and not exists (
               select 1 from quality_hold qh
                where qh.item_id = ib.item_id
                  and qh.status = 'ACTIVE'
                  and (qh.lot_id is null or qh.lot_id = ib.lot_id)
                  and (qh.location_id is null or qh.location_id = ib.location_id)
             )
       order by decode(l.location_type, 'PICK_FACE', 1, 'BULK', 2),
                (select lt.expiry_date from lot lt where lt.lot_id = ib.lot_id) nulls last,
                ib.location_id;
  begin
    select ol.order_id, ol.item_id, ol.qty_ordered, ol.qty_allocated, o.warehouse_id
      into l_order_id, l_item_id, l_qty_ordered, l_qty_allocated, l_warehouse_id
      from outbound_order_line ol
      join outbound_order o on o.order_id = ol.order_id
     where ol.line_id = p_line_id;

    l_remaining := l_qty_ordered - l_qty_allocated;
    if l_remaining <= 0 then
      return;
    end if;

    select nvl(max(sequence_no), 0) + 10 into l_next_seq
      from pick_task
     where order_line_id = p_line_id;

    for r in c_candidates loop
      exit when l_remaining <= 0;
      l_take := least(l_remaining, r.qty_available);

      pkg_inventory.allocate(
        p_item_id => l_item_id, p_location_id => r.location_id, p_lot_id => r.lot_id, p_qty => l_take
      );

      insert into pick_task (
        order_line_id, item_id, lot_id, from_location_id, qty_requested, sequence_no
      ) values (
        p_line_id, l_item_id, r.lot_id, r.location_id, l_take, l_next_seq
      );

      l_next_seq := l_next_seq + 10;
      l_qty_allocated := l_qty_allocated + l_take;
      l_remaining := l_remaining - l_take;
    end loop;

    update outbound_order_line
       set qty_allocated = l_qty_allocated,
           status = case
                       when l_qty_allocated >= l_qty_ordered then 'ALLOCATED'
                       when l_qty_allocated > 0 then 'PENDING'
                       else 'SHORT'
                     end,
           updated_by = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
           updated_on = sysdate
     where line_id = p_line_id;
  end allocate_line;

  procedure allocate_order (
    p_order_id in outbound_order.order_id%type
  ) is
    l_unallocated_lines number;
  begin
    for r in (select line_id from outbound_order_line where order_id = p_order_id and status <> 'CANCELLED') loop
      allocate_line(r.line_id);
    end loop;

    select count(*) into l_unallocated_lines
      from outbound_order_line
     where order_id = p_order_id
       and status not in ('ALLOCATED', 'CANCELLED');

    if l_unallocated_lines = 0 then
      update outbound_order
         set status = 'ALLOCATED',
             updated_by = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
             updated_on = sysdate
       where order_id = p_order_id;
    end if;
  end allocate_order;

  procedure cancel_order (
    p_order_id in outbound_order.order_id%type
  ) is
  begin
    for r in (
      select t.task_id, t.item_id, t.lot_id, t.from_location_id, t.qty_requested - t.qty_picked as qty_open
        from pick_task t
        join outbound_order_line ol on ol.line_id = t.order_line_id
       where ol.order_id = p_order_id
         and t.status not in ('PICKED', 'CANCELLED')
    ) loop
      if r.qty_open > 0 then
        pkg_inventory.release_allocation(
          p_item_id => r.item_id, p_location_id => r.from_location_id, p_lot_id => r.lot_id, p_qty => r.qty_open
        );
      end if;
      update pick_task set status = 'CANCELLED' where task_id = r.task_id;
    end loop;

    update outbound_order_line
       set status = 'CANCELLED'
     where order_id = p_order_id
       and status <> 'CANCELLED';

    update outbound_order
       set status = 'CANCELLED',
           updated_by = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
           updated_on = sysdate
     where order_id = p_order_id;

    if sql%rowcount = 0 then
      raise_application_error(-20050, 'Outbound order not found: order_id=' || p_order_id);
    end if;
  end cancel_order;

end pkg_outbound;
/
