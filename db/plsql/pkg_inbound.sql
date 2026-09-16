-- FR-02: automated inbound receiving. Goods are received into the
-- warehouse's RECEIVING dock location first (real-time inventory record),
-- then moved to a final bin via putaway_line. Every stock movement goes
-- through pkg_inventory.post_transaction, so INVENTORY_TRANSACTION stays
-- the single source of truth.

set define off

create or replace package pkg_inbound as

  function create_receipt (
    p_supplier_id   in inbound_receipt.supplier_id%type default null,
    p_po_reference  in inbound_receipt.po_reference%type default null,
    p_warehouse_id  in inbound_receipt.warehouse_id%type,
    p_expected_date in inbound_receipt.expected_date%type default null
  ) return inbound_receipt.receipt_id%type;

  function add_line (
    p_receipt_id   in inbound_receipt_line.receipt_id%type,
    p_item_id      in inbound_receipt_line.item_id%type,
    p_expected_qty in inbound_receipt_line.expected_qty%type,
    p_lot_id       in inbound_receipt_line.lot_id%type default null
  ) return inbound_receipt_line.line_id%type;

  procedure receive_line (
    p_line_id      in inbound_receipt_line.line_id%type,
    p_received_qty in inbound_receipt_line.received_qty%type,
    p_lot_id       in inbound_receipt_line.lot_id%type default null
  );

  procedure putaway_line (
    p_line_id     in inbound_receipt_line.line_id%type,
    p_location_id in location.location_id%type,
    p_qty         in number
  );

  procedure complete_receipt (
    p_receipt_id in inbound_receipt.receipt_id%type
  );

end pkg_inbound;
/

