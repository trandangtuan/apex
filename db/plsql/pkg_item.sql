-- FR-01: CRUD API for the item / SKU catalog.
-- (comment-only change: CI deploy pipeline smoke test)

set define off

create or replace package pkg_item as

  function create_item (
    p_item_code           in item.item_code%type,
    p_item_name           in item.item_name%type,
    p_device_category     in item.device_category%type,
    p_uom                 in item.uom%type default 'EA',
    p_barcode_value       in item.barcode_value%type default null,
    p_qr_value            in item.qr_value%type default null,
    p_manufacturer        in item.manufacturer%type default null,
    p_model_no            in item.model_no%type default null,
    p_is_lot_tracked      in item.is_lot_tracked%type default 'Y',
    p_reorder_point       in item.reorder_point%type default 0,
    p_default_supplier_id in item.default_supplier_id%type default null
  ) return item.item_id%type;

  procedure update_item (
    p_item_id         in item.item_id%type,
    p_item_name       in item.item_name%type default null,
    p_device_category in item.device_category%type default null,
    p_uom             in item.uom%type default null,
    p_barcode_value   in item.barcode_value%type default null,
    p_qr_value        in item.qr_value%type default null,
    p_manufacturer    in item.manufacturer%type default null,
    p_model_no        in item.model_no%type default null,
    p_reorder_point   in item.reorder_point%type default null
  );

  procedure set_active (
    p_item_id    in item.item_id%type,
    p_is_active  in item.is_active%type
  );

end pkg_item;
/

create or replace package body pkg_item as

  function create_item (
    p_item_code           in item.item_code%type,
    p_item_name           in item.item_name%type,
    p_device_category     in item.device_category%type,
    p_uom                 in item.uom%type default 'EA',
    p_barcode_value       in item.barcode_value%type default null,
    p_qr_value            in item.qr_value%type default null,
    p_manufacturer        in item.manufacturer%type default null,
    p_model_no            in item.model_no%type default null,
    p_is_lot_tracked      in item.is_lot_tracked%type default 'Y',
    p_reorder_point       in item.reorder_point%type default 0,
    p_default_supplier_id in item.default_supplier_id%type default null
  ) return item.item_id%type is
    l_item_id item.item_id%type;
  begin
    insert into item (
      item_code, item_name, device_category, uom, barcode_value, qr_value,
      manufacturer, model_no, is_lot_tracked, reorder_point, default_supplier_id
    ) values (
      upper(p_item_code), p_item_name, p_device_category, p_uom, p_barcode_value, p_qr_value,
      p_manufacturer, p_model_no, p_is_lot_tracked, p_reorder_point, p_default_supplier_id
    )
    returning item_id into l_item_id;

    return l_item_id;
  end create_item;

  procedure update_item (
    p_item_id         in item.item_id%type,
    p_item_name       in item.item_name%type default null,
    p_device_category in item.device_category%type default null,
    p_uom             in item.uom%type default null,
    p_barcode_value   in item.barcode_value%type default null,
    p_qr_value        in item.qr_value%type default null,
    p_manufacturer    in item.manufacturer%type default null,
    p_model_no        in item.model_no%type default null,
    p_reorder_point   in item.reorder_point%type default null
  ) is
  begin
    update item
       set item_name       = nvl(p_item_name, item_name),
           device_category = nvl(p_device_category, device_category),
           uom              = nvl(p_uom, uom),
           barcode_value    = nvl(p_barcode_value, barcode_value),
           qr_value         = nvl(p_qr_value, qr_value),
           manufacturer     = nvl(p_manufacturer, manufacturer),
           model_no         = nvl(p_model_no, model_no),
           reorder_point    = nvl(p_reorder_point, reorder_point),
           updated_by       = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
           updated_on       = sysdate
     where item_id = p_item_id;

    if sql%rowcount = 0 then
      raise_application_error(-20010, 'Item not found: item_id=' || p_item_id);
    end if;
  end update_item;

  procedure set_active (
    p_item_id    in item.item_id%type,
    p_is_active  in item.is_active%type
  ) is
  begin
    update item
       set is_active  = p_is_active,
           updated_by = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
           updated_on = sysdate
     where item_id = p_item_id;

    if sql%rowcount = 0 then
      raise_application_error(-20010, 'Item not found: item_id=' || p_item_id);
    end if;
  end set_active;

end pkg_item;
/
