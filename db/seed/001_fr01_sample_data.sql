-- Sample/demo data for FR-01 tables (supplier, warehouse, location, item, lot, inventory_balance)
-- Safe to run once against an empty ADMIN schema after 001_fr01_inventory_master.sql

set define off

insert into supplier (supplier_code, supplier_name, contact_email)
values ('SUP-001','IDEMIA Slovakia s.r.o.','sales@idemia.example');

insert into warehouse (warehouse_code, warehouse_name, address)
values ('WH-BA','Bratislava Central Warehouse','Logisticka 1, Bratislava');

insert into location (warehouse_id, location_code, zone, aisle, rack, shelf, location_type)
  select warehouse_id, 'REC-01', 'RECEIVING', null, null, null, 'RECEIVING' from warehouse where warehouse_code='WH-BA';
insert into location (warehouse_id, location_code, zone, aisle, rack, shelf, location_type)
  select warehouse_id, 'A-01-01', 'A', '01', '01', '1', 'PICK_FACE' from warehouse where warehouse_code='WH-BA';
insert into location (warehouse_id, location_code, zone, aisle, rack, shelf, location_type)
  select warehouse_id, 'A-01-02', 'A', '01', '02', '1', 'PICK_FACE' from warehouse where warehouse_code='WH-BA';

insert into item (item_code, item_name, device_category, is_lot_tracked, barcode_value, default_supplier_id)
  select 'BIO-RDR-001','Biometric Fingerprint Reader X200','BIOMETRIC_READER','Y','8901234500017', supplier_id from supplier where supplier_code='SUP-001';
insert into item (item_code, item_name, device_category, is_lot_tracked, barcode_value)
  values ('MON-24-001','24-inch LED Monitor','MONITOR','N','8901234500024');
insert into item (item_code, item_name, device_category, is_lot_tracked, barcode_value)
  values ('TAB-10-001','10-inch Android Tablet','TABLET','Y','8901234500031');
insert into item (item_code, item_name, device_category, is_lot_tracked, barcode_value)
  values ('SPK-BT-001','Bluetooth Warehouse Speaker','SPEAKER','N','8901234500048');
insert into item (item_code, item_name, device_category, is_lot_tracked, barcode_value)
  values ('EPO-43-001','43-inch E-Poster Display','E_POSTER','N','8901234500055');

insert into lot (item_id, lot_number, manufacture_date, qc_status)
  select item_id, 'LOT-2026-001', date '2026-06-05', 'PASSED' from item where item_code='BIO-RDR-001';
insert into lot (item_id, lot_number, manufacture_date, qc_status)
  select item_id, 'LOT-2026-002', date '2026-06-10', 'PENDING' from item where item_code='TAB-10-001';

insert into inventory_balance (item_id, location_id, lot_id, qty_on_hand, qty_allocated)
  select i.item_id, l.location_id, lt.lot_id, 120, 20
  from item i, location l, lot lt
  where i.item_code='BIO-RDR-001' and l.location_code='A-01-01' and lt.lot_number='LOT-2026-001';

insert into inventory_balance (item_id, location_id, lot_id, qty_on_hand, qty_allocated)
  select i.item_id, l.location_id, null, 50, 0
  from item i, location l
  where i.item_code='MON-24-001' and l.location_code='A-01-02';

insert into inventory_balance (item_id, location_id, lot_id, qty_on_hand, qty_allocated)
  select i.item_id, l.location_id, null, 15, 0
  from item i, location l
  where i.item_code='MON-24-001' and l.location_code='REC-01';

commit;