create or replace package body pkg_inbound as

  function create_receipt (
    p_supplier_id   in inbound_receipt.supplier_id%type default null,
    p_po_reference  in inbound_receipt.po_reference%type default null,
    p_warehouse_id  in inbound_receipt.warehouse_id%type,
    p_expected_date in inbound_receipt.expected_date%type default null
  ) return inbound_receipt.receipt_id%type is
    l_receipt_id inbound_receipt.receipt_id%type;
  begin
    insert into inbound_receipt (
      supplier_id, po_reference, warehouse_id, expected_date
    ) values (
      p_supplier_id, p_po_reference, p_warehouse_id, p_expected_date
    )
    returning receipt_id into l_receipt_id;

    return l_receipt_id;
  end create_receipt;

  function add_line (
    p_receipt_id   in inbound_receipt_line.receipt_id%type,
    p_item_id      in inbound_receipt_line.item_id%type,
    p_expected_qty in inbound_receipt_line.expected_qty%type,
    p_lot_id       in inbound_receipt_line.lot_id%type default null
  ) return inbound_receipt_line.line_id%type is
    l_line_id inbound_receipt_line.line_id%type;
  begin
    insert into inbound_receipt_line (
      receipt_id, item_id, lot_id, expected_qty
    ) values (
      p_receipt_id, p_item_id, p_lot_id, p_expected_qty
    )
    returning line_id into l_line_id;

    return l_line_id;
  end add_line;

  procedure receive_line (
    p_line_id      in inbound_receipt_line.line_id%type,
    p_received_qty in inbound_receipt_line.received_qty%type,
    p_lot_id       in inbound_receipt_line.lot_id%type default null
  ) is
    l_receipt_id       inbound_receipt_line.receipt_id%type;
    l_item_id          inbound_receipt_line.item_id%type;
    l_warehouse_id     inbound_receipt.warehouse_id%type;
    l_receiving_loc_id location.location_id%type;
    l_lot_id           inbound_receipt_line.lot_id%type;
  begin
    select rl.receipt_id, rl.item_id, nvl(p_lot_id, rl.lot_id), r.warehouse_id
      into l_receipt_id, l_item_id, l_lot_id, l_warehouse_id
      from inbound_receipt_line rl
      join inbound_receipt r on r.receipt_id = rl.receipt_id
     where rl.line_id = p_line_id;

    l_receiving_loc_id := pkg_inventory.get_location_by_type(l_warehouse_id, 'RECEIVING');

    pkg_inventory.post_transaction(
      p_item_id         => l_item_id,
      p_location_id     => l_receiving_loc_id,
      p_lot_id          => l_lot_id,
      p_txn_type        => 'RECEIPT',
      p_qty             => p_received_qty,
      p_source_doc_type => 'INBOUND_RECEIPT_LINE',
      p_source_doc_id   => p_line_id
    );

    update inbound_receipt_line
       set received_qty = received_qty + p_received_qty,
           lot_id        = l_lot_id,
           status        = 'RECEIVED',
           updated_by    = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
           updated_on    = sysdate
     where line_id = p_line_id;

    update inbound_receipt
       set status     = 'RECEIVING',
           updated_by = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
           updated_on = sysdate
     where receipt_id = l_receipt_id
       and status = 'EXPECTED';
  exception
    when no_data_found then
      raise_application_error(-20041, 'Inbound receipt line not found: line_id=' || p_line_id);
  end receive_line;

  procedure putaway_line (
    p_line_id     in inbound_receipt_line.line_id%type,
    p_location_id in location.location_id%type,
    p_qty         in number
  ) is
    l_item_id          inbound_receipt_line.item_id%type;
    l_lot_id            inbound_receipt_line.lot_id%type;
    l_warehouse_id       inbound_receipt.warehouse_id%type;
    l_receiving_loc_id   location.location_id%type;
  begin
    select rl.item_id, rl.lot_id, r.warehouse_id
      into l_item_id, l_lot_id, l_warehouse_id
      from inbound_receipt_line rl
      join inbound_receipt r on r.receipt_id = rl.receipt_id
     where rl.line_id = p_line_id;

    l_receiving_loc_id := pkg_inventory.get_location_by_type(l_warehouse_id, 'RECEIVING');

    pkg_inventory.post_transaction(
      p_item_id         => l_item_id,
      p_location_id     => l_receiving_loc_id,
      p_lot_id          => l_lot_id,
      p_txn_type        => 'MOVE',
      p_qty             => -p_qty,
      p_source_doc_type => 'INBOUND_RECEIPT_LINE',
      p_source_doc_id   => p_line_id
    );

    pkg_inventory.post_transaction(
      p_item_id         => l_item_id,
      p_location_id     => p_location_id,
      p_lot_id          => l_lot_id,
      p_txn_type        => 'PUTAWAY',
      p_qty             => p_qty,
      p_source_doc_type => 'INBOUND_RECEIPT_LINE',
      p_source_doc_id   => p_line_id
    );

    update inbound_receipt_line
       set putaway_location_id = p_location_id,
           status               = 'PUTAWAY',
           updated_by           = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
           updated_on           = sysdate
     where line_id = p_line_id;
  exception
    when no_data_found then
      raise_application_error(-20041, 'Inbound receipt line not found: line_id=' || p_line_id);
  end putaway_line;

  procedure complete_receipt (
    p_receipt_id in inbound_receipt.receipt_id%type
  ) is
    l_open_lines number;
  begin
    select count(*) into l_open_lines
      from inbound_receipt_line
     where receipt_id = p_receipt_id
       and status not in ('PUTAWAY', 'CANCELLED');

    if l_open_lines > 0 then
      raise_application_error(-20042,
        'Cannot complete receipt_id=' || p_receipt_id || ': ' || l_open_lines ||
        ' line(s) not yet putaway or cancelled');
    end if;

    update inbound_receipt
       set status     = 'COMPLETED',
           updated_by = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
           updated_on = sysdate
     where receipt_id = p_receipt_id;

    if sql%rowcount = 0 then
      raise_application_error(-20043, 'Inbound receipt not found: receipt_id=' || p_receipt_id);
    end if;
  end complete_receipt;

end pkg_inbound;
/
