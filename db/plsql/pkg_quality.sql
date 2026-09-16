-- FR-07: quality management API. record_inspection drives LOT.qc_status
-- through the existing PKG_LOT transition rules, so quality decisions stay
-- centralized. place_hold/release_hold manage finer-grained holds that
-- PKG_OUTBOUND.allocate_line checks before reserving any stock.

set define off

create or replace package pkg_quality as

  function record_inspection (
    p_source_type in quality_inspection.source_type%type,
    p_item_id      in quality_inspection.item_id%type,
    p_result       in quality_inspection.result%type,
    p_source_id    in quality_inspection.source_id%type default null,
    p_lot_id       in quality_inspection.lot_id%type default null,
    p_defect_code  in quality_inspection.defect_code%type default null,
    p_notes        in quality_inspection.notes%type default null
  ) return quality_inspection.inspection_id%type;

  function place_hold (
    p_item_id     in quality_hold.item_id%type,
    p_reason      in quality_hold.reason%type,
    p_lot_id      in quality_hold.lot_id%type default null,
    p_location_id in quality_hold.location_id%type default null
  ) return quality_hold.hold_id%type;

  procedure release_hold (
    p_hold_id in quality_hold.hold_id%type
  );

end pkg_quality;
/

create or replace package body pkg_quality as

  function record_inspection (
    p_source_type in quality_inspection.source_type%type,
    p_item_id      in quality_inspection.item_id%type,
    p_result       in quality_inspection.result%type,
    p_source_id    in quality_inspection.source_id%type default null,
    p_lot_id       in quality_inspection.lot_id%type default null,
    p_defect_code  in quality_inspection.defect_code%type default null,
    p_notes        in quality_inspection.notes%type default null
  ) return quality_inspection.inspection_id%type is
    l_inspection_id quality_inspection.inspection_id%type;
  begin
    insert into quality_inspection (
      source_type, source_id, item_id, lot_id, result, defect_code, notes
    ) values (
      p_source_type, p_source_id, p_item_id, p_lot_id, p_result, p_defect_code, p_notes
    )
    returning inspection_id into l_inspection_id;

    if p_lot_id is not null then
      case p_result
        when 'PASS' then pkg_lot.set_qc_status(p_lot_id => p_lot_id, p_qc_status => 'PASSED');
        when 'FAIL' then pkg_lot.set_qc_status(p_lot_id => p_lot_id, p_qc_status => 'FAILED');
        else null; -- CONDITIONAL: leave qc_status as-is, expect a manual hold via place_hold
      end case;
    end if;

    return l_inspection_id;
  end record_inspection;

  function place_hold (
    p_item_id     in quality_hold.item_id%type,
    p_reason      in quality_hold.reason%type,
    p_lot_id      in quality_hold.lot_id%type default null,
    p_location_id in quality_hold.location_id%type default null
  ) return quality_hold.hold_id%type is
    l_hold_id quality_hold.hold_id%type;
  begin
    insert into quality_hold (
      item_id, lot_id, location_id, reason
    ) values (
      p_item_id, p_lot_id, p_location_id, p_reason
    )
    returning hold_id into l_hold_id;

    return l_hold_id;
  end place_hold;

  procedure release_hold (
    p_hold_id in quality_hold.hold_id%type
  ) is
  begin
    update quality_hold
       set status       = 'RELEASED',
           released_by  = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
           release_date = sysdate
     where hold_id = p_hold_id
       and status = 'ACTIVE';

    if sql%rowcount = 0 then
      raise_application_error(-20090,
        'Quality hold not found or already released: hold_id=' || p_hold_id);
    end if;
  end release_hold;

end pkg_quality;
/
