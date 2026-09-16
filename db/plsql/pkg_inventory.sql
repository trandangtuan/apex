-- FR-01/FR-06: single choke point for every INVENTORY_BALANCE mutation.
-- Every future module (inbound, outbound, quality, cycle count) must call
-- pkg_inventory.post_transaction / allocate / release_allocation instead of
-- updating INVENTORY_BALANCE directly, so INVENTORY_TRANSACTION stays a
-- complete, trustworthy ledger.

set define off

create or replace package pkg_inventory as

  procedure post_transaction (
    p_item_id         in item.item_id%type,
    p_location_id     in location.location_id%type,
    p_lot_id          in lot.lot_id%type default null,
    p_txn_type        in inventory_transaction.txn_type%type,
    p_qty             in inventory_transaction.qty%type,
    p_source_doc_type in inventory_transaction.source_doc_type%type default null,
    p_source_doc_id   in inventory_transaction.source_doc_id%type default null,
    p_notes           in inventory_transaction.notes%type default null
  );

  procedure allocate (
    p_item_id     in item.item_id%type,
    p_location_id in location.location_id%type,
    p_lot_id      in lot.lot_id%type default null,
    p_qty         in number
  );

  procedure release_allocation (
    p_item_id     in item.item_id%type,
    p_location_id in location.location_id%type,
    p_lot_id      in lot.lot_id%type default null,
    p_qty         in number
  );

  function qty_on_hand (
    p_item_id     in item.item_id%type,
    p_location_id in location.location_id%type,
    p_lot_id      in lot.lot_id%type default null
  ) return number;

  function qty_available (
    p_item_id     in item.item_id%type,
    p_location_id in location.location_id%type,
    p_lot_id      in lot.lot_id%type default null
  ) return number;

  -- Resolves the single active location of a given type for a warehouse
  -- (e.g. RECEIVING dock, SHIPPING staging area). Raises an error if none
  -- is configured, so callers fail fast instead of posting to a wrong bin.
  function get_location_by_type (
    p_warehouse_id  in warehouse.warehouse_id%type,
    p_location_type in location.location_type%type
  ) return location.location_id%type;

end pkg_inventory;
/

create or replace package body pkg_inventory as

  procedure post_transaction (
    p_item_id         in item.item_id%type,
    p_location_id     in location.location_id%type,
    p_lot_id          in lot.lot_id%type default null,
    p_txn_type        in inventory_transaction.txn_type%type,
    p_qty             in inventory_transaction.qty%type,
    p_source_doc_type in inventory_transaction.source_doc_type%type default null,
    p_source_doc_id   in inventory_transaction.source_doc_id%type default null,
    p_notes           in inventory_transaction.notes%type default null
  ) is
    l_current_qty inventory_balance.qty_on_hand%type;
  begin
    if p_qty < 0 then
      begin
        select qty_on_hand into l_current_qty
          from inventory_balance
         where item_id = p_item_id
           and location_id = p_location_id
           and lot_id_key = nvl(p_lot_id, 0)
           for update;
      exception
        when no_data_found then
          l_current_qty := 0;
      end;
      if l_current_qty + p_qty < 0 then
        raise_application_error(-20001,
          'Insufficient quantity on hand for item_id=' || p_item_id ||
          ', location_id=' || p_location_id ||
          ' (on hand ' || l_current_qty || ', requested ' || abs(p_qty) || ')');
      end if;
    end if;

    insert into inventory_transaction (
      item_id, location_id, lot_id, txn_type, qty, source_doc_type, source_doc_id, notes
    ) values (
      p_item_id, p_location_id, p_lot_id, p_txn_type, p_qty, p_source_doc_type, p_source_doc_id, p_notes
    );

    merge into inventory_balance ib
    using (select p_item_id as item_id, p_location_id as location_id, p_lot_id as lot_id from dual) src
       on (ib.item_id = src.item_id and ib.location_id = src.location_id and ib.lot_id_key = nvl(src.lot_id, 0))
     when matched then
       update set ib.qty_on_hand = ib.qty_on_hand + p_qty,
                   ib.updated_on = sysdate
     when not matched then
       insert (item_id, location_id, lot_id, qty_on_hand)
       values (src.item_id, src.location_id, src.lot_id, p_qty);
  end post_transaction;

  procedure allocate (
    p_item_id     in item.item_id%type,
    p_location_id in location.location_id%type,
    p_lot_id      in lot.lot_id%type default null,
    p_qty         in number
  ) is
  begin
    update inventory_balance
       set qty_allocated = qty_allocated + p_qty,
           updated_on = sysdate
     where item_id = p_item_id
       and location_id = p_location_id
       and lot_id_key = nvl(p_lot_id, 0);

    if sql%rowcount = 0 then
      raise_application_error(-20002,
        'No inventory balance row found to allocate for item_id=' || p_item_id ||
        ', location_id=' || p_location_id);
    end if;
  end allocate;

  procedure release_allocation (
    p_item_id     in item.item_id%type,
    p_location_id in location.location_id%type,
    p_lot_id      in lot.lot_id%type default null,
    p_qty         in number
  ) is
  begin
    update inventory_balance
       set qty_allocated = qty_allocated - p_qty,
           updated_on = sysdate
     where item_id = p_item_id
       and location_id = p_location_id
       and lot_id_key = nvl(p_lot_id, 0);

    if sql%rowcount = 0 then
      raise_application_error(-20002,
        'No inventory balance row found to release allocation for item_id=' || p_item_id ||
        ', location_id=' || p_location_id);
    end if;
  end release_allocation;

  function qty_on_hand (
    p_item_id     in item.item_id%type,
    p_location_id in location.location_id%type,
    p_lot_id      in lot.lot_id%type default null
  ) return number is
    l_qty number;
  begin
    select qty_on_hand into l_qty
      from inventory_balance
     where item_id = p_item_id
       and location_id = p_location_id
       and lot_id_key = nvl(p_lot_id, 0);
    return l_qty;
  exception
    when no_data_found then
      return 0;
  end qty_on_hand;

  function qty_available (
    p_item_id     in item.item_id%type,
    p_location_id in location.location_id%type,
    p_lot_id      in lot.lot_id%type default null
  ) return number is
    l_qty number;
  begin
    select qty_available into l_qty
      from inventory_balance
     where item_id = p_item_id
       and location_id = p_location_id
       and lot_id_key = nvl(p_lot_id, 0);
    return l_qty;
  exception
    when no_data_found then
      return 0;
  end qty_available;

  function get_location_by_type (
    p_warehouse_id  in warehouse.warehouse_id%type,
    p_location_type in location.location_type%type
  ) return location.location_id%type is
    l_location_id location.location_id%type;
  begin
    select location_id into l_location_id
      from location
     where warehouse_id = p_warehouse_id
       and location_type = p_location_type
       and is_active = 'Y'
       and rownum = 1;
    return l_location_id;
  exception
    when no_data_found then
      raise_application_error(-20003,
        'No active ' || p_location_type || ' location configured for warehouse_id=' || p_warehouse_id);
  end get_location_by_type;

end pkg_inventory;
/
