-- FR-04: packing. Builds package lines directly from PICKED pick tasks so
-- a line fulfilled from multiple lots ends up as multiple package lines
-- with the correct lot each, instead of guessing one lot per order line.

set define off

create or replace package pkg_packing as

  function pack_order (
    p_order_id in outbound_order.order_id%type
  ) return ship_package.package_id%type;

end pkg_packing;
/

create or replace package body pkg_packing as

  function pack_order (
    p_order_id in outbound_order.order_id%type
  ) return ship_package.package_id%type is
    l_package_id  ship_package.package_id%type;
    l_open_lines  number;
  begin
    select count(*) into l_open_lines
      from outbound_order_line
     where order_id = p_order_id
       and status not in ('PICKED', 'CANCELLED');

    if l_open_lines > 0 then
      raise_application_error(-20070,
        'Cannot pack order_id=' || p_order_id || ': ' || l_open_lines || ' line(s) not fully picked');
    end if;

    insert into ship_package (order_id, status, packed_by)
    values (p_order_id, 'PACKED', coalesce(sys_context('APEX$SESSION','APP_USER'), user))
    returning package_id into l_package_id;

    insert into ship_package_line (package_id, order_line_id, item_id, lot_id, qty)
    select l_package_id, t.order_line_id, t.item_id, t.lot_id, t.qty_picked
      from pick_task t
      join outbound_order_line ol on ol.line_id = t.order_line_id
     where ol.order_id = p_order_id
       and t.status = 'PICKED';

    update outbound_order
       set status = 'PACKED',
           updated_by = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
           updated_on = sysdate
     where order_id = p_order_id;

    return l_package_id;
  end pack_order;

end pkg_packing;
/
