-- FR-09: inbound integration (e-shop order import). stage_payload is
-- idempotent on IDEMPOTENCY_KEY so a retried webhook/API call is a no-op
-- instead of creating a duplicate order. apply_order_import parses the
-- staged JSON and drives the same PKG_OUTBOUND API a manual order would
-- use, so imported orders get identical allocation behavior. Errors are
-- recorded on the log row via an autonomous transaction, then re-raised,
-- so the failure is visible even though the partially-created order rolls
-- back with the caller's transaction.

set define off

create or replace package pkg_integration_in as

  function stage_payload (
    p_integration_type in integration_log.integration_type%type,
    p_payload           in integration_log.payload%type,
    p_idempotency_key   in integration_log.idempotency_key%type default null
  ) return integration_log.log_id%type;

  function apply_order_import (
    p_log_id in integration_log.log_id%type
  ) return outbound_order.order_id%type;

end pkg_integration_in;
/

create or replace package body pkg_integration_in as

  -- Autonomous transaction pragma is only valid on a schema-level or
  -- packaged subprogram, not on a block nested inside an exception
  -- handler, hence this private helper.
  procedure log_error (
    p_log_id in integration_log.log_id%type,
    p_error  in varchar2
  ) is
    pragma autonomous_transaction;
  begin
    update integration_log
       set status = 'ERROR',
           error_message = p_error
     where log_id = p_log_id;
    commit;
  end log_error;

  function stage_payload (
    p_integration_type in integration_log.integration_type%type,
    p_payload           in integration_log.payload%type,
    p_idempotency_key   in integration_log.idempotency_key%type default null
  ) return integration_log.log_id%type is
    -- Autonomous + committed on purpose: durably acknowledging "we received
    -- this payload" must survive even if the caller's own transaction (or a
    -- later apply_order_import call in the same transaction) rolls back or
    -- errors. It also avoids leaving a row lock that would make log_error's
    -- autonomous UPDATE self-deadlock (ORA-00060) if apply runs right after.
    pragma autonomous_transaction;
    l_log_id integration_log.log_id%type;
  begin
    if p_idempotency_key is not null then
      begin
        select log_id into l_log_id
          from integration_log
         where idempotency_key = p_idempotency_key;
        commit;
        return l_log_id;
      exception
        when no_data_found then
          null;
      end;
    end if;

    insert into integration_log (
      direction, integration_type, payload, status, idempotency_key
    ) values (
      'INBOUND', p_integration_type, p_payload, 'RECEIVED', p_idempotency_key
    )
    returning log_id into l_log_id;

    commit;
    return l_log_id;
  end stage_payload;

  function apply_order_import (
    p_log_id in integration_log.log_id%type
  ) return outbound_order.order_id%type is
    l_payload         integration_log.payload%type;
    l_status          integration_log.status%type;
    l_order_number    outbound_order.order_number%type;
    l_customer_code   varchar2(20);
    l_warehouse_code  varchar2(10);
    l_required_ship   varchar2(20);
    l_customer_id     customer.customer_id%type;
    l_warehouse_id    warehouse.warehouse_id%type;
    l_order_id        outbound_order.order_id%type;
    l_line_count      pls_integer;
  begin
    -- No FOR UPDATE here: log_error() below updates this same row through an
    -- autonomous transaction on error, and holding a row lock in the main
    -- transaction would make that update self-deadlock (ORA-00060).
    select payload, status into l_payload, l_status
      from integration_log
     where log_id = p_log_id;

    if l_status <> 'RECEIVED' then
      raise_application_error(-20100,
        'integration_log log_id=' || p_log_id || ' is not in RECEIVED status (status=' || l_status || ')');
    end if;

    apex_json.parse(l_payload);

    l_order_number   := apex_json.get_varchar2(p_path => 'order_number');
    l_customer_code  := apex_json.get_varchar2(p_path => 'customer_code');
    l_warehouse_code := apex_json.get_varchar2(p_path => 'warehouse_code');
    l_required_ship  := apex_json.get_varchar2(p_path => 'required_ship_date');

    begin
      select customer_id into l_customer_id from customer where customer_code = l_customer_code;
    exception
      when no_data_found then
        raise_application_error(-20101, 'Unknown customer_code in payload: ' || l_customer_code);
    end;

    begin
      select warehouse_id into l_warehouse_id from warehouse where warehouse_code = l_warehouse_code;
    exception
      when no_data_found then
        raise_application_error(-20102, 'Unknown warehouse_code in payload: ' || l_warehouse_code);
    end;

    l_order_id := pkg_outbound.create_order(
      p_order_number        => l_order_number,
      p_customer_id         => l_customer_id,
      p_warehouse_id        => l_warehouse_id,
      p_order_source        => 'ESHOP_API',
      p_required_ship_date  => case when l_required_ship is not null then to_date(l_required_ship, 'YYYY-MM-DD') end
    );

    l_line_count := apex_json.get_count(p_path => 'lines');
    for i in 1 .. nvl(l_line_count, 0) loop
      declare
        l_item_code varchar2(30) := apex_json.get_varchar2(p_path => 'lines[%d].item_code', p0 => i);
        l_qty       number := apex_json.get_number(p_path => 'lines[%d].qty', p0 => i);
        l_item_id   item.item_id%type;
        l_line_id   outbound_order_line.line_id%type;
      begin
        begin
          select item_id into l_item_id from item where item_code = l_item_code;
        exception
          when no_data_found then
            raise_application_error(-20103, 'Unknown item_code in payload: ' || l_item_code);
        end;
        l_line_id := pkg_outbound.add_line(p_order_id => l_order_id, p_item_id => l_item_id, p_qty_ordered => l_qty);
      end;
    end loop;

    pkg_outbound.allocate_order(p_order_id => l_order_id);

    update integration_log
       set status = 'PROCESSED',
           related_order_id = l_order_id
     where log_id = p_log_id;

    return l_order_id;
  exception
    when others then
      log_error(p_log_id, substr(sqlerrm, 1, 4000));
      raise;
  end apply_order_import;

end pkg_integration_in;
/
