-- FR-01/FR-05: CRUD API for warehouse storage locations (bins).

set define off

create or replace package pkg_location as

  function create_location (
    p_warehouse_id  in location.warehouse_id%type,
    p_location_code in location.location_code%type,
    p_location_type in location.location_type%type default 'BULK',
    p_zone          in location.zone%type default null,
    p_aisle         in location.aisle%type default null,
    p_rack          in location.rack%type default null,
    p_shelf         in location.shelf%type default null,
    p_capacity_uom  in location.capacity_uom%type default null,
    p_capacity_qty  in location.capacity_qty%type default null
  ) return location.location_id%type;

  procedure update_location (
    p_location_id   in location.location_id%type,
    p_location_type in location.location_type%type default null,
    p_zone          in location.zone%type default null,
    p_aisle         in location.aisle%type default null,
    p_rack          in location.rack%type default null,
    p_shelf         in location.shelf%type default null,
    p_capacity_uom  in location.capacity_uom%type default null,
    p_capacity_qty  in location.capacity_qty%type default null
  );

  procedure set_active (
    p_location_id in location.location_id%type,
    p_is_active   in location.is_active%type
  );

end pkg_location;
/

create or replace package body pkg_location as

  function create_location (
    p_warehouse_id  in location.warehouse_id%type,
    p_location_code in location.location_code%type,
    p_location_type in location.location_type%type default 'BULK',
    p_zone          in location.zone%type default null,
    p_aisle         in location.aisle%type default null,
    p_rack          in location.rack%type default null,
    p_shelf         in location.shelf%type default null,
    p_capacity_uom  in location.capacity_uom%type default null,
    p_capacity_qty  in location.capacity_qty%type default null
  ) return location.location_id%type is
    l_location_id location.location_id%type;
  begin
    insert into location (
      warehouse_id, location_code, location_type, zone, aisle, shelf, rack, capacity_uom, capacity_qty
    ) values (
      p_warehouse_id, upper(p_location_code), p_location_type, p_zone, p_aisle, p_shelf, p_rack, p_capacity_uom, p_capacity_qty
    )
    returning location_id into l_location_id;

    return l_location_id;
  end create_location;

  procedure update_location (
    p_location_id   in location.location_id%type,
    p_location_type in location.location_type%type default null,
    p_zone          in location.zone%type default null,
    p_aisle         in location.aisle%type default null,
    p_rack          in location.rack%type default null,
    p_shelf         in location.shelf%type default null,
    p_capacity_uom  in location.capacity_uom%type default null,
    p_capacity_qty  in location.capacity_qty%type default null
  ) is
  begin
    update location
       set location_type = nvl(p_location_type, location_type),
           zone           = nvl(p_zone, zone),
           aisle          = nvl(p_aisle, aisle),
           rack           = nvl(p_rack, rack),
           shelf          = nvl(p_shelf, shelf),
           capacity_uom   = nvl(p_capacity_uom, capacity_uom),
           capacity_qty   = nvl(p_capacity_qty, capacity_qty),
           updated_by     = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
           updated_on     = sysdate
     where location_id = p_location_id;

    if sql%rowcount = 0 then
      raise_application_error(-20020, 'Location not found: location_id=' || p_location_id);
    end if;
  end update_location;

  procedure set_active (
    p_location_id in location.location_id%type,
    p_is_active   in location.is_active%type
  ) is
  begin
    update location
       set is_active  = p_is_active,
           updated_by = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
           updated_on = sysdate
     where location_id = p_location_id;

    if sql%rowcount = 0 then
      raise_application_error(-20020, 'Location not found: location_id=' || p_location_id);
    end if;
  end set_active;

end pkg_location;
/
