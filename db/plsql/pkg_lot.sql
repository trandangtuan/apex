-- FR-01/FR-07: CRUD API for item lots/batches, including QC status transitions.
-- QC status starts PENDING; PASSED/FAILED can only be reached from PENDING or
-- from HOLD, and any status can be moved to HOLD. This mirrors the future
-- quality-management workflow (FR-07) and keeps qc_status changes auditable
-- through one entry point instead of ad hoc updates.

set define off

create or replace package pkg_lot as

  function create_lot (
    p_item_id          in lot.item_id%type,
    p_lot_number       in lot.lot_number%type,
    p_supplier_id      in lot.supplier_id%type default null,
    p_manufacture_date in lot.manufacture_date%type default null,
    p_expiry_date      in lot.expiry_date%type default null
  ) return lot.lot_id%type;

  procedure set_qc_status (
    p_lot_id     in lot.lot_id%type,
    p_qc_status  in lot.qc_status%type
  );

end pkg_lot;
/

create or replace package body pkg_lot as

  function create_lot (
    p_item_id          in lot.item_id%type,
    p_lot_number       in lot.lot_number%type,
    p_supplier_id      in lot.supplier_id%type default null,
    p_manufacture_date in lot.manufacture_date%type default null,
    p_expiry_date      in lot.expiry_date%type default null
  ) return lot.lot_id%type is
    l_lot_id lot.lot_id%type;
  begin
    insert into lot (
      item_id, lot_number, supplier_id, manufacture_date, expiry_date
    ) values (
      p_item_id, p_lot_number, p_supplier_id, p_manufacture_date, p_expiry_date
    )
    returning lot_id into l_lot_id;

    return l_lot_id;
  end create_lot;

  procedure set_qc_status (
    p_lot_id    in lot.lot_id%type,
    p_qc_status in lot.qc_status%type
  ) is
    l_current_status lot.qc_status%type;
    l_allowed        boolean := false;
  begin
    select qc_status into l_current_status
      from lot
     where lot_id = p_lot_id
       for update;

    if l_current_status = 'PENDING' and p_qc_status in ('PASSED','FAILED','HOLD') then
      l_allowed := true;
    elsif l_current_status = 'HOLD' and p_qc_status in ('PASSED','FAILED') then
      l_allowed := true;
    elsif l_current_status in ('PASSED','FAILED') and p_qc_status = 'HOLD' then
      l_allowed := true;
    end if;

    if not l_allowed then
      raise_application_error(-20031,
        'Invalid QC status transition for lot_id=' || p_lot_id ||
        ': ' || l_current_status || ' -> ' || p_qc_status);
    end if;

    update lot
       set qc_status  = p_qc_status,
           updated_by = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
           updated_on = sysdate
     where lot_id = p_lot_id;
  exception
    when no_data_found then
      raise_application_error(-20030, 'Lot not found: lot_id=' || p_lot_id);
  end set_qc_status;

end pkg_lot;
/
