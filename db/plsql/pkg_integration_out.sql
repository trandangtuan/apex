-- FR-09: outbound integration events (order status -> future e-shop/accounting).
-- Builds a JSON snapshot via APEX_JSON and stages it in INTEGRATION_LOG;
-- actually delivering it to an external system is out of scope until a real
-- endpoint exists (see INTEGRATION_ENDPOINT_CONFIG).

set define off

create or replace package pkg_integration_out as

  function publish_order_event (
    p_order_id in outbound_order.order_id%type
  ) return integration_log.log_id%type;

end pkg_integration_out;
/

create or replace package body pkg_integration_out as

  function publish_order_event (
    p_order_id in outbound_order.order_id%type
  ) return integration_log.log_id%type is
    l_log_id  integration_log.log_id%type;
    l_payload clob;
  begin
    apex_json.initialize_clob_output;
    apex_json.open_object;

    for r in (
      select o.order_number, o.status, c.customer_code
        from outbound_order o
        join customer c on c.customer_id = o.customer_id
       where o.order_id = p_order_id
    ) loop
      apex_json.write('order_number', r.order_number);
      apex_json.write('status', r.status);
      apex_json.write('customer_code', r.customer_code);
    end loop;

    apex_json.open_array('lines');
    for r in (
      select i.item_code, ol.qty_ordered, ol.qty_shipped
        from outbound_order_line ol
        join item i on i.item_id = ol.item_id
       where ol.order_id = p_order_id
    ) loop
      apex_json.open_object;
      apex_json.write('item_code', r.item_code);
      apex_json.write('qty_ordered', r.qty_ordered);
      apex_json.write('qty_shipped', r.qty_shipped);
      apex_json.close_object;
    end loop;
    apex_json.close_array;

    apex_json.close_object;
    l_payload := apex_json.get_clob_output;
    apex_json.free_output;

    insert into integration_log (
      direction, integration_type, payload, status, related_order_id
    ) values (
      'OUTBOUND', 'ORDER_STATUS', l_payload, 'PROCESSED', p_order_id
    )
    returning log_id into l_log_id;

    return l_log_id;
  end publish_order_event;

end pkg_integration_out;
/
