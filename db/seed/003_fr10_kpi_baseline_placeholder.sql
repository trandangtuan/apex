-- PLACEHOLDER / FAKE demo data for the 3 OIP KPIs (FR-10).
-- Replace these rows with real measured figures before UAT/final report --
-- see BASELINE_NOTE and IS_PLACEHOLDER on each row.

set define off

insert into kpi_baseline (
    kpi_code, kpi_name, unit, direction, baseline_value,
    baseline_measured_from, baseline_measured_to, baseline_note, target_value, oip_ref, is_placeholder
) values (
    'INV_DELIVERY_ACCURACY', 'Inventory and delivery accuracy', '%', 'HIGHER', 90,
    null, null, 'PLACEHOLDER: fake demo value, not measured. Replace with a real pre-system baseline before UAT.', 97,
    'OIP: minimum 97% inventory and delivery accuracy', 'Y'
);

insert into kpi_baseline (
    kpi_code, kpi_name, unit, direction, baseline_value,
    baseline_measured_from, baseline_measured_to, baseline_note, target_value, oip_ref, is_placeholder
) values (
    'ORDER_CYCLE_TIME', 'Order processing time', 'hours', 'LOWER', 48,
    null, null, 'PLACEHOLDER: fake demo value, not measured. Replace with a real pre-system baseline before UAT.', 36,
    'OIP: reduce order processing time by at least 25%', 'Y'
);

insert into kpi_baseline (
    kpi_code, kpi_name, unit, direction, baseline_value,
    baseline_measured_from, baseline_measured_to, baseline_note, target_value, oip_ref, is_placeholder
) values (
    'ERROR_RATE', 'Operational error rate', 'errors per 100 lines shipped', 'LOWER', 6,
    null, null, 'PLACEHOLDER: fake demo value, not measured. Replace with a real pre-system baseline before UAT.', 4.2,
    'OIP: reduce operating cost / error count by 25-30%', 'Y'
);

commit;
